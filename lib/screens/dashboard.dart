// lib/screens/dashboard.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart'; // for input formatters

// ⬇️ Use your existing DB layer (no DBHelper edits required for now)
// We'll grab the Database instance from here and run small SQL helpers.
import 'package:agrimitra/services/db_helper.dart';
import 'package:sqflite/sqflite.dart';

// ✅ open Disease Detect screen
import 'package:agrimitra/screens/disease.dart';

// ✅ NEW: import Govt Schemes screen
import 'package:agrimitra/screens/govt.dart';

class DashboardPage extends StatefulWidget {
  static const route = '/dashboard';
  const DashboardPage({super.key});

  // <-- keep _todo as a static on DashboardPage
  static void _todo(BuildContext context, String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name — screen coming soon')),
    );
  }

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // ---------------- Weather state ----------------
  Map<String, dynamic>? _weatherData;
  bool _isLoadingWeather = false;
  String _weatherError = '';
  final String _owmApiKey = '8d6127e074f05533890c5b550b4c0e2b';

  // ✅ manual city override
  String? _manualCity; // e.g., "Hyderabad" or "Hyderabad, IN"

  // ---------------- Market ticker state ----------------
  static const String _govApiKey =
      '579b464db66ec23bdd0000010baed15d539144fa62035eb3cd19e551';
  static const String _resourceUrl =
      'https://api.data.gov.in/resource/35985678-0d79-46b4-9ed6-6f13308a1d24';

  final List<String> _dashboardCommodities = const [
    'Wheat',
    'Rice',
    'Cotton',
    'Soybean',
  ];

  final String? _pinState = null;  // e.g., 'Karnataka'
  final String? _pinMarket = null; // e.g., 'Binny Mill (F&V), Bangalore'

  bool _isLoadingTickers = false;
  String _tickerError = '';
  List<_MarketTicker> _tickers = [];

  @override
  void initState() {
    super.initState();
    _refreshWeather(); // uses manual city if set, else GPS
    _loadMarketTickers();
  }

  // ---------------- Weather ----------------

  Future<void> _refreshWeather() async {
    if (_manualCity != null && _manualCity!.trim().isNotEmpty) {
      await _fetchWeatherByCity(_manualCity!.trim());
    } else {
      await _getCurrentLocationWeather();
    }
  }

  Future<void> _getCurrentLocationWeather() async {
    setState(() {
      _isLoadingWeather = true;
      _weatherError = '';
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _weatherError = 'Location services are disabled';
          _isLoadingWeather = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _weatherError = 'Location permission denied';
            _isLoadingWeather = false;
          });
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _weatherError = 'Location permissions are permanently denied';
          _isLoadingWeather = false;
        });
        return;
      }

      Position? pos = await Geolocator.getLastKnownPosition();
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
      } catch (_) {}
      pos ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );

      await _fetchWeatherData(pos.latitude, pos.longitude);
    } catch (e) {
      setState(() {
        _weatherError = 'Failed to get location: $e';
        _isLoadingWeather = false;
      });
    }
  }

  Future<void> _fetchWeatherData(double lat, double lon) async {
    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$_owmApiKey&units=metric',
    );
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        setState(() {
          _weatherData = json.decode(res.body);
          _isLoadingWeather = false;
        });
      } else {
        setState(() {
          _weatherError = 'Failed to load weather data: ${res.statusCode}';
          _isLoadingWeather = false;
        });
      }
    } catch (e) {
      setState(() {
        _weatherError = 'Failed to load weather data: $e';
        _isLoadingWeather = false;
      });
    }
  }

  Future<void> _fetchWeatherByCity(String cityQuery) async {
    setState(() {
      _isLoadingWeather = true;
      _weatherError = '';
    });
    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather?q=$cityQuery&appid=$_owmApiKey&units=metric',
    );
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        setState(() {
          _weatherData = json.decode(res.body);
          _isLoadingWeather = false;
        });
      } else {
        setState(() {
          _weatherError = 'City not found (${res.statusCode}). Try "City, IN".';
          _isLoadingWeather = false;
        });
      }
    } catch (e) {
      setState(() {
        _weatherError = 'Failed to load weather (city): $e';
        _isLoadingWeather = false;
      });
    }
  }

  Future<void> _promptSetCity() async {
    final ctrl = TextEditingController(text: _manualCity ?? '');
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Location (City)'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'e.g., Hyderabad or Hyderabad, IN',
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.pop(ctx, ctrl.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (res != null) {
      setState(() => _manualCity = res.isEmpty ? null : res);
      await _refreshWeather();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _manualCity == null
                ? 'Cleared manual location. Using GPS.'
                : 'Using manual location: $_manualCity',
          ),
        ),
      );
    }
  }

  // ---------------- Market tickers (data.gov.in) ----------------
  Future<void> _loadMarketTickers() async {
    setState(() {
      _isLoadingTickers = true;
      _tickerError = '';
      _tickers = [];
    });

    try {
      final futures = _dashboardCommodities.map((c) =>
          _fetchLatestTicker(commodity: c, state: _pinState, market: _pinMarket));
      final results = await Future.wait(futures);

      final nonNull = results.whereType<_MarketTicker>().toList();

      if (nonNull.isEmpty) {
        setState(() {
          _tickerError =
          'No market rows returned. Try different commodities or remove region filters.';
          _isLoadingTickers = false;
        });
        return;
      }

      nonNull.sort((a, b) => a.commodity.compareTo(b.commodity));
      setState(() {
        _tickers = nonNull.take(4).toList();
        _isLoadingTickers = false;
      });
    } catch (e) {
      setState(() {
        _tickerError = 'Error loading market data: $e';
        _isLoadingTickers = false;
      });
    }
  }

  Future<_MarketTicker?> _fetchLatestTicker({
    required String commodity,
    String? state,
    String? market,
  }) async {
    final latestParams = <String, String>{
      'api-key': _govApiKey,
      'format': 'json',
      'limit': '50',
      'offset': '0',
      'sort[Arrival_Date]': 'desc',
      'filters[Commodity]': commodity,
    };
    if (state != null && state.trim().isNotEmpty) {
      latestParams['filters[State]'] = state.trim();
    }
    if (market != null && market.trim().isNotEmpty) {
      latestParams['filters[Market]'] = market.trim();
    }

    final latestUri = Uri.parse(_resourceUrl).replace(queryParameters: latestParams);
    final latestRes = await http.get(latestUri).timeout(const Duration(seconds: 30));
    if (latestRes.statusCode != 200) return null;

    final latestBody = json.decode(latestRes.body) as Map<String, dynamic>;
    final latestCount = (latestBody['count'] ?? 0) as int;
    final latestMsg = (latestBody['message'] ?? '').toString().toLowerCase();
    if (latestCount == 0 && latestMsg.contains('resource id')) return null;

    final latestRecords = (latestBody['records'] ?? []) as List;
    if (latestRecords.isEmpty) return null;

    Map<String, dynamic>? pick;
    for (final r in latestRecords) {
      final m = (r as Map<String, dynamic>)['Modal_Price'];
      if (m != null && m.toString().trim().isNotEmpty) {
        pick = r as Map<String, dynamic>;
        break;
      }
    }
    pick ??= latestRecords.first as Map<String, dynamic>;

    int _toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      return int.tryParse(v.toString().trim()) ?? 0;
    }

    final latestModal = _toInt(pick['Modal_Price']);
    final marketName = (pick['Market'] ?? '').toString();
    final stateName = (pick['State'] ?? '').toString();
    final dateStr = (pick['Arrival_Date'] ?? '').toString(); // dd/MM/yyyy
    final prevChange = await _computeChangePct(
      commodity: commodity,
      state: state,
      market: market,
      excludeDate: dateStr,
    );

    return _MarketTicker(
      commodity: commodity,
      priceINR: latestModal,
      changePct: prevChange,
      market: marketName,
      state: stateName,
      date: dateStr,
    );
  }

  Future<double?> _computeChangePct({
    required String commodity,
    String? state,
    String? market,
    required String excludeDate,
  }) async {
    final params = <String, String>{
      'api-key': _govApiKey,
      'format': 'json',
      'limit': '100',
      'offset': '0',
      'sort[Arrival_Date]': 'desc',
      'filters[Commodity]': commodity,
    };
    if (state != null && state.trim().isNotEmpty) {
      params['filters[State]'] = state.trim();
    }
    if (market != null && market.trim().isNotEmpty) {
      params['filters[Market]'] = market.trim();
    }

    final uri = Uri.parse(_resourceUrl).replace(queryParameters: params);
    final res = await http.get(uri).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) return null;

    final body = json.decode(res.body) as Map<String, dynamic>;
    final recs = (body['records'] ?? []) as List;
    if (recs.length < 2) return null;

    int _toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      return int.tryParse(v.toString().trim()) ?? 0;
    }

    Map<String, dynamic>? prev;
    for (final r in recs) {
      final m = (r as Map<String, dynamic>)['Modal_Price'];
      final d = (r['Arrival_Date'] ?? '').toString();
      if (d != excludeDate && m != null && m.toString().trim().isNotEmpty) {
        prev = r as Map<String, dynamic>;
        break;
      }
    }
    if (prev == null) return null;

    Map<String, dynamic>? latest;
    for (final r in recs) {
      final m = (r as Map<String, dynamic>)['Modal_Price'];
      final d = (r['Arrival_Date'] ?? '').toString();
      if (d == excludeDate && m != null && m.toString().trim().isNotEmpty) {
        latest = r as Map<String, dynamic>;
        break;
      }
    }
    latest ??= recs.first as Map<String, dynamic>;

    final latestModal = _toInt(latest['Modal_Price']);
    final prevModal = _toInt(prev['Modal_Price']);
    if (latestModal == 0 || prevModal == 0) return null;

    final pct = ((latestModal - prevModal) / prevModal) * 100.0;
    return pct.isFinite ? pct : null;
  }

  // ---------------- Helpers for Quick Stats ----------------
  int? _currentTempC() {
    try {
      final t = _weatherData?['main']?['temp'];
      if (t is num) return t.round();
    } catch (_) {}
    return null;
  }

  double? _currentWindKmh() {
    try {
      final s = _weatherData?['wind']?['speed']; // m/s from OWM
      if (s is num) return (s * 3.6);
    } catch (_) {}
    return null;
  }

  int? _wheatPrice() {
    try {
      final w = _tickers.firstWhere(
            (t) => t.commodity.toLowerCase() == 'wheat',
        orElse: () => _tickers.first,
      );
      return w.priceINR;
    } catch (_) {
      return null;
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final args = ModalRoute.of(context)?.settings.arguments;
    String? displayName;
    String? email;
    int userId = 1; // fallback
    if (args is Map) {
      displayName = args['displayName'] as String?;
      email = args['email'] as String?;
      final uid = args['userId'];
      if (uid is int) userId = uid;
    }

    final friendlyName = (displayName?.trim().isNotEmpty == true)
        ? displayName!.trim()
        : (email != null && email!.contains('@'))
        ? email!.split('@').first
        : 'Farmer';

    final tempC = _currentTempC();
    final windKmh = _currentWindKmh();
    final wheat = _wheatPrice();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AgriMitra'),
        backgroundColor: colorScheme.primaryContainer,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _UserChip(name: friendlyName),
          ),
          PopupMenuButton<String>(
            tooltip: 'Menu',
            onSelected: (value) async {
              switch (value) {
                case 'profile':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _ProfileSettingsPage(userId: userId),
                    ),
                  );
                  break;
                case 'refresh':
                  await _refreshWeather();
                  await _loadMarketTickers();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Refreshing...')),
                  );
                  break;
                case 'logout':
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                        (_) => false,
                  );
                  break;
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'profile', child: Text('Settings / Profile')),
              PopupMenuItem(value: 'refresh', child: Text('Refresh')),
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: _DashboardDrawer(
        userId: userId,
        friendlyName: friendlyName,
        email: email,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WelcomeCard(friendlyName: friendlyName),
              const SizedBox(height: 20),

              _QuickStatsRow(
                wheatPrice: wheat,
                temperatureC: tempC,
                windKmh: windKmh,
              ),
              const SizedBox(height: 20),

              Text(
                'Features',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _FeatureGrid(
                items: [
                  FeatureItem(
                    title: 'Crop Prices',
                    subtitle: 'Mandi & forecast',
                    icon: Icons.price_change_outlined,
                    color: Colors.green,
                    onTap: () => Navigator.pushNamed(context, '/crop-prices'),
                  ),
                  FeatureItem(
                    title: 'Rent Equipment',
                    subtitle: 'Tractor, drone…',
                    icon: Icons.agriculture_outlined,
                    color: Colors.blue,
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/rent',
                      arguments: {
                        'userId': userId,
                        'displayName': friendlyName,
                      },
                    ),
                  ),
                  FeatureItem(
                    title: 'Disease Detect',
                    subtitle: 'Upload leaf photo',
                    icon: Icons.health_and_safety_outlined,
                    color: Colors.orange,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DiseasePage()),
                    ),
                  ),
                  FeatureItem(
                    title: 'Growth Monitor',
                    subtitle: 'Yield & weather',
                    icon: Icons.monitor_heart_outlined,
                    color: Colors.purple,
                    onTap: () =>
                        DashboardPage._todo(context, 'Growth Monitoring'),
                  ),
                  FeatureItem(
                    title: 'Govt Schemes',
                    subtitle: 'Eligibility & apply',
                    icon: Icons.assignment_turned_in_outlined,
                    color: Colors.teal,
                    // ✅ NOW navigates to govt.dart
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GovtPage()),
                    ),
                  ),
                  FeatureItem(
                    title: 'Community',
                    subtitle: 'Ask & share',
                    icon: Icons.forum_outlined,
                    color: Colors.indigo,
                    onTap: () =>
                        DashboardPage._todo(context, 'Community Q&A'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _WeatherAdvisoryCard(
                weatherData: _weatherData,
                isLoading: _isLoadingWeather,
                error: _weatherError,
                onRefresh: _refreshWeather,
                manualCity: _manualCity,
                onSetCity: _promptSetCity,
                onClearCity: () async {
                  setState(() => _manualCity = null);
                  await _refreshWeather();
                },
              ),
              const SizedBox(height: 20),

              Text(
                'Market Updates',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _MarketUpdates(
                isLoading: _isLoadingTickers,
                error: _tickerError,
                tickers: _tickers,
                onRefresh: _loadMarketTickers,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* --------------------------- Market Models & UI --------------------------- */

class _MarketTicker {
  final String commodity;
  final int priceINR;
  final double? changePct;
  final String market;
  final String state;
  final String date; // dd/MM/yyyy

  _MarketTicker({
    required this.commodity,
    required this.priceINR,
    required this.changePct,
    required this.market,
    required this.state,
    required this.date,
  });
}

class _MarketUpdates extends StatelessWidget {
  final bool isLoading;
  final String error;
  final List<_MarketTicker> tickers;
  final VoidCallback onRefresh;

  const _MarketUpdates({
    required this.isLoading,
    required this.error,
    required this.tickers,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error.isNotEmpty) {
      return Row(
        children: [
          Expanded(child: Text(error, style: const TextStyle(color: Colors.red))),
          IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh)),
        ],
      );
    }
    if (tickers.isEmpty) {
      return Row(
        children: [
          const Expanded(child: Text('No market data')),
          IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh)),
        ],
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tickers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) => _MarketTile(t: tickers[i]),
      ),
    );
  }
}

