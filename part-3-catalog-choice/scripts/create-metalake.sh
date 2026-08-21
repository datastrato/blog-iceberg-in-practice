#!/bin/bash
# One-time setup: waits for catalog-dynamic to report healthy, then creates
# the metalake every catalog in this tour gets created under. The catalogs
# themselves -- the actual demo -- are the numbered scripts, not this one.
# Run once per fresh `docker compose up`.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "=== waiting for catalog-dynamic to report healthy ==="
for i in $(seq 1 60); do
  status="$(docker compose ps catalog-dynamic --format '{{.Health}}' 2>/dev/null || true)"
  if [ "$status" = "healthy" ]; then
    echo "catalog-dynamic is healthy"
    break
  fi
  if [ "$i" -eq 60 ]; then
    echo "catalog-dynamic did not become healthy within 2 minutes" >&2
    exit 1
  fi
  sleep 2
done

BASE="http://localhost:8090/api"

echo "=== POST /metalakes ==="
curl -sS -X POST "$BASE/metalakes" \
  -H 'Accept: application/vnd.gravitino.v1+json' \
  -H 'Content-Type: application/json' \
  -d '{"name": "demo_metalake", "comment": "iceberg-in-practice catalog-choice rig"}'
echo
