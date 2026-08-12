#!/bin/bash
# Spark against the embedded/aux Iceberg REST service (catalog-dynamic:9001).
# `warehouse` is set to the catalog's name ("lake") -- this is a real, named
# Gravitino catalog, and `warehouse` is a catalog-name lookup key, not a storage
# path. See the README's "warehouse means catalog name" gotcha.
set -euo pipefail

exec /opt/spark/bin/spark-sql \
  --jars "$(echo /opt/spark/jars/extra/*.jar | tr ' ' ',')" \
  --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
  --conf spark.sql.catalog.lake=org.apache.iceberg.spark.SparkCatalog \
  --conf spark.sql.catalog.lake.type=rest \
  --conf spark.sql.catalog.lake.uri=http://catalog-dynamic:9001/iceberg/ \
  --conf spark.sql.catalog.lake.warehouse=lake \
  --conf spark.sql.catalog.lake.io-impl=org.apache.iceberg.aws.s3.S3FileIO \
  --conf spark.sql.catalog.lake.s3.endpoint=http://minio:9000 \
  --conf spark.sql.catalog.lake.s3.path-style-access=true \
  --conf spark.sql.defaultCatalog=lake \
  --conf spark.driver.memory=2g \
  --conf spark.sql.shuffle.partitions=4 \
  --master "local[4]" \
  "$@"
