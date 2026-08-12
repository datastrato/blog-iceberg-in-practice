#!/bin/bash
# Flink 1.20.5 SQL client + iceberg-flink-runtime-1.20:1.11.0.
# Run inside the flink-jobmanager container: flink-sql.sh /sql/02-flink-dynamic.sql
#
# No --jar flags: the connector jars are mounted into a subdirectory of lib/, and
# Flink's own config.sh classpath builder (`find $FLINK_LIB_DIR ! -type d -name
# '*.jar'`) already recurses into it, so they're on the classpath exactly once.
# Passing them again via --jar loads a second copy into a different classloader,
# and Iceberg's RESTCatalog from one copy fails to cast to Catalog from the other.
set -euo pipefail

exec /opt/flink/bin/sql-client.sh embedded -f "$1"
