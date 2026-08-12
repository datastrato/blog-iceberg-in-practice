#!/bin/bash
# Creates the metalake and the dynamic-mode Iceberg catalog through Gravitino's
# management API. This is the two curls from the README's Quickstart section,
# wrapped up for convenience -- run it by hand once per fresh
# `docker compose up`, after catalog-dynamic is healthy.
#
# `credential-providers` is set on the catalog from the start (rather than
# added later with a follow-up PUT): "type": "RELATIONAL" and
# "provider": "lakehouse-iceberg" are both required for an Iceberg catalog and
# easy to miss -- the natural guess for `type` is "ICEBERG", which is wrong.
set -euo pipefail

BASE="http://localhost:8090/api"

curl -sS -X POST "$BASE/metalakes" \
  -H 'Accept: application/vnd.gravitino.v1+json' \
  -H 'Content-Type: application/json' \
  -d '{"name": "demo_metalake", "comment": "iceberg-in-practice dynamic-mode rig"}'
echo

curl -sS -X POST "$BASE/metalakes/demo_metalake/catalogs" \
  -H 'Accept: application/vnd.gravitino.v1+json' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "lake",
    "type": "RELATIONAL",
    "comment": "dynamic-mode Iceberg catalog, JDBC/Postgres backend, MinIO warehouse",
    "provider": "lakehouse-iceberg",
    "properties": {
      "catalog-backend": "jdbc",
      "uri": "jdbc:postgresql://postgres:5432/iceberg_dynamic",
      "warehouse": "s3://lakehouse/warehouse-dynamic",
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
