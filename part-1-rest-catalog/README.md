# Part 1: The Iceberg REST Catalog, a curl-level tour

Part 1 of the blog series walks through what the Iceberg REST Catalog spec
actually standardizes — the catalog API, the commit protocol, and credential
vending. This directory is the hands-on companion: the same mechanics, called
directly with curl, so you can see the actual requests and responses instead of
taking the post's word for it.

> **This is a demo rig, not a reference deployment.** See part 2's README for
> the full disclaimer — everything here runs against that same demo stack.

## Prerequisites

This tour makes no infrastructure of its own — it runs entirely against the
stack from **part 2**. Before running anything here:

1. Start the part-2 stack: `cd ../part-2-one-table-many-engines && docker compose up -d`
2. Create its `lake` catalog: `./scripts/create-catalog.sh` (or the two curls in
   part 2's README Quickstart)

Everything below then runs from *this* directory.

Every command here creates and uses its own `tour` namespace and `events`
table — separate from part 2's `demo` namespace — so running this tour, in any
order, any number of times, never changes part 2's expected row counts or
snapshot chain.

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

Run that, make a commit (`scripts/02-metadata-pointer-swap.sh` does this via
DuckDB, since a from-scratch curl commit means constructing a full Iceberg
metadata.json and manifest by hand), and run it again — `metadata-location`
points at a different file. Each commit is a brand-new metadata.json; the swap
is what makes a commit atomic and every prior state still readable.

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

### List both namespaces

```bash
curl http://localhost:9002/iceberg/v1/lake/namespaces
```

If you've already worked through part 2's engine sections, you'll see both
`demo` and `tour` here. If you're doing part 1 in isolation right after the
Quickstart, you'll see just `tour` — that's expected, and is itself the point:
namespaces are scoped independently within a catalog, not a shared blob, and
nothing this tour does can touch `demo`'s rows or snapshots.
