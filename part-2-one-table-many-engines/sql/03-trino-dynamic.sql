-- Trino 483. Proves Trino sees rows from BOTH Spark and Flink through the
-- dynamic-mode endpoint (conf/trino/catalog/lake_dynamic.properties).

SELECT writer, count(*) AS rows, sum(amount) AS total
FROM lake_dynamic.demo.orders
GROUP BY writer
ORDER BY writer;

SELECT count(*) AS total_rows FROM lake_dynamic.demo.orders;

SELECT snapshot_id, parent_id, operation, committed_at
FROM lake_dynamic.demo."orders$snapshots"
ORDER BY committed_at;
