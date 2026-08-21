# Iceberg in Practice

Companion code for **Iceberg in Practice**, a series on running Apache Iceberg
well — starting from the REST Catalog spec itself and building up to real
multi-engine usage. Read the series on [datastrato.ai](https://datastrato.ai/blog):

- **Part 1: [The Iceberg REST Catalog, Actually Explained](https://datastrato.ai/blog/iceberg-rest-catalog-actually-explained)**
- **Part 2: [One Table, Many Engines](https://datastrato.ai/blog/one-table-many-engines)**
- **Part 3: Catalog Choice: The Decision That Outlives Your Engines** (post
  link added when it publishes)

> **These are demo rigs, not reference deployments.** Single-node storage, no
> auth, no TLS, no HA — built to make Iceberg's behavior visible, not to model
> a production topology. Each part's README says so again, closer to the code.

Each part is **self-contained**: its own `docker-compose.yml`, its own
Gravitino/Postgres/MinIO, runnable from that part's directory alone in a fresh
clone — no need to check out or start any other part first. The parts do
publish the same host ports (by design, so the stacks stay identical in shape),
so bring one down before starting the other; see each part's own README for
the exact port list.

## Contents

- **[`part-1-rest-catalog/`](part-1-rest-catalog/)** — a curl-level tour of the
  Iceberg REST Catalog API: config discovery, creating a namespace and table,
  watching the metadata pointer swap across commits, and fetching vended
  credentials. The one non-curl step (making an actual commit) runs through a
  SHA-pinned PyIceberg client, not a query engine.
- **[`part-2-one-table-many-engines/`](part-2-one-table-many-engines/)** — one
  Iceberg REST Catalog, four engines (Spark, Flink, Trino, DuckDB) reading and
  writing the same table, including a concurrency test with two engines
  committing at once.
- **[`part-3-catalog-choice/`](part-3-catalog-choice/)** — a curl-level tour of
  catalogs as API objects: creating and dropping catalogs through Gravitino's
  management API with no restart, proving a drop de-registers without
  destroying data, and registering a pre-existing Iceberg JDBC catalog that
  Gravitino never created, then reading its rows back through the Iceberg REST
  endpoint with DuckDB.

## License

Apache License 2.0 — see [LICENSE](LICENSE).
