-- Spark 3.5.8, iceberg-spark-runtime-3.5_2.12:1.11.0.
-- Catalog config lives on the spark-sql command line; see scripts/spark-sql-dynamic.sh.
-- Endpoint is catalog-dynamic:9001 (embedded IRC aux service). `warehouse=lake` is
-- set explicitly: it's a real catalog-name lookup against Gravitino's own catalog
-- registry, and "lake" is the catalog created via scripts/create-catalog.sh.

CREATE NAMESPACE IF NOT EXISTS lake.demo;

CREATE TABLE IF NOT EXISTS lake.demo.orders (
    order_id    BIGINT,
    customer_id BIGINT,
    amount      DECIMAL(10,2),
    status      STRING,
    writer      STRING,
    created_at  TIMESTAMP
)
USING iceberg
PARTITIONED BY (days(created_at));

-- Fresh data, tagged writer='spark-dynamic' so later engines can distinguish
-- rows by who wrote them.
INSERT INTO lake.demo.orders
SELECT
    id                                                        AS order_id,
    CAST(id % 500 AS BIGINT)                                  AS customer_id,
    CAST(round(10 + (id % 1000) * 0.37, 2) AS DECIMAL(10,2))  AS amount,
    CASE WHEN id % 3 = 0 THEN 'shipped'
         WHEN id % 3 = 1 THEN 'pending'
         ELSE 'cancelled' END                                 AS status,
    'spark-dynamic'                                           AS writer,
    timestamp'2026-08-01 00:00:00' + make_interval(0,0,0,0,0, CAST(id % 2880 AS INT), 0) AS created_at
FROM range(1, 5001);

SELECT writer, count(*) AS rows, sum(amount) AS total FROM lake.demo.orders GROUP BY writer;
SELECT count(*) AS snapshot_count FROM lake.demo.orders.snapshots;
