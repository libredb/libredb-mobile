# Hand-written Studio answers

These answers are hand-written, not recorded: they hold the container shapes and edge answers that the SQLite sample of `tool/studio-dev` cannot produce, and `test/infrastructure/studio/handwritten_studio_answers_test.dart` reads each one through the app's readers.
Each follows libredb-studio at 02dc26057; where the producing function runs without a live engine, the answer is that function's output under Bun with stubbed engine replies, and otherwise it is written from the code named below.
The names, counts and the ClickHouse server message are made up; the fields, their shapes and Studio's own sentences are not.
Record a real answer instead wherever `tool/studio-dev` can produce one.

| Answer | Studio source |
| --- | --- |
| `mongodb/meta.json`, `oracle/meta.json`, `mssql/meta.json` | `src/app/api/db/provider-meta/route.ts`, the provider's `getCapabilities()` and `getLabels()` |
| `mongodb/containers.json`, `mongodb/list_collection.json` | `src/lib/db/providers/document/mongodb/index.ts`, `listContainers` and `objectsFrom` |
| `mongodb/query_find.json` | `src/lib/db/providers/document/mongodb/values.ts`, `serializeMongoDocument` (an ObjectId as its hex string, a Date as its ISO text), and `index.ts`, `uniquelyKeyedRows` over `unionFields`, through the body of `src/lib/api/editor-query.ts`; libredb-studio at c9989a6b5 |
| `mongodb/describe_collection.json` | `src/lib/db/providers/document/mongodb/index.ts`, `objectDetailFrom` |
| `oracle/list_package.json` | `src/lib/db/providers/sql/oracle.ts`, `collapsePackages` |
| `oracle/source_package.json` | `src/lib/db/providers/sql/oracle.ts`, `readObjectSource` and `sourcePart`; the DDL text from `tests/integration/db/oracle-provider.test.ts` |
| `mssql/containers_database.json`, `mssql/containers_schema.json` | `src/lib/db/providers/sql/mssql.ts`, `listContainers` |
| `rabbitmq/counts.json` | `src/lib/db/providers/stream/rabbitmq/objects.ts`, `countKinds` |
| `firestore/describe_collection.json` | `src/lib/db/providers/document/firestore/objects.ts`, `describeFirestoreObject`, and `sampling.ts`, `inferColumns` |
| `firestore/source_document.json`, `firestore/source_document_colon_id.json` | `src/lib/db/providers/document/firestore/objects.ts`, `readFirestoreSource`, through `boundSourceDocument` in `src/lib/api/object-route.ts` |
| `clickhouse/describe_indexes_unavailable.json` | `src/lib/db/providers/sql/clickhouse/objects.ts`, `describeObject` |
| `postgres/describe_exclusion.json` | `src/lib/db/providers/sql/postgres.ts`, `objectDetailFromRow` |
| `firestore/meta.json`, `etcd/meta.json` | `src/app/api/db/provider-meta/route.ts`, the provider's `getCapabilities()` and `getLabels()`; `keyScan` from `document/firestore/key-scan.ts`, `FIRESTORE_KEY_SCAN`, and `keyvalue/etcd/key-scan.ts`, `ETCD_KEY_SCAN` |
| `firestore/keyscan_level.json` | `src/lib/db/providers/document/firestore/key-scan.ts`, `scanIdLevel` on the root level with a count of 3, over a stubbed `listCollectionIds` that returns a page token on each of Studio's 10 requests and one reserved id (`__stats__`) |
| `redis/keyscan_clustered.json` | `src/lib/db/providers/keyvalue/redis.ts`, `scanKeysPage`, with stubbed `SCAN`, `DBSIZE`, `INFO cluster` (`cluster_enabled:1`) and `TYPE` replies |
