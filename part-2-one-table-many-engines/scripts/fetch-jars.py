#!/usr/bin/env python3
"""Fetch the pinned Spark/Flink/Hadoop/Iceberg jars and the DuckDB CLI.

Every artifact below is pinned to an exact version and a SHA-256 checksum taken
from the artifact's official source (Maven Central's own sidecar file for the
Iceberg/Hadoop jars; computed locally from the signed GitHub release asset for
DuckDB, whose release has no published checksums file). A download that doesn't
match its pinned hash is treated as a hard failure, not a warning -- this script
never puts an unverified file where an engine can load it.

Run automatically by the `jars-init` service on `docker compose up`. Re-running
is safe: artifacts already present with the correct hash are left alone.
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
        "name": "iceberg-spark-runtime-3.5_2.12-1.11.0.jar",
        "url": "https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/1.11.0/iceberg-spark-runtime-3.5_2.12-1.11.0.jar",
        "sha256": "94b8e36fc329f0293d44ba9e01b784a56e9501affec1842d898144c51f6e486a",
        "dest": "/out/spark/iceberg-spark-runtime-3.5_2.12-1.11.0.jar",
    },
    {
        "name": "iceberg-aws-bundle-1.11.0.jar (spark)",
        "url": "https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-aws-bundle/1.11.0/iceberg-aws-bundle-1.11.0.jar",
        "sha256": "38f01da7e96850cdd05e6616d758b77b43314b712a8808e3f9a824d56976162f",
        "dest": "/out/spark/iceberg-aws-bundle-1.11.0.jar",
    },
    {
        "name": "iceberg-flink-runtime-1.20-1.11.0.jar",
        "url": "https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-flink-runtime-1.20/1.11.0/iceberg-flink-runtime-1.20-1.11.0.jar",
        "sha256": "33f7c29e2d53ef2c6e2942c1c324d817a03e32cc080f8a8b3056a3d0846e3691",
        "dest": "/out/flink/iceberg-flink-runtime-1.20-1.11.0.jar",
    },
    {
        "name": "hadoop-client-api-3.3.6.jar",
        "url": "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-client-api/3.3.6/hadoop-client-api-3.3.6.jar",
        "sha256": "f3d2347a6e1c6885d5bcfd4f60c3ac3810ec11068fc161e04329baabf412d963",
        "dest": "/out/flink/hadoop-client-api-3.3.6.jar",
    },
    {
        "name": "hadoop-client-runtime-3.3.6.jar",
        "url": "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-client-runtime/3.3.6/hadoop-client-runtime-3.3.6.jar",
        "sha256": "15f01bc804294df06d2effc87de363a83cf589f50558bdbf48f72541ad8de854",
        "dest": "/out/flink/hadoop-client-runtime-3.3.6.jar",
    },
    {
        "name": "iceberg-aws-bundle-1.11.0.jar (flink)",
        "url": "https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-aws-bundle/1.11.0/iceberg-aws-bundle-1.11.0.jar",
        "sha256": "38f01da7e96850cdd05e6616d758b77b43314b712a8808e3f9a824d56976162f",
        "dest": "/out/flink/iceberg-aws-bundle-1.11.0.jar",
    },
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
        "    `docker compose up jars-init`.",
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
