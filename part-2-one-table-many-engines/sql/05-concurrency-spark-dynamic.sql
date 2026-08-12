-- Spark half of the overlapping-commit test. 1000 rows tagged
-- writer='spark-concurrent-dynamic'.

INSERT INTO lake.demo.orders
SELECT
    100000 + id                                              AS order_id,
    CAST(id % 500 AS BIGINT)                                 AS customer_id,
    CAST(99.99 AS DECIMAL(10,2))                             AS amount,
    'pending'                                                AS status,
    'spark-concurrent-dynamic'                                AS writer,
    timestamp'2026-08-03 09:00:00'                           AS created_at
FROM range(1, 1001);
