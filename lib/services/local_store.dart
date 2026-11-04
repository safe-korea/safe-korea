import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'browser_records_stub.dart'
    if (dart.library.js_interop) 'browser_records_web.dart';

import 'dart:io';

import 'package:flutter/services.dart';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

class MeetingPoint {
  const MeetingPoint(this.latitude, this.longitude);
  final double latitude, longitude;
  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
  Map<String, double> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };
  static MeetingPoint? fromJson(dynamic value) {
    if (value is! Map ||
        value['latitude'] is! num ||
        value['longitude'] is! num) {
      return null;
    }
    final point = MeetingPoint(
      (value['latitude'] as num).toDouble(),
      (value['longitude'] as num).toDouble(),
    );
    return point.isValid ? point : null;
  }
}

class FamilyPlan {
  const FamilyPlan({
    this.contactName = '',
    this.phone = '',
    this.meetingPlace = '',
    this.backupPlace = '',
    this.note = '',
    this.backupContactName = '',
    this.backupPhone = '',
    this.meetingPoint,
    this.backupPoint,
  });
  final String contactName,
      phone,
      meetingPlace,
      backupPlace,
      note,
      backupContactName,
      backupPhone;
  final MeetingPoint? meetingPoint, backupPoint;
  bool get hasMeetingPlan =>
      meetingPlace.trim().isNotEmpty ||
      backupPlace.trim().isNotEmpty ||
      note.trim().isNotEmpty ||
      meetingPoint != null ||
      backupPoint != null;
  bool get isEmpty =>
      !hasMeetingPlan &&
      [
        contactName,
        phone,
        backupContactName,
        backupPhone,
      ].every((value) => value.trim().isEmpty);
  Map<String, dynamic> toJson() => {
    'contactName': contactName,
    'phone': phone,
    'meetingPlace': meetingPlace,
    'backupPlace': backupPlace,
    'note': note,
    'backupContactName': backupContactName,
    'backupPhone': backupPhone,
    if (meetingPoint?.isValid ?? false) 'meetingPoint': meetingPoint!.toJson(),
    if (backupPoint?.isValid ?? false) 'backupPoint': backupPoint!.toJson(),
  };
  factory FamilyPlan.fromJson(Map<String, dynamic> json) => FamilyPlan(
    contactName: json['contactName'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    meetingPlace: json['meetingPlace'] as String? ?? '',
    backupPlace: json['backupPlace'] as String? ?? '',
    note: json['note'] as String? ?? '',
    backupContactName: json['backupContactName'] as String? ?? '',
    backupPhone: json['backupPhone'] as String? ?? '',
    meetingPoint: MeetingPoint.fromJson(json['meetingPoint']),
    backupPoint: MeetingPoint.fromJson(json['backupPoint']),
  );
}

class LocalStore {
  // Preserve the public injection argument used by storage tests.
  // ignore: prefer_initializing_formals
  LocalStore({Database? database}) : _database = database;
  Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    if (Platform.isIOS) {
      // Do not save private family plans if backup exclusion cannot be applied.
      await const MethodChannel('kr.example.safe_korea/privacy')
          .invokeMethod<void>('excludeFamilyBackup');
    }
    return _database = await openDatabase(
      path.join(await getDatabasesPath(), 'safe_korea.db'),
      version: 1,
      onCreate: (db, version) => db.execute(
        'CREATE TABLE plans (id INTEGER PRIMARY KEY, content TEXT NOT NULL)',
      ),
    );
  }

  Future<void> _ensureCatalogTable() async => (await database).execute(
    'CREATE TABLE IF NOT EXISTS shelter_catalog (id INTEGER PRIMARY KEY, content TEXT NOT NULL)',
  );
  Future<Map<String, dynamic>?> loadShelterCatalog() async {
    if (kIsWeb) {
      return (readBrowserRecord('catalog') as Map?)?.cast<String, dynamic>();
    }
    await _ensureCatalogTable();
    final rows = await (await database).query(
      'shelter_catalog',
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['content'] as String) as Map<String, dynamic>;
  }

