#!/bin/bash
# Shows the table's metadata pointer moving across two commits.
#
# Every table's REST representation includes "metadata-location": the path to
# the current metadata.json file. A commit doesn't edit that file in place --
# it writes a brand new metadata.json and atomically swaps the pointer to it.
# This script commits twice (via DuckDB, already running as part of the part-2
# stack) and fetches the table between each commit so you can watch the pointer
# move.
set -euo pipefail
cd "$(dirname "$0")/../../part-2-one-table-many-engines"

TABLE_URL="http://localhost:9002/iceberg/v1/lake/namespaces/tour/tables/events"

echo "=== metadata-location before any commits ==="
curl -sS "$TABLE_URL" | python3 -c 'import json,sys; print(json.load(sys.stdin)["metadata-location"])'

commit() {
  docker compose exec -T duckdb /opt/duckdb/duckdb -c "
    INSTALL iceberg; LOAD iceberg; INSTALL httpfs; LOAD httpfs;
    CREATE OR REPLACE SECRET minio_secret (TYPE S3, KEY_ID 'minioadmin', SECRET 'minioadmin', ENDPOINT 'minio:9000', URL_STYLE 'path', USE_SSL false, REGION 'us-east-1');
    ATTACH 'lake' AS lake (TYPE ICEBERG, ENDPOINT 'http://catalog-dynamic:9001/iceberg/', AUTHORIZATION_TYPE 'none');
    $1
  " >/dev/null

}

echo
echo "=== commit 1: insert one row ==="
commit "INSERT INTO lake.tour.events VALUES (1, 'signup', TIMESTAMP '2026-08-01 00:00:00');"

echo "=== metadata-location after commit 1 ==="
curl -sS "$TABLE_URL" | python3 -c 'import json,sys; print(json.load(sys.stdin)["metadata-location"])'

echo
echo "=== commit 2: insert one more row ==="
commit "INSERT INTO lake.tour.events VALUES (2, 'purchase', TIMESTAMP '2026-08-01 01:00:00');"

echo "=== metadata-location after commit 2 ==="
curl -sS "$TABLE_URL" | python3 -c 'import json,sys; print(json.load(sys.stdin)["metadata-location"])'

echo
echo "Two commits, two different metadata.json paths -- the table object itself"
echo "was never edited in place; each commit wrote a new file and swapped the pointer."
