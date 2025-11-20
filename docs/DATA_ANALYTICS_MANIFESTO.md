# Data & Analytics Manifesto: 18 Foundational Principles

**Version**: 2.0
**Classification**: Public
**License**: CC0 - Public Domain
**Standards**: ISO 8000 (Data Quality), DAMA-DMBOK principles
**Last Updated**: 2025-11-20

---

## Core Principles

### I. Data as Product
**Data assets shall be treated as first-class products with defined ownership, SLAs, and user contracts.**

Data is not byproduct of operational systems; it is intentional output requiring engineering discipline. Each dataset has accountable owner, quality metrics, documentation, and consumers. Producers serve consumers with reliability commitments.

- **Owner**: defined individual/team responsible for quality, availability, evolution
- **SLA**: latency, completeness, accuracy thresholds documented and monitored
- **Contract**: schema, semantics, update frequency, retention policy published
- **Consumers**: identified, requirements gathered, breaking changes communicated
- **Product thinking**: roadmap, versioning, deprecation policy, support channels

*Example*: `customers_v2` table owned by CRM team, 99.9% availability SLA, < 1 hour freshness, schema in Git, 15 downstream consumers cataloged.

---

### II. Single Source of Truth
**Each business entity or fact shall have exactly one authoritative source; downstream systems consume, never redefine.**

Eliminate data duplication at semantic level. One golden record per concept. Derived data clearly labeled as such. Version conflicts impossible by design.

- **Customer data**: one source system (CRM), all others reference or replicate
- **Derived metrics**: calculation logic centralized, not reimplemented per consumer
- `SELECT * FROM customers` not `SELECT DISTINCT name, address FROM orders`
- **Canonical identifiers** propagated; surrogate keys mapped to natural keys
- **Logical SSOT**: Multiple physical copies acceptable for performance/geo-distribution, but one logical source with sync mechanisms

*Trade-off*: Absolute SSOT can create bottlenecks. Solution: Domain-driven SSOT - each domain owns its entities, federation through data mesh patterns.

---

### III. Immutability & Temporal Integrity
**Historical data shall be preserved; facts are appended, never deleted or overwritten.**

Audit trail complete. Time-travel queries possible. Current state derived from event history. Corrections append; original records retained.

- **Event sourcing**: `INSERT` only, no `UPDATE` or `DELETE` on fact tables
- **Slowly Changing Dimensions**: Type 2 (add row with effective dates) over Type 1 (overwrite)
- **Soft deletes**: `deleted_at` timestamp, not removal
- **Bitemporal tables**: `valid_time` (business time) + `transaction_time` (system time)
- **Corrections**: New row with `correction_flag = TRUE`, original preserved

*GDPR Compatibility*: Use pseudonymization with separate key vault; comply with Right to Erasure by deleting keys, rendering data unlinkable, not deleting historical facts.

---

### IV. Schema as Contract
**Data structures shall be explicitly defined, versioned, and enforced; schema evolution non-breaking.**

Strong typing mandatory. Schemas version controlled. Breaking changes require new version. Backward compatibility preserved through migration periods.

- **Schema registries**: Avro, Protobuf, JSON Schema with version management
- **Breaking change**: field removal, type change, constraint addition, required field addition
- **Non-breaking**: optional field addition, constraint relaxation, documentation updates
- **Evolution**: `v1` → `v2` with deprecation period, both supported during transition (6-12 months typical)
- **Forward/backward compatibility**: New code reads old data, old code reads new data

*Example*: Adding `customer.email_verified` (optional) is non-breaking. Changing `order.amount` from DECIMAL to INT is breaking, requires `orders_v3`.

---

### V. Data Quality by Design
**Quality checks integrated at ingestion; invalid data rejected or quarantined immediately.**

Validate early. Fail fast. Never persist bad data to production tables. Quality dimensions: accuracy, completeness, consistency, timeliness, validity, uniqueness.

- **Ingestion validation**: schema conformance, business rule checks, referential integrity
- **Quality gates**: data cannot promote through environments without passing thresholds
- **Metrics**: `NULL` rate, uniqueness violations, distribution drift, freshness lag
- **Quarantine tables**: failed records isolated with rejection reason for remediation
- **Criticality tiers**: Block on critical fields (customer_id), quarantine on non-critical (middle_name)

*Trade-off*: Perfect quality delays delivery. Solution: Risk-based approach - strict gates for financial data, relaxed for exploratory datasets.

---

### VI. Lineage & Provenance
**Data transformations shall be traceable from source to consumption; dependencies explicit.**

DAG (Directed Acyclic Graph) of transformations documented and visualized. Impact analysis automated. Data catalog maintains lineage metadata.

- **Column-level lineage**: `revenue = SUM(orders.amount * 1.2)` traceable to source columns
- **Dependencies**: upstream changes trigger downstream awareness/rebuilds
- **Tooling**: dbt DAG, Airflow task graphs, OpenLineage, data catalog lineage graphs
- **Reproducibility**: given source data + transformation code → deterministic output
- **Impact analysis**: "If I change `orders.status` schema, what breaks?" answered automatically

*Implementation*: dbt `ref()` macro creates explicit dependencies, automatically generates lineage graph.

---

### VII. Idempotency & Determinism
**Pipeline executions shall produce identical results when run multiple times on same input.**

Reprocessing safe. No side effects. No hidden state dependencies. Timestamps from data, not system clock.

- `INSERT ... ON CONFLICT UPDATE`: upsert semantics for reprocessing
- **Date partitioning**: `WHERE event_date = '2025-11-17'` not `WHERE created_at > NOW() - INTERVAL '1 day'`
- **Deterministic**: no `RANDOM()`, `NOW()`, `UUID()` in transformations; use event timestamps
- **Stateless**: output function of input only, not previous run state
- **Windowing**: For streaming, use event-time windows with watermarks, not processing-time

