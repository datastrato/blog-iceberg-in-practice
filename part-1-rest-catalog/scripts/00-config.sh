#!/bin/bash
# GET /v1/config -- the first call any Iceberg REST client makes. It returns the
# server's defaults and overrides for this catalog, including its "prefix" (the
# path segment every other endpoint is namespaced under).
set -euo pipefail

curl -sS 'http://localhost:9002/iceberg/v1/config?warehouse=lake'
echo
