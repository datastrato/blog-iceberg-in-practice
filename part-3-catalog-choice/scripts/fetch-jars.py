#!/usr/bin/env python3
"""Fetch the pinned DuckDB CLI used to read the registered catalog back.

Pinned to an exact version and a SHA-256 checksum computed locally from the
signed GitHub release asset (DuckDB's release publishes no checksums file). A
download that doesn't match its pinned hash is treated as a hard failure, not a
warning -- this script never puts an unverified binary where an engine can run
it.

Part 2 fetches Spark/Flink/Iceberg jars this way too; part 3 needs only the one
artifact, because the seeder writes through PyIceberg rather than a JVM engine.

Run by the `jars-init` service, which lives in the `federation` compose profile
-- so it runs for scripts 05-06, not on a plain `docker compose up -d`.
Re-running is safe: an artifact already present is left alone.
"""
import hashlib
import shutil
import sys
import urllib.error
import urllib.request
import zipfile
from pathlib import Path

MANIFEST = [
    {
        "name": "duckdb_cli-linux-amd64.zip (v1.5.5)",
        "url": "https://github.com/duckdb/duckdb/releases/download/v1.5.5/duckdb_cli-linux-amd64.zip",
        "sha256": "08c0ca117111fcede14239d0093792352befdc174218c344d232c13279643d05",
        "dest": "/out/duckdb/_duckdb_cli.zip",
        "extract_to": "/out/duckdb/duckdb",
    },
]


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def fail(artifact, reason):
    target = artifact.get("extract_to", artifact["dest"])
    print(f"\n!!! FETCH FAILED: {artifact['name']}", file=sys.stderr)
    print(f"    reason: {reason}", file=sys.stderr)
    print(f"    url:    {artifact['url']}", file=sys.stderr)
    print(f"    expected sha256: {artifact['sha256']}", file=sys.stderr)
    print(
        "    If you're offline or behind a proxy, fetch this URL by hand and place\n"
        f"    it at {target} inside the jars-init container's mounted\n"
        "    volume (e.g. `docker cp <file> <container>:<path>`), then re-run\n"
        "    `docker compose --profile federation up jars-init`.",
        file=sys.stderr,
    )
    sys.exit(1)


def already_present(artifact):
    final = Path(artifact.get("extract_to", artifact["dest"]))
    if not final.is_file():
        return False
    if "extract_to" in artifact:
        # The pinned hash covers the zip, not the extracted binary -- if the
        # binary is already there, trust it (it can only have come from a
        # previously-verified run of this same script).
        return True
    return sha256_of(final) == artifact["sha256"]


def fetch(artifact):
    if already_present(artifact):
        print(f"OK  (cached) {artifact['name']}")
        return

    dest = Path(artifact["dest"])
    dest.parent.mkdir(parents=True, exist_ok=True)
    print(f"... fetching {artifact['name']}")
    try:
        urllib.request.urlretrieve(artifact["url"], dest)
    except (urllib.error.URLError, OSError) as e:
        fail(artifact, f"download error: {e}")

    actual = sha256_of(dest)
    if actual != artifact["sha256"]:
        dest.unlink(missing_ok=True)
        fail(artifact, f"SHA256 mismatch (expected {artifact['sha256']}, got {actual})")

    if "extract_to" in artifact:
        with zipfile.ZipFile(dest) as zf:
            names = [n for n in zf.namelist() if not n.endswith("/")]
            if len(names) != 1:
                fail(artifact, f"expected exactly one file inside the zip, found {names}")
            final = Path(artifact["extract_to"])
            with zf.open(names[0]) as src, open(final, "wb") as out:
                shutil.copyfileobj(src, out)
            final.chmod(0o755)
        dest.unlink()

    print(f"OK  {artifact['name']}")


def main():
    for artifact in MANIFEST:
        fetch(artifact)
    print("\nAll artifacts fetched and verified.")


if __name__ == "__main__":
    main()
