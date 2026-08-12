#!/bin/bash
# Creates a namespace and a table through the raw Iceberg REST Catalog API --
# the same protocol every engine in part 2 speaks, just called directly.
#
# Uses its own "tour" namespace, separate from part 2's "demo" namespace, so
# running this tour can never change part 2's expected row counts or snapshot
# chain, no matter what order you run things in or how many times you rerun it.
#
# Safe to rerun: drops the tour table/namespace first if they're already there.
set -euo pipefail

BASE="http://localhost:9002/iceberg/v1/lake"

curl -sS -X DELETE "$BASE/namespaces/tour/tables/events" >/dev/null 2>&1 || true
curl -sS -X DELETE "$BASE/namespaces/tour" >/dev/null 2>&1 || true

echo "=== POST /namespaces (create 'tour') ==="
curl -sS -X POST "$BASE/namespaces" \
  -H 'Content-Type: application/json' \
  -d '{"namespace": ["tour"], "properties": {}}'
echo

echo "=== POST /namespaces/tour/tables (create 'events') ==="
curl -sS -X POST "$BASE/namespaces/tour/tables" \
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
echo
