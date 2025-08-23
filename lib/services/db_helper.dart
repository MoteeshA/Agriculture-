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

  // ⬆️ Version bump (v5) to add user role/KYC columns + seed superadmin
  static const _dbName = 'agrimitra.db';
  static const _dbVersion = 5; // was 4

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

        // v3 (certification fields) - already part of _createEquipment

        // v4 (e-fuel: equipment fuel columns + fuel_logs)
        await _createFuelLogs(db);

        // v5 (users: role + KYC)
        await _ensureUserRoleKycColumns(db);
        await _seedSuperAdmin(db); // create admin@gmail.com / admin
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Safe, idempotent upgrades
        if (oldVersion < 2) {
          await _createEquipment(db);
          await _createRentalRequests(db);
          await _createNotifications(db);
        }
        if (oldVersion < 3) {
          await _ensureCertificationColumns(db);
        }
        if (oldVersion < 4) {
          await _ensureFuelColumns(db);
          await _createFuelLogs(db);
        }
        if (oldVersion < 5) {
          await _ensureUserRoleKycColumns(db);
          await _seedSuperAdmin(db);
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
        createdAt TEXT NOT NULL,
        -- v5 admin/KYC fields
        role TEXT NOT NULL DEFAULT 'user',           -- user | admin | superadmin
        kyc_status TEXT NOT NULL DEFAULT 'none',     -- none | pending | verified | rejected
        kyc_note TEXT,
        kyc_verified_at TEXT
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
        created_at TEXT,

        -- v3 certification fields
        cert_status TEXT DEFAULT 'none',   -- none | auto_verified | verified | rejected | expired
        cert_source TEXT,                  -- owner_kyc | doc_match | oem | admin
        cert_expires_at TEXT,              -- ISO8601
        cert_note TEXT,

        -- v4 e-fuel fields
        fuel_type TEXT,                    -- e.g., Diesel, Petrol, Electric, Hybrid
        fuel_capacity REAL,                -- tank/battery capacity (L or kWh)
        fuel_unit TEXT DEFAULT 'L',        -- 'L' for liters or 'kWh' for electric
        fuel_level REAL,                   -- current level (same unit as fuel_unit)
        efuel_supported INTEGER DEFAULT 0  -- 1 if supports digital fuel/energy tracking
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
        type TEXT,             -- request_received | request_update | cert_update
        payload TEXT,          -- JSON blob
        is_read INTEGER,
        created_at TEXT
      );
    ''');
  }

  /// v4: fuel refuel logs
  Future<void> _createFuelLogs(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fuel_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        equipment_id INTEGER NOT NULL,
        liters REAL,          -- amount refueled (or kWh if electric)
        cost REAL,            -- total cost for this refuel
        odometer REAL,        -- optional (km or hours)
        note TEXT,
        created_at TEXT NOT NULL
      );
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_fuel_logs_equipment ON fuel_logs(equipment_id);');
  }

  /* -------------------- Migrations (idempotent) -------------------- */

  /// v3 migration: add cert columns if they don't exist.
  Future<void> _ensureCertificationColumns(Database db) async {
    Future<bool> _columnExists(String table, String col) async {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      return info.any((m) => (m['name'] as String?) == col);
    }

    Future<void> _addColumn(String sql) async {
      try {
        await db.execute(sql);
      } catch (_) {
        // ignore if already exists or sqlite error on older devices
      }
    }

    if (!await _columnExists('equipment', 'cert_status')) {
      await _addColumn("ALTER TABLE equipment ADD COLUMN cert_status TEXT DEFAULT 'none'");
    }
    if (!await _columnExists('equipment', 'cert_source')) {
      await _addColumn("ALTER TABLE equipment ADD COLUMN cert_source TEXT");
    }
    if (!await _columnExists('equipment', 'cert_expires_at')) {
      await _addColumn("ALTER TABLE equipment ADD COLUMN cert_expires_at TEXT");
    }
    if (!await _columnExists('equipment', 'cert_note')) {
      await _addColumn("ALTER TABLE equipment ADD COLUMN cert_note TEXT");
    }
  }

  /// v4 migration: add e-fuel columns if they don't exist.
  Future<void> _ensureFuelColumns(Database db) async {
    Future<bool> _columnExists(String table, String col) async {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      return info.any((m) => (m['name'] as String?) == col);
    }

    Future<void> _addColumn(String sql) async {
      try {
        await db.execute(sql);
      } catch (_) {
        // ignore if already exists
      }
    }

    if (!await _columnExists('equipment', 'fuel_type')) {
      await _addColumn("ALTER TABLE equipment ADD COLUMN fuel_type TEXT");
    }
    if (!await _columnExists('equipment', 'fuel_capacity')) {
      await _addColumn("ALTER TABLE equipment ADD COLUMN fuel_capacity REAL");
    }
    if (!await _columnExists('equipment', 'fuel_unit')) {
      await _addColumn("ALTER TABLE equipment ADD COLUMN fuel_unit TEXT DEFAULT 'L'");
    }
    if (!await _columnExists('equipment', 'fuel_level')) {
      await _addColumn("ALTER TABLE equipment ADD COLUMN fuel_level REAL");
    }
    if (!await _columnExists('equipment', 'efuel_supported')) {
      await _addColumn("ALTER TABLE equipment ADD COLUMN efuel_supported INTEGER DEFAULT 0");
    }
  }

  /// v5 migration: add role + KYC columns if missing.
  Future<void> _ensureUserRoleKycColumns(Database db) async {
    Future<bool> _columnExists(String table, String col) async {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      return info.any((m) => (m['name'] as String?) == col);
    }

    Future<void> _addColumn(String sql) async {
      try {
        await db.execute(sql);
      } catch (_) {
        // ignore if already there
      }
    }

    if (!await _columnExists('users', 'role')) {
      await _addColumn("ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'user'");
    }
    if (!await _columnExists('users', 'kyc_status')) {
      await _addColumn(
          "ALTER TABLE users ADD COLUMN kyc_status TEXT NOT NULL DEFAULT 'none'");
    }
    if (!await _columnExists('users', 'kyc_note')) {
      await _addColumn("ALTER TABLE users ADD COLUMN kyc_note TEXT");
    }
    if (!await _columnExists('users', 'kyc_verified_at')) {
      await _addColumn("ALTER TABLE users ADD COLUMN kyc_verified_at TEXT");
    }
  }

  /// Seed default superadmin (admin@gmail.com / admin)
  Future<void> _seedSuperAdmin(Database db) async {
    try {
      final existing = await db.query(
        'users',
        columns: ['id'],
        where: 'email=?',
        whereArgs: ['admin@gmail.com'],
        limit: 1,
      );
      if (existing.isNotEmpty) return;

      final now = DateTime.now().toIso8601String();
      final passHash = _hashPassword('admin');

      await db.insert('users', {
        'name': 'Super Admin',
        'email': 'admin@gmail.com',
        'passwordHash': passHash,
        'createdAt': now,
        'role': 'superadmin',
        'kyc_status': 'verified',
        'kyc_note': 'Pre-seeded superadmin',
        'kyc_verified_at': now,
      });
    } catch (_) {
      // ignore if any constraint fails
    }
  }

  /// Utility: hash passwords with SHA256
  String _hashPassword(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /* ============================= USERS API (original) ============================= */

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

  /* ============== NEW: Admin/KYC helpers (non-breaking additions) ============== */

  Future<bool> isAdminVerified(int userId) async {
    final db = await database;
    final rows = await db.query('users',
        columns: ['role', 'kyc_status'], where: 'id=?', whereArgs: [userId], limit: 1);
    if (rows.isEmpty) return false;
    final role = (rows.first['role'] ?? 'user').toString();
    final kyc = (rows.first['kyc_status'] ?? 'none').toString();
    return (role == 'admin' || role == 'superadmin') && kyc == 'verified';
  }

  Future<int> setUserRole(int userId, String role) async {
    final db = await database;
    return db.update('users', {'role': role}, where: 'id=?', whereArgs: [userId]);
  }

  Future<int> setKycStatus({
    required int userId,
    required String status, // none | pending | verified | rejected
    String? note,
  }) async {
    final db = await database;
    final changes = <String, Object?>{
      'kyc_status': status,
      'kyc_note': note,
    };
    if (status == 'verified') {
      changes['kyc_verified_at'] = DateTime.now().toIso8601String();
    }
    return db.update('users', changes, where: 'id=?', whereArgs: [userId]);
  }

  /* ============================= RENTAL API (existing) ============================= */

  // Equipment
  Future<int> addEquipment(Map<String, dynamic> data) async {
    final db = await database;
    // Ensure defaults for new cert fields if not provided
    data.putIfAbsent('cert_status', () => 'none');
    data.putIfAbsent('cert_source', () => null);
    data.putIfAbsent('cert_expires_at', () => null);
    data.putIfAbsent('cert_note', () => null);

    // Ensure defaults for e-fuel fields (optional inputs)
    data.putIfAbsent('fuel_type', () => null);
    data.putIfAbsent('fuel_capacity', () => null);
    data.putIfAbsent('fuel_unit', () => 'L');
    data.putIfAbsent('fuel_level', () => null);
    data.putIfAbsent('efuel_supported', () => 0);

    return db.insert('equipment', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> myEquipment(int ownerId) async {
    final db = await database;
    return db.query('equipment',
        where: 'owner_id=?', whereArgs: [ownerId], orderBy: 'created_at DESC');
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
    final rows =
    await db.query('equipment', where: 'id=?', whereArgs: [id], limit: 1);
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
        where: 'id=?',
        whereArgs: [equipmentId],
        limit: 1);
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

  Future<int> updateRequestStatus(
      int requestId, String status, int ownerId) async {
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
        where: 'user_id=?', whereArgs: [userId], orderBy: 'created_at DESC');
  }

  Future<int> markNotificationRead(int notifId) async {
    final db = await database;
    return db.update('notifications', {'is_read': 1},
        where: 'id=?', whereArgs: [notifId]);
  }

  /* ========================== CERTIFICATION API (existing) ========================== */

  /// Update certification for an equipment item.
  /// certStatus: none | auto_verified | verified | rejected | expired
  /// certSource: owner_kyc | doc_match | oem | admin
  /// certExpiresAt: ISO8601 (nullable)
  /// certNote: free text (nullable)
  /// notifyOwner: if true, sends a 'cert_update' notification to the owner
  Future<int> setEquipmentCertification({
    required int equipmentId,
    required String certStatus,
    String? certSource,
    String? certExpiresAt,
    String? certNote,
    bool notifyOwner = true,
  }) async {
    final db = await database;

    final changes = <String, Object?>{
      'cert_status': certStatus,
      'cert_source': certSource,
      'cert_expires_at': certExpiresAt,
      'cert_note': certNote,
    };

    final updated = await db.update(
      'equipment',
      changes,
      where: 'id=?',
      whereArgs: [equipmentId],
    );

    if (notifyOwner) {
      final eq = await db.query('equipment',
          columns: ['owner_id', 'title'],
          where: 'id=?',
          whereArgs: [equipmentId],
          limit: 1);
      if (eq.isNotEmpty) {
        final ownerId = eq.first['owner_id'] as int;
        final title = (eq.first['title'] ?? '').toString();
        await db.insert('notifications', {
          'user_id': ownerId,
          'type': 'cert_update',
          'payload': jsonEncode({
            'equipment_id': equipmentId,
            'title': title,
            'cert_status': certStatus,
            'cert_source': certSource,
            'cert_expires_at': certExpiresAt,
            'cert_note': certNote,
          }),
          'is_read': 0,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    }

    return updated;
  }

  /// New (non-breaking): enforce admin check wrapper.
  /// Use this in admin UI: it only applies certification if the actor is an approved admin.
  Future<int> setEquipmentCertificationByAdmin({
    required int actorUserId,
    required int equipmentId,
    required String certStatus,
    String? certSource,
    String? certExpiresAt,
    String? certNote,
    bool notifyOwner = true,
  }) async {
    final ok = await isAdminVerified(actorUserId);
    if (!ok) {
      throw Exception('Forbidden: admin verification required');
    }
    return setEquipmentCertification(
      equipmentId: equipmentId,
      certStatus: certStatus,
      certSource: certSource ?? 'admin',
      certExpiresAt: certExpiresAt,
      certNote: certNote,
      notifyOwner: notifyOwner,
    );
  }

  /* =============================== E-FUEL API (existing) =============================== */

  /// Set or update fuel info for an equipment item.
  /// Example units: 'L' for diesel/petrol, 'kWh' for electric machinery.
  Future<int> setEquipmentFuelInfo({
    required int equipmentId,
    String? fuelType, // Diesel, Petrol, Electric, Hybrid
    double? fuelCapacity, // capacity in unit
    String? fuelUnit, // 'L' or 'kWh'
    double? fuelLevel, // current level in same unit
    bool? efuelSupported, // supports digital tracking
  }) async {
    final db = await database;
    final changes = <String, Object?>{};
    if (fuelType != null) changes['fuel_type'] = fuelType;
    if (fuelCapacity != null) changes['fuel_capacity'] = fuelCapacity;
    if (fuelUnit != null) changes['fuel_unit'] = fuelUnit;
    if (fuelLevel != null) changes['fuel_level'] = fuelLevel;
    if (efuelSupported != null) changes['efuel_supported'] = efuelSupported ? 1 : 0;

    if (changes.isEmpty) return 0;

    return db.update('equipment', changes, where: 'id=?', whereArgs: [equipmentId]);
  }

  /// Log a refuel (or recharge for Electric with unit=kWh).
  /// If `updateLevel` is true, increases the equipment's fuel_level by `liters`.
  Future<int> addFuelLog({
    required int equipmentId,
    required double liters, // or kWh
    double? cost, // total cost
    double? odometer, // optional
    String? note,
    bool updateLevel = true,
  }) async {
    final db = await database;
    final id = await db.insert('fuel_logs', {
      'equipment_id': equipmentId,
      'liters': liters,
      'cost': cost,
      'odometer': odometer,
      'note': note,
      'created_at': DateTime.now().toIso8601String(),
    });

    if (updateLevel) {
      final eq = await equipmentById(equipmentId);
      if (eq != null) {
        final current =
        (eq['fuel_level'] is num) ? (eq['fuel_level'] as num).toDouble() : 0.0;
        final capacity = (eq['fuel_capacity'] is num)
            ? (eq['fuel_capacity'] as num).toDouble()
            : null;
        double next = (current.isFinite ? current : 0.0) + liters;
        if (capacity != null && capacity > 0 && next > capacity) {
          next = capacity; // clamp to capacity
        }
        await setEquipmentFuelInfo(equipmentId: equipmentId, fuelLevel: next);
      }
    }
    return id;
  }

  /// Manually update the fuel level (e.g., after usage).
  Future<int> updateEquipmentFuelLevel({
    required int equipmentId,
    required double fuelLevel,
  }) async {
    return setEquipmentFuelInfo(equipmentId: equipmentId, fuelLevel: fuelLevel);
  }

  /// Get recent fuel logs for an equipment item.
  Future<List<Map<String, dynamic>>> recentFuelLogs(int equipmentId,
      {int limit = 20}) async {
    final db = await database;
    return db.query(
      'fuel_logs',
      where: 'equipment_id=?',
      whereArgs: [equipmentId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }
}
