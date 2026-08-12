#!/bin/bash
# Runs a SQL file through Trino via `docker compose exec`. Trino needs no extra
# jars or wrapper config beyond conf/trino/catalog/lake_dynamic.properties,
# which is already mounted into the container.
set -euo pipefail
cd "$(dirname "$0")/.."

SQLFILE="${1:-sql/03-trino-dynamic.sql}"
docker compose exec -T trino trino -f "/sql/$(basename "$SQLFILE")"