*Example*: Bad: `INSERT INTO daily_summary SELECT COUNT(*), CURRENT_DATE FROM events WHERE processed = FALSE; UPDATE events SET processed = TRUE`
Good: `INSERT INTO daily_summary SELECT COUNT(*), event_date FROM events WHERE event_date = '2025-11-17' GROUP BY event_date ON CONFLICT (event_date) DO UPDATE ...`

---

### VIII. Separation of Concerns
**Storage, computation, and consumption layers architecturally distinct; optimize independently.**

Raw data persisted separately from transformed data. Analytics workloads don't impact transactional systems. Query engines scale independently of storage.

- **Bronze/Silver/Gold** (or Raw/Cleansed/Curated) layers separated
- **OLTP ≠ OLAP**: transactional databases replicated to analytical warehouse via CDC
- **Compute elasticity**: query engines (Spark, Presto, BigQuery) scale without data movement
- **Storage formats**: row-based (PostgreSQL) for OLTP, columnar (Parquet, ORC) for analytics
- **Decoupled scaling**: Add query concurrency without increasing storage costs

*Architecture*: PostgreSQL (OLTP) → Debezium CDC → Kafka → Snowflake (OLAP). Writes don't impact analytical queries.

---

### IX. Late Binding & Flexibility
**Schema-on-read over schema-on-write where appropriate; support exploratory analysis.**

Preserve raw data in native format. Apply schema at query time. Enable ad-hoc exploration without ETL delay. Balance flexibility with governance.

- **Data lake**: raw files (JSON, CSV, Parquet) + metadata catalog + query engine (Trino, Athena)
- **Schema evolution**: additive changes don't break existing queries
- **Partitioning**: discoverable without schema modification (`/year=2025/month=11/day=17/`)
- **Exploration**: analysts query raw/bronze layer without engineering bottleneck
- **Progressive governance**: Bronze (flexible) → Silver (validated) → Gold (strictly governed)

*Trade-off*: Schema-on-read flexibility vs. query performance. Solution: Bronze flexible for exploration, Gold strict for production reporting.

---

### X. Declarative Transformation Logic
**Data transformations expressed as idempotent SQL/code defining desired state, not procedural steps.**

Define what, not how. Version controlled. Peer reviewed. Testable. Self-documenting through transparency.

- **dbt models**: `SELECT` statements defining table contents, executed by framework
- **SQL over procedural code**: `CREATE TABLE AS SELECT` > Python loops
- **Version control**: transformations in Git with PR review process
- **Testing**: schema tests, data tests, referential integrity checks in pipeline
- **Documentation as code**: Column descriptions in schema YAML files

*Example*:
```sql
-- models/marts/fct_orders.sql
{{ config(materialized='incremental', unique_key='order_id') }}

SELECT
    order_id,
    customer_id,
    order_date,
    amount,
    status
FROM {{ ref('stg_orders') }}
{% if is_incremental() %}
WHERE order_date > (SELECT MAX(order_date) FROM {{ this }})
{% endif %}
```

---

### XI. Incremental & Partitioned Processing
**Process data in bounded chunks; avoid full table scans; enable parallel execution.**

Partition by time, geography, tenant, or domain entity. Process only changed data. Parallelization through partitioning. Cost-efficient at scale.

- **Time partitioning**: daily/hourly folders, process only latest partition
- **Watermarking**: track high-water mark of processed data, resume from checkpoint
- **Incremental models**: `WHERE event_timestamp > (SELECT MAX(event_timestamp) FROM target)`
- **Backfills**: reprocess historical partitions independently without full refresh
- **Partition pruning**: Query optimization eliminates 99% of data from scan

*Cost impact*: Full scan of 10TB table: $50. Partition-pruned scan of 10GB: $0.05. 1000x savings.

---

### XII. Metrics as Code
**Business metrics defined once in version-controlled semantic layer; consistent across tools.**

Centralized metric definitions. Calculations not duplicated per dashboard/report. Version history preserved. Impact analysis for metric changes.

- **Semantic layer**: LookML, dbt metrics, Cube.js, MetricFlow definitions
- **Single definition**: `revenue = SUM(CASE WHEN status='completed' THEN amount ELSE 0 END)`
- **Certification**: blessed metrics badged; ad-hoc calculations discouraged for KPIs
- **Governance**: metric ownership, change approval, deprecation process
- **Versioning**: When calculation changes, create `revenue_v2`, support both during transition, migrate consumers, deprecate `revenue_v1`

*Example*:
```yaml
# metrics/revenue.yml
metrics:
  - name: revenue
    label: Total Revenue
    type: sum
    sql: amount
    filters:
      - field: status
        value: 'completed'
    owner: finance-team
    timestamp: order_date
```

---

### XIII. Data Observability
**Pipelines instrumented for monitoring; anomalies detected automatically; alerts actionable.**

Monitor data quality, freshness, volume, schema changes. Detect drift. Alert on SLA violations. Observability ≠ monitoring dashboards; automated detection required.

- **Freshness**: alert if table not updated within SLA window (e.g., daily table stale > 26 hours)
- **Volume anomalies**: statistical detection of unexpected row count changes (Z-score > 3)
- **Schema drift**: alert on unexpected columns, type changes, constraint violations
- **Data quality**: distribution checks, null rate thresholds, referential integrity
- **Incidents**: automated detection → alert → runbook → resolution → post-mortem
- **Lineage-aware**: Upstream failure cascades downstream notifications

*Tooling*: Great Expectations, Elementary, Monte Carlo, Datafold, custom dbt tests.

