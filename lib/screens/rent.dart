// lib/screens/rent.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:agrimitra/services/db_helper.dart'; // unified DB layer
import 'package:sqflite/sqflite.dart'; // for tiny lookups we do locally

class RentPage extends StatefulWidget {
  static const route = '/rent';
  const RentPage({super.key});

  @override
  State<RentPage> createState() => _RentPageState();
}

class _RentPageState extends State<RentPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<void> _dbInit;

  int _userId = 1; // fallback if not provided via arguments
  String _displayName = 'User';
  int _lastUnreadShown = -1; // for one-time "you have X notifications" popup

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _dbInit = _initDb();
    // After DB ready, show a heads-up if there are unread notifications
    _dbInit.then((_) => _maybeShowUnreadSnack());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final uid = args['userId'];
      final name = args['displayName'];
      if (uid is int) _userId = uid;
      if (name is String) _displayName = name;
    }
  }

  Future<void> _initDb() async {
    await DBHelper.instance.database; // ensure DB + tables ready
  }

  Future<int> _fetchUnreadCount() async {
    final db = await DBHelper.instance.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM notifications WHERE user_id=? AND is_read=0',
      [_userId],
    );
    final v = rows.isNotEmpty ? rows.first['c'] : 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  Future<void> _maybeShowUnreadSnack() async {
    if (!mounted) return;
    final unread = await _fetchUnreadCount();
    if (!mounted) return;
    if (unread > 0 && unread != _lastUnreadShown) {
      _lastUnreadShown = unread;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You have $unread new notification${unread == 1 ? '' : 's'}')),
      );
      setState(() {}); // also refresh badge
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _refreshAll() {
    // used by child tabs to refresh the badge after actions
    setState(() {});
    _maybeShowUnreadSnack();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FutureBuilder<void>(
      future: _dbInit,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Rent Equipment'),
            backgroundColor: cs.primaryContainer,
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                const Tab(icon: Icon(Icons.store_mall_directory_outlined), text: 'Give on Rent'),
                const Tab(icon: Icon(Icons.shopping_cart_outlined), text: 'Take on Rent'),
                // Notifications tab with badge
                Tab(
                  icon: FutureBuilder<int>(
                    future: _fetchUnreadCount(),
                    builder: (ctx, snap) {
                      final count = snap.data ?? 0;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.notifications_outlined),
                          if (count > 0)
                            Positioned(
                              right: -6,
                              top: -6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  count > 99 ? '99+' : '$count',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  text: 'Notifications',
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _GiveOnRentTab(userId: _userId, onToast: _toast),
              _TakeOnRentTab(userId: _userId, onToast: _toast),
              _NotificationsTab(userId: _userId, onToast: _toast, onChanged: _refreshAll),
            ],
          ),
        );
      },
    );
  }
}

/* ============================ TAB 1: GIVE ON RENT ============================ */

class _GiveOnRentTab extends StatefulWidget {
  final int userId;
  final void Function(String) onToast;
  const _GiveOnRentTab({required this.userId, required this.onToast});

  @override
  State<_GiveOnRentTab> createState() => _GiveOnRentTabState();
}

