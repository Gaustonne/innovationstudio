import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

import 'package:inventory/common/db/db.dart';

/// Test helper to initialize sqflite in ffi mode and ensure a clean app DB.
Future<void> initTestDatabase() async {
  // Initialize ffi implementation and set the factory used by sqflite package.
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Remove any existing app DB so AppDatabase will create a fresh DB during tests.
  final dbDir = await getDatabasesPath();
  await Directory(dbDir).create(recursive: true);
  final dbPath = join(dbDir, 'inventory.db');
  final f = File(dbPath);
  if (await f.exists()) {
    try {
      await AppDatabase.close();
    } catch (_) {}
    await f.delete();
  }
}

Future<void> closeAndDeleteAppDatabase() async {
  try {
    await AppDatabase.close();
  } catch (_) {}
  final dbDir = await getDatabasesPath();
  final dbPath = join(dbDir, 'inventory.db');
  final f = File(dbPath);
  if (await f.exists()) {
    await f.delete();
  }
}