---

### XIV. Privacy & Compliance by Design
**Data governance controls embedded in architecture; PII protected at collection; access audited.**

Classification automated. Access control granular. Retention policies enforced. Anonymization/pseudonymization applied early. Regulatory compliance (GDPR, CCPA) operationalized.

- **Column-level classification**: PII, sensitive, public tags in catalog (automated via regex/ML)
- **Access control**: row-level security, column masking, role-based permissions
- **Right to erasure**: delete propagation through lineage graph, or pseudonymization key deletion
- **Data minimization**: collect only necessary fields, purge per retention policy
- **Audit logs**: all data access logged with user, timestamp, query, purpose
- **Anonymization**: k-anonymity, l-diversity, differential privacy for public datasets

*Example*: `customers.email` tagged as PII → automatic column masking for non-privileged users, retention policy 7 years, audit log on access.

---

### XV. Documentation as Practice
**Every dataset documented at creation; schemas, semantics, SLAs, examples, contact information maintained.**

README for datasets. Business glossary terms linked. Example queries provided. Known limitations documented. Contact information current.

- **Data catalog entry**: description, owner, update frequency, schema, sample queries
- **Column documentation**: business meaning, allowed values, measurement units, example values
- **Known issues**: edge cases, data quality limitations, planned improvements
- **Discoverability**: searchable catalog, tags, domain classification
- **Currency**: documentation updated with schema changes, stale docs flagged (> 6 months)
- **Business glossary**: Canonical definitions ("What is a 'customer'?") linked from columns

*Example*:
```yaml
version: 2
models:
  - name: fct_orders
    description: "Order transactions with customer and product details. Grain: one row per order."
    owner: data-platform-team
    sla: "Updated hourly, < 2 hour lag from source"
    columns:
      - name: order_id
        description: "Unique order identifier from e-commerce platform"
        tests: [unique, not_null]
      - name: amount
        description: "Order total in USD, including tax, excluding shipping"
```

---

### XVI. Explicit Data Contracts
**Producer-consumer agreements machine-readable and enforced; breaking changes prevented at deployment time.**

Contracts codify expectations: schema, quality, SLA, semantic meaning. Violations caught in CI/CD before production. Enables decentralized ownership without chaos.

- **Contract components**:
  - Schema (Avro, Protobuf, JSON Schema)
  - Quality (null rate < 1%, uniqueness constraints)
  - SLA (freshness, availability)
  - Semantic meaning (business glossary terms)
  - Example data (valid and invalid samples)
- **Enforcement**: CI/CD gates reject breaking changes without major version bump
- **Tooling**: dbt contracts, Great Expectations, Soda, custom contract validators
- **Failure modes**: Consumer notified before producer deploys incompatible change
- **Contract testing**: Producer runs consumer test suite before deployment

*Example*:
```yaml
# contracts/orders_v2.yml
name: orders_v2
owner: commerce-team
consumers: [analytics-team, ml-team, finance-team]
schema:
  - name: order_id
    type: STRING
    required: true
    unique: true
  - name: amount
    type: DECIMAL(10,2)
    required: true
    min: 0
quality:
  - null_rate(customer_id) < 0.01
  - uniqueness(order_id) = 1.0
sla:
  freshness: 1 hour
  availability: 99.9%
```

*Breaking change prevention*: PR adds `required: true` to optional field → CI fails → "Breaking change detected, version bump to v3 required."

---

### XVII. Comprehensive Testing
**Data pipelines tested at unit, integration, and end-to-end levels; regressions caught pre-production.**

Test transformations like application code. Fixtures for unit tests. Staging environment for integration tests. Statistical tests for data quality.

- **Unit**: Individual transformation logic with sample fixtures (10-100 rows)
  - `assert_equals(calculate_revenue(test_orders), expected_revenue)`
- **Integration**: Pipeline segments with realistic data volumes (1-10% production scale)
  - dbt build in CI environment with yesterday's data
- **End-to-end**: Full DAG execution in staging environment (production-like)
  - Smoke tests after deployment
- **Contract**: Consumer expectations validated against producer output
  - Backward compatibility tests: new producer code with old consumer code
- **Regression**: Historical outputs stored and compared (golden datasets)
  - `SELECT * FROM fct_orders WHERE date='2025-01-01'` results unchanged after refactor
- **Property-based**: Statistical properties asserted (distributions, correlations)
  - `assert revenue.mean() between 95 and 105` (expected ~100)

*dbt example*:
```sql
-- tests/assert_order_amounts_positive.sql
SELECT * FROM {{ ref('fct_orders') }}
WHERE amount < 0
-- Test passes if query returns 0 rows
```

*CI/CD workflow*:
1. PR opened → unit tests run (30 seconds)
2. Approved → integration tests in staging (5 minutes)
3. Merged → E2E tests in staging (20 minutes)
4. Staging validated → deploy to production
5. Post-deploy smoke tests (2 minutes)

---

### XVIII. Cost-Aware Engineering
**Storage, compute, and query patterns designed for cost efficiency; tradeoffs explicit and monitored.**

Data systems expensive at scale. Optimize intentionally. Monitor costs per team/project. Budget alerts. Cost-performance tradeoffs explicit.

- **Partitioning**: Prune 99% of data for typical queries (time, tenant, region)
  - `WHERE date >= '2025-11-01'` scans 20 days, not 10 years
- **Materialization strategy**:
  - **View**: No storage cost, compute every query (low write:read ratio)
  - **Table**: Storage cost, compute once (high write:read ratio)
  - **Incremental**: Balance of both
