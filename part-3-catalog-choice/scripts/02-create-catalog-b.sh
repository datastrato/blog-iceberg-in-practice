#!/bin/bash
# Beat 3: as many catalogs as you want, one endpoint. Catalog B
# ("team_b_dev") gets its own backend database too -- two catalogs sharing one
# DB are aliases over the same namespace set, not isolated tenants (see README
# Gotchas). This script proves both liveness and isolation.
set -euo pipefail
cd "$(dirname "$0")/.."

BASE="http://localhost:8090/api"

echo "=== creating backend database iceberg_team_b ==="
docker compose exec -T postgres psql -U iceberg -d iceberg -tc \
  "SELECT 1 FROM pg_database WHERE datname = 'iceberg_team_b'" | grep -q 1 \
  || docker compose exec -T postgres psql -U iceberg -d iceberg -c "CREATE DATABASE iceberg_team_b"

echo "=== POST /metalakes/demo_metalake/catalogs (team_b_dev) ==="
curl -sS -X POST "$BASE/metalakes/demo_metalake/catalogs" \
  -H 'Accept: application/vnd.gravitino.v1+json' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "team_b_dev",
    "type": "RELATIONAL",
    "comment": "catalog B -- its own backend DB and warehouse prefix",
    "provider": "lakehouse-iceberg",
    "properties": {
      "catalog-backend": "jdbc",
      "uri": "jdbc:postgresql://postgres:5432/iceberg_team_b",
      "warehouse": "s3://lakehouse/warehouse-team-b",
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

echo "=== prove live: GET /iceberg/v1/config?warehouse=team_b_dev ==="
curl -sS 'http://localhost:9002/iceberg/v1/config?warehouse=team_b_dev'
echo

echo "=== prove live: namespace round-trip ==="
curl -sS -X POST 'http://localhost:9002/iceberg/v1/team_b_dev/namespaces' \
  -H 'Content-Type: application/json' -d '{"namespace": ["catalog_b_ns"]}'
echo
curl -sS 'http://localhost:9002/iceberg/v1/team_b_dev/namespaces'
echo

echo "=== management API: list catalogs ==="
curl -sS "$BASE/metalakes/demo_metalake/catalogs" \
  -H 'Accept: application/vnd.gravitino.v1+json'
echo

echo "=== prove isolation: lake still only has catalog_a_ns ==="
curl -sS 'http://localhost:9002/iceberg/v1/lake/namespaces'
echo

echo "=== prove isolation: team_b_dev still only has catalog_b_ns ==="
curl -sS 'http://localhost:9002/iceberg/v1/team_b_dev/namespaces'
echo
