import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

class FamilyPlan {
  const FamilyPlan({
    this.contactName = '',
    this.phone = '',
    this.meetingPlace = '',
    this.backupPlace = '',
    this.note = '',
    this.backupContactName = '',
    this.backupPhone = '',
  });
  final String contactName,
      phone,
      meetingPlace,
      backupPlace,
      note,
      backupContactName,
      backupPhone;
  bool get isEmpty => toJson().values.every((value) => value.trim().isEmpty);
  Map<String, String> toJson() => {
    'contactName': contactName,
    'phone': phone,
    'meetingPlace': meetingPlace,
    'backupPlace': backupPlace,
    'note': note,
    'backupContactName': backupContactName,
    'backupPhone': backupPhone,
  };
  factory FamilyPlan.fromJson(Map<String, dynamic> json) => FamilyPlan(
    contactName: json['contactName'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    meetingPlace: json['meetingPlace'] as String? ?? '',
    backupPlace: json['backupPlace'] as String? ?? '',
    note: json['note'] as String? ?? '',
    backupContactName: json['backupContactName'] as String? ?? '',
    backupPhone: json['backupPhone'] as String? ?? '',
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
    await _ensureCatalogTable();
    await (await database).insert('shelter_catalog', {
      'id': 1,
      'content': jsonEncode(catalog),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _ensurePreparationTable() async => (await database).execute(
    'CREATE TABLE IF NOT EXISTS preparation (id INTEGER PRIMARY KEY, content TEXT NOT NULL)',
  );
  Future<Set<String>> loadPreparation() async {
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
    await _ensurePreparationTable();
    await (await database).insert('preparation', {
      'id': 1,
      'content': jsonEncode(values.toList()..sort()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<FamilyPlan> load() async {
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
    await (await database).insert('plans', {
      'id': 1,
      'content': jsonEncode(plan.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clear() async {
    await (await database).delete('plans', where: 'id = ?', whereArgs: [1]);
  }
}