- **Storage tiers**:
  - **Hot** (SSD): last 30 days, frequent access
  - **Warm** (HDD): last 2 years, monthly access
  - **Cold** (archive): > 2 years, rare access, 10x cheaper
- **Compute rightsizing**:
  - Warehouse size (S/M/L/XL) based on query complexity
  - Autoscaling policies, suspend after 5 minutes idle
  - Spot instances for batch processing (50-90% savings)
- **Query optimization**:
  - **Predicate pushdown**: Filter before join
  - **Column pruning**: `SELECT needed_cols`, not `SELECT *`
  - **Broadcast joins**: Small dimension tables broadcasted to workers
  - **Z-ordering/clustering**: Co-locate related data on disk
- **Monitoring**:
  - Cost per query, pipeline, team with budgets
  - Alert: team exceeds $10k/month budget
  - Showback/chargeback for accountability

*Example*:
- Before: `SELECT * FROM events` (10TB) → $500/query
- After: `SELECT user_id, event_type FROM events WHERE date='2025-11-17'` (10GB) → $0.50/query
- 1000x cost reduction through partitioning + column pruning

---

## Trade-offs & Resolution Patterns

Real-world data engineering requires balancing competing principles. Common conflicts and their resolutions:

### Immutability vs. Privacy (Right to Erasure)
**Conflict**: Principle III requires preserving history. GDPR requires deleting personal data on request.

**Resolution**:
- **Pseudonymization**: Store hashed customer ID with separate key vault. To "delete," remove the key, rendering historical facts unlinkable but preserved for aggregate analytics.
- **Partial deletion**: Delete PII columns (`email`, `address`), retain transactional facts (`amount`, `timestamp`, `pseudonymous_id`)
- **Retention policies**: Automatically purge data older than legal requirement (e.g., 7 years)

### Single Source of Truth vs. Late Binding Flexibility
**Conflict**: Principle II enforces strict schemas. Principle IX enables exploratory flexibility.

**Resolution**: **Layered governance**:
- **Bronze layer**: Schema-on-read, JSON/Parquet raw files, exploratory
- **Silver layer**: Schema-on-write validated, cleaned, documented
- **Gold layer**: Strict SSOT, blessed business entities, production reporting

Analysts explore Bronze, promote valuable patterns to Silver/Gold.

### Quality Gates vs. Delivery Speed
**Conflict**: Principle V blocks bad data. Product teams need fast iteration.

**Resolution**: **Risk-based quality tiers**:
- **Critical** (financial, legal): 100% validation, block on failure
- **Important** (core product): 99% validation, alert on failure
- **Exploratory** (experimental features): Best-effort, quarantine on failure

Example: Block if `order.amount IS NULL`. Quarantine if `customer.middle_name` invalid.

### Cost vs. Completeness
**Conflict**: Principle III preserves all history. Principle XVIII minimizes cost.

**Resolution**: **Tiered storage + compaction**:
- Hot tier: Last 90 days, full detail, SSD
- Warm tier: 90 days - 2 years, daily aggregates, HDD
- Cold tier: > 2 years, monthly aggregates, S3 Glacier
- Purge: > 7 years (legal retention limit)

Example: Retain clickstream events (petabytes) for 30 days, daily aggregates for 2 years, monthly for 7 years.

### Centralization vs. Domain Ownership
**Conflict**: Central platform ensures consistency. Domain teams need autonomy.

**Resolution**: **Data Mesh with Federated Governance**:
- **Domains own data products**: Commerce team owns orders, Customer team owns customers
- **Central platform provides tooling**: Self-serve data infrastructure (dbt, Airflow, Snowflake)
- **Federated governance**: Central policies (privacy, security), domain-specific SLAs
- **Interoperability standards**: Shared schema registry, lineage format (OpenLineage), catalog

---

## Anti-Patterns

Common violations with real-world consequences:

### ❌ Dashboard-Driven Development
**Anti-Pattern**: Building pipelines to match existing (broken) dashboard instead of fixing root data quality issue.

**Consequence**: Technical debt accumulates. "Shadow ETL" in BI tool. Unmaintainable.

**Solution**: Fix upstream data quality. Rebuild dashboard from clean data. Delete workaround transformations.

### ❌ Gold Plating
**Anti-Pattern**: Over-engineering data quality for infrequently-used datasets.

**Consequence**: Wasted engineering time. Analysis paralysis. Delayed delivery.

**Solution**: Prioritize based on consumption patterns. 80/20 rule: Perfect the 20% of tables driving 80% of queries. Best-effort for long-tail.

### ❌ Premature Optimization
**Anti-Pattern**: Building real-time streaming pipeline for daily batch use case.

**Consequence**: 10x cost, 5x complexity, no user benefit.

**Solution**: Honestly assess latency requirements. Most analytics tolerate hourly/daily latency. Start with batch, migrate to streaming only when business case proven.

### ❌ Copy-Paste Transformations
**Anti-Pattern**: Duplicating SQL logic across pipelines instead of centralizing.

**Consequence**: Divergent definitions. "Revenue" means 5 different things. Trust erodes.

**Solution**: Principle XII (Metrics as Code). Single source, dbt macro/CTE, semantic layer.

### ❌ Siloed Ownership
**Anti-Pattern**: Central data team as bottleneck for all transformations.

**Consequence**: 2-week ticket queue. Analysts blocked. Shadow pipelines in spreadsheets.

**Solution**: Domain teams own their data products. Platform team provides self-serve tooling. Data team focuses on governance, not execution.

### ❌ Schema-less Hell
**Anti-Pattern**: No schema enforcement. JSON blobs with arbitrary structure.

**Consequence**: Queries break unexpectedly. Data types inconsistent. Joins impossible.

