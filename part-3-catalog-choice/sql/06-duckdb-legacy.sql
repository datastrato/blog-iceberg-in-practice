-- Reads the registered legacy catalog through Gravitino's Iceberg REST
-- endpoint. DuckDB never sees Postgres, never sees the JDBC catalog, and gets
-- no S3 keys: the catalog vends short-lived table-scoped credentials because
-- it was registered with "credential-providers": "s3-token". Same attach shape
-- as part 2's sql/04-duckdb-dynamic.sql.
INSTALL iceberg;
LOAD iceberg;
INSTALL httpfs;
LOAD httpfs;

ATTACH 'legacy' AS legacy (
    TYPE ICEBERG,
    ENDPOINT 'http://catalog-dynamic:9001/iceberg/',
    AUTHORIZATION_TYPE 'none',
    ACCESS_DELEGATION_MODE 'vended_credentials'
);

SELECT count(*) AS n, sum(amount) AS total FROM legacy.sales.orders;
