#!/bin/bash
# Footnote to the same section: dropping a catalog de-registers it, it does not destroy
# metadata or data. Recreates a catalog pointed at the dropped team_b_dev's
# old backend database (iceberg_team_b, never dropped -- only the catalog
# object was) and shows catalog_b_ns is still there. Self-cleaning: drops the
# recovery catalog at the end so the tour stays safely rerunnable.
set -euo pipefail

BASE="http://localhost:8090/api"

echo "=== POST /metalakes/demo_metalake/catalogs (team_b_recovered, reuses team_b_dev's old backend DB) ==="
curl -sS -X POST "$BASE/metalakes/demo_metalake/catalogs" \
  -H 'Accept: application/vnd.gravitino.v1+json' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "team_b_recovered",
    "type": "RELATIONAL",
    "comment": "reuses the backend DB the dropped team_b_dev catalog used -- proves drop is non-destructive",
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

echo "=== prove persistence: catalog_b_ns survived the earlier drop ==="
curl -sS 'http://localhost:9002/iceberg/v1/team_b_recovered/namespaces'
echo

echo "=== self-cleanup: disable + drop team_b_recovered ==="
curl -sS -X PATCH "$BASE/metalakes/demo_metalake/catalogs/team_b_recovered" \
  -H 'Accept: application/vnd.gravitino.v1+json' \
  -H 'Content-Type: application/json' \
  -d '{"inUse": false}'
echo
curl -sS -X DELETE "$BASE/metalakes/demo_metalake/catalogs/team_b_recovered" \
  -H 'Accept: application/vnd.gravitino.v1+json'
echo