**Solution**: Principle IV (Schema as Contract). Even if schema-on-read at Bronze, enforce at Silver/Gold.

### ❌ Manual Data Quality Checks
**Anti-Pattern**: Analyst manually spot-checks dashboard every morning, emails team if broken.

**Consequence**: Doesn't scale. Issues detected after users see bad data. No alerting at night/weekend.

**Solution**: Principle XIII (Observability). Automated tests, statistical anomaly detection, PagerDuty integration.

### ❌ Undocumented Transformations
**Anti-Pattern**: Complex SQL in Airflow DAG with no comments. Original author left company.

**Consequence**: "No one knows what this does, don't touch it." Technical debt immortal.

**Solution**: Principle X (Declarative), XV (Documentation). dbt model with column-level documentation, business glossary terms, example queries.

---

## Modern Architecture Considerations

### Data Mesh Principles

For decentralized, domain-driven data ownership at scale:

**Domain Ownership**:
- Domains (e.g., Commerce, Marketing, Product) own data products end-to-end
- Data product = dataset + transformations + documentation + SLA + support

**Data as Product**:
- Each domain treats data as product for internal consumers
- Product thinking: roadmap, versioning, user feedback, quality metrics

**Self-Serve Data Platform**:
- Central platform team provides infrastructure: orchestration (Airflow), warehouse (Snowflake), catalog, CI/CD
- Domains deploy autonomously without platform team involvement

**Federated Computational Governance**:
- Policies defined centrally (privacy, security, interoperability)
- Enforcement automated through platform (e.g., PII auto-masking)
- Domains implement policies through templated tools

*Example*: Commerce domain publishes `commerce.orders` data product. Marketing domain consumes for attribution analysis. Central platform provides dbt project template enforcing privacy policies. Commerce team deploys independently.

### Streaming Architecture

For real-time/near-real-time use cases:

**Event-Driven**:
- Source systems emit events to Kafka/Kinesis
- Consumers process event streams
- Eventual consistency model

**Exactly-Once Semantics**:
- Idempotent processing (Principle VII) + transactional writes
- Kafka transactions, Flink checkpoints, Spark Structured Streaming

**Windowing**:
- **Tumbling**: Fixed, non-overlapping (every hour)
- **Sliding**: Overlapping (last hour, updated every minute)
- **Session**: Gap-based (user session until 30min inactivity)

**Late Arrivals**:
- Watermarks: "Expect data within 10 minutes of event time"
- Late data: either drop or emit late corrections
- Balancing latency vs. completeness

**Stateful Processing**:
- Aggregations (SUM, COUNT) require state management
- Checkpointing for fault tolerance
- State stores (RocksDB) for large state

*Example*: Fraud detection requires < 100ms latency. Stream `transactions` events from Kafka, join with `user_risk_scores` in Flink state store, emit fraud alerts. Batch processing inadequate for this latency requirement.

### ML/AI Pipelines

For machine learning on data platforms:

**Feature Stores**:
- Centralized features (transformed signals for ML)
- Online store (low-latency serving) + offline store (batch training)
- Time-travel: retrieve features as of training time to prevent leakage

**Training/Serving Skew**:
- Training uses batch ETL logic. Serving uses real-time API logic. Logic diverges → model degrades.
- Solution: Shared feature transformation code (Python library), deployed to both batch and real-time

**Versioning**:
- Model version (v3.2) + feature version (v1.5) + training data snapshot (2025-11-17)
- Reproducibility: retrain model from historical artifacts

**Lineage Integration**:
- `model_v3.2 → training_data_2025-11-17 → feature_store_v1.5 → raw_events`
- Impact analysis: If `user_events` schema changes, which models need retraining?

**Monitoring**:
- Feature drift: input distributions shift (COVID changes user behavior)
- Prediction drift: output distributions shift (more fraud predictions)
- Ground truth feedback: predictions vs. actual outcomes

*Example*: Recommendation model uses features from feature store. Feature engineering in dbt SQL, served via REST API for real-time predictions and batch for training. Feature store ensures training/serving consistency.

---

## Tool Ecosystem Map

Mapping principles to implementing technologies:

| Principle | Open Source | Commercial | Notes |
|-----------|-------------|------------|-------|
| I (Data as Product) | dbt, Amundsen | Atlan, Alation | Data catalog + ownership |
| IV (Schema as Contract) | Avro, Protobuf, JSON Schema | Confluent Schema Registry | Version compatibility |
| V (Data Quality) | Great Expectations, Soda, dbt tests | Monte Carlo, Datafold, Lightup | Automated quality checks |
| VI (Lineage) | OpenLineage, dbt docs, SQLLineage | Atlan, Collibra, Manta | Column-level lineage |
| VIII (Separation) | Trino, Presto, Spark | Snowflake, BigQuery, Databricks | Decoupled compute/storage |
| X (Declarative) | dbt, SQLMesh | Matillion, Dataform (Google) | SQL-based transformations |
| XI (Incremental) | dbt incremental, Spark streaming | Fivetran incremental, Airbyte | Efficient processing |
| XII (Metrics as Code) | dbt metrics, Cube.js, MetricFlow | Looker (LookML), Transform | Semantic layer |
| XIII (Observability) | Elementary, re_data | Monte Carlo, Datafold, Bigeye | Anomaly detection |
| XIV (Privacy) | Apache Ranger, AWS Macie | Immuta, BigID, OneTrust | Data governance |
| XVI (Contracts) | dbt contracts, Great Expectations | Soda, Datafold | Contract enforcement |
| XVII (Testing) | pytest, dbt tests | Datafold (diff testing) | Automated testing |
| XVIII (Cost) | Kubernetes autoscaling, S3 tiers | Snowflake auto-suspend, BigQuery BI Engine | Cost optimization |

