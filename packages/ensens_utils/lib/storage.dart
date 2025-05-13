import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'models/settings.dart';

final class EnsensStorage {
  EnsensStorage();
  bool _initialized = false;
  final _DataBaseProvider _provider =
      _DataBaseProvider(fileName: 'ensens.sqlite');
  // final _SqlRequests _sqlRequests;
  late final _Settings _settings = _Settings(provider: _provider);
  late final _DeviceInfo _deviceInfo = _DeviceInfo(provider: _provider);
  late final _History _history =
      _History(provider: _provider, table: 'History');
  int? deviceId;

  Future<int?> getDeviceId(String name) => _deviceInfo.getKey(name);
  Future<bool> deviceExists(String name) => _deviceInfo.exists(name);
  Future<int> addDevice(String name) => _deviceInfo.add(name);
  Future<int> deleteDeviceByName(String name) => _deviceInfo.deleteByName(name);
  Future<int> deleteDevice(int id) => _deviceInfo.delete(id);

  Future<Settings> getSettings() => _settings.get();
  Future<void> updateSettings(Settings s) => _settings.update(s);

  Future<void> recreateHistory() async {
    try {
      await _provider.dropTable('History');
      await _provider.rawExecute(_history.create);
    } catch (_) {
      throw UnimplementedError('Failed to recreate history table!');
    }
  }

  String get historyTableName => _history.table;

  Future<int> getHistoryLength() =>
      _history.getHistoryLength(deviceId: deviceId);

  Future<DateTime?> getLastHistoryTs() async {
    final Map<String, dynamic> raw =
        await getSingleHistory(deviceId: deviceId, last: true);
    return raw.isNotEmpty ? DateTime.fromMillisecondsSinceEpoch(raw['timestamp']! as int) : null;
  }

  Future<DateTime?> getFirstHistoryTs() async {
    final Map<String, dynamic> raw = await getSingleHistory(deviceId: deviceId);
    return raw.isNotEmpty ? DateTime.fromMillisecondsSinceEpoch(raw['timestamp'] as int) : null;
  }

  Future<Map<String, dynamic>> getSingleHistory(
      {int? deviceId, bool last = false}) async {
    final List<Map<String, dynamic>> entries =
        await _history.getHistory(deviceId: deviceId, last: last, limit: 1);
    return entries.isNotEmpty ? entries.first : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> getHistory(
          {int? deviceId,
          bool last = false,
          int? limit,
          String? where,
          List<String>? columns}) =>
      _history.getHistory(
          deviceId: deviceId,
          columns: columns,
          last: last,
          limit: limit,
          where: where);

  Future<void> addHistory(List<Map<String, Object?>> history) =>
      _history.addHistory(history);

  Future<int> deleteHistory(List<int> ids) => _history.deleteHistory(ids);

  Future<void> init() async {
    _initialized = await _provider.init();
    if (!_initialized) {
      throw ArgumentError('Database provider is not initialized!');
    }
    final Map<String, String> tables = <String, String>{
      _settings.table: _settings.create,
      _deviceInfo.table: _deviceInfo.create,
      _history.table: _history.create
    };
    for (final MapEntry<String, String> entry in tables.entries) {
      try {
        if (!await _provider.tableExists(entry.key)) {
          await _provider.rawExecute(entry.value);
        }
      } catch (_) {
        throw UnimplementedError("Failed to init '${entry.key}' table!");
      }
    }
    // add initial data
    if (await _provider.getTableLength(_settings.table) == 0) {
      try {
        final Settings entry = Settings(
            searchDevicePattern: _settings._deafultSearchDevicePattern);
        final Map<String, Object?> raw = _settings.toRaw(entry);
        await _provider.database.insert(_settings.table, raw);
      } catch (_) {
        throw UnimplementedError(
            'Failed to fill settings with default values!');
      }
    }
  }
}

class _History {
  _History({required this.provider, required this.table});
  final _DataBaseProvider provider;

  final String table;
  final String key = '_id';

  String get create => '''
  CREATE TABLE "$table" (
    "$key"	INTEGER NOT NULL UNIQUE,
    "hwId" INTEGER NOT NULL,
    "battery" INTEGER DEFAULT 0,
    "temperature" REAL DEFAULT 0,
    "voc" REAL DEFAULT 0,
    "co2" REAL DEFAULT 0,
    "iaq" REAL DEFAULT 0,
    "humidity" REAL DEFAULT 0,
    "pressure" REAL DEFAULT 0,
    "timestamp" INTEGER DEFAULT 0,
    PRIMARY KEY("$key" AUTOINCREMENT)
  )
  ''';

  Future<int> getHistoryLength({int? deviceId}) =>
      provider.getTableLength(table,
          extraCond: deviceId != null ? 'WHERE hwId == $deviceId' : '');

