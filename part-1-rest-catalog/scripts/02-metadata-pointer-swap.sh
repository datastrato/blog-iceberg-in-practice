#!/bin/bash
# Shows the table's metadata pointer moving across two commits.
#
# Every table's REST representation includes "metadata-location": the path to
# the current metadata.json file. A commit doesn't edit that file in place --
# it writes a brand new metadata.json and atomically swaps the pointer to it.
#
# The commits themselves run through scripts/commit-event.py (via the
# `pyiceberg` container already running as part of this part's own stack) --
# see that script and README.md's "The tour" for why a commit needs a
# client library and not just curl. Everything else here, before and after
# each commit, is still plain curl: that's what actually shows the pointer
# moving.
set -euo pipefail
cd "$(dirname "$0")/.."

TABLE_URL="http://localhost:9002/iceberg/v1/lake/namespaces/tour/tables/events"

echo "=== metadata-location before any commits ==="
curl -sS "$TABLE_URL" | python3 -c 'import json,sys; print(json.load(sys.stdin)["metadata-location"])'

commit() {
  docker compose exec -T pyiceberg python3 /scripts/commit-event.py "$1" "$2" "$3"
}

echo
echo "=== commit 1: insert one row (via PyIceberg) ==="
commit 1 signup "2026-08-01 00:00:00"

echo "=== metadata-location after commit 1 ==="
curl -sS "$TABLE_URL" | python3 -c 'import json,sys; print(json.load(sys.stdin)["metadata-location"])'

echo
echo "=== commit 2: insert one more row (via PyIceberg) ==="
commit 2 purchase "2026-08-01 01:00:00"

echo "=== metadata-location after commit 2 ==="
curl -sS "$TABLE_URL" | python3 -c 'import json,sys; print(json.load(sys.stdin)["metadata-location"])'

echo
echo "Two commits, two different metadata.json paths -- the table object itself"
echo "was never edited in place; each commit wrote a new file and swapped the pointer."