**Orchestration**: Airflow (OSS), Dagster (OSS), Prefect (hybrid), Astronomer (commercial)
**Catalogs**: Amundsen (OSS), DataHub (OSS), Atlan (commercial), Alation (commercial)
**Reverse ETL**: Census (commercial), Hightouch (commercial), Grouparoo (OSS - archived)

---

## Implementation Checklist

Minimum viable implementation for each principle:

### I. Data as Product
- [ ] Identify owner (name + contact) for each production dataset
- [ ] Document SLA (freshness, availability) in catalog
- [ ] Publish schema in version control (Git)
- [ ] Identify and catalog consumers (downstream tables/dashboards)
- [ ] Establish support channel (Slack, email)

### II. Single Source of Truth
- [ ] Map business entities to source systems (Customer → CRM, Order → E-commerce DB)
- [ ] Audit duplicate entity definitions across systems
- [ ] Consolidate to single source per entity, deprecate others
- [ ] Document canonical identifiers (primary keys)
- [ ] Establish cross-reference tables for surrogate keys

### III. Immutability & Temporal Integrity
- [ ] Implement soft deletes (`deleted_at`) instead of hard deletes
- [ ] Add audit columns (`created_at`, `updated_at`, `updated_by`) to fact tables
- [ ] Convert dimension tables to Slowly Changing Dimension Type 2 (`valid_from`, `valid_to`)
- [ ] Establish retention policies (how long to keep history)
- [ ] Test time-travel queries (`WHERE valid_from <= '2024-01-01' AND valid_to > '2024-01-01'`)

### IV. Schema as Contract
- [ ] Deploy schema registry (Confluent, AWS Glue, custom)
- [ ] Define schemas in Avro/Protobuf/JSON Schema for key datasets
- [ ] Implement schema validation at ingestion
- [ ] Establish versioning convention (v1, v2, v3)
- [ ] Document breaking vs. non-breaking changes in runbook

### V. Data Quality by Design
- [ ] Implement ingestion validation (reject malformed records)
- [ ] Define quality metrics for top 10 tables (null rate, uniqueness, freshness)
- [ ] Create quality dashboard with trend charts
- [ ] Set up alerting on quality threshold breaches
- [ ] Establish quarantine table pattern for failed records

### VI. Lineage & Provenance
- [ ] Visualize DAG of transformations (dbt docs, Airflow UI)
- [ ] Implement column-level lineage (manually document for key metrics)
- [ ] Enable impact analysis ("what breaks if I change this?")
- [ ] Integrate lineage into data catalog
- [ ] Test reproducibility (rerun pipeline on historical data)

### VII. Idempotency & Determinism
- [ ] Audit pipelines for non-deterministic functions (`NOW()`, `RANDOM()`)
- [ ] Replace with event timestamps from data
- [ ] Implement upsert logic (`INSERT ... ON CONFLICT UPDATE`)
- [ ] Use date partitioning for incremental processing
- [ ] Test: run pipeline twice, assert identical output

### VIII. Separation of Concerns
- [ ] Separate production OLTP databases from OLAP warehouse
- [ ] Implement CDC replication (Debezium, Fivetran, Airbyte)
- [ ] Establish Bronze/Silver/Gold layer convention
- [ ] Use columnar format (Parquet) for analytics tables
- [ ] Configure compute autoscaling independent of storage

### IX. Late Binding & Flexibility
- [ ] Set up data lake for raw file storage (S3, ADLS, GCS)
- [ ] Deploy query engine for schema-on-read (Trino, Athena, BigQuery)
- [ ] Implement partitioning discovery (Hive-style `/year=2025/month=11/`)
- [ ] Enable analyst self-service querying of Bronze layer
- [ ] Progressive governance: flexible Bronze → strict Gold

### X. Declarative Transformation Logic
- [ ] Migrate transformations to dbt SQL models (or equivalent)
- [ ] Store transformation code in Git
- [ ] Implement PR review process for changes
- [ ] Add dbt tests (schema tests, data tests)
- [ ] Generate and publish documentation (dbt docs generate)

### XI. Incremental & Partitioned Processing
- [ ] Partition large tables by date (`event_date`, `created_at`)
- [ ] Implement incremental models (process only new data)
- [ ] Track high-water marks for incremental pipelines
- [ ] Enable parallel processing of partitions
- [ ] Test backfill process (reprocess historical data)

### XII. Metrics as Code
- [ ] Identify top 20 business metrics (revenue, DAU, churn, etc.)
- [ ] Define metrics in semantic layer (dbt metrics, LookML, Cube.js)
- [ ] Centralize calculation logic (no duplication)
- [ ] Version metrics (revenue_v1, revenue_v2)
- [ ] Deprecate ad-hoc metric calculations in dashboards

### XIII. Data Observability
- [ ] Implement freshness monitoring (alert if > SLA)
- [ ] Set up volume anomaly detection (Z-score > 3)
- [ ] Monitor schema changes (alert on unexpected columns)
- [ ] Add data quality checks with alerting
- [ ] Create incident runbooks for common failures

### XIV. Privacy & Compliance by Design
- [ ] Classify columns (PII, sensitive, public) in catalog
- [ ] Implement column-level access control (masking for non-privileged users)
- [ ] Set up audit logging (all access to PII logged)
- [ ] Define retention policies per data classification
- [ ] Test Right to Erasure process (delete user data on request)

### XV. Documentation as Practice
- [ ] Create data catalog entry for each production dataset
- [ ] Document columns (business meaning, allowed values, examples)
- [ ] Add example queries to catalog
- [ ] Link business glossary terms
- [ ] Update documentation with schema changes (automated via dbt)

