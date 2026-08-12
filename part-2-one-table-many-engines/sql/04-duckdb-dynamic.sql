-- DuckDB 1.5.5, against the embedded IRC. Three things worth calling out (see
-- the README's "Gotchas" section for the full story):
--
--   - AUTHORIZATION_TYPE 'none' must be explicit. DuckDB's default for a
--     TYPE ICEBERG attach is oauth2, and it refuses to proceed without
--     credentials in that mode -- even against a catalog that has no auth at all.
--   - ACCESS_DELEGATION_MODE 'vended_credentials' (underscore, not hyphen) is
--     what lets DuckDB skip client-side S3 credentials entirely: the catalog
--     hands back short-lived, table-scoped credentials at query time. Verified
--     against a fresh process with duckdb_secrets() empty before the query ran.
--   - ATTACH's first argument is 'lake' (the Gravitino catalog name), not an
--     empty string or a storage path -- same warehouse-as-catalog-name lookup
--     as every other engine here.

INSTALL iceberg;
LOAD iceberg;
INSTALL httpfs;
LOAD httpfs;

ATTACH 'lake' AS lake_dynamic (
    TYPE ICEBERG,
    ENDPOINT 'http://catalog-dynamic:9001/iceberg/',
    AUTHORIZATION_TYPE 'none',
    ACCESS_DELEGATION_MODE 'vended_credentials'
);

-- No client-side S3 credentials configured above. If your catalog doesn't vend
-- credentials (no `credential-providers` set on it), attach with a static
-- secret instead:
--
-- CREATE OR REPLACE SECRET minio_secret (
--     TYPE S3,
--     KEY_ID 'minioadmin',
--     SECRET 'minioadmin',
--     ENDPOINT 'minio:9000',
--     URL_STYLE 'path',
--     USE_SSL false,
--     REGION 'us-east-1'
-- );
--
-- ATTACH 'lake' AS lake_dynamic (TYPE ICEBERG, ENDPOINT 'http://catalog-dynamic:9001/iceberg/', AUTHORIZATION_TYPE 'none');

SELECT writer, count(*) AS rows, sum(amount) AS total FROM lake_dynamic.demo.orders GROUP BY writer ORDER BY writer;
SELECT count(*) AS n FROM lake_dynamic.demo.orders;
SHOW ALL TABLES;
