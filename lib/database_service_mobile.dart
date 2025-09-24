import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:latlong2/latlong.dart';

import 'models.dart';
import 'database_service_interface.dart';

class MobileDatabaseService implements AppDatabaseService {
  static final MobileDatabaseService _instance = MobileDatabaseService._internal();
  factory MobileDatabaseService() => _instance;
  MobileDatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('navigate_app.db');
    return _database!;
  }

  @override
  Future<void> init() async {
    _database = await _initDB('navigate_app.db');
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        userID INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        profile_photo TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE routes(
        routeID INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        points TEXT NOT NULL,
        startPoint TEXT,
        endPoint TEXT,
        distance REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE user_routes(
        user_route_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        route_id INTEGER,
        FOREIGN KEY (user_id) REFERENCES users(userID),
        FOREIGN KEY (route_id) REFERENCES routes(routeID)
      )
    ''');

    await db.execute('''
      CREATE TABLE areas(
        areaID INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE area_routes(
        area_route_id INTEGER PRIMARY KEY AUTOINCREMENT,
        area_id INTEGER,
        route_id INTEGER,
        FOREIGN KEY (area_id) REFERENCES areas(areaID),
        FOREIGN KEY (route_id) REFERENCES routes(routeID)
      )
    ''');

    await db.execute('''
      CREATE TABLE crowd_reports(
        reportID INTEGER PRIMARY KEY AUTOINCREMENT,
        area_id INTEGER,
        crowd_level INTEGER NOT NULL,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (area_id) REFERENCES areas(areaID)
      )
    ''');
  }

  @override
  Future<int> insertRoute({
    required String name,
    required List<LatLng> points,
    int? userId,
  }) async {
    final db = await database;
    final pointsStr = jsonEncode(points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList());
    final routeId = await db.insert('routes', {'name': name, 'points': pointsStr});

    if (userId != null) {
      await insertUserRoute(userId, routeId);
    }
    return routeId;
  }

  @override
  Future<User> createUser(User user) async {
    final db = await database;
    final id = await db.insert('users', user.toMap());
    return user.copyWith(userID: id);
  }

  @override
  Future<User?> getUser(String email, String password) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    } else {
      return null;
    }
  }

  @override
  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    } else {
      return null;
    }
  }

  @override
  Future<User> updateUser(User user) async {
    final db = await database;
    await db.update(
      'users',
      user.toMap(),
      where: 'userID = ?',
      whereArgs: [user.userID],
    );
    return user;
  }

  @override
  Future<AppRoute?> getRouteById(int routeId) async {
    final db = await database;
    final maps = await db.query(
      'routes',
      where: 'routeID = ?',
      whereArgs: [routeId],
    );

    if (maps.isNotEmpty) {
      return AppRoute.fromMap(maps.first);
    } else {
      return null;
    }
  }

  @override
  Future<List<AppRoute>> getSavedRoutesByUser(int userId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT r.* FROM routes r
      INNER JOIN user_routes ur ON r.routeID = ur.route_id
      WHERE ur.user_id = ?
    ''', [userId]);

    return maps.map((map) => AppRoute.fromMap(map)).toList();
  }

  @override
  Future<void> deleteSavedRoute(int routeId) async {
    final db = await database;
    await db.delete('user_routes', where: 'route_id = ?', whereArgs: [routeId]);
  }

  @override
  Future<void> insertUserRoute(int userId, int routeId) async {
    final db = await database;
    await db.insert('user_routes', {'user_id': userId, 'route_id': routeId});
  }

  @override
  Future<List<Area>> getAreas() async {
    final db = await database;
    final maps = await db.query('areas');
    return maps.map((map) => Area.fromMap(map)).toList();
  }

  @override
  Future<List<AppRoute>> getAreaRoutes(int areaId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT r.* FROM routes r
      INNER JOIN area_routes ar ON r.routeID = ar.route_id
      WHERE ar.area_id = ?
    ''', [areaId]);

    return maps.map((map) => AppRoute.fromMap(map)).toList();
  }

  @override
  Future<void> insertCrowdReport(CrowdReport report) async {
    final db = await database;
    await db.insert('crowd_reports', report.toMap());
  }

  @override
  Future<List<CrowdReport>> getCrowdReports(int areaId) async {
    final db = await database;
    final maps = await db.query(
      'crowd_reports',
      where: 'area_id = ?',
      whereArgs: [areaId],
      orderBy: 'timestamp DESC',
    );

    return maps.map((map) => CrowdReport.fromMap(map)).toList();
  }
}

AppDatabaseService getDatabaseService() => MobileDatabaseService();