### XVI. Explicit Data Contracts
- [ ] Define contracts for top 10 datasets (schema + quality + SLA)
- [ ] Implement contract validation in CI/CD
- [ ] Set up breaking change detection (version bump required)
- [ ] Notify consumers before contract changes
- [ ] Test backward compatibility (old consumer + new producer)

### XVII. Comprehensive Testing
- [ ] Add unit tests for transformation logic (dbt tests, pytest)
- [ ] Set up CI environment for integration tests
- [ ] Implement regression testing (golden datasets)
- [ ] Add contract tests (consumer expectations)
- [ ] Run smoke tests post-deployment

### XVIII. Cost-Aware Engineering
- [ ] Implement partitioning for cost reduction (query pruning)
- [ ] Set up cost monitoring dashboard (cost per team/project)
- [ ] Define materialization strategy (view vs. table vs. incremental)
- [ ] Configure compute autoscaling and auto-suspend
- [ ] Establish budget alerts (team exceeds $X/month)

---

## Organizational Enablement

Data excellence requires cultural transformation, not just technology:

### Executive Sponsorship
- **Top-down mandate**: CEO/CTO communication on "data as strategic asset"
- **Budget allocation**: Dedicate 10-15% of engineering budget to data platform
- **Success metrics**: Data quality KPIs in executive dashboard (freshness, completeness)
- **Accountability**: Data incidents reviewed in leadership meetings

### Incentive Alignment
- **Reward data quality**: Engineer bonuses tied to SLA achievement
- **Penalize silos**: Manager reviews include cross-team collaboration metrics
- **Celebrate success**: Spotlight teams improving data quality, reducing incidents
- **Blameless post-mortems**: Focus on system improvements, not individual fault

### Training Programs
- **SQL for analysts**: 2-day bootcamp on JOINs, window functions, CTEs
- **Data modeling for engineers**: Dimensional modeling, normalization, schema design
- **dbt for analytics engineers**: Hands-on workshop on building transformation pipelines
- **Governance for leaders**: Policy-setting, escalation procedures, regulatory compliance

### Community of Practice
- **Data guild**: Monthly meetups, show-and-tell, knowledge sharing
- **Office hours**: Data platform team availability for consultation
- **Internal blog**: Document lessons learned, best practices
- **Mentorship**: Pair senior and junior data engineers

### Conway's Law Considerations
- **Domain-aligned teams**: Commerce team owns commerce data products end-to-end
- **Platform team**: Builds self-serve infrastructure, not execution bottleneck
- **Data governance**: Enabling function, not control tower. Set policy, provide tooling.
- **Avoid**: Centralized data team as single point of failure for all transformations

### Change Management
- **Pilot program**: Start with one domain (e.g., Commerce), prove value, expand
- **Quick wins**: Fix most painful data quality issue in 2 weeks → build credibility
- **Migration path**: Parallel run old and new pipelines, gradual cutover
- **Sunset legacy**: Decommission old systems after 6-month overlap

---

## Pipeline Maturity Model

Assess current state and set improvement goals:

### Level 0 - Chaos
- Manual SQL queries copy-pasted into production
- No version control
- No testing, monitoring, or documentation
- Data quality issues discovered by end users

**Action**: Establish Git repository for all SQL, implement basic documentation

### Level 1 - Scripted
- Python/SQL scripts automated via cron
- Some version control (ad-hoc Git usage)
- Basic testing (manual spot checks)
- Monitoring: email on failure

**Action**: Migrate to workflow orchestrator (Airflow, Prefect), implement unit tests

### Level 2 - Orchestrated
- DAG-based workflows with dependencies
- Consistent version control (all code in Git)
- Automated testing (schema tests, data tests)
- Monitoring dashboards (query dashboards for issues)

**Action**: Add data quality gates, automated anomaly detection, CI/CD pipelines

### Level 3 - DataOps
- CI/CD pipelines (deploy on merge to main)
- Comprehensive testing (unit, integration, E2E)
- Data quality gates (cannot deploy bad data)
- Observability (automated alerts, runbooks, post-mortems)

**Action**: Build semantic layer, enable self-service, federate ownership

### Level 4 - Self-Service Platform
- Semantic layer (metrics as code, certified definitions)
- Governed self-service (analysts query without engineering bottleneck)
- Federated ownership (domains own data products)
- Data mesh architecture (decentralized, domain-driven)

**Action**: Continuous improvement, cost optimization, advanced ML integration

---

## Data Quality Dimensions (Expanded)

1. **Accuracy**: Values represent reality correctly
   - Measurement: Reconciliation against source of truth
   - Example: `bank_balance` in warehouse matches bank API

2. **Completeness**: No missing required values
   - Measurement: `NULL` rate per column
   - Example: `customer.email` < 1% NULL for required field

3. **Consistency**: Same data across systems matches; no contradictions
   - Measurement: Cross-system reconciliation
   - Example: `SUM(orders.amount)` matches `revenue` in finance system

4. **Timeliness**: Data available within SLA; freshness meets requirements
   - Measurement: `MAX(updated_at)` vs. current time
   - Example: Daily table refreshed by 6am every day

5. **Validity**: Values conform to format, type, domain constraints
   - Measurement: Regex validation, range checks
   - Example: `email` matches regex, `age` between 0 and 120

6. **Uniqueness**: No unintended duplicates; primary keys enforced
   - Measurement: `COUNT(DISTINCT primary_key)` = `COUNT(*)`
   - Example: No duplicate `order_id` in `fct_orders`

7. **Integrity**: Referential integrity maintained (foreign keys valid)
   - Measurement: Orphaned record detection
   - Example: Every `order.customer_id` exists in `dim_customers`