  Future<List<Map<String, dynamic>>> getHistory(
          {int? deviceId,
          bool last = false,
          int? limit,
          String? where,
          List<String>? columns}) =>
      provider.database.query(table,
          columns: columns,
          where: where == null || where.isEmpty
              ? null
              : '${deviceId != null ? 'hwId == $deviceId' : ''}'
                  '${where.isNotEmpty ? ' AND $where' : ''}',
          orderBy: last ? '$key DESC' : 'timestamp ASC, hwId ASC',
          limit: limit);

  Future<void> addHistory(List<Map<String, Object?>> history) async {
    for (final Map<String, Object?> e in history) {
      try {
        final int rowId = await provider.database.update(table, e,
            conflictAlgorithm: ConflictAlgorithm.replace,
            where: 'hwId == ${e['hwId']} AND timestamp == ${e['timestamp']}');
        if (rowId == 0) {
          provider.database
              .insert(table, e, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      } catch (_) {
        throw UnimplementedError('Failed to add history entry: $e !');
      }
    }
  }

  Future<int> deleteHistory(List<int> ids) async {
    final String keys = ids.join(',');
    try {
      final int rows =
          await provider.database.delete(table, where: '$key IN ($keys)');
      return rows;
    } catch (_) {
      throw UnimplementedError('Failed to delete history!');
    }
  }
}

final class _DeviceInfo {
  _DeviceInfo({required this.provider});
  final _DataBaseProvider provider;

  final String table = 'DeviceInfo';
  final String key = '_id';

  String get create => '''
  CREATE TABLE "$table" (
    "$key" INTEGER NOT NULL UNIQUE,
    "name" TEXT NOT NULL UNIQUE,
    PRIMARY KEY("$key" AUTOINCREMENT)
  )
  ''';

  Future<bool> exists(String name) async => await getKey(name) != null;

  Future<int?> getKey(String name) async {
    final List<Map<String, Object?>> raw = await provider.database.query(table,
        columns: <String>[key], where: "name == '$name'", limit: 1);
    return raw.isNotEmpty ? raw.first.values.first! as int : null;
  }

  Future<int> add(String name) =>
      provider.database.insert(table, <String, Object?>{'name': name},
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<int> deleteByName(String name) =>
      provider.database.delete(table, where: "name == '$name'");

  Future<int> delete(int id) =>
      provider.database.delete(table, where: "$key == '$id'");
}

final class _Settings {
  _Settings({required this.provider});
  final _DataBaseProvider provider;

  final String table = 'Settings';
  final String key = '_id';

  final String _deafultSearchDevicePattern = 'ES_';

  String get create => '''
  CREATE TABLE "$table" (
    "$key" INTEGER NOT NULL UNIQUE,
    "searchDevicePattern"	TEXT DEFAULT '$_deafultSearchDevicePattern',
    "temperatureCtoF"	INTEGER DEFAULT 0,
    "pressureHpaToMmhg"	INTEGER DEFAULT 0,
    PRIMARY KEY("$key" AUTOINCREMENT)
  )
  ''';

  Map<String, Object?> toRaw(Settings settings) => settings.toMap().map(
      (String key, dynamic value) => MapEntry<String, Object?>(
          key, value is bool ? (value ? 1 : 0) : value));

  Settings fromRaw(Map<String, Object?> raw) => SettingsMapper.fromMap(raw);

  Future<Settings> get() async {
    final List<Map<String, Object?>> raw =
        await provider.database.query(table, limit: 1);
    if (raw.isEmpty) {
      throw UnimplementedError();
    }
    return fromRaw(raw.first);
  }

  Future<void> update(Settings settings) =>
      provider.database.update(table, toRaw(settings), where: '$key == 1');
}

final class _DataBaseProvider {
  _DataBaseProvider({required this.fileName});

  final String fileName;
  late Database _database;

  Database get database => _database;

  Future<bool> init() async {
    final bool isTargetPlatform = !kIsWeb && Platform.isAndroid;
    if (!isTargetPlatform) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final String databasePath = (await getApplicationDocumentsDirectory()).path;
    final String path = join(databasePath, fileName);

    _database = await openDatabase(path);
    return true;
  }

  Future<void> close() => database.close();

  Future<void> dropTable(String tableName) =>
      _database.execute('DROP TABLE IF EXISTS $tableName');

  Future<bool> tableExists(String tableName) async {
    final List<Map<String, Object?>> res = await database.query('sqlite_master',
        where: "name == '$tableName'", limit: 1);
    return res.isNotEmpty;
  }

  Future<int> getTableLength(String tableName,
      {String key = '_id', String extraCond = ''}) async {
    final int? length = Sqflite.firstIntValue(await database
        .rawQuery("SELECT COUNT($key) FROM '$tableName' $extraCond"));
    return length ?? 0;
  }

  Future<List<Map<String, Object?>>> rawQuery(String sql,
          [List<Object?>? arguments]) =>
      database.rawQuery(sql, arguments);

  Future<void> rawExecute(String sql, [List<Object?>? arguments]) =>
      database.execute(sql, arguments);
}
