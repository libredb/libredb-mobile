import 'package:flutter/material.dart';

/// The icon of an engine whose type the app does not know, since Studio adds engines over time.
const IconData genericEngineIcon = Icons.storage_outlined;

/// The icon for a connection's engine `type`, by family; the type is an opaque string, compared exactly, and one the
/// app does not know gets [genericEngineIcon].
IconData engineIcon(String type) => _engineIcons[type] ?? genericEngineIcon;

const _relational = Icons.table_chart_outlined;
const _file = Icons.insert_drive_file_outlined;
const _document = Icons.description_outlined;
const _keyValue = Icons.vpn_key_outlined;
const _search = Icons.manage_search;
const _wideColumn = Icons.view_column_outlined;
const _timeSeries = Icons.show_chart;
const _messaging = Icons.swap_horiz;
const _graph = Icons.hub_outlined;
const _vector = Icons.scatter_plot_outlined;
const _objectStore = Icons.cloud_outlined;
const _cluster = Icons.dns_outlined;
const _industrial = Icons.precision_manufacturing_outlined;
const _network = Icons.router_outlined;

/// Studio's engine ids (libredb-studio `src/lib/db-ui-config.ts`) by family.
const Map<String, IconData> _engineIcons = {
  'postgres': _relational,
  'mysql': _relational,
  'oracle': _relational,
  'db2': _relational,
  'mssql': _relational,
  'clickhouse': _relational,
  'druid': _relational,
  'trino': _relational,
  'databend': _relational,
  'bigquery': _relational,
  'snowflake': _relational,
  'spark': _relational,
  'libredb': _relational,
  'sqlite': _file,
  'duckdb': _file,
  'libsql': _file,
  'mongodb': _document,
  'couchbase': _document,
  'firestore': _document,
  'redis': _keyValue,
  'etcd': _keyValue,
  'oxia': _keyValue,
  'elasticsearch': _search,
  'opensearch': _search,
  'cassandra': _wideColumn,
  'prometheus': _timeSeries,
  'influxdb': _timeSeries,
  'influxdb3': _timeSeries,
  'kafka': _messaging,
  'rabbitmq': _messaging,
  'mqtt': _messaging,
  'sparkplug': _messaging,
  'neo4j': _graph,
  'milvus': _vector,
  'qdrant': _vector,
  's3': _objectStore,
  'kubernetes': _cluster,
  'opcua': _industrial,
  'mtconnect': _industrial,
  'modbus': _industrial,
  'netconf': _network,
  'snmp': _network,
};
