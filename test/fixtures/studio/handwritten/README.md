# Hand-written Studio answers

These answers are hand-written, not recorded: they hold the container shapes and edge answers that the SQLite sample of `tool/studio-dev` cannot produce, and `test/infrastructure/studio/handwritten_studio_answers_test.dart` reads each one through the app's readers.
Each follows libredb-studio at 02dc26057; where the producing function runs without a live engine, the answer is that function's output under Bun with stubbed engine replies, and otherwise it is written from the code named below.
The names, counts and the ClickHouse server message are made up; the fields, their shapes and Studio's own sentences are not.
Record a real answer instead wherever `tool/studio-dev` can produce one.

| Answer | Studio source |
| --- | --- |
| `mongodb/meta.json`, `oracle/meta.json`, `mssql/meta.json` | `src/app/api/db/provider-meta/route.ts`, the provider's `getCapabilities()` and `getLabels()` |
| `mongodb/containers.json`, `mongodb/list_collection.json` | `src/lib/db/providers/document/mongodb/index.ts`, `listContainers` and `objectsFrom` |
| `mongodb/describe_collection.json` | `src/lib/db/providers/document/mongodb/index.ts`, `objectDetailFrom` |
| `oracle/list_package.json` | `src/lib/db/providers/sql/oracle.ts`, `collapsePackages` |
| `oracle/source_package.json` | `src/lib/db/providers/sql/oracle.ts`, `readObjectSource` and `sourcePart`; the DDL text from `tests/integration/db/oracle-provider.test.ts` |
| `mssql/containers_database.json`, `mssql/containers_schema.json` | `src/lib/db/providers/sql/mssql.ts`, `listContainers` |
| `rabbitmq/counts.json` | `src/lib/db/providers/stream/rabbitmq/objects.ts`, `countKinds` |
| `firestore/describe_collection.json` | `src/lib/db/providers/document/firestore/objects.ts`, `describeFirestoreObject`, and `sampling.ts`, `inferColumns` |
| `firestore/source_document.json`, `firestore/source_document_colon_id.json` | `src/lib/db/providers/document/firestore/objects.ts`, `readFirestoreSource`, through `boundSourceDocument` in `src/lib/api/object-route.ts` |
| `clickhouse/describe_indexes_unavailable.json` | `src/lib/db/providers/sql/clickhouse/objects.ts`, `describeObject` |
| `postgres/describe_exclusion.json` | `src/lib/db/providers/sql/postgres.ts`, `objectDetailFromRow` |
