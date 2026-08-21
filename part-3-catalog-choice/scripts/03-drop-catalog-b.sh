#!/bin/bash
# Beat 4: "deletable the same way" is true, but not a single
# symmetric call. A naive DELETE on an active catalog is rejected -- that
# guardrail (can't drop an in-use catalog by accident) is a feature, not
# friction. This script shows the rejection first, then does the real
# two-step: disable, then drop.
set -euo pipefail

BASE="http://localhost:8090/api"

echo "=== naive DELETE on an active catalog (expected to fail) ==="
curl -sS -X DELETE "$BASE/metalakes/demo_metalake/catalogs/team_b_dev" \
  -H 'Accept: application/vnd.gravitino.v1+json'
echo

echo "=== disable: PATCH inUse=false ==="
curl -sS -X PATCH "$BASE/metalakes/demo_metalake/catalogs/team_b_dev" \
  -H 'Accept: application/vnd.gravitino.v1+json' \
  -H 'Content-Type: application/json' \
  -d '{"inUse": false}'
echo

echo "=== drop: DELETE ==="
curl -sS -X DELETE "$BASE/metalakes/demo_metalake/catalogs/team_b_dev" \
  -H 'Accept: application/vnd.gravitino.v1+json'
echo

echo "=== prove gone: GET /iceberg/v1/config?warehouse=team_b_dev (expect 404) ==="
curl -sS -w '\nHTTP %{http_code}\n' 'http://localhost:9002/iceberg/v1/config?warehouse=team_b_dev'

echo "=== prove lake unaffected ==="
curl -sS 'http://localhost:9002/iceberg/v1/config?warehouse=lake'
echo
curl -sS 'http://localhost:9002/iceberg/v1/lake/namespaces'
echo
