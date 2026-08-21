"""Seed a standalone Iceberg JDBC catalog that Gravitino has never seen.

This is the "catalog you already run" in the federation demo. Nothing here
touches Gravitino: PyIceberg's SqlCatalog talks straight to Postgres over JDBC
and writes data files straight to MinIO, exactly as it would if this catalog
had been running in your estate for a year before Gravitino existed. The
Gravitino server is not in this file's configuration and does not need to be
running for it to work.

CATALOG_NAME is the load-bearing detail. Iceberg's JDBC catalog stores it in
the `catalog_name` column of `iceberg_tables` and filters every namespace and
table lookup by it, so whatever is registered in Gravitino later has to name
this same string via `catalog-backend-name` -- see the README's Gotchas and
scripts/06-register-legacy.sh, which shows what happens when it doesn't.

Run one-shot by scripts/05-seed-legacy-catalog.sh.
"""
import pyarrow as pa
from pyiceberg.catalog.sql import SqlCatalog
from pyiceberg.schema import Schema
from pyiceberg.types import DoubleType, LongType, NestedField, StringType

CATALOG_NAME = "legacy"

catalog = SqlCatalog(
    CATALOG_NAME,
    **{
        "uri": "postgresql+psycopg2://iceberg:iceberg@postgres:5432/iceberg_legacy",
        "warehouse": "s3://lakehouse/warehouse-legacy",
        "s3.endpoint": "http://minio:9000",
        "s3.access-key-id": "minioadmin",
        "s3.secret-access-key": "minioadmin",
        "s3.region": "us-east-1",
    },
)

catalog.create_namespace_if_not_exists("sales")

# Every field is optional, so the Arrow batch below can be plain nullable
# columns -- part 1's README has the matching gotcha for required fields.
schema = Schema(
    NestedField(1, "order_id", LongType(), required=False),
    NestedField(2, "region", StringType(), required=False),
    NestedField(3, "amount", DoubleType(), required=False),
)
table = catalog.create_table_if_not_exists("sales.orders", schema=schema)

rows = pa.table(
    {
        "order_id": pa.array([1, 2, 3, 4], type=pa.int64()),
        "region": pa.array(["emea", "amer", "apac", "emea"], type=pa.string()),
        "amount": pa.array([100.50, 250.25, 75.00, 312.75], type=pa.float64()),
    }
)
table.append(rows)

scan = table.scan().to_arrow()
total = sum(scan.column("amount").to_pylist())
print(f"seeded {scan.num_rows} rows into {CATALOG_NAME}.sales.orders, sum(amount)={total:.2f}")