class _GiveOnRentTabState extends State<_GiveOnRentTab> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _rate = TextEditingController();
  final _location = TextEditingController();
  final _phone = TextEditingController();
  final _imageUrl = TextEditingController();

  Future<List<Map<String, dynamic>>> _loadMine() {
    return DBHelper.instance.myEquipment(widget.userId);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await DBHelper.instance.addEquipment({
      'owner_id': widget.userId,
      'title': _title.text.trim(),
      'description': _desc.text.trim(),
      'daily_rate': int.tryParse(_rate.text.trim()) ?? 0,
      'location': _location.text.trim(),
      'phone': _phone.text.trim(),
      'image_url': _imageUrl.text.trim(),
      'available': 1,
      'created_at': DateTime.now().toIso8601String(),
      // no need to pass cert_* here; DB has defaults
    });

    widget.onToast('Equipment listed!');
    _title.clear();
    _desc.clear();
    _rate.clear();
    _location.clear();
    _phone.clear();
    _imageUrl.clear();
    setState(() {}); // refresh list
  }

  Future<void> _removeListing(Map<String, dynamic> e) async {
    final id = (e['id'] as int?) ?? 0;
    if (id == 0) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove listing?'),
        content: Text(
          'This will remove "${(e['title'] ?? '').toString()}" from the marketplace.\n'
              'Any pending requests will be cleared.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final db = await DBHelper.instance.database;
      await db.transaction((txn) async {
        // Clear related requests to avoid orphaned rows / joins.
        await txn.delete('rental_requests', where: 'equipment_id=?', whereArgs: [id]);
        // Remove the equipment (owner-guarded).
        await txn.delete('equipment', where: 'id=? AND owner_id=?', whereArgs: [id, widget.userId]);
      });
      widget.onToast('Listing removed');
      setState(() {}); // refresh list
    } catch (err) {
      widget.onToast('Failed to remove: $err');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Form card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.store_mall_directory_outlined, color: cs.primary),
                          const SizedBox(width: 8),
                          Text('List your equipment',
                              style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _title,
                        decoration: const InputDecoration(
                          labelText: 'Title* (e.g., 45HP Tractor)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _desc,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _rate,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Daily rate (₹)*',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n <= 0) return 'Enter a valid amount';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _location,
                        decoration: const InputDecoration(
                          labelText: 'Your location*',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Contact number*',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (v.trim().length < 8) return 'Too short';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _imageUrl,
                        decoration: const InputDecoration(
                          labelText: 'Image URL (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _submit,
                          child: const Text('Add Equipment'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // My equipment list
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined),
                const SizedBox(width: 8),
                Text('My Listings', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadMine(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final items = snap.data!;
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No listings yet. Add your first equipment above.'),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final e = items[i];
                    final available = (e['available'] as int) == 1;
                    final certStatus = (e['cert_status'] ?? 'none').toString(); // ★
                    return _EquipmentCard(
                      title: (e['title'] ?? '').toString(),
                      desc: (e['description'] ?? '').toString(),
                      rate: (e['daily_rate'] ?? 0) as int,
                      location: (e['location'] ?? '').toString(),
                      phone: (e['phone'] ?? '').toString(),
                      imageUrl: (e['image_url'] ?? '').toString(),
                      certStatus: certStatus, // ★
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: available ? Colors.green[50] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              available ? 'Available' : 'Paused',
                              style: TextStyle(
                                color: available ? Colors.green : Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: available ? 'Pause' : 'Make available',
                            icon: Icon(available ? Icons.pause_circle : Icons.play_circle),
                            onPressed: () async {
                              await DBHelper.instance
                                  .toggleEquipmentAvailability(e['id'] as int, !available);
                              setState(() {});
                            },
                          ),
                          IconButton(
                            tooltip: 'Remove listing',
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _removeListing(e),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

/* ============================ TAB 2: TAKE ON RENT ============================ */

class _TakeOnRentTab extends StatefulWidget {
  final int userId;
  final void Function(String) onToast;
  const _TakeOnRentTab({required this.userId, required this.onToast});

  @override
  State<_TakeOnRentTab> createState() => _TakeOnRentTabState();
}

class _TakeOnRentTabState extends State<_TakeOnRentTab> {
  final _q = TextEditingController();

  /// Load ids of equipment this user has already requested (pending/accepted)
  Future<Set<int>> _myRequestedEquipmentIds() async {
    final db = await DBHelper.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT equipment_id FROM rental_requests
      WHERE requester_id = ? AND status IN ('pending','accepted')
      ''',
      [widget.userId],
    );
    return rows
        .map((r) => (r['equipment_id'] as int?) ?? 0)
        .where((id) => id != 0)
        .toSet();
  }

  Future<List<Map<String, dynamic>>> _loadAvailable() async {
    final all = await DBHelper.instance.availableEquipmentExcept(widget.userId);
    final requested = await _myRequestedEquipmentIds();

    // Hide things I've already requested (this is your "vanish into waitlist")
    final filtered = all.where((e) => !requested.contains(e['id'] as int)).toList();

    final query = _q.text.trim().toLowerCase();
    if (query.isEmpty) return filtered;

    return filtered.where((e) {
      final t = (e['title'] ?? '').toString().toLowerCase();
      final d = (e['description'] ?? '').toString().toLowerCase();
      final loc = (e['location'] ?? '').toString().toLowerCase();
      return t.contains(query) || d.contains(query) || loc.contains(query);
    }).toList();
  }

  void _openRequestSheet(Map<String, dynamic> equip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RequestSheet(
        equipment: equip,
        requesterId: widget.userId,
        onSubmitted: () async {
          Navigator.pop(context);
          widget.onToast('Request sent to owner!');
          setState(() {}); // triggers _loadAvailable(), which will now hide it
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _q,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search by title, description, location',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _q.clear();
                    setState(() {});
                  },
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadAvailable(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final items = snap.data!;
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No equipment available right now.'),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final e = items[i];
                    final certStatus = (e['cert_status'] ?? 'none').toString(); // ★
                    return _EquipmentCard(
                      title: (e['title'] ?? '').toString(),
                      desc: (e['description'] ?? '').toString(),
                      rate: (e['daily_rate'] ?? 0) as int,
                      location: (e['location'] ?? '').toString(),
                      phone: (e['phone'] ?? '').toString(),
                      imageUrl: (e['image_url'] ?? '').toString(),
                      certStatus: certStatus, // ★
                      trailing: FilledButton.icon(
                        onPressed: () => _openRequestSheet(e),
                        icon: const Icon(Icons.send),
                        label: const Text('Request'),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

class _RequestSheet extends StatefulWidget {
  final Map<String, dynamic> equipment;
  final int requesterId;
  final VoidCallback onSubmitted;
  const _RequestSheet({
    required this.equipment,
    required this.requesterId,
    required this.onSubmitted,
  });

  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _message = TextEditingController();
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _location = TextEditingController();
  final _phone = TextEditingController();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await DBHelper.instance.createRequest(
      equipmentId: widget.equipment['id'] as int,
      requesterId: widget.requesterId,
      message: _message.text.trim(),
      startDate: _start.text.trim(),
      endDate: _end.text.trim(),
      location: _location.text.trim(),
      phone: _phone.text.trim(),
    );
    widget.onSubmitted();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.equipment;
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: media.viewInsets.bottom,
        left: 16, right: 16, top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: 46, height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[400], borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 12),
            Text('Request: ${(e['title'] ?? '').toString()}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _message,
                    decoration: const InputDecoration(
                      labelText: 'Message to owner',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _start,
                    decoration: const InputDecoration(
                      labelText: 'Start date (YYYY-MM-DD)*',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _end,
                    decoration: const InputDecoration(
                      labelText: 'End date (YYYY-MM-DD)*',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _location,
                    decoration: const InputDecoration(
                      labelText: 'Your location*',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Contact number*',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (v.trim().length < 8) return 'Too short';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.send),
                      onPressed: _submit,
                      label: const Text('Send Request'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================ TAB 3: NOTIFICATIONS ============================ */

class _NotificationsTab extends StatefulWidget {
  final int userId;
  final void Function(String) onToast;
  final VoidCallback onChanged; // to refresh badge in parent
  const _NotificationsTab({required this.userId, required this.onToast, required this.onChanged});

  @override
  State<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<_NotificationsTab> {
  Future<List<Map<String, dynamic>>> _loadNotifs() {
    return DBHelper.instance.notificationsFor(widget.userId);
  }

  /// "Waitlist": my own requests (most recent first)
  Future<List<Map<String, dynamic>>> _loadMyRequests() async {
    final db = await DBHelper.instance.database;
    return db.rawQuery('''
      SELECT rr.id as request_id, rr.status, rr.created_at, rr.start_date, rr.end_date,
             e.title, e.image_url, e.daily_rate
      FROM rental_requests rr
      JOIN equipment e ON e.id = rr.equipment_id
      WHERE rr.requester_id = ?
      ORDER BY rr.created_at DESC
    ''', [widget.userId]);
  }

  /// Resolve a user name by id for nicer notification subtitles.
  final Map<int, String> _nameCache = {};
  Future<String> _nameForUser(int id) async {
    if (_nameCache.containsKey(id)) return _nameCache[id]!;
    final db = await DBHelper.instance.database;
    final rows = await db.query('users', columns: ['name'], where: 'id=?', whereArgs: [id], limit: 1);
    final name = rows.isNotEmpty ? (rows.first['name'] as String? ?? 'User $id') : 'User $id';
    _nameCache[id] = name;
    return name;
  }

  /// Ensure column exists (used for rejection reason).
  Future<void> _ensureColumn(String table, String col, String type) async {
    final db = await DBHelper.instance.database;
    final cols = await db.rawQuery('PRAGMA table_info($table)');
    final has = cols.any((m) => (m['name'] as String).toLowerCase() == col.toLowerCase());
    if (!has) {
      await db.execute('ALTER TABLE $table ADD COLUMN $col $type;');
    }
  }

  Future<String?> _rejectionReasonForRequest(int requestId) async {
    final db = await DBHelper.instance.database;
    await _ensureColumn('rental_requests', 'rejection_reason', 'TEXT');
    final rows = await db.query('rental_requests',
        columns: ['rejection_reason'], where: 'id=?', whereArgs: [requestId], limit: 1);
    if (rows.isNotEmpty) {
      final r = rows.first['rejection_reason'];
      if (r is String && r.trim().isNotEmpty) return r.trim();
    }
    return null;
  }

  Future<String?> _certNoteForEquipment(int equipmentId) async {
    final db = await DBHelper.instance.database;
    // Try to read cert_note if it exists.
    try {
      final rows = await db.query('equipment',
          columns: ['cert_note'], where: 'id=?', whereArgs: [equipmentId], limit: 1);
      if (rows.isNotEmpty) {
        final v = rows.first['cert_note'];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
    } catch (_) {
      // if the column doesn't exist, ignore
    }
    return null;
  }

  Future<void> _openOwnerInbox() async {
    // Owner can inspect incoming requests and accept/reject.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _OwnerRequestsSheet(
        ownerId: widget.userId,
        onAction: () {
          Navigator.pop(context);
          widget.onToast('Updated request status');
          setState(() {});
          widget.onChanged();
        },
      ),
    );
  }

  Future<void> _acceptFromNotif(int requestId, int notifId) async {
    await DBHelper.instance.updateRequestStatus(requestId, 'accepted', widget.userId);
    await DBHelper.instance.markNotificationRead(notifId);
    widget.onToast('Accepted — you\'ll coordinate with the renter.');
    setState(() {});
    widget.onChanged();
  }

  Future<void> _markRead(int notifId) async {
    await DBHelper.instance.markNotificationRead(notifId);
    setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
        widget.onChanged();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.inbox_outlined),
                const SizedBox(width: 8),
                Text('Your Notifications',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _openOwnerInbox,
                  icon: const Icon(Icons.manage_accounts_outlined, size: 18),
                  label: const Text('Owner Inbox'),
                )
              ],
            ),

            // --- Waitlist: my own requests ---
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('My Requests (Waitlist)',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadMyRequests(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: LinearProgressIndicator(minHeight: 2),
                  );
                }
                final reqs = snap.data!;
                if (reqs.isEmpty) {
                  return const SizedBox.shrink();
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reqs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = reqs[i];
                    final status = (r['status'] ?? 'pending').toString();
                    Color c = Colors.orange;
                    if (status == 'accepted') c = Colors.green;
                    if (status == 'rejected') c = Colors.red;

                    final requestId = (r['request_id'] as int?) ?? 0;

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.hourglass_bottom_outlined),
                        title: Text('${r['title']}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(' ${r['start_date']} → ${r['end_date']}'),
                            if (status == 'rejected')
                              FutureBuilder<String?>(
                                future: _rejectionReasonForRequest(requestId),
                                builder: (ctx, rs) {
                                  final reason = (rs.data ?? '').trim();
                                  return reason.isEmpty
                                      ? const SizedBox.shrink()
                                      : Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Reason: $reason',
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                        trailing: Text(status.toUpperCase(),
                            style: TextStyle(color: c, fontWeight: FontWeight.w700)),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // --- Actual notifications ---
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadNotifs(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final items = snap.data!;
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No notifications yet.'),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final n = items[i];
                    final isRead = (n['is_read'] as int) == 1;
                    final type = (n['type'] ?? '').toString();
                    final payloadStr = (n['payload'] ?? '{}').toString();
                    final payload = _safeJson(payloadStr);
                    final created = (n['created_at'] ?? '').toString();

                    String title;
                    Widget subtitleWidget;
                    Widget? trailing;

                    if (type == 'request_received') {
                      title = 'New rental request for "${payload['title'] ?? 'Equipment'}"';
                      final requesterId = (payload['requester_id'] ?? 0) is int
                          ? payload['requester_id'] as int
                          : int.tryParse((payload['requester_id'] ?? '0').toString()) ?? 0;
                      final requestId = (payload['request_id'] ?? 0) is int
                          ? payload['request_id'] as int
                          : int.tryParse((payload['request_id'] ?? '0').toString()) ?? 0;

                      subtitleWidget = FutureBuilder<String>(
                        future: _nameForUser(requesterId),
                        builder: (ctx, snapName) {
                          final name = snapName.data ?? 'User $requesterId';
                          return Text('From $name • ${payload['start_date']} → ${payload['end_date']}');
                        },
                      );

                      // Actions: Accept or Later (mark read)
                      trailing = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => _acceptFromNotif(requestId, n['id'] as int),
                            child: const Text('Accept'),
                          ),
                          const SizedBox(width: 6),
                          if (!isRead)
                            TextButton(
                              onPressed: () => _markRead(n['id'] as int),
                              child: const Text('Later'),
                            ),
                        ],
                      );
                    } else if (type == 'request_update') {
                      final status = (payload['status'] ?? '').toString();
                      title = 'Request update: $status';
                      final requestId = (payload['request_id'] is int)
                          ? payload['request_id'] as int
                          : int.tryParse('${payload['request_id'] ?? 0}') ?? 0;
                      final payloadReason = (payload['reason'] ?? '').toString().trim();

                      if (status.toLowerCase() == 'rejected') {
                        // Show reason from payload, else fetch from rental_requests
                        subtitleWidget = FutureBuilder<String?>(
                          future: payloadReason.isNotEmpty
                              ? Future.value(payloadReason)
                              : _rejectionReasonForRequest(requestId),
                          builder: (ctx, rs) {
                            final r = (rs.data ?? '').trim();
                            final reasonLine = r.isEmpty ? '' : '\nReason: $r';
                            return Text('For "${payload['title'] ?? 'Equipment'}"$reasonLine');
                          },
                        );
                      } else {
                        subtitleWidget = Text('For "${payload['title'] ?? 'Equipment'}"');
                      }

                      trailing = isRead
                          ? null
                          : TextButton(
                        onPressed: () => _markRead(n['id'] as int),
                        child: const Text('Mark read'),
                      );
                    } else if (type == 'cert_update') { // ★ support cert notifications with reason
                      final status = (payload['cert_status'] ?? '').toString();
                      title = 'Certification: ${status.isEmpty ? 'Update' : status}';

                      if (status.toLowerCase() == 'rejected') {
                        final notePayload = ((payload['note'] ?? payload['cert_note']) ?? '').toString().trim();
                        final equipmentId = (payload['equipment_id'] is int)
                            ? payload['equipment_id'] as int
                            : int.tryParse('${payload['equipment_id'] ?? 0}') ?? 0;

                        subtitleWidget = FutureBuilder<String?>(
                          future: notePayload.isNotEmpty
                              ? Future.value(notePayload)
                              : (equipmentId > 0 ? _certNoteForEquipment(equipmentId) : Future.value(null)),
                          builder: (ctx, rs) {
                            final note = (rs.data ?? '').trim();
                            final reasonLine = note.isEmpty ? '' : '\nReason: $note';
                            return Text('For "${payload['title'] ?? 'Equipment'}"$reasonLine');
                          },
                        );
                      } else {
                        subtitleWidget = Text('For "${payload['title'] ?? 'Equipment'}"');
                      }

                      trailing = isRead
                          ? null
                          : TextButton(
                        onPressed: () => _markRead(n['id'] as int),
                        child: const Text('Mark read'),
                      );
                    } else {
                      title = 'Notification';
                      subtitleWidget = Text(created);
                      trailing = isRead
                          ? null
                          : TextButton(
                        onPressed: () => _markRead(n['id'] as int),
                        child: const Text('Mark read'),
                      );
                    }

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isRead ? Colors.grey[300]! : Colors.blueAccent),
                      ),
                      child: ListTile(
                        leading: Icon(
                          type == 'request_received'
                              ? Icons.mark_email_unread_outlined
                              : Icons.info_outline,
                          color: isRead ? Colors.grey : Colors.blueAccent,
                        ),
                        title: Text(title),
                        subtitle: subtitleWidget,
                        trailing: trailing,
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

class _OwnerRequestsSheet extends StatefulWidget {
  final int ownerId;
  final VoidCallback onAction;
  const _OwnerRequestsSheet({required this.ownerId, required this.onAction});

  @override
  State<_OwnerRequestsSheet> createState() => _OwnerRequestsSheetState();
}

class _OwnerRequestsSheetState extends State<_OwnerRequestsSheet> {
  Future<List<Map<String, dynamic>>> _load() {
    return DBHelper.instance.incomingRequestsForOwner(widget.ownerId);
  }

  Future<void> _ensureRejectionColumn() async {
    final db = await DBHelper.instance.database;
    final cols = await db.rawQuery('PRAGMA table_info(rental_requests)');
    final has = cols.any((m) => (m['name'] as String).toLowerCase() == 'rejection_reason');
    if (!has) {
      await db.execute('ALTER TABLE rental_requests ADD COLUMN rejection_reason TEXT;');
    }
  }

  Future<void> _changeStatus(int requestId, String status) async {
    await DBHelper.instance.updateRequestStatus(requestId, status, widget.ownerId);
    widget.onAction();
  }

  Future<void> _rejectWithReason(int requestId) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject request'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Reason (required)',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final reason = reasonCtrl.text.trim();
    await _ensureRejectionColumn();
    // 1) Update status via existing helper (keeps your notification flow)
    await DBHelper.instance.updateRequestStatus(requestId, 'rejected', widget.ownerId);
    // 2) Persist the reason so renter can see it later
    final db = await DBHelper.instance.database;
    await db.update(
      'rental_requests',
      {'rejection_reason': reason},
      where: 'id=?',
      whereArgs: [requestId],
    );
    widget.onAction();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: media.viewInsets.bottom,
        left: 16, right: 16, top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 46, height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[400], borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 12),
          Text('Incoming Requests',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _load(),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final items = snap.data!;
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No requests yet.'),
                );
              }
              return Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final r = items[i];
                    final status = (r['status'] ?? 'pending').toString();
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: (r['image_url'] != null && (r['image_url'] as String).isNotEmpty)
                              ? NetworkImage((r['image_url'] as String))
                              : null,
                          child: (r['image_url'] == null || (r['image_url'] as String).isEmpty)
                              ? const Icon(Icons.agriculture)
                              : null,
                        ),
                        title: Text('${r['title']} • ₹${r['daily_rate']}/day'),
                        subtitle: Text(
                          'Dates: ${r['start_date']} → ${r['end_date']}\n'
                              'From: ${r['req_location']} • ${r['req_phone']}\n'
                              'Message: ${r['message'] ?? '-'}',
                        ),
                        isThreeLine: true,
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(status.toUpperCase(),
                                style: TextStyle(
                                  color: status == 'pending'
                                      ? Colors.orange
                                      : status == 'accepted'
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.w700,
                                )),
                            const SizedBox(height: 6),
                            if (status == 'pending')
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Accept',
                                    onPressed: () => _changeStatus(r['request_id'] as int, 'accepted'),
                                    icon: const Icon(Icons.check_circle, color: Colors.green),
                                  ),
                                  IconButton(
                                    tooltip: 'Reject (add reason)',
                                    onPressed: () => _rejectWithReason(r['request_id'] as int),
                                    icon: const Icon(Icons.cancel, color: Colors.red),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/* ============================ SMALL UI HELPERS ============================ */

class _EquipmentCard extends StatelessWidget {
  final String title;
  final String desc;
  final int rate;
  final String location;
  final String phone;
  final String imageUrl;
  final String? certStatus; // ★ certification status (optional)
  final Widget? trailing;

  const _EquipmentCard({
    required this.title,
    required this.desc,
    required this.rate,
    required this.location,
    required this.phone,
    required this.imageUrl,
    this.certStatus, // ★
    this.trailing,
  });

  bool get _isCertified {
    final s = (certStatus ?? 'none').toLowerCase();
    return s == 'verified' || s == 'auto_verified';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: (imageUrl.isNotEmpty)
                  ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.agriculture, size: 28),
              )
                  : const Icon(Icons.agriculture, size: 28),
            ),
            const SizedBox(width: 12),
            // text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row + Certified chip (if any)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isCertified) // ★ show certification chip
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.verified, size: 14, color: Colors.green),
                              SizedBox(width: 4),
                              Text(
                                'Certified',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc.isEmpty ? '—' : desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.currency_rupee, size: 16, color: cs.primary),
                      Text('$rate/day   ·  '),
                      const Icon(Icons.place, size: 16, color: Colors.grey),
                      Flexible(child: Text(location, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone_android, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(phone),
                    ],
                  ),
                ],
              ),
            ),
            if (trailing != null) const SizedBox(width: 8),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

Map<String, dynamic> _safeJson(String s) {
  try {
    final v = jsonDecode(s);
    return v is Map<String, dynamic> ? v : {};
  } catch (_) {
    return {};
  }
}
