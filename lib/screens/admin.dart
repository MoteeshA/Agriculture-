// lib/screens/admin.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../services/db_helper.dart';

class AdminPage extends StatefulWidget {
  static const route = '/admin';
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

enum _Filter { pending, verified, all }

class _AdminPageState extends State<AdminPage> {
  final _q = TextEditingController();
  _Filter _filter = _Filter.pending;
  bool _loading = false;
  String _error = '';
  List<Map<String, dynamic>> _items = [];

  // Cache owner profiles to avoid repeated queries/dialog open
  final Map<int, Map<String, dynamic>> _profileCache = {};

  @override
  void initState() {
    super.initState();
    _bootstrap().then((_) => _refresh());
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // Ensure user_profiles table exists and has the new KYC columns
    final db = await DBHelper.instance.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profiles(
        user_id INTEGER PRIMARY KEY,
        full_name TEXT,
        phone TEXT,
        address TEXT,
        farm_size TEXT,
        machinery TEXT,
        updated_at TEXT
      );
    ''');

    // Add columns if missing
    await _ensureColumn(db, 'user_profiles', 'aadhar_number', "TEXT");
    await _ensureColumn(db, 'user_profiles', 'govt_id_type', "TEXT");   // e.g., 'PAN', 'VoterID', 'DL'
    await _ensureColumn(db, 'user_profiles', 'govt_id_number', "TEXT"); // the ID value
  }

  Future<void> _ensureColumn(Database db, String table, String col, String type) async {
    final cols = await db.rawQuery("PRAGMA table_info($table)");
    final has = cols.any((r) => (r['name'] as String).toLowerCase() == col.toLowerCase());
    if (!has) {
      await db.execute('ALTER TABLE $table ADD COLUMN $col $type;');
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final db = await DBHelper.instance.database;

      // Base query with owner name/email joined in
      final rows = await db.rawQuery('''
        SELECT e.*, u.name AS owner_name, u.email AS owner_email
        FROM equipment e
        LEFT JOIN users u ON u.id = e.owner_id
        ORDER BY e.created_at DESC
      ''');

      final query = _q.text.trim().toLowerCase();
      List<Map<String, dynamic>> filtered = rows;

      // Filter by cert status
      filtered = filtered.where((e) {
        final status = (e['cert_status'] ?? 'none').toString().toLowerCase();
        switch (_filter) {
          case _Filter.pending:
          // treat 'none' or 'expired' or explicitly 'rejected' as pending review
            return status == 'none' || status == 'expired' || status == 'rejected';
          case _Filter.verified:
            return status == 'verified' || status == 'auto_verified';
          case _Filter.all:
            return true;
        }
      }).toList();

      // Text search across title/desc/location/owner_name
      if (query.isNotEmpty) {
        filtered = filtered.where((e) {
          bool has(String k) => (e[k] ?? '').toString().toLowerCase().contains(query);
          return has('title') ||
              has('description') ||
              has('location') ||
              has('owner_name');
        }).toList();
      }

      setState(() {
        _items = filtered;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load: $e';
        _loading = false;
      });
    }
  }

  // ---------- Profile/KYC helpers ----------
  Future<Map<String, dynamic>?> _getOwnerProfile(int ownerId) async {
    if (_profileCache.containsKey(ownerId)) return _profileCache[ownerId];
    final db = await DBHelper.instance.database;
    final rows = await db.query('user_profiles', where: 'user_id=?', whereArgs: [ownerId], limit: 1);
    if (rows.isEmpty) return null;
    final prof = rows.first;
    _profileCache[ownerId] = prof;
    return prof;
  }

  bool _isNullOrEmpty(dynamic v) => v == null || v.toString().trim().isEmpty;

  bool _validAadhar(String? s) {
    if (s == null) return false;
    final digits = s.replaceAll(RegExp(r'\D'), '');
    return digits.length == 12; // simple length check; (no Verhoeff here)
  }

  bool _hasValidGovtId(Map<String, dynamic> p) {
    final t = (p['govt_id_type'] ?? '').toString().trim();
    final n = (p['govt_id_number'] ?? '').toString().trim();
    return t.isNotEmpty && n.isNotEmpty;
  }

  /// Returns list of missing items. Requires: name, phone, address,
  /// and (aadhar_number OR (govt_id_type + govt_id_number))
  List<String> _missingKycFields(Map<String, dynamic>? p) {
    final miss = <String>[];
    if (p == null) {
      return ['Profile not found (user hasn\'t filled it)'];
    }
    if (_isNullOrEmpty(p['full_name'])) miss.add('Full name');
    if (_isNullOrEmpty(p['phone'])) miss.add('Phone');
    if (_isNullOrEmpty(p['address'])) miss.add('Address');

    final aad = (p['aadhar_number'] ?? '').toString();
    final hasAad = _validAadhar(aad);
    final hasGovt = _hasValidGovtId(p);

    if (!hasAad && !hasGovt) {
      miss.add('KYC ID (Aadhaar 12-digit or Govt ID type + number)');
    }
    return miss;
  }

  String _maskAadhar(String? s) {
    if (s == null) return '—';
    final d = s.replaceAll(RegExp(r'\D'), '');
    if (d.length < 12) return s;
    return 'XXXX-XXXX-${d.substring(8)}';
  }

  // ---------- Approval / Rejection ----------
  Future<void> _approve(Map<String, dynamic> e) async {
    // KYC gate: ensure owner has complete profile
    final ownerId = (e['owner_id'] ?? 0) is int ? e['owner_id'] as int : int.tryParse('${e['owner_id']}') ?? 0;
    final profile = await _getOwnerProfile(ownerId);
    final missing = _missingKycFields(profile);

    if (missing.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Cannot Approve — KYC Incomplete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('The owner must complete the following before certification:'),
              const SizedBox(height: 8),
              ...missing.map((m) => Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 6),
                  Flexible(child: Text(m)),
                ],
              )),
              const SizedBox(height: 10),
              const Text(
                'Ask the owner to open Settings / Profile and fill Aadhaar (12-digit) '
                    'or provide an alternate Government ID (type + number).',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showProfileDialog(ownerId, preloaded: profile);
              },
              child: const Text('View Profile'),
            ),
          ],
        ),
      );
      return;
    }

    // Optional expiry: 12 months from now
    final defaultExpiry = DateTime.now().add(const Duration(days: 365));
    final ctrlNote = TextEditingController(text: (e['cert_note'] ?? '').toString());
    DateTime expiry = defaultExpiry;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Approve certification'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Equipment: ${e['title']}'),
                const SizedBox(height: 8),
                // Quick KYC summary (so admin can see at approval time)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _kycSummary(profile!),
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrlNote,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.event),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Expires: ${expiry.toIso8601String().split('T').first}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: expiry,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) {
                          setLocal(() {
                            expiry = DateTime(
                              picked.year, picked.month, picked.day, 23, 59, 50,
                            );
                          });
                        }
                      },
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.verified),
                label: const Text('Approve'),
                onPressed: () async {
                  final id = e['id'] as int;
                  await DBHelper.instance.setEquipmentCertification(
                    equipmentId: id,
                    certStatus: 'verified',
                    certSource: 'admin',
                    certExpiresAt: expiry.toIso8601String(),
                    certNote: ctrlNote.text.trim().isEmpty ? null : ctrlNote.text.trim(),
                    notifyOwner: true,
                  );
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Certification approved')),
                    );
                    _refresh();
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  String _kycSummary(Map<String, dynamic> p) {
    final name = (p['full_name'] ?? '—').toString();
    final phone = (p['phone'] ?? '—').toString();
    final addr = (p['address'] ?? '—').toString();
    final aad = (p['aadhar_number'] ?? '').toString();
    final gidT = (p['govt_id_type'] ?? '').toString();
    final gidN = (p['govt_id_number'] ?? '').toString();

    String idLine;
    if (_validAadhar(aad)) {
      idLine = 'Aadhaar: ${_maskAadhar(aad)}';
    } else if (gidT.isNotEmpty && gidN.isNotEmpty) {
      idLine = '$gidT: $gidN';
    } else {
      idLine = 'ID: —';
    }

    return 'Owner KYC → $name, $phone\n$addr\n$idLine';
    // (Add farm_size/machinery if you want)
  }

  Future<void> _reject(Map<String, dynamic> e) async {
    final ctrlNote = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject certification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Equipment: ${e['title']}'),
            const SizedBox(height: 8),
            TextField(
              controller: ctrlNote,
              decoration: const InputDecoration(
                labelText: 'Reason (required)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.cancel),
            label: const Text('Reject'),
            onPressed: () async {
              final reason = ctrlNote.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a reason')),
                );
                return;
              }
              final id = e['id'] as int;
              await DBHelper.instance.setEquipmentCertification(
                equipmentId: id,
                certStatus: 'rejected',
                certSource: 'admin',
                certExpiresAt: null,
                certNote: reason,
                notifyOwner: true,
              );
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Certification rejected')),
                );
                _refresh();
              }
            },
          ),
        ],
      ),
    );
  }

  // ---------- Profile dialog ----------
  Future<void> _showProfileDialog(int ownerId, {Map<String, dynamic>? preloaded}) async {
    final p = preloaded ?? await _getOwnerProfile(ownerId);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Owner Profile'),
        content: (p == null)
            ? const Text('No profile found for this user.')
            : Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Full name', p['full_name']),
            _row('Phone', p['phone']),
            _row('Address', p['address']),
            const SizedBox(height: 8),
            _row('Farm size', p['farm_size']),
            _row('Machinery', p['machinery']),
            const Divider(),
            _row('Aadhaar', _validAadhar('${p['aadhar_number']}') ? _maskAadhar('${p['aadhar_number']}') : '—'),
            _row('Govt ID Type', p['govt_id_type']),
            _row('Govt ID Number', p['govt_id_number']),
            const SizedBox(height: 6),
            Builder(
              builder: (ctx) {
                final missing = _missingKycFields(p);
                if (missing.isEmpty) {
                  return Row(
                    children: const [
                      Icon(Icons.check_circle, color: Colors.green, size: 18),
                      SizedBox(width: 6),
                      Text('KYC Complete'),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                        SizedBox(width: 6),
                        Text('KYC Incomplete'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...missing.map((m) => Text('• $m', style: const TextStyle(fontSize: 12))),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, dynamic v) {
    final val = (v == null || v.toString().trim().isEmpty) ? '—' : v.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text('$k:', style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(val)),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'verified':
      case 'auto_verified':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'expired':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  Widget _statusChip(Map<String, dynamic> e) {
    final status = (e['cert_status'] ?? 'none').toString();
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status.toLowerCase() == 'verified' || status.toLowerCase() == 'auto_verified'
                ? Icons.verified
                : Icons.info_outline,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  int _badgeCount(String status) {
    return _items.where((e) => ((e['cert_status'] ?? 'none').toString().toLowerCase() == status)).length;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin — Certifications'),
        backgroundColor: cs.primaryContainer,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          PopupMenuButton<_Filter>(
            tooltip: 'Filter',
            initialValue: _filter,
            onSelected: (f) {
              setState(() => _filter = f);
              _refresh();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _Filter.pending,
                child: Row(
                  children: [
                    const Icon(Icons.pending_outlined),
                    const SizedBox(width: 6),
                    const Text('Pending / Needs review'),
                    const Spacer(),
                    _Badge(count: _items.where((e) {
                      final s = (e['cert_status'] ?? 'none').toString().toLowerCase();
                      return s == 'none' || s == 'expired' || s == 'rejected';
                    }).length),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _Filter.verified,
                child: Row(
                  children: [
                    const Icon(Icons.verified_outlined),
                    const SizedBox(width: 6),
                    const Text('Verified'),
                    const Spacer(),
                    _Badge(count: _items.where((e) {
                      final s = (e['cert_status'] ?? 'none').toString().toLowerCase();
                      return s == 'verified' || s == 'auto_verified';
                    }).length),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _Filter.all,
                child: Row(
                  children: [
                    const Icon(Icons.all_inbox_outlined),
                    const SizedBox(width: 6),
                    const Text('All'),
                    const Spacer(),
                    _Badge(count: _items.length),
                  ],
                ),
              ),
            ],
          ),
          // --- Logout button ---
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _q,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search title / description / location / owner',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _q.clear();
                      _refresh();
                    },
                  ),
                ),
                onChanged: (_) => _refresh(),
              ),
            ),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error, style: const TextStyle(color: Colors.red)),
              )
            else if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No matching equipment.'),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final e = _items[i];
                      final status = (e['cert_status'] ?? 'none').toString();
                      final imageUrl = (e['image_url'] ?? '').toString();
                      final owner = (e['owner_name'] ?? '—').toString();
                      final ownerEmail = (e['owner_email'] ?? '—').toString();
                      final expiresAt = (e['cert_expires_at'] ?? '').toString();
                      final ownerId = (e['owner_id'] ?? 0) is int ? e['owner_id'] as int : int.tryParse('${e['owner_id']}') ?? 0;

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: status.toLowerCase() == 'verified'
                                ? Colors.green.shade200
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // thumbnail
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: imageUrl.isNotEmpty
                                    ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.agriculture, size: 28),
                                )
                                    : const Icon(Icons.agriculture, size: 28),
                              ),
                              const SizedBox(width: 12),
                              // details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${e['title'] ?? ''}',
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        _statusChip(e),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      (e['description'] ?? '—').toString(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.person, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Flexible(child: Text(owner, overflow: TextOverflow.ellipsis)),
                                        const SizedBox(width: 12),
                                        const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Flexible(child: Text(ownerEmail, overflow: TextOverflow.ellipsis)),
                                        const SizedBox(width: 12),
                                        const Icon(Icons.place, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            (e['location'] ?? '—').toString(),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 4,
                                      children: [
                                        if ((e['fuel_type'] ?? '').toString().isNotEmpty)
                                          _kv('Fuel', e['fuel_type']),
                                        if ((e['fuel_capacity']?.toString().isNotEmpty ?? false))
                                          _kv('Capacity', '${e['fuel_capacity']} ${e['fuel_unit'] ?? ''}'),
                                        if (expiresAt.isNotEmpty)
                                          _kv('Expires', expiresAt.split('T').first),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // actions
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.badge_outlined, size: 18),
                                    label: const Text('View Profile'),
                                    onPressed: () => _showProfileDialog(ownerId),
                                  ),
                                  const SizedBox(height: 6),
                                  if (status.toLowerCase() != 'verified')
                                    FilledButton.icon(
                                      icon: const Icon(Icons.verified, size: 18),
                                      label: const Text('Approve'),
                                      onPressed: () => _approve(e),
                                    ),
                                  const SizedBox(height: 6),
                                  if (status.toLowerCase() == 'verified')
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.edit_note, size: 18),
                                      label: const Text('Edit'),
                                      onPressed: () => _approve(e), // reuse approve dialog to update expiry/note
                                    ),
                                  if (status.toLowerCase() != 'rejected') ...[
                                    const SizedBox(height: 6),
                                    TextButton.icon(
                                      icon: const Icon(Icons.cancel, size: 18, color: Colors.red),
                                      label: const Text('Reject', style: TextStyle(color: Colors.red)),
                                      onPressed: () => _reject(e),
                                    ),
                                  ],
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count.toString(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

Widget _kv(String k, dynamic v) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey[300]!),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$k: ',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
        ),
        Text(
          '$v',
          style: const TextStyle(fontSize: 11),
        ),
      ],
    ),
  );
}
