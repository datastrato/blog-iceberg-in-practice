# Part 2: One table, many engines

A single Gravitino Iceberg REST Catalog, running in **dynamic mode** (the catalog
is created at runtime through Gravitino's management API, not from a static
config file). Spark, Flink, Trino, and DuckDB all read and write the same
`demo.orders` table through it — including two of them writing at the same time.

> **This is a demo rig, not a reference deployment.** Single-node MinIO, a shared
> Postgres instance for everything, no auth, no TLS, no HA. It's built to make
> the REST Catalog's behavior visible, not to model a production topology. Part
> 1 is fully independent of this stack but uses the **same host ports** — bring
> one part down (`docker compose down`) before starting the other.

## Prerequisites

- Docker with Compose v2 (`docker compose version`)
- ~250MB free disk for the fetched jars/binaries, and internet access the first
  time you run it (see below)

## Quickstart

```bash
docker compose up -d
```

This single command brings up MinIO, Postgres, and the Gravitino catalog server,
and — via two one-shot init services — automatically:

- **`jars-init`** fetches and SHA-256-verifies the pinned Spark/Flink/Hadoop/Iceberg
  jars and the DuckDB CLI (see `scripts/fetch-jars.py` for the exact pinned
  versions and hashes). If a download fails or a hash doesn't match, it fails
  loudly with the artifact name and source URL so you can fetch it by hand.
