#!/bin/bash
# Fetches short-lived, scoped credentials for the table's own storage location
# from the credentials endpoint -- this is what lets an engine read/write S3
# directly without ever holding a long-lived key of its own. The "lake" catalog
# was created (in part 2's Quickstart) with credential-providers=s3-token, so
# this returns genuine STS-vended credentials, not a static passthrough.
set -euo pipefail

curl -sS 'http://localhost:9002/iceberg/v1/lake/namespaces/tour/tables/events/credentials'
echo
