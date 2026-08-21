#!/bin/bash
# Runs the full catalog-choice tour in order. Same boxed-banner convention as
# part-1's run-all.sh. Starts with create-metalake.sh, which also waits for
# catalog-dynamic to report healthy -- without that wait, script 01's first
# POST can race the server and fail confusingly.
set -euo pipefail
cd "$(dirname "$0")"

echo "############################################"
echo "# 0. create-metalake"
echo "############################################"
./create-metalake.sh
echo

echo "############################################"
echo "# 1. create catalog A (lake)"
echo "############################################"
./01-create-catalog-a.sh
echo

echo "############################################"
echo "# 2. create catalog B (team_b_dev), prove isolation"
echo "############################################"
./02-create-catalog-b.sh
echo

echo "############################################"
echo "# 3. drop catalog B (two-step)"
echo "############################################"
./03-drop-catalog-b.sh
echo

echo "############################################"
echo "# 4. prove non-destructive drop"
echo "############################################"
./04-persistence-after-drop.sh
echo

echo "############################################"
echo "# 5. seed a catalog Gravitino has never seen"
echo "############################################"
./05-seed-legacy-catalog.sh
echo

echo "############################################"
echo "# 6. register it in one POST, prove federation"
echo "############################################"
./06-register-legacy.sh
echo