8. **Precision**: Appropriate level of detail/granularity
   - Measurement: Decimal places, rounding
   - Example: Currency stored as DECIMAL(10,2), not FLOAT

---

## Dimensional Modeling Principles (Expanded)

### Fact Tables
- **Atomic grain**: Lowest level of detail (one row per transaction, event, measurement)
- **Additive measures**: Metrics that can be summed (amount, quantity)
- **Semi-additive**: Metrics summed across some dimensions (balance across customers, not time)
- **Non-additive**: Metrics requiring averaging/complex math (ratios, percentages)
- **Foreign keys**: References to dimension tables
- **Degenerate dimensions**: Dimension data stored in fact (transaction ID)

*Example*: `fct_orders` - grain is one row per order. Columns: `order_id`, `customer_id` (FK), `product_id` (FK), `order_date` (FK), `amount` (additive), `quantity` (additive)

### Dimension Tables
- **Descriptive attributes**: Text, categories for filtering/grouping
- **Denormalized**: Attributes from multiple normalized tables flattened
- **Slowly Changing Dimensions**:
  - **Type 0**: No changes allowed (birthdate)
  - **Type 1**: Overwrite (no history - address correction)
  - **Type 2**: Add row with effective dates (full history - job title changes)
  - **Type 3**: Add columns (old_value, new_value - track one change)
- **Surrogate keys**: Artificial primary key (auto-increment) independent of natural key

*Example*: `dim_customers` - surrogate key `customer_key`, natural key `customer_id`, attributes `name`, `email`, `segment`, `valid_from`, `valid_to` (SCD Type 2)

### Star Schema
- **Fact table** surrounded by **dimension tables**
- Simple queries: `SELECT dim.attribute, SUM(fact.measure) FROM fact JOIN dim GROUP BY dim.attribute`
- Query-performant: Minimal joins, columnar compression
- Intuitive: Business users understand structure

### Snowflake Schema
- Normalized dimensions (dimension hierarchies split into separate tables)
- Storage-efficient but more complex queries (more joins)
- Less common in modern analytics (storage cheap, query performance prioritized)

### Conformed Dimensions
- **Shared dimensions** across fact tables (same `dim_date`, `dim_customer` for orders and support tickets)
- **Enables cross-domain analysis**: "Revenue by customer segment" joins `fct_orders` and `dim_customers`. "Support costs by customer segment" joins `fct_support_tickets` and same `dim_customers`. Can now analyze revenue vs. support cost.
- **Master data management**: One authoritative dimension, multiple facts reference

---

## Metaprinciples (Expanded)

**Optimize for Consumption, Not Production**
Analytics infrastructure exists to serve decision-makers. Producer convenience subordinate to consumer utility. Metrics: query latency, data freshness, user satisfaction. Not: pipeline simplicity.

**Left-Shift Data Quality**
Catch errors at ingestion, not discovery in dashboards. Cost of fixing increases exponentially downstream. $1 at source, $10 in pipeline, $100 in production, $1000 in business decision.

**Conway's Law Applied**
Data architecture reflects organizational communication patterns. Siloed teams → data silos. Cross-functional teams own domains end-to-end → integrated data products.

**Reproducibility is Non-Negotiable**
Given source data version + transformation code version → deterministic output. No "works on my machine." Version control for data (snapshots) and code (Git).

**Self-Service with Guardrails**
Analysts empowered to query without data engineering bottleneck, within governance boundaries. Governed self-service: access control, certified metrics, curated datasets. Not: wild west, not centralized gatekeeping.

**Batch vs. Stream: Choose Deliberately**
Batch (hourly/daily) sufficient for 90% of use cases. Stream processing for real-time needs only (fraud detection, trading, live dashboards). Streaming 5-10x more complex and expensive.

**Cost-Aware by Default**
Storage cheap, compute expensive. Design for cost: partition pruning, predicate pushdown, materialized views, autoscaling. Monitor and optimize continuously.

**Schema Registry Mandatory**
For event streams and data interchange. Version compatibility enforced at runtime. Prevents "schema hell" (producer changes break consumers).

**Progressive Governance**
Bronze layer: flexible, exploratory. Silver: validated, cleaned. Gold: strictly governed, production. Balance innovation and control.

**Fail Fast, Fail Loudly**
Data quality issues should block pipelines, not silently propagate. Alert immediately. Never persist bad data to production tables.

---

## Version History

**v2.0 (2025-11-20)**
- Added Principle XVI (Explicit Data Contracts)
- Added Principle XVII (Comprehensive Testing)
- Added Principle XVIII (Cost-Aware Engineering)
- New section: Trade-offs & Resolution Patterns
- New section: Anti-Patterns
- New section: Modern Architecture Considerations (Data Mesh, Streaming, ML)
- New section: Tool Ecosystem Map
- New section: Implementation Checklist (minimum viable per principle)
- New section: Organizational Enablement
- Expanded Data Quality Dimensions (7 → 8)
- Expanded Dimensional Modeling Principles
- Expanded Metaprinciples
- Enhanced existing principles with trade-offs, examples, GDPR considerations

**v1.0 (2025-XX-XX)**
- Initial release: 15 foundational principles
- Core sections: Corollaries, Dimensional Modeling, Data Quality, Pipeline Maturity

---

**Status**: Living document - community contributions welcome
**Feedback**: GitHub Issues / Pull Requests
**Citation**: "Data & Analytics Manifesto v2.0" (2025), licensed under CC0 Public Domain

---

**Acknowledgments**: Built on principles from DAMA-DMBOK, Kimball dimensional modeling, data mesh (Zhamak Dehghani), dbt best practices, and battle scars from production data systems at scale.
