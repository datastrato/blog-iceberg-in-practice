# Part 1: The Iceberg REST Catalog, a curl-level tour

Part 1 of the blog series walks through what the Iceberg REST Catalog spec
actually standardizes — the catalog API, the commit protocol, and credential
vending. This directory is the hands-on companion: the same mechanics, called
directly with curl, so you can see the actual requests and responses instead of
taking the post's word for it.

> **This is a demo rig, not a reference deployment.** Single-node MinIO, a
> shared Postgres instance, no auth, no TLS, no HA — built to make the REST
> Catalog's behavior visible, not to model a production topology. This part is
> fully independent of part 2: its own Gravitino, Postgres, and MinIO, brought
> up from this directory alone. The two parts use the **same host ports**
> (see below), so bring one stack down (`docker compose down`) before starting
> the other.

## Prerequisites

- Docker with Compose v2 (`docker compose version`)

## Quickstart

```bash
docker compose up -d
```

This brings up MinIO, Postgres, and the Gravitino catalog server, and — via two
one-shot init services — automatically prepares Gravitino's own metadata schema
(`schema-init`) and installs a SHA-pinned PyIceberg client (`pyiceberg-init`;
see [Gotchas](#gotchas) for why this tour needs it at all).

Wait for `catalog-dynamic` to report healthy:

```bash
docker compose ps catalog-dynamic
```

Then create the metalake and the `lake` catalog — the same two curls as part
2's Quickstart, deliberately not automated by `docker compose up` for the same
reason: seeing them run is the point.

```bash
./scripts/create-catalog.sh
```

Everything below then runs from *this* directory, against this part's own
catalog. Host ports: 9000/9090 MinIO, 8090 Gravitino API, 9002 Iceberg REST —
identical to part 2's, by design; the two stacks are otherwise entirely
independent and share no volumes or state.

Every command here creates and uses its own `tour` namespace and `events`
table, so running this tour, in any order, any number of times, is always safe
to rerun.

## The tour

| Script | Blog section | What it shows |
|---|---|---|
| `scripts/00-config.sh` | *What the spec actually standardizes* → **1. The catalog API itself** | `GET /v1/config` — the first call any client makes, returning the catalog's defaults/overrides and its `prefix`. |
| `scripts/01-namespace-and-table.sh` | **1. The catalog API itself** | Creates a namespace and a table with `POST /namespaces` and `POST /namespaces/{ns}/tables` — the same calls every engine in part 2 makes under the hood. |
| `scripts/02-metadata-pointer-swap.sh` | **2. The commit protocol** | Two commits, two fetches of the table in between — watch `metadata-location` move to a new file on every commit instead of being edited in place. |
| `scripts/03-vended-credentials.sh` | **3. Credential vending** | `GET .../tables/{table}/credentials` — short-lived, scoped S3 credentials for the table's own storage prefix, minted on request. |

(*4. Server-side scan planning*, the spec's fourth pillar, has no curl demo here
— it's a planning-time optimization more visible in an engine's query plan than
in a single request/response pair.)

Run them individually in order, or all at once:

```bash
./scripts/run-all.sh
```

### 1. The catalog API itself

```bash
curl 'http://localhost:9002/iceberg/v1/config?warehouse=lake'
```

`warehouse=lake` is the catalog name (see part 2's "warehouse means catalog
name" gotcha) — the response's `prefix` field is what every other endpoint
below is namespaced under: `/v1/{prefix}/namespaces/...`.

Then create a namespace and a table in it:

```bash
curl -X POST http://localhost:9002/iceberg/v1/lake/namespaces \
  -H 'Content-Type: application/json' \
  -d '{"namespace": ["tour"], "properties": {}}'

curl -X POST http://localhost:9002/iceberg/v1/lake/namespaces/tour/tables \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "events",
    "schema": {
      "type": "struct",
      "schema-id": 0,
      "fields": [
        {"id": 1, "name": "event_id", "required": true, "type": "long"},
        {"id": 2, "name": "event_name", "required": false, "type": "string"},
        {"id": 3, "name": "event_time", "required": false, "type": "timestamp"}
      ]
    },
    "properties": {}
  }'
```

### 2. The commit protocol

```bash
curl http://localhost:9002/iceberg/v1/lake/namespaces/tour/tables/events \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["metadata-location"])'
```

Run that, make a commit, and run it again — `metadata-location` points at a
different file. Each commit is a brand-new metadata.json; the swap is what
makes a commit atomic and every prior state still readable.

The commit itself (`scripts/02-metadata-pointer-swap.sh` calls
`scripts/commit-event.py`, run inside the `pyiceberg` container) is the one
step in this tour that isn't plain curl, and deliberately so: a commit is a
client-library operation. The client writes the actual data file and a new
manifest first, then makes **one** atomic REST update call — the
"requirements + updates" protocol from the blog post, here in its real,
runnable form. A from-scratch curl commit would mean hand-building an Iceberg
manifest and metadata.json by hand, which defeats the point of showing the
protocol. PyIceberg is a REST-catalog Python client, not a query engine — see
[Gotchas](#gotchas) for the one thing it needs that the blog post's own
PyIceberg snippet doesn't set.

### 3. Credential vending

```bash
curl http://localhost:9002/iceberg/v1/lake/namespaces/tour/tables/events/credentials
```

Returns something shaped like:

```json
{
  "storage-credentials": [{
    "prefix": "s3://lakehouse/warehouse-dynamic/tour/events",
    "config": {
      "s3.access-key-id": "<redacted>",
      "s3.secret-access-key": "<redacted>",
      "s3.session-token": "<redacted-jwt>",
      "s3.session-token-expires-at-ms": "<epoch-ms>",
      "client.refresh-credentials-endpoint": "v1/lake/namespaces/tour/tables/events/credentials"
    }
  }]
}
```

These are real, short-lived MinIO STS credentials minted for this specific
table prefix — not the static `minioadmin`/`minioadmin` root credentials the
rig uses elsewhere. This is what lets an engine hand a client a table
reference without ever handing it a long-lived key.

### List namespaces

```bash
curl http://localhost:9002/iceberg/v1/lake/namespaces
```

Always just `tour` — this part's catalog is entirely its own, not shared with
part 2's stack at all.

## Gotchas

**PyIceberg needs `auth={"type": "noop"}` explicitly, or it 401s.** Without an
explicit auth override, PyIceberg's REST client attaches a literal
`Authorization: Bearer None` header (no token configured, stringified anyway),
and Gravitino rejects it outright rather than treating it as no credentials at
all. `scripts/commit-event.py` sets `auth={"type": "noop"}` on `load_catalog`
to get a clean, unauthenticated connection — the PyIceberg equivalent of
DuckDB's `AUTHORIZATION_TYPE 'none'` in part 2.

**`event_id` needs an explicit non-nullable pyarrow schema.** The `events`
table's `event_id` column is `required` (see `scripts/01-namespace-and-table.sh`).
A plain `pa.table({...})` defaults every column to nullable, and PyIceberg's
`append()` rejects the mismatch before writing anything. `commit-event.py`
builds an explicit `pa.schema(...)` with `event_id` marked `nullable=False` to
match.

**Same host ports as part 2.** Both parts publish MinIO on 9000/9090, Gravitino
on 8090, and the Iceberg REST endpoint on 9002. `docker compose down` one part
before starting the other.

## Teardown

```bash
docker compose down -v
```
