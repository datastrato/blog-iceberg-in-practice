# Part 3: Catalogs as API objects, a curl-level tour

Companion code for "Catalog Choice: The Decision That Outlives Your Engines"
(Iceberg in Practice #3), the "Catalogs as API objects" section. Same
dynamic-mode Gravitino server as part 2, no engines attached: this tour only
ever talks to Gravitino's management API and the embedded Iceberg REST
service, and shows
what it means for a catalog to be an API object instead of a fixed endpoint --
including registering a catalog Gravitino never created and serving it
unchanged.

> **This is a demo rig, not a reference deployment.** Single-node MinIO, a
> shared Postgres instance, no auth, no TLS, no HA — built to make dynamic
> catalog provisioning visible, not to model a production topology. This part
> is fully independent of parts 1 and 2: its own Gravitino, Postgres, and
> MinIO, brought up from this directory alone. All three parts use the
> **same host ports**, so bring one stack down (`docker compose down`) before
> starting another.

## Prerequisites

- Docker with Compose v2 (`docker compose version`)

## Quickstart

```bash
docker compose up -d
```

This brings up MinIO and Postgres, and — via the one-shot `schema-init`
service — automatically prepares Gravitino's own metadata schema. Creating
the metalake and every catalog after it is deliberately **not** automated,
because seeing them appear and disappear by API call is the point of this
tour.

```bash
./scripts/create-metalake.sh
```

This waits for `catalog-dynamic` to report healthy (it can take ~30s from a
cold `up -d`) before creating the metalake, so it's safe to run right after
`docker compose up -d` without a separate manual health check.

Scripts 05 and 06 need a writer (PyIceberg) and a reader (DuckDB). Both sit
in the `federation` compose profile, so `docker compose up -d` above stays
engine-free; the scripts start them one-shot when they run, and nothing is
left idling afterwards.

Host ports: 9000/9090 MinIO, 8090 Gravitino API, 9002 Iceberg REST, 5432
Postgres — identical to parts 1 and 2's, by design; the three stacks are
otherwise entirely independent and share no volumes or state.

## The tour

| Script | Blog section | What it shows |
|---|---|---|
| `scripts/create-metalake.sh` | *setup, not part of the demo* | Waits for `catalog-dynamic` healthy, then `POST /metalakes` — the one-time precondition every catalog below is created under. |
| `scripts/01-create-catalog-a.sh` | **Catalogs as API objects** | `POST /metalakes/demo_metalake/catalogs` creates catalog A (`lake`) with its own backend database, live on the IRC endpoint immediately — `GET /iceberg/v1/config?warehouse=lake` and a namespace round-trip, no restart involved. |
| `scripts/02-create-catalog-b.sh` | same | A second catalog (`team_b_dev`), own backend database, same endpoint. Proves both isolation (each catalog only ever lists its own namespace) and that the management API now lists both. |
| `scripts/03-drop-catalog-b.sh` | same | "Deletable the same way" — almost. A bare `DELETE` on an active catalog is rejected first (`1010 CatalogInUseException`); the real sequence is disable (`PATCH {"inUse": false}`), then `DELETE`. Catalog A is proven untouched throughout. |
| `scripts/04-persistence-after-drop.sh` | same, footnote | Recreates a catalog against `team_b_dev`'s old backend database and shows its namespace survived the drop — dropping a catalog de-registers it, it doesn't destroy data. Cleans up after itself. |
| `scripts/05-seed-legacy-catalog.sh` | **Register a catalog you already run** | Builds the "catalog you already run": its own database (`iceberg_legacy`) and warehouse prefix, with `sales.orders` seeded through PyIceberg's `SqlCatalog` — a plain JDBC client with no Gravitino in its config. Ends by listing Gravitino's catalogs to show it still knows nothing about any of it. |
| `scripts/06-register-legacy.sh` | same | One POST registers that catalog, `catalog-backend-name` included among its properties. Everything after it is proof: `GET /iceberg/v1/config?warehouse=legacy` answers with no restart, the seeded `sales` namespace and `orders` table are listed, and DuckDB reads the rows back through the IRC endpoint, asserting they match what script 05 wrote. Gravitino never created this metadata; it registered and served it. |

Run them individually in order, or all at once: `./scripts/run-all.sh`.

Scripts 05–06 need only `create-metalake.sh` first — they don't depend on 01–04,
and they use their own database and warehouse prefix.

## Gotchas

- **Two catalogs sharing one backend database are aliases, not isolated
  tenants.** Gravitino's `uri` property on a JDBC-backend catalog points at a
  database, not a namespace scoped to that catalog — point two catalogs at
  the same database and they see each other's namespaces. That's why every
  catalog in this tour (`iceberg_lake`, `iceberg_team_b`) gets its own
  database, created live in the script that creates the catalog. A catalog is
  a serving and governance boundary; the backend database is the storage
  boundary. Provision both per tenant.

- **Catalog delete is two-step, on purpose.** `DELETE` on an in-use catalog
  is rejected with `1010 CatalogInUseException`, not silently ignored or
  force-deleted. `scripts/03-drop-catalog-b.sh` shows the rejection before
  doing the real disable-then-drop sequence. Treat this as a guardrail, not
  friction — it's exactly what you want from infrastructure you provision by
  API call instead of a fixed endpoint someone hands you.

- **Registering a JDBC catalog you already run needs `catalog-backend-name`.**
  It defaults to the backend type (`jdbc`), not to the name you register the
  catalog under, and Iceberg's JDBC backend filters every namespace and table
  lookup by that name — so get it wrong and registration succeeds,
  `/iceberg/v1/config` answers, and every listing comes back empty with
  nothing in the response or the server log to say why. Set it to the name the
  catalog was already written under, whatever engine wrote it.
  `scripts/06-register-legacy.sh` sets it correctly, so the tour never hits
  this; the failure mode is documented here because nothing in the API or the
  server log points at it.

- **Seed with the engine you'd actually have run.** Script 05 uses PyIceberg,
  but nothing about the seeder is special: any client that writes an Iceberg
  JDBC catalog produces metadata Gravitino can register and serve as-is,
  provided the registered `catalog-backend-name` matches the name that client
  wrote under. The federation claim is about the metadata, not the writer.

- **Same host ports as parts 1 and 2.** Bring whichever other stack is
  running down first (`docker compose down` from its own directory).

## Teardown

```bash
docker compose down -v
```