class _MarketTile extends StatelessWidget {
  final _MarketTicker t;
  const _MarketTile({required this.t});

  @override
  Widget build(BuildContext context) {
    final isUp = (t.changePct ?? 0) >= 0;
    final changeText = (t.changePct == null)
        ? '—'
        : '${isUp ? '+' : ''}${t.changePct!.toStringAsFixed(1)}%';
    final changeColor = (t.changePct == null)
        ? Colors.grey
        : (isUp ? Colors.green : Colors.red);

    return Container(
      width: 160,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(height: 1.1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.commodity, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              '₹${t.priceINR}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              changeText,
              style: TextStyle(color: changeColor, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                t.market.isEmpty ? t.state : t.market,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              t.date,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

/* --------------------------- Reusable Widgets --------------------------- */

class _UserChip extends StatelessWidget {
  final String name;
  const _UserChip({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? 'F'
        : name
        .trim()
        .split(RegExp(r'\s+'))
        .map((w) => w[0])
        .take(2)
        .join()
        .toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DashboardDrawer extends StatelessWidget {
  final int userId;
  final String friendlyName;
  final String? email;

  const _DashboardDrawer({
    required this.userId,
    required this.friendlyName,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.agriculture, size: 50, color: Colors.green),
                    SizedBox(height: 8),
                    Text('AgriMitra',
                        style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('Farmer\'s Companion'),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Dashboard'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.price_change_outlined),
              title: const Text('Crop Prices'),
              onTap: () => Navigator.pushNamed(context, '/crop-prices'),
            ),
            ListTile(
              leading: const Icon(Icons.agriculture_outlined),
              title: const Text('Equipment Rental'),
              onTap: () => Navigator.pushNamed(
                context,
                '/rent',
                arguments: {
                  'userId': userId,
                  'displayName': friendlyName,
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.local_florist_outlined),
              title: const Text('Crop Health'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DiseasePage()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.assignment_turned_in_outlined),
              title: const Text('Govt Schemes'),
              // ✅ NOW navigates to govt.dart
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GovtPage()),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings / Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _ProfileSettingsPage(userId: userId),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help & Support'),
              onTap: () => DashboardPage._todo(context, 'Help & Support'),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                      (_) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final String friendlyName;
  const _WelcomeCard({required this.friendlyName});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, $friendlyName!',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check today\'s crop prices, weather updates, and farming tips to maximize your yield.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {},
                    child: const Text('Explore Today\'s Tips'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            const Icon(Icons.agriculture, size: 60, color: Colors.green),
          ],
        ),
      ),
    );
  }
}

/* ---------------- Quick Stats (now dynamic) ---------------- */

class _QuickStatsRow extends StatelessWidget {
  final int? wheatPrice;
  final int? temperatureC;
  final double? windKmh;

  const _QuickStatsRow({
    this.wheatPrice,
    this.temperatureC,
    this.windKmh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatItem(
          value: (wheatPrice != null) ? '₹$wheatPrice' : '—',
          label: 'Wheat (Modal)',
          icon: Icons.trending_up,
          color: Colors.green,
        ),
        _StatItem(
          value: (temperatureC != null) ? '$temperatureC°C' : '—',
          label: 'Temperature',
          icon: Icons.thermostat,
          color: Colors.orange,
        ),
        _StatItem(
          value: (windKmh != null) ? '${windKmh!.toStringAsFixed(0)} km/h' : '—',
          label: 'Wind',
          icon: Icons.air,
          color: Colors.blue,
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/* ---------------- Weather & Advisory Card ---------------- */

class _WeatherAdvisoryCard extends StatelessWidget {
  final Map<String, dynamic>? weatherData;
  final bool isLoading;
  final String error;
  final VoidCallback onRefresh;

  // manual city controls
  final String? manualCity;
  final VoidCallback onSetCity;
  final VoidCallback onClearCity;

  const _WeatherAdvisoryCard({
    required this.weatherData,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
    this.manualCity,
    required this.onSetCity,
    required this.onClearCity,
  });

  String _getWeatherAdvisory(Map<String, dynamic>? weatherData) {
    if (weatherData == null) return 'Loading weather data...';

    final main = weatherData['main'];
    final weather = weatherData['weather'][0];
    final int temp = (main['temp'] as num).round();
    final int humidity = (main['humidity'] as num).round();
    final String condition = (weather['main'] as String?) ?? '';

    if (condition == 'Rain') {
      return 'Advisory: Rain expected. Postpone field activities and ensure proper drainage.';
    } else if (temp > 35) {
      return 'Advisory: High temperature. Irrigate crops in the early morning or late evening.';
    } else if (humidity < 30) {
      return 'Advisory: Low humidity. Consider additional irrigation to prevent soil moisture loss.';
    } else if (temp < 10) {
      return 'Advisory: Cold temperatures. Protect sensitive crops from potential frost.';
    } else {
      return 'Advisory: Favorable weather conditions for most farming activities.';
    }
  }

  String _getWeatherIcon(String condition) {
    switch (condition) {
      case 'Clear':
        return '☀️';
      case 'Clouds':
        return '☁️';
      case 'Rain':
        return '🌧️';
      case 'Drizzle':
        return '🌦️';
      case 'Thunderstorm':
        return '⛈️';
      case 'Snow':
        return '❄️';
      case 'Mist':
      case 'Fog':
        return '🌫️';
      default:
        return '🌤️';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool usingCity = (manualCity != null && manualCity!.trim().isNotEmpty);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row with actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.wb_sunny, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'Weather & Advisory',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Set Location (City)',
                      icon: const Icon(Icons.location_on_outlined),
                      onPressed: onSetCity,
                      iconSize: 20,
                    ),
                    if (usingCity)
                      IconButton(
                        tooltip: 'Clear manual location',
                        icon: const Icon(Icons.close),
                        onPressed: onClearCity,
                        iconSize: 20,
                      ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: onRefresh,
                      iconSize: 20,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Chip(
                  label: Text(
                    usingCity
                        ? 'Location: ${manualCity!}'
                        : 'Location: GPS',
                    style: const TextStyle(fontSize: 12),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                if (weatherData != null && weatherData!['name'] != null)
                  Chip(
                    label: Text(
                      'City: ${weatherData!['name']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (error.isNotEmpty)
              Text('Error: $error', style: const TextStyle(color: Colors.red))
            else if (weatherData != null)
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${weatherData!['name'] ?? '—'}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${_getWeatherIcon((weatherData!['weather'][0]['main'] as String?) ?? '')} ${weatherData!['weather'][0]['main']}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(weatherData!['main']['temp'] as num).round()}°C',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Feels like: ${(weatherData!['main']['feels_like'] as num).round()}°C',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Humidity: ${(weatherData!['main']['humidity'] as num).round()}%'),
                        Text('Wind: ${(weatherData!['wind']['speed'] as num)} m/s'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (weatherData!['coord'] != null && weatherData!['dt'] != null)
                      Text(
                        '(${weatherData!['coord']['lat']}, ${weatherData!['coord']['lon']}) • '
                            '${DateTime.fromMillisecondsSinceEpoch((weatherData!['dt'] as int) * 1000).toLocal()}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    const SizedBox(height: 12),
                  ],
                )
              else
                const Text('No weather data available'),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getWeatherAdvisory(weatherData),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------ Feature Grid ------------------------------ */

class FeatureItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  FeatureItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _FeatureGrid extends StatelessWidget {
  final List<FeatureItem> items;
  const _FeatureGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 3,
      childAspectRatio: 0.78,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: items
          .map(
            (f) => _FeatureTile(
          title: f.title,
          subtitle: f.subtitle,
          icon: f.icon,
          color: f.color,
          onTap: f.onTap,
        ),
      )
          .toList(),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FeatureTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* =======================================================================
   SETTINGS / PROFILE PAGE (unchanged)
   ======================================================================= */

class _ProfileSettingsPage extends StatefulWidget {
  final int userId;
  const _ProfileSettingsPage({required this.userId});

  @override
  State<_ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<_ProfileSettingsPage> {
  final _formKey = GlobalKey<FormState>();

  // Profile fields
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _farmSize = TextEditingController();
  final _machinery = TextEditingController();

  // --- KYC fields ---
  final _aadhaar = TextEditingController();
  String? _govtIdType;
  final _govtIdNumber = TextEditingController();

  bool _loading = false;
  bool _saving = false;
  bool _hasPendingCert = false;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
    _checkPendingCertification();
  }

  Future<Database> _db() async => DBHelper.instance.database;

  Future<void> _ensureTables() async {
    final db = await _db();
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
    await db.execute('''
      CREATE TABLE IF NOT EXISTS certification_requests(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        status TEXT,
        details TEXT,
        created_at TEXT
      );
    ''');

    await _ensureColumn(db, 'user_profiles', 'aadhar_number', 'TEXT');
    await _ensureColumn(db, 'user_profiles', 'govt_id_type', 'TEXT');
    await _ensureColumn(db, 'user_profiles', 'govt_id_number', 'TEXT');
  }

  Future<void> _ensureColumn(Database db, String table, String col, String type) async {
    final cols = await db.rawQuery('PRAGMA table_info($table)');
    final has = cols.any((m) => (m['name'] as String).toLowerCase() == col.toLowerCase());
    if (!has) {
      await db.execute('ALTER TABLE $table ADD COLUMN $col $type;');
    }
  }

  Future<void> _loadExistingProfile() async {
    setState(() => _loading = true);
    await _ensureTables();
    final db = await _db();
    final rows = await db.query(
      'user_profiles',
      where: 'user_id=?',
      whereArgs: [widget.userId],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final m = rows.first;
      _fullName.text = (m['full_name'] ?? '').toString();
      _phone.text = (m['phone'] ?? '').toString();
      _address.text = (m['address'] ?? '').toString();
      _farmSize.text = (m['farm_size'] ?? '').toString();
      _machinery.text = (m['machinery'] ?? '').toString();

      _aadhaar.text = (m['aadhar_number'] ?? '').toString();
      _govtIdType = (m['govt_id_type'] ?? '').toString().isEmpty ? null : (m['govt_id_type']).toString();
      _govtIdNumber.text = (m['govt_id_number'] ?? '').toString();
    }
    setState(() => _loading = false);
  }

  Future<void> _checkPendingCertification() async {
    await _ensureTables();
    final db = await _db();
    final rows = await db.query(
      'certification_requests',
      where: 'user_id=? AND status=?',
      whereArgs: [widget.userId, 'pending'],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    setState(() {
      _hasPendingCert = rows.isNotEmpty;
    });
  }

  bool _validAadhaar(String? s) {
    if (s == null) return false;
    final digits = s.replaceAll(RegExp(r'\D'), '');
    return digits.length == 12;
  }

  bool _hasGovtId() {
    return (_govtIdType != null && _govtIdType!.trim().isNotEmpty) &&
        _govtIdNumber.text.trim().isNotEmpty;
  }

  bool _kycComplete() {
    final baseOk = _fullName.text.trim().isNotEmpty &&
        _phone.text.trim().isNotEmpty &&
        _address.text.trim().isNotEmpty;
    final aadOk = _validAadhaar(_aadhaar.text);
    final govtOk = _hasGovtId();
    return baseOk && (aadOk || govtOk);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await _ensureTables();
    final db = await _db();

    final data = {
      'user_id': widget.userId,
      'full_name': _fullName.text.trim(),
      'phone': _phone.text.trim(),
      'address': _address.text.trim(),
      'farm_size': _farmSize.text.trim(),
      'machinery': _machinery.text.trim(),
      'aadhar_number': _aadhaar.text.trim(),
      'govt_id_type': (_govtIdType ?? '').trim(),
      'govt_id_number': _govtIdNumber.text.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    await db.insert(
      'user_profiles',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    setState(() => _saving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved')),
    );
  }

  Future<void> _requestCertification() async {
    if (!_kycComplete()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete your profile and KYC (Aadhaar OR Govt ID) before requesting certification.'),
        ),
      );
      return;
    }

    if (_hasPendingCert) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Certification already requested (pending).')),
      );
      return;
    }
    await _saveProfile();

    await _ensureTables();
    final db = await _db();

    final details = jsonEncode({
      'full_name': _fullName.text.trim(),
      'phone': _phone.text.trim(),
      'address': _address.text.trim(),
      'farm_size': _farmSize.text.trim(),
      'machinery': _machinery.text.trim(),
      'aadhar_number_masked': _validAadhaar(_aadhaar.text)
          ? 'XXXX-XXXX-${_aadhaar.text.replaceAll(RegExp(r'\\D'), '').substring(8)}'
          : '',
      'govt_id_type': (_govtIdType ?? '').trim(),
      'govt_id_number': _govtIdNumber.text.trim(),
    });

    await db.insert('certification_requests', {
      'user_id': widget.userId,
      'status': 'pending',
      'details': details,
      'created_at': DateTime.now().toIso8601String(),
    });

    setState(() => _hasPendingCert = true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Certification request submitted for admin review')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings / Profile'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _SettingsSection(
                  title: 'Personal',
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _fullName,
                        decoration: const InputDecoration(
                          labelText: 'Full name*',
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
                          labelText: 'Phone*',
                          border: OutlineInputBorder(),
                        ),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]'))],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (v.replaceAll(RegExp(r'\\D'), '').length < 8) return 'Too short';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _address,
                        decoration: const InputDecoration(
                          labelText: 'Address*',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                        validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  title: 'Identity (KYC)',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _aadhaar,
                        decoration: const InputDecoration(
                          labelText: 'Aadhaar Number (12 digits)',
                          border: OutlineInputBorder(),
                          helperText: 'Provide Aadhaar OR a Government ID below',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
                        validator: (v) {
                          final digits = (v ?? '').replaceAll(RegExp(r'\\D'), '');
                          if (digits.isEmpty) return null;
                          return digits.length == 12 ? null : 'Must be exactly 12 digits';
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _govtIdType,
                              decoration: const InputDecoration(
                                labelText: 'Govt ID Type',
                                border: OutlineInputBorder(),
                              ),
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(value: 'PAN', child: Text('PAN')),
                                DropdownMenuItem(value: 'Voter ID', child: Text('Voter ID')),
                                DropdownMenuItem(value: 'Driving License', child: Text('Driving License')),
                                DropdownMenuItem(value: 'Passport', child: Text('Passport')),
                                DropdownMenuItem(value: 'Ration Card', child: Text('Ration Card')),
                                DropdownMenuItem(value: 'Other', child: Text('Other')),
                              ],
                              onChanged: (v) => setState(() => _govtIdType = v),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _govtIdNumber,
                              decoration: const InputDecoration(
                                labelText: 'Govt ID Number',
                                border: OutlineInputBorder(),
                              ),
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]'))],
                              validator: (v) {
                                final hasType = _govtIdType != null && _govtIdType!.trim().isNotEmpty;
                                final hasNum = (v ?? '').trim().isNotEmpty;
                                if (!hasType && !hasNum) return null;
                                if (hasType && !hasNum) return 'Enter ID number';
                                if ((_govtIdType ?? '') == 'PAN') {
                                  final panOk = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch((v ?? '').toUpperCase());
                                  if (!panOk) return 'Invalid PAN format';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (_) {
                          final kycOk = _kycComplete();
                          return Row(
                            children: [
                              Icon(
                                kycOk ? Icons.verified_user : Icons.error_outline,
                                color: kycOk ? Colors.green : Colors.orange,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                kycOk
                                    ? 'KYC complete'
                                    : 'KYC incomplete (need Aadhaar OR Govt ID)',
                                style: TextStyle(
                                  color: kycOk ? Colors.green[700] : Colors.orange[700],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  title: 'Farm & Equipment',
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _farmSize,
                        decoration: const InputDecoration(
                          labelText: 'Farm size (acres/hectares)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _machinery,
                        decoration: const InputDecoration(
                          labelText: 'Machinery (comma separated)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: _saving
                        ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.save_outlined),
                    onPressed: _saving ? null : _saveProfile,
                    label: const Text('Save Profile'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.verified_user_outlined),
                    onPressed: _hasPendingCert ? null : _requestCertification,
                    label: Text(
                      _hasPendingCert
                          ? 'Certification Request: Pending'
                          : 'Request Certification Review',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'After you submit, an admin can review your profile and mark your equipment as "Certified".',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _SettingsSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.manage_accounts_outlined),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
