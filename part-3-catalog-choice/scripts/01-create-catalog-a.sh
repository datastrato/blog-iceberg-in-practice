#!/bin/bash
# Beat 1-2: one POST creates a catalog, live on the IRC endpoint
# immediately, no restart. Catalog A ("lake") gets its own backend database --
# see README Gotchas for why every catalog in this tour gets one of its own.
set -euo pipefail
cd "$(dirname "$0")/.."

BASE="http://localhost:8090/api"

echo "=== creating backend database iceberg_lake ==="
docker compose exec -T postgres psql -U iceberg -d iceberg -tc \
  "SELECT 1 FROM pg_database WHERE datname = 'iceberg_lake'" | grep -q 1 \
  || docker compose exec -T postgres psql -U iceberg -d iceberg -c "CREATE DATABASE iceberg_lake"

echo "=== POST /metalakes/demo_metalake/catalogs (lake) ==="
curl -sS -X POST "$BASE/metalakes/demo_metalake/catalogs" \
  -H 'Accept: application/vnd.gravitino.v1+json' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "lake",
    "type": "RELATIONAL",
    "comment": "catalog A -- its own backend DB and warehouse prefix",
    "provider": "lakehouse-iceberg",
    "properties": {
      "catalog-backend": "jdbc",
      "uri": "jdbc:postgresql://postgres:5432/iceberg_lake",
      "warehouse": "s3://lakehouse/warehouse-lake",
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

echo "=== prove live, no restart: GET /iceberg/v1/config?warehouse=lake ==="
curl -sS 'http://localhost:9002/iceberg/v1/config?warehouse=lake'
echo

echo "=== prove live: namespace round-trip ==="
curl -sS -X POST 'http://localhost:9002/iceberg/v1/lake/namespaces' \
  -H 'Content-Type: application/json' -d '{"namespace": ["catalog_a_ns"]}'
echo
curl -sS 'http://localhost:9002/iceberg/v1/lake/namespaces'
echo
