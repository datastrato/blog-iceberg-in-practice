-- Flink half of the overlapping-commit test. 1000 rows tagged
-- writer='flink-concurrent-dynamic'.

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

SET 'execution.runtime-mode' = 'batch';

CREATE TEMPORARY TABLE row_gen (
    n BIGINT
) WITH (
    'connector' = 'datagen',
    'number-of-rows' = '1000',
    'fields.n.kind' = 'sequence',
    'fields.n.start' = '1',
    'fields.n.end' = '1000'
);

INSERT INTO orders
SELECT
    200000 + n                                            AS order_id,
    CAST(n % 500 AS BIGINT)                               AS customer_id,
    CAST(77.77 AS DECIMAL(10,2))                          AS amount,
    'pending'                                             AS status,
    'flink-concurrent-dynamic'                            AS writer,
    TIMESTAMP '2026-08-03 09:00:00'                       AS created_at
FROM row_gen;
