import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  // Define database details
  static const String _dbName = 'jungle_clock.db';
  static const int _dbVersion = 1;

  // Define table and column names
  static const String tableLocation = 'location_records';
  static const String colId = '_id'; // Primary key
  static const String colEmployeeId = 'employee_id';
  static const String colLatitude = 'latitude';
  static const String colLongitude = 'longitude';
  static const String colTimestamp = 'timestamp'; // Store as ISO8601 String

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

  // Create the table
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
    // Add index for potential queries later
    await db.execute('CREATE INDEX idx_employee_timestamp ON $tableLocation ($colEmployeeId, $colTimestamp)');
  }

  // Insert a location record
  Future<int> insertLocationRecord({
    required int employeeId,
    required double latitude,
    required double longitude,
    required String timestamp, // ISO8601 format string
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
        conflictAlgorithm: ConflictAlgorithm.replace, // Optional: handle conflicts
      );
    } catch (e) {
      print("Error inserting location record: $e");
      return -1; // Indicate error
    }
  }

  // Optional: Method to query records (for debugging or later features)
  Future<List<Map<String, dynamic>>> queryAllRecords() async {
    try {
      Database db = await database;
      return await db.query(tableLocation, orderBy: '$colTimestamp DESC');
    } catch (e) {
      print("Error querying records: $e");
      return [];
    }
  }
}
