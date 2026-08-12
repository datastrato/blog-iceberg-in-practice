#!/bin/bash
# Runs a SQL file through the DuckDB CLI (fetched by jars-init) against the
# dynamic-mode catalog.
set -euo pipefail
cd "$(dirname "$0")/.."

SQLFILE="${1:-sql/04-duckdb-dynamic.sql}"
docker compose exec -T duckdb /opt/duckdb/duckdb -f "/sql/$(basename "$SQLFILE")"
