import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

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

  // ---------------- Market ticker state ----------------
  // Uses data.gov.in (same resource as your CropPricesPage)
  static const String _govApiKey =
      '579b464db66ec23bdd0000010baed15d539144fa62035eb3cd19e551';
  static const String _resourceUrl =
      'https://api.data.gov.in/resource/35985678-0d79-46b4-9ed6-6f13308a1d24';

  // Show these on the dashboard ticker row
  final List<String> _dashboardCommodities = const [
    'Wheat',
    'Rice',
    'Cotton',
    'Soybean',
  ];

  // Pin to a region (optional)
  final String? _pinState = null;  // e.g., 'Karnataka'
  final String? _pinMarket = null; // e.g., 'Binny Mill (F&V), Bangalore'

  bool _isLoadingTickers = false;
  String _tickerError = '';
  List<_MarketTicker> _tickers = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocationWeather();
    _loadMarketTickers();
  }

  // ---------------- Weather ----------------
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

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
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

    // Read optional args from Navigator for display name/email/userId
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

    // Fallback: email local-part → else "Farmer"
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile coming soon')),
                  );
                  break;
                case 'refresh':
                  _getCurrentLocationWeather();
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
              PopupMenuItem(value: 'profile', child: Text('Profile')),
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
              // Welcome Card
              _WelcomeCard(friendlyName: friendlyName),
              const SizedBox(height: 20),

              // Quick Stats Row (now dynamic)
              _QuickStatsRow(
                wheatPrice: wheat,
                temperatureC: tempC,
                windKmh: windKmh,
              ),
              const SizedBox(height: 20),

              // Main Features Grid
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
                    // ✅ Pass userId + displayName so rent shows correct lists
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
                    onTap: () =>
                        DashboardPage._todo(context, 'Crop Disease Detection'),
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
                    onTap: () =>
                        DashboardPage._todo(context, 'Government Schemes'),
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

              // Weather & Advisory Section - uses real data
              _WeatherAdvisoryCard(
                weatherData: _weatherData,
                isLoading: _isLoadingWeather,
                error: _weatherError,
                onRefresh: _getCurrentLocationWeather,
              ),
              const SizedBox(height: 20),

              // Market Updates
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
  final double? changePct; // positive/negative if previous found
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
      padding: const EdgeInsets.all(10), // tighter padding to avoid tiny overflow
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
              t.date, // dd/MM/yyyy from API
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
              // ✅ Drawer also navigates to rent.dart with user context
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
              onTap: () =>
                  DashboardPage._todo(context, 'Crop Disease Detection'),
            ),
            ListTile(
              leading: const Icon(Icons.assignment_turned_in_outlined),
              title: const Text('Govt Schemes'),
              onTap: () => DashboardPage._todo(context, 'Government Schemes'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () => DashboardPage._todo(context, 'Settings'),
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
  final int? wheatPrice;     // INR per modal price (latest)
  final int? temperatureC;   // from OWM
  final double? windKmh;     // from OWM (converted)

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

  const _WeatherAdvisoryCard({
    required this.weatherData,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: onRefresh,
                  iconSize: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),

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
