#!/bin/bash
# Federation beat 1 of 2: build the "catalog you already run".
# Creates a Postgres database and an Iceberg JDBC catalog inside it that
# Gravitino has never heard of, with its own warehouse prefix, and seeds
# sales.orders through PyIceberg's SqlCatalog -- a plain JDBC client, no
# Gravitino anywhere in its config. Script 06 registers it afterwards.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "=== create the legacy catalog's own backend database ==="
docker compose exec -T postgres psql -U iceberg -d iceberg -tc \
  "SELECT 1 FROM pg_database WHERE datname = 'iceberg_legacy'" | grep -q 1 \
  || docker compose exec -T postgres psql -U iceberg -d iceberg -c "CREATE DATABASE iceberg_legacy"

echo "=== seed sales.orders through PyIceberg's SqlCatalog (Gravitino not involved) ==="
docker compose --profile federation run --rm -T pyiceberg python3 /scripts/seed-legacy.py

echo "=== what landed in the backend, straight from Postgres ==="
docker compose exec -T postgres psql -U iceberg -d iceberg_legacy \
  -c "SELECT catalog_name, table_namespace, table_name FROM iceberg_tables"

echo "=== Gravitino still knows nothing about it: list catalogs ==="
curl -sS "http://localhost:8090/api/metalakes/demo_metalake/catalogs" \
  -H 'Accept: application/vnd.gravitino.v1+json'
echo
