#!/bin/bash
# Overlapping Spark and Flink commits against demo.orders through the
# embedded/aux Iceberg REST service. Both writers are launched at (nearly) the
# same time; the point is to show Iceberg's optimistic-concurrency retry
# resolving the race into an unbroken snapshot chain, not to prove true
# wall-clock overlap.
#
# Flink jobs run async against the SQL client, so after launching it this script
# polls Flink's REST API for the submitted job to reach a terminal state before
# reading final results.
set -uo pipefail
cd "$(dirname "$0")/.."

echo "=== pre-flight row count ==="
docker compose exec -T trino trino --execute \
  "SELECT writer, count(*) FROM lake_dynamic.demo.orders GROUP BY writer ORDER BY writer" 2>&1

echo
echo "=== launching both writers ==="
docker compose exec -T spark /scripts/spark-sql-dynamic.sh -f /sql/05-concurrency-spark-dynamic.sql \
  > /tmp/conc-spark-dynamic.log 2>&1 &
SPARK_PID=$!
docker compose exec -T flink-jobmanager /scripts/flink-sql.sh /sql/05-concurrency-flink-dynamic.sql \
  > /tmp/conc-flink-dynamic.log 2>&1 &
FLINK_PID=$!

wait $SPARK_PID; SPARK_RC=$?
wait $FLINK_PID; FLINK_RC=$?
echo "spark exit=$SPARK_RC   flink exit=$FLINK_RC"

FLINK_JOB_ID=$(grep -oE 'Job ID: [a-f0-9]+' /tmp/conc-flink-dynamic.log | awk '{print $3}')
if [ -n "$FLINK_JOB_ID" ]; then
  echo "=== polling Flink job $FLINK_JOB_ID for terminal state ==="
  for i in $(seq 1 40); do
    STATE=$(curl -sS "http://localhost:8080/jobs/$FLINK_JOB_ID" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('state','?'))" 2>/dev/null)
    echo "  $STATE"
    case "$STATE" in FINISHED|FAILED|CANCELED) break;; esac
    sleep 3
  done
else
  echo "!!! could not find a Flink job ID in the log -- job may not have submitted"
fi

echo
echo "=== spark tail ==="; tail -15 /tmp/conc-spark-dynamic.log
echo "=== flink tail ==="; tail -15 /tmp/conc-flink-dynamic.log

echo
echo "=== post-run counts (both concurrent writers must appear) ==="
docker compose exec -T trino trino --execute \
  "SELECT writer, count(*) AS rows FROM lake_dynamic.demo.orders GROUP BY writer ORDER BY writer" 2>&1

echo
echo "=== snapshot chain (parent_id must link every snapshot; no orphans) ==="
docker compose exec -T trino trino --execute \
  "SELECT snapshot_id, parent_id, operation, committed_at FROM lake_dynamic.demo.\"orders\$snapshots\" ORDER BY committed_at" 2>&1

echo
echo "=== total rows must equal the sum of every insert ==="
docker compose exec -T trino trino --execute \
  "SELECT count(*) AS total FROM lake_dynamic.demo.orders" 2>&1