- **`schema-init`** creates the two Postgres databases Gravitino needs and loads
  its entity-store schema — see [Gotchas](#gotchas) below for why this step exists.

Wait for `catalog-dynamic` to report healthy:

```bash
docker compose ps catalog-dynamic
```

Then create the metalake and the `lake` catalog — this is the part that's
deliberately **not** automated, because seeing it happen is the point of this
demo:

```bash
./scripts/create-catalog.sh
```

or by hand, the same two curls it runs:

```bash
curl -X POST -H 'Accept: application/vnd.gravitino.v1+json' -H 'Content-Type: application/json' \
  -d '{"name": "demo_metalake", "comment": "iceberg-in-practice dynamic-mode rig"}' \
  http://localhost:8090/api/metalakes

curl -X POST -H 'Accept: application/vnd.gravitino.v1+json' -H 'Content-Type: application/json' \
  -d '{"name": "lake", "type": "RELATIONAL", "provider": "lakehouse-iceberg", "properties": { ... }}' \
  http://localhost:8090/api/metalakes/demo_metalake/catalogs
```

Verify the catalog is live:

```bash
curl 'http://localhost:9002/iceberg/v1/config?warehouse=lake'
# {"defaults":{...,"prefix":"lake"},"overrides":{},...}   HTTP 200
```

## Spark

```bash
docker compose exec spark /scripts/spark-sql-dynamic.sh -f /sql/01-spark-dynamic.sql
```

Creates `lake.demo.orders` and inserts 5,000 rows tagged `writer='spark-dynamic'`.

**Expected:** `spark-dynamic  5000  974075.00`, 1 snapshot.

## Flink

```bash
docker compose exec flink-jobmanager /scripts/flink-sql.sh /sql/02-flink-dynamic.sql
```

Inserts 2,000 more rows into the same table, tagged `writer='flink-dynamic'`.
Flink submits this as an async job — the SQL client returns once it's
submitted, not once it's finished; check the Flink UI at `localhost:8080` if you
want to watch it land.

**Expected:** 2,000 rows appear once the job reaches `FINISHED`.

## Trino

```bash
./scripts/trino-sql.sh sql/03-trino-dynamic.sql
```

Reads the table Spark created and Flink appended to — no config beyond
`conf/trino/catalog/lake_dynamic.properties`, which was already in place before
either engine wrote anything.

**Expected:** `flink-dynamic 2000 / spark-dynamic 5000`, total **7,000** rows,
2 snapshots.

## DuckDB

```bash
./scripts/duckdb-sql.sh sql/04-duckdb-dynamic.sql
```

Same 7,000 rows, same per-writer breakdown, read with **zero client-side S3
credentials** — the `ATTACH` uses `ACCESS_DELEGATION_MODE 'vended_credentials'`,
so the catalog hands DuckDB short-lived, table-scoped credentials at query
time instead of a static key. See [Gotchas](#gotchas) for the details that
make this `ATTACH` easy to get wrong on the first try.

**Expected:** `flink-dynamic 2000 / spark-dynamic 5000`, total **7,000** rows,
and `duckdb_secrets()` empty before the query runs.

## Concurrency test

```bash
./scripts/run-concurrency-dynamic.sh
```

Launches a Spark insert and a Flink insert against the same table at
(approximately) the same time — 1,000 rows each, tagged
`spark-concurrent-dynamic` and `flink-concurrent-dynamic` — then polls until
both land, and checks Trino for the result.

**Expected output:**

```
spark-concurrent-dynamic   1000 rows
flink-concurrent-dynamic   1000 rows
total                      9000 rows

snapshot chain (4 snapshots, unbroken parent -> child):
  <snapshot 1> (root, append)
    -> <snapshot 2> (append)
      -> <snapshot 3> (append)
        -> <snapshot 4> (append)
```

Snapshot IDs are assigned at commit time and will differ on every run — what
matters is that there are exactly 4, one per `INSERT` across the whole demo
(Spark 01, Flink 02, and the two concurrent writes here), and that
`parent_id` links each one to the previous with no gaps or forks. If the two
concurrent writers had raced destructively you'd see a missing link or a
row-count short of 9,000; Iceberg's optimistic-concurrency retry is what
prevents that.

## Gotchas

**`SKIP_CONFIG_REWRITE`.** The Gravitino image's entrypoint rewrites
`conf/gravitino.conf` from environment variables on every boot, `os.remove()`-ing
the file first — which can't work on a bind-mounted file. This undocumented env
var turns the rewrite off, which is what makes a mounted conf file possible at
all. It's set in `docker-compose.yml`'s `catalog-dynamic` service.

**The entity-store schema has to be pre-created.** The Iceberg catalog's own
JDBC backend auto-creates its tables via `jdbc-initialize: true` on first use —
but Gravitino's *own* metadata store (metalakes, catalogs, schemas as Gravitino
entities) has no equivalent auto-migration. Booting against an empty
`gravitino_meta` database fails immediately, and the failure doesn't reach
`docker compose logs` — Gravitino's startup errors go to a log file inside the
container, not stdout. The `schema-init` service in `docker-compose.yml` runs
the image's own shipped schema script (`conf/gravitino-meta-schema-1.3.0-postgresql.sql`)
before `catalog-dynamic` ever starts, so you shouldn't hit this — but if you ever
run the catalog against a fresh database by hand, this is why it'll fail silently.

**`warehouse` means catalog name, not storage path.** Every engine config above
sets `warehouse=lake` (or the DuckDB/Trino equivalent) — that's the name of the
Gravitino catalog created in the Quickstart, looked up via the same mechanism
Gravitino uses everywhere else, not an S3 path. Passing an actual storage path
here (an easy first guess) 404s.

**DuckDB's `AUTHORIZATION_TYPE` and the `vended_credentials` spelling.** DuckDB
defaults a `TYPE ICEBERG` secret/attach to `oauth2` and refuses to proceed
without credentials in that mode — even against a catalog with no auth at all,
so `AUTHORIZATION_TYPE 'none'` has to be explicit (see `sql/04-duckdb-dynamic.sql`).
That script also sets `ACCESS_DELEGATION_MODE 'vended_credentials'` so DuckDB
fetches short-lived, table-scoped credentials from the catalog instead of
needing a static S3 secret of its own — the enum value is `vended_credentials`
with an **underscore**; `vended-credentials` (hyphen) is rejected outright, not
silently ignored. If your catalog doesn't vend credentials (no
`credential-providers` set on it), the script's commented-out block shows the
static-secret fallback.

## Teardown

```bash
docker compose down -v
```
