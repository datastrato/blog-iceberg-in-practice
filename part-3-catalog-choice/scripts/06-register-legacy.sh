#!/bin/bash
# Federation beat 2 of 2: register the catalog seeded by script 05
# and serve it, unchanged, through Gravitino's Iceberg REST endpoint.
#
# One POST registers a catalog that already exists and already has data in it.
# Everything after the POST is proof: the endpoint answers with no restart, the
# seeded namespace and table are listed, and a client that wrote none of it
# reads the rows back through the REST endpoint.
set -euo pipefail
cd "$(dirname "$0")/.."

BASE="http://localhost:8090/api"
EXPECTED="4|738.5"

echo "=== register the existing catalog: POST /metalakes/demo_metalake/catalogs ==="
echo "--- Gravitino server has been up since: $(docker compose ps catalog-dynamic --format '{{.RunningFor}}')"
echo "--- POST at: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
curl -sS -X POST "$BASE/metalakes/demo_metalake/catalogs" \
  -H 'Accept: application/vnd.gravitino.v1+json' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "legacy",
    "type": "RELATIONAL",
    "comment": "a catalog Gravitino never created -- registered, not migrated",
    "provider": "lakehouse-iceberg",
    "properties": {
      "catalog-backend": "jdbc",
      "catalog-backend-name": "legacy",
      "uri": "jdbc:postgresql://postgres:5432/iceberg_legacy",
      "warehouse": "s3://lakehouse/warehouse-legacy",
      "jdbc-driver": "org.postgresql.Driver",
      "jdbc-user": "iceberg",
      "jdbc-password": "iceberg",
      "jdbc-initialize": "true",
      "io-impl": "org.apache.iceberg.aws.s3.S3FileIO",
      "s3-endpoint": "http://minio:9000",
      "s3-access-key-id": "minioadmin",
      "s3-secret-access-key": "minioadmin",
      "s3-region": "us-east-1",
      "s3-path-style-access": "true",
      "credential-providers": "s3-token",
      "s3-role-arn": "arn:aws:iam::123456789012:role/gravitino",
      "s3-token-service-endpoint": "http://minio:9000"
    }
  }'
echo

echo "=== live immediately, no restart -- GET /iceberg/v1/config?warehouse=legacy ==="
echo "--- GET at:  $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "--- server still up since: $(docker compose ps catalog-dynamic --format '{{.RunningFor}}')"
curl -sS 'http://localhost:9002/iceberg/v1/config?warehouse=legacy'
echo

echo "=== the seeded namespace is there ==="
curl -sS 'http://localhost:9002/iceberg/v1/legacy/namespaces'
echo

echo "=== and the seeded table ==="
curl -sS 'http://localhost:9002/iceberg/v1/legacy/namespaces/sales/tables'
echo

echo "=== read the rows back through the IRC endpoint, with a client that didn't write them ==="
ACTUAL="$(docker compose --profile federation run --rm -T duckdb \
  /opt/duckdb/duckdb -noheader -list -f /sql/06-duckdb-legacy.sql | tail -1 | tr -d '\r')"
echo "DuckDB read: $ACTUAL   (expected: $EXPECTED)"
if [ "$ACTUAL" != "$EXPECTED" ]; then
  echo "MISMATCH: what came back through Gravitino is not what script 05 seeded" >&2
  exit 1
fi

echo
echo "=== Gravitino did not create any of this. It registered it and served it, unchanged. ==="
