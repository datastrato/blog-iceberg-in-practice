-- Flink 1.20.5, iceberg-flink-runtime-1.20:1.11.0.
-- Endpoint is catalog-dynamic:9001. `warehouse` is set to "lake" (the catalog
-- name) -- same lookup mechanism as sql/01-spark-dynamic.sql.

SET 'execution.runtime-mode' = 'batch';
SET 'sql-client.execution.result-mode' = 'tableau';

CREATE CATALOG lake WITH (
  'type'         = 'iceberg',
  'catalog-type' = 'rest',
  'uri'          = 'http://catalog-dynamic:9001/iceberg/',
  'warehouse'    = 'lake',
  'io-impl'      = 'org.apache.iceberg.aws.s3.S3FileIO',
  's3.endpoint'  = 'http://minio:9000',
  's3.path-style-access' = 'true'
);

USE CATALOG lake;
USE demo;

CREATE TEMPORARY TABLE row_gen (
    n BIGINT
) WITH (
    'connector' = 'datagen',
    'number-of-rows' = '2000',
    'fields.n.kind' = 'sequence',
    'fields.n.start' = '1',
    'fields.n.end' = '2000'
);

-- 2000 rows tagged writer='flink-dynamic' into the table Spark created.
INSERT INTO orders
SELECT
    5000 + n                                              AS order_id,
    CAST(n % 500 AS BIGINT)                               AS customer_id,
    CAST(15.50 AS DECIMAL(10,2))                          AS amount,
    'shipped'                                             AS status,
    'flink-dynamic'                                       AS writer,
    TIMESTAMP '2026-08-02 12:00:00'                       AS created_at
FROM row_gen;
