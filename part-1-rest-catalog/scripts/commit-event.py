#!/usr/bin/env python3
"""Make one commit to lake.tour.events via PyIceberg.

This is the one non-curl step in the tour. A commit means writing an actual data
file and a new manifest before the catalog's single atomic REST update call --
that's a client-library operation, not something curl can do without hand-building
Iceberg's file formats by hand. Every curl call around this script (in
scripts/02-metadata-pointer-swap.sh) still shows the actual protocol: fetch
metadata-location, commit, fetch metadata-location again, watch it point at a new
file. This script is only the write path itself -- the same "write data, then one
atomic update" shape the blog post's commit-protocol section describes.

Usage: commit-event.py <event_id> <event_name> <event_time ISO8601>
"""
import sys
from datetime import datetime

import pyarrow as pa
from pyiceberg.catalog import load_catalog


def main() -> None:
    event_id, event_name, event_time = sys.argv[1], sys.argv[2], sys.argv[3]

    # auth={"type": "noop"} is PyIceberg's equivalent of DuckDB's
    # AUTHORIZATION_TYPE 'none': without it, PyIceberg's REST client attaches a
    # literal `Authorization: Bearer None` header (no token configured, stringified
    # anyway), which Gravitino rejects with 401. See README.md's Gotchas.
    catalog = load_catalog(
        "lake",
        uri="http://catalog-dynamic:9001/iceberg/",
        warehouse="lake",
        **{"auth": {"type": "noop"}},
    )

    # scripts/01-namespace-and-table.sh already created this table via curl;
    # load it rather than create it, so a rerun can't silently change its schema.
    table = catalog.load_table("tour.events")

    # event_id is `required` in the table's schema (see 01-namespace-and-table.sh);
    # PyIceberg checks the appended data's nullability against it field-for-field,
    # so the pyarrow schema has to say non-nullable explicitly -- a plain pa.array()
    # defaults every field to nullable and append() rejects the mismatch outright.
    arrow_schema = pa.schema(
        [
            pa.field("event_id", pa.int64(), nullable=False),
            pa.field("event_name", pa.string(), nullable=True),
            pa.field("event_time", pa.timestamp("us"), nullable=True),
        ]
    )
    row = pa.table(
        {
            "event_id": [int(event_id)],
            "event_name": [event_name],
            "event_time": [datetime.fromisoformat(event_time)],
        },
        schema=arrow_schema,
    )
    table.append(row)  # <-- the one atomic REST update call happens inside here


if __name__ == "__main__":
    main()
