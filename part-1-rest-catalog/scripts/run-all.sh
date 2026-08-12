#!/bin/bash
# Runs the whole part-1 tour end to end, in the order the README walks through
# it. Requires the part-2 stack already up and its `lake` catalog already
# created -- see README.md's Prerequisites.
set -euo pipefail
cd "$(dirname "$0")"

echo "############################################"
echo "# 1. GET /v1/config"
echo "############################################"
./00-config.sh

echo
echo "############################################"
echo "# 2. Create a namespace and a table"
echo "############################################"
./01-namespace-and-table.sh

echo
echo "############################################"
echo "# 3. Metadata pointer swap across two commits"
echo "############################################"
./02-metadata-pointer-swap.sh

echo
echo "############################################"
echo "# 4. Fetch vended credentials"
echo "############################################"
./03-vended-credentials.sh

echo
echo "############################################"
echo "# 5. List namespaces -- tour and (if part 2's engine sections have run) demo"
echo "############################################"
curl -sS 'http://localhost:9002/iceberg/v1/lake/namespaces'
echo
