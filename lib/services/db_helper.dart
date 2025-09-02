import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  // --- FIX: Renamed function back to initDB() to match your main.dart ---
  static Future<Database> initDB() async {
    if (_db != null) return _db!;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'safety_app.db');

    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        // Contacts table
        await db.execute('''
          CREATE TABLE contacts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            phone TEXT,
            is_primary INTEGER DEFAULT 0
          )
        ''');

        // Safe Zones table with new columns
        await db.execute('''
          CREATE TABLE safe_zones (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            iconCode INTEGER NOT NULL,
            iconFont TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add new columns to the existing safe_zones table without deleting data
          await db.execute("ALTER TABLE safe_zones ADD COLUMN description TEXT");
          await db.execute("ALTER TABLE safe_zones ADD COLUMN latitude REAL NOT NULL DEFAULT 0.0");
          await db.execute("ALTER TABLE safe_zones ADD COLUMN longitude REAL NOT NULL DEFAULT 0.0");
        }
      },
    );
    return _db!;
  }

  // ================= CONTACTS (NOW CORRECTLY CALLING initDB) =================

  static Future<int> insertContact(String name, String phone) async {
    final db = await initDB(); // Changed back to initDB
    return await db.insert('contacts', {'name': name, 'phone': phone});
  }

  static Future<List<Map<String, dynamic>>> getContacts() async {
    final db = await initDB(); // Changed back to initDB
    return await db.query('contacts');
  }

  static Future<int> deleteContact(int id) async {
    final db = await initDB(); // Changed back to initDB
    return await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> setPrimaryContact(int id) async {
    final db = await initDB(); // Changed back to initDB
    await db.transaction((txn) async {
      await txn.update('contacts', {'is_primary': 0});
      await txn.update('contacts', {'is_primary': 1}, where: 'id = ?', whereArgs: [id]);
    });
  }

  static Future<Map<String, dynamic>?> getPrimaryContact() async {
    final db = await initDB(); // Changed back to initDB
    final result = await db.query('contacts', where: 'is_primary = 1', limit: 1);
    if (result.isNotEmpty) return result.first;
    return null;
  }

  // ================= SAFE ZONES (NOW CORRECTLY CALLING initDB) =================

  static Future<int> insertSafeZone(Map<String, dynamic> data) async {
    final db = await initDB(); // Changed back to initDB
    return await db.insert(
      'safe_zones',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Map<String, dynamic>>> getSafeZones() async {
    final db = await initDB(); // Changed back to initDB
    return await db.query('safe_zones');
  }

  static Future<int> deleteSafeZone(int id) async {
    final db = await initDB(); // Changed back to initDB
    return await db.delete('safe_zones', where: 'id = ?', whereArgs: [id]);
  }
}