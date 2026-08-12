# Iceberg in Practice

Companion code for **Iceberg in Practice**, a series on running Apache Iceberg
well — starting from the REST Catalog spec itself and building up to real
multi-engine usage. Read the series on [datastrato.ai](https://datastrato.ai/blog):

- **Part 1: [The Iceberg REST Catalog, Actually Explained](https://datastrato.ai/blog/iceberg-rest-catalog-actually-explained)**
- **Part 2: [One Table, Many Engines](https://datastrato.ai/blog/one-table-many-engines)**

> **These are demo rigs, not reference deployments.** Single-node storage, no
> auth, no TLS, no HA — built to make Iceberg's behavior visible, not to model
> a production topology. Each part's README says so again, closer to the code.

## Contents

- **[`part-1-rest-catalog/`](part-1-rest-catalog/)** — a curl-level tour of the
  Iceberg REST Catalog API: config discovery, creating a namespace and table,
  watching the metadata pointer swap across commits, and fetching vended
  credentials. Runs against part 2's stack; no infrastructure of its own.
- **[`part-2-one-table-many-engines/`](part-2-one-table-many-engines/)** — one
  Iceberg REST Catalog, four engines (Spark, Flink, Trino, DuckDB) reading and
  writing the same table, including a concurrency test with two engines
  committing at once.

## License

Apache License 2.0 — see [LICENSE](LICENSE).
