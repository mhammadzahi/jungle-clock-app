// lib/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  static const String _dbName = 'jungle_clock.db';
  static const int _dbVersion = 1;
  static const String tableLocation = 'location_records';
  static const String colId = '_id';
  static const String colEmployeeId = 'employee_id';
  static const String colLatitude = 'latitude';
  static const String colLongitude = 'longitude';
  static const String colTimestamp = 'timestamp';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableLocation (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colEmployeeId INTEGER NOT NULL,
        $colLatitude REAL NOT NULL,
        $colLongitude REAL NOT NULL,
        $colTimestamp TEXT NOT NULL
      )
      ''');
    await db.execute('CREATE INDEX idx_employee_timestamp ON $tableLocation ($colEmployeeId, $colTimestamp)');
  }

  Future<int> insertLocationRecord({
    required int employeeId,
    required double latitude,
    required double longitude,
    required String timestamp,
  }) async {
    try {
      Database db = await database;
      return await db.insert(
        tableLocation,
        {
          colEmployeeId: employeeId,
          colLatitude: latitude,
          colLongitude: longitude,
          colTimestamp: timestamp,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print("Error inserting location record: $e");
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> queryAllRecords() async {
    try {
      Database db = await database;
      // Ensure we only get records relevant if needed, but for now get all
      return await db.query(tableLocation, orderBy: '$colTimestamp ASC'); // Order chronologically
    } catch (e) {
      print("Error querying records: $e");
      return [];
    }
  }

  // --- NEW METHOD ---
  // Deletes all records from the location table
  Future<int> deleteAllRecords() async {
    try {
      Database db = await database;
      int count = await db.delete(tableLocation);
      print("Deleted $count records from $tableLocation");
      return count;
    } catch (e) {
      print("Error deleting records: $e");
      return -1; // Indicate error
    }
  }
// ---------------
}
