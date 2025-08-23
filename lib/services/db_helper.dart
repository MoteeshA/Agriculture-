import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:crypto/crypto.dart';

/// --- User Model + DB Helper combined ---

class UserModel {
  final int? id;
  final String name;
  final String email;
  final String passwordHash;
  final String createdAt;

  UserModel({
    this.id,
    required this.name,
    required this.email,
    required this.passwordHash,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'passwordHash': passwordHash,
    'createdAt': createdAt,
  };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
    id: map['id'] as int?,
    name: map['name'] as String,
    email: map['email'] as String,
    passwordHash: map['passwordHash'] as String,
    createdAt: map['createdAt'] as String,
  );
}

class DBHelper {
  static final DBHelper instance = DBHelper._internal();
  DBHelper._internal();

  static Database? _db;

  // ⬆️ Version bump to add rental tables while retaining users table
  static const _dbName = 'agrimitra.db';
  static const _dbVersion = 2;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB(_dbName);
    return _db!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        // v1
        await _createUsers(db);

        // v2 (rental feature)
        await _createEquipment(db);
        await _createRentalRequests(db);
        await _createNotifications(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Safe, idempotent upgrades
        if (oldVersion < 2) {
          await _createEquipment(db);
          await _createRentalRequests(db);
          await _createNotifications(db);
        }
      },
    );
  }

  /* -------------------- Table creators (idempotent) -------------------- */

  Future<void> _createUsers(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        passwordHash TEXT NOT NULL,
        createdAt TEXT NOT NULL
      );
    ''');
  }

  Future<void> _createEquipment(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS equipment(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        owner_id INTEGER,
        title TEXT,
        description TEXT,
        daily_rate INTEGER,
        location TEXT,
        phone TEXT,
        image_url TEXT,
        available INTEGER,
        created_at TEXT
      );
    ''');
  }

  Future<void> _createRentalRequests(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rental_requests(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        equipment_id INTEGER,
        requester_id INTEGER,
        message TEXT,
        start_date TEXT,
        end_date TEXT,
        location TEXT,
        phone TEXT,
        status TEXT,           -- pending | accepted | rejected | cancelled
        created_at TEXT
      );
    ''');
  }

  Future<void> _createNotifications(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        type TEXT,             -- request_received | request_update
        payload TEXT,          -- JSON blob
        is_read INTEGER,
        created_at TEXT
      );
    ''');
  }

  /// Utility: hash passwords with SHA256
  String _hashPassword(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /* ============================= USERS API (unchanged) ============================= */

  Future<int> createUser({
    required String name,
    required String email,
    required String password,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final passHash = _hashPassword(password);

    final user = UserModel(
      name: name,
      email: email.trim().toLowerCase(),
      passwordHash: passHash,
      createdAt: now,
    );

    return await db.insert('users', user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final db = await database;
    final res = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return UserModel.fromMap(res.first);
  }

  Future<bool> verifyUser(String email, String password) async {
    final user = await getUserByEmail(email);
    if (user == null) return false;
    return user.passwordHash == _hashPassword(password);
  }

  /* ============================= RENTAL API (new) ============================= */

  // Equipment
  Future<int> addEquipment(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('equipment', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> myEquipment(int ownerId) async {
    final db = await database;
    return db.query('equipment',
        where: 'owner_id=?',
        whereArgs: [ownerId],
        orderBy: 'created_at DESC');
  }

  Future<List<Map<String, dynamic>>> availableEquipmentExcept(int userId) async {
    final db = await database;
    return db.query('equipment',
        where: 'available=1 AND owner_id<>?',
        whereArgs: [userId],
        orderBy: 'created_at DESC');
  }

  Future<int> toggleEquipmentAvailability(int equipmentId, bool available) async {
    final db = await database;
    return db.update('equipment', {'available': available ? 1 : 0},
        where: 'id=?', whereArgs: [equipmentId]);
  }

  Future<Map<String, dynamic>?> equipmentById(int id) async {
    final db = await database;
    final rows = await db.query('equipment', where: 'id=?', whereArgs: [id], limit: 1);
    return rows.isNotEmpty ? rows.first : null;
  }

  // Requests + Notifications
  Future<int> createRequest({
    required int equipmentId,
    required int requesterId,
    required String message,
    required String startDate,
    required String endDate,
    required String location,
    required String phone,
  }) async {
    final db = await database;

    final requestId = await db.insert('rental_requests', {
      'equipment_id': equipmentId,
      'requester_id': requesterId,
      'message': message,
      'start_date': startDate,
      'end_date': endDate,
      'location': location,
      'phone': phone,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });

    // Owner notification
    final rows = await db.query('equipment',
        columns: ['owner_id', 'title'],
        where: 'id=?', whereArgs: [equipmentId], limit: 1);
    if (rows.isNotEmpty) {
      final ownerId = rows.first['owner_id'] as int;
      final title = (rows.first['title'] ?? '').toString();

      await db.insert('notifications', {
        'user_id': ownerId,
        'type': 'request_received',
        'payload': jsonEncode({
          'equipment_id': equipmentId,
          'title': title,
          'request_id': requestId,
          'requester_id': requesterId,
          'message': message,
          'start_date': startDate,
          'end_date': endDate,
          'location': location,
          'phone': phone,
        }),
        'is_read': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    return requestId;
  }

  Future<int> updateRequestStatus(int requestId, String status, int ownerId) async {
    final db = await database;

    await db.update('rental_requests', {'status': status},
        where: 'id=?', whereArgs: [requestId]);

    // Notify requester
    final reqRows = await db.query('rental_requests',
        where: 'id=?', whereArgs: [requestId], limit: 1);
    if (reqRows.isNotEmpty) {
      final requesterId = reqRows.first['requester_id'] as int;
      final equipmentId = reqRows.first['equipment_id'] as int;
      final eq = await equipmentById(equipmentId);

      await db.insert('notifications', {
        'user_id': requesterId,
        'type': 'request_update',
        'payload': jsonEncode({
          'request_id': requestId,
          'equipment_id': equipmentId,
          'title': (eq?['title'] ?? '').toString(),
          'status': status,
          'owner_id': ownerId,
        }),
        'is_read': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    return 1;
  }

  Future<List<Map<String, dynamic>>> incomingRequestsForOwner(int ownerId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT rr.id as request_id, rr.status, rr.created_at, rr.start_date, rr.end_date,
             rr.location as req_location, rr.phone as req_phone, rr.message,
             e.id as equipment_id, e.title, e.image_url, e.daily_rate
      FROM rental_requests rr
      JOIN equipment e ON e.id = rr.equipment_id
      WHERE e.owner_id = ?
      ORDER BY rr.created_at DESC
    ''', [ownerId]);
  }

  Future<List<Map<String, dynamic>>> notificationsFor(int userId) async {
    final db = await database;
    return db.query('notifications',
        where: 'user_id=?',
        whereArgs: [userId],
        orderBy: 'created_at DESC');
  }

  Future<int> markNotificationRead(int notifId) async {
    final db = await database;
    return db.update('notifications', {'is_read': 1},
        where: 'id=?', whereArgs: [notifId]);
  }
}