  Future<void> saveShelterCatalog(Map<String, dynamic> catalog) async {
    if (kIsWeb) {
      writeBrowserRecord('catalog', catalog);
      return;
    }
    await _ensureCatalogTable();
    await (await database).insert('shelter_catalog', {
      'id': 1,
      'content': jsonEncode(catalog),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // One "my area" map at a time: saving a new district replaces the old one.
  Future<void> _ensureAreaMapTable() async => (await database).execute(
    'CREATE TABLE IF NOT EXISTS area_map (id INTEGER PRIMARY KEY, content TEXT NOT NULL)',
  );
  Future<Map<String, dynamic>?> loadAreaMap() async {
    if (kIsWeb) {
      return (readBrowserRecord('areaMap') as Map?)?.cast<String, dynamic>();
    }
    await _ensureAreaMapTable();
    final rows = await (await database).query(
      'area_map',
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['content'] as String) as Map<String, dynamic>;
  }

  Future<void> saveAreaMap(Map<String, dynamic> record) async {
    if (kIsWeb) {
      writeBrowserRecord('areaMap', record);
      return;
    }
    await _ensureAreaMapTable();
    await (await database).insert('area_map', {
      'id': 1,
      'content': jsonEncode(record),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeAreaMap() async {
    if (kIsWeb) {
      removeBrowserRecord('areaMap');
      return;
    }
    await _ensureAreaMapTable();
    await (await database).delete('area_map', where: 'id = ?', whereArgs: [1]);
  }

  Future<void> _ensurePreparationTable() async => (await database).execute(
    'CREATE TABLE IF NOT EXISTS preparation (id INTEGER PRIMARY KEY, content TEXT NOT NULL)',
  );
  Future<Set<String>> loadPreparation() async {
    if (kIsWeb) {
      return (readBrowserRecord('preparation') as List? ?? [])
          .cast<String>()
          .toSet();
    }
    await _ensurePreparationTable();
    final rows = await (await database).query(
      'preparation',
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return {};
    return (jsonDecode(rows.first['content'] as String) as List)
        .cast<String>()
        .toSet();
  }

  Future<void> savePreparation(Set<String> values) async {
    if (kIsWeb) {
      writeBrowserRecord('preparation', values.toList()..sort());
      return;
    }
    await _ensurePreparationTable();
    await (await database).insert('preparation', {
      'id': 1,
      'content': jsonEncode(values.toList()..sort()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _ensureSavedSheltersTable() async => (await database).execute(
    'CREATE TABLE IF NOT EXISTS saved_shelters (id TEXT PRIMARY KEY, content TEXT NOT NULL, saved_at TEXT NOT NULL)',
  );
  Future<List<Map<String, dynamic>>> loadSavedShelters() async {
    if (kIsWeb) {
      return (readBrowserRecord('shelters') as Map? ?? {}).values
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    await _ensureSavedSheltersTable();
    final rows = await (await database).query(
      'saved_shelters',
      orderBy: 'saved_at DESC, id ASC',
    );
    return rows
        .map(
          (row) => jsonDecode(row['content'] as String) as Map<String, dynamic>,
        )
        .toList();
  }

  Future<void> saveSavedShelter(String id, Map<String, dynamic> entry) async {
    if (kIsWeb) {
      final records = Map<String, dynamic>.from(
        readBrowserRecord('shelters') as Map? ?? {},
      );
      records[id] = entry;
      writeBrowserRecord('shelters', records);
      return;
    }
    await _ensureSavedSheltersTable();
    await (await database).insert('saved_shelters', {
      'id': id,
      'content': jsonEncode(entry),
      'saved_at': entry['savedAt'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Role reassignment and personal records must commit together.
  Future<void> saveSavedShelters(List<Map<String, dynamic>> entries) async {
    if (kIsWeb) {
      final records = Map<String, dynamic>.from(
        readBrowserRecord('shelters') as Map? ?? {},
      );
      for (final e in entries) {
        records[e['storageKey'] as String] = {...e}..remove('storageKey');
      }
      writeBrowserRecord('shelters', records);
      return;
    }
    await _ensureSavedSheltersTable();
    await (await database).transaction((txn) async {
      for (final entry in entries) {
        await txn.insert('saved_shelters', {
          'id': entry['storageKey'],
          'content': jsonEncode({...entry}..remove('storageKey')),
          'saved_at': entry['savedAt'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> removeSavedShelter(String id) async {
    if (kIsWeb) {
      final records = Map<String, dynamic>.from(
        readBrowserRecord('shelters') as Map? ?? {},
      );
      records.remove(id);
      writeBrowserRecord('shelters', records);
      return;
    }
    await _ensureSavedSheltersTable();
    await (await database).delete(
      'saved_shelters',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<FamilyPlan> load() async {
    if (kIsWeb) {
      final raw = readBrowserRecord('family');
      return raw == null
          ? const FamilyPlan()
          : FamilyPlan.fromJson(Map<String, dynamic>.from(raw as Map));
    }
    final rows = await (await database).query(
      'plans',
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return const FamilyPlan();
    return FamilyPlan.fromJson(
      jsonDecode(rows.first['content'] as String) as Map<String, dynamic>,
    );
  }

  Future<void> save(FamilyPlan plan) async {
    if (kIsWeb) {
      writeBrowserRecord('family', plan.toJson());
      return;
    }
    await (await database).insert('plans', {
      'id': 1,
      'content': jsonEncode(plan.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clear() async {
    if (kIsWeb) {
      removeBrowserRecord('family');
      return;
    }
    await (await database).delete('plans', where: 'id = ?', whereArgs: [1]);
  }
}
