import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CropPricesPage extends StatefulWidget {
  static const route = '/crop-prices';
  const CropPricesPage({super.key});

  @override
  State<CropPricesPage> createState() => _CropPricesPageState();
}

class _CropPricesPageState extends State<CropPricesPage> {
  // ====== CONFIG ======
  static const String apiKey =
      '579b464db66ec23bdd0000010baed15d539144fa62035eb3cd19e551';
  static const String baseUrl =
      'https://api.data.gov.in/resource/35985678-0d79-46b4-9ed6-6f13308a1d24';

  // ====== UI STATE ======
  final _commodityCtrl = TextEditingController(text: 'Tomato');
  final _stateCtrl = TextEditingController();  // e.g., Karnataka
  final _marketCtrl = TextEditingController(); // e.g., Binny Mill (F&V), Bangalore
  DateTime? _selectedDate;

  bool _loading = false;
  String _error = '';
  List<PriceRecord> _records = [];

  List<DailyPoint> _dailySeries = [];    // aggregated by date
  List<DailyPoint> _forecastNext7 = [];  // 7-day forecast

  // ====== DATE HELPERS (no intl) ======
  String _two(int x) => x < 10 ? '0$x' : '$x';

  /// API wants dd/MM/yyyy
  String _fmtApiDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

  /// UI shows yyyy-MM-dd
  String _fmtUiDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  /// Parse dd/MM/yyyy
  DateTime _parseApiDate(String s) {
    try {
      final p = s.split('/');
      if (p.length == 3) {
        final d = int.parse(p[0]);
        final m = int.parse(p[1]);
        final y = int.parse(p[2]);
        return DateTime(y, m, d);
      }
    } catch (_) {}
    return DateTime.now();
  }

  @override
  void dispose() {
    _commodityCtrl.dispose();
    _stateCtrl.dispose();
    _marketCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchAll(); // initial load
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2006, 1, 1),
      lastDate: now,
    );
    if (!mounted) return;
    setState(() => _selectedDate = picked);
  }

  Future<void> _clearDate() async {
    setState(() => _selectedDate = null);
  }

  Future<void> _fetchAll() async {
    setState(() {
      _loading = true;
      _error = '';
      _records = [];
      _dailySeries = [];
      _forecastNext7 = [];
    });

    try {
      // fetch a couple of pages to have enough data for trend
      const int pageLimit = 200;
      const int maxPages = 2;

      for (int i = 0; i < maxPages; i++) {
        final page = await _fetchPage(limit: pageLimit, offset: i * pageLimit);
        if (page.isEmpty) break;
        _records.addAll(page);
        if (page.length < pageLimit) break;
      }

      // newest first
      _records.sort((a, b) => b.arrivalDate.compareTo(a.arrivalDate));

      if (_records.isEmpty) {
        setState(() {
          _error =
          'No records returned. Try another commodity/state/market or clear the date filter.';
        });
      } else {
        _dailySeries = _aggregateDaily(_records);
        _forecastNext7 = _buildForecast(_dailySeries, nextDays: 7, lookback: 10);
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// One page from Data.gov.in with filters & sorting
  Future<List<PriceRecord>> _fetchPage({int limit = 200, int offset = 0}) async {
    final params = <String, String>{
      'api-key': apiKey,
      'format': 'json',
      'limit': '$limit',
      'offset': '$offset',
      'sort[Arrival_Date]': 'desc',
    };

    final commodity = _commodityCtrl.text.trim();
    final state = _stateCtrl.text.trim();
    final market = _marketCtrl.text.trim();

    if (commodity.isNotEmpty) params['filters[Commodity]'] = commodity;
    if (state.isNotEmpty) params['filters[State]'] = state;
    if (market.isNotEmpty) params['filters[Market]'] = market;
    if (_selectedDate != null) params['filters[Arrival_Date]'] = _fmtApiDate(_selectedDate!);

    final uri = Uri.parse(baseUrl).replace(queryParameters: params);
    final res = await http.get(uri).timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final body = json.decode(res.body) as Map<String, dynamic>;
    final count = (body['count'] ?? 0) as int;
    final msg = (body['message'] ?? '').toString();

    // Sometimes 200 + misleading "Resource id doesn't exist."
    if (count == 0 && msg.toLowerCase().contains('resource id')) {
      return <PriceRecord>[];
    }

    final recs = (body['records'] ?? []) as List;
    final out = <PriceRecord>[];
    for (final r in recs) {
      try {
        out.add(PriceRecord.fromJson(r as Map<String, dynamic>, parseDate: _parseApiDate));
      } catch (_) {}
    }
    return out;
  }

  /// Aggregate by date → average modal price
  List<DailyPoint> _aggregateDaily(List<PriceRecord> records) {
    final map = <DateTime, List<double>>{};
    for (final r in records) {
      final d = DateTime(r.arrivalDate.year, r.arrivalDate.month, r.arrivalDate.day);
      map.putIfAbsent(d, () => []).add(r.modalPrice.toDouble());
    }
    final days = map.keys.toList()..sort();
    return [for (final d in days) DailyPoint(date: d, value: _avg(map[d]!))];
  }

  double _avg(List<double> xs) =>
      xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

  /// Simple linear regression on last [lookback] daily points → next [nextDays]
  List<DailyPoint> _buildForecast(
      List<DailyPoint> series, {
        int nextDays = 7,
        int lookback = 10,
      }) {
    if (series.length < 3) return [];
    final tail = series.length > lookback
        ? series.sublist(series.length - lookback)
        : List<DailyPoint>.from(series);

    final n = tail.length;
    final xs = List<double>.generate(n, (i) => i.toDouble());
    final ys = tail.map((e) => e.value).toList();

    double sum(List<double> a) => a.fold(0.0, (p, c) => p + c);

    final sumX = sum(xs);
    final sumY = sum(ys);
    final sumXX = sum(xs.map((x) => x * x).toList());
    final sumXY = sum([for (int i = 0; i < n; i++) xs[i] * ys[i]]);

    final denom = (n * sumXX - sumX * sumX);
    if (denom == 0) return [];

    final a = (sumY * sumXX - sumX * sumXY) / denom; // intercept
    final b = (n * sumXY - sumX * sumY) / denom;     // slope

    final lastDate = series.last.date;
    final future = <DailyPoint>[];
    for (int i = 1; i <= nextDays; i++) {
      final t = xs.last + i;
      double y = a + b * t;
      if (y < 0) y = 0;
      future.add(DailyPoint(date: lastDate.add(Duration(days: i)), value: y));
    }
    return future;
  }

  // ====== UI ======
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Crop Prices')),
      body: SafeArea(
        child: Column(
          children: [
            _FilterBar(
              commodityCtrl: _commodityCtrl,
              stateCtrl: _stateCtrl,
              marketCtrl: _marketCtrl,
              selectedDate: _selectedDate,
              onPickDate: _pickDate,
              onClearDate: _clearDate,
              onSearch: _fetchAll,
              loading: _loading,
              fmtUiDate: _fmtUiDate,
            ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error, style: TextStyle(color: theme.colorScheme.error)),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _records.isEmpty
                  ? const Center(child: Text('No data'))
                  : _ResultsAndForecast(
                records: _records,
                daily: _dailySeries,
                forecast: _forecastNext7,
                fmtUiDate: _fmtUiDate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================== MODELS ============================== */

class PriceRecord {
  final String state;
  final String district;
  final String market;
  final String commodity;
  final String variety;
  final String grade;
  final DateTime arrivalDate;
  final int minPrice;
  final int maxPrice;
  final int modalPrice;
  final String? remarks;

  PriceRecord({
    required this.state,
    required this.district,
    required this.market,
    required this.commodity,
    required this.variety,
    required this.grade,
    required this.arrivalDate,
    required this.minPrice,
    required this.maxPrice,
    required this.modalPrice,
    this.remarks,
  });

  factory PriceRecord.fromJson(
      Map<String, dynamic> j, {
        required DateTime Function(String) parseDate,
      }) {
    final dateStr = (j['Arrival_Date'] ?? j['arrival_date'] ?? '').toString();

    int _toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      final s = v.toString().trim();
      return int.tryParse(s) ?? 0;
    }

    return PriceRecord(
      state: (j['State'] ?? '').toString(),
      district: (j['District'] ?? '').toString(),
      market: (j['Market'] ?? '').toString(),
      commodity: (j['Commodity'] ?? '').toString(),
      variety: (j['Variety'] ?? '').toString(),
      grade: (j['Grade'] ?? '').toString(),
      arrivalDate: parseDate(dateStr),
      minPrice: _toInt(j['Min_Price']),
      maxPrice: _toInt(j['Max_Price']),
      modalPrice: _toInt(j['Modal_Price']),
      remarks: j['Remarks']?.toString(),
    );
  }
}

class DailyPoint {
  final DateTime date;
  final double value;
  DailyPoint({required this.date, required this.value});
}

/* ============================ WIDGETS ============================ */

class _FilterBar extends StatelessWidget {
  final TextEditingController commodityCtrl;
  final TextEditingController stateCtrl;
  final TextEditingController marketCtrl;
  final DateTime? selectedDate;
  final VoidCallback onSearch;
  final VoidCallback onClearDate;
  final Future<void> Function() onPickDate;
  final bool loading;
  final String Function(DateTime) fmtUiDate;

  const _FilterBar({
    required this.commodityCtrl,
    required this.stateCtrl,
    required this.marketCtrl,
    required this.selectedDate,
    required this.onPickDate,
    required this.onClearDate,
    required this.onSearch,
    required this.loading,
    required this.fmtUiDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String dateLabel =
    selectedDate == null ? 'Any date' : 'Date: ${fmtUiDate(selectedDate!)}';

    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            _SmallField(label: 'Commodity', controller: commodityCtrl, hint: 'e.g., Tomato'),
            _SmallField(label: 'State', controller: stateCtrl, hint: 'e.g., Karnataka'),
            _SmallField(
              label: 'Market',
              controller: marketCtrl,
              hint: 'e.g., Binny Mill (F&V), Bangalore',
              width: 260,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(dateLabel, style: theme.textTheme.bodyMedium),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: loading ? null : onPickDate,
                  icon: const Icon(Icons.date_range),
                  label: const Text('Pick'),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: loading ? null : onClearDate,
                  child: const Text('Clear'),
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: loading ? null : onSearch,
              icon: const Icon(Icons.search),
              label: const Text('Search'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final double width;

  const _SmallField({
    required this.label,
    required this.controller,
    this.hint,
    this.width = 180,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }
}

class _ResultsAndForecast extends StatelessWidget {
  final List<PriceRecord> records;
  final List<DailyPoint> daily;
  final List<DailyPoint> forecast;
  final String Function(DateTime) fmtUiDate;

  const _ResultsAndForecast({
    required this.records,
    required this.daily,
    required this.forecast,
    required this.fmtUiDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Latest Market Data (${records.length} rows)',
              style:
              theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('State')),
                  DataColumn(label: Text('District')),
                  DataColumn(label: Text('Market')),
                  DataColumn(label: Text('Commodity')),
                  DataColumn(label: Text('Variety')),
                  DataColumn(label: Text('Min')),
                  DataColumn(label: Text('Max')),
                  DataColumn(label: Text('Modal')),
                ],
                rows: [
                  for (final r in records)
                    DataRow(cells: [
                      DataCell(Text(fmtUiDate(r.arrivalDate))),
                      DataCell(Text(r.state)),
                      DataCell(Text(r.district)),
                      DataCell(Text(r.market)),
                      DataCell(Text(r.commodity)),
                      DataCell(Text(r.variety)),
                      DataCell(Text('₹${r.minPrice}')),
                      DataCell(Text('₹${r.maxPrice}')),
                      DataCell(Text(
                        '₹${r.modalPrice}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      )),
                    ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Price Trend (Daily Avg. Modal) & 7-Day Forecast',
              style:
              theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          if (daily.isEmpty)
            const Text(
              'Not enough daily data to compute a trend. Try removing filters or fetching more rows.',
            )
          else
            _ForecastBlock(daily: daily, forecast: forecast, fmtUiDate: fmtUiDate),
        ],
      ),
    );
  }
}

class _ForecastBlock extends StatelessWidget {
  final List<DailyPoint> daily;
  final List<DailyPoint> forecast;
  final String Function(DateTime) fmtUiDate;

  const _ForecastBlock({
    required this.daily,
    required this.forecast,
    required this.fmtUiDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final histTail = daily.length > 10 ? daily.sublist(daily.length - 10) : daily;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _MiniList(
                    title: 'Recent Daily Avg (Modal)',
                    items: [
                      for (final p in histTail)
                        '${fmtUiDate(p.date)}  —  ₹${p.value.toStringAsFixed(0)}',
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniList(
                    title: 'Forecast (Next 7 days)',
                    items: forecast.isEmpty
                        ? ['Insufficient data for forecast']
                        : [
                      for (final f in forecast)
                        '${fmtUiDate(f.date)}  —  ₹${f.value.toStringAsFixed(0)}'
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Forecast uses a simple linear trend over the last ~10 daily points (no seasonality).',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniList extends StatelessWidget {
  final String title;
  final List<String> items;

  const _MiniList({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
            theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...items.map(
              (s) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(s),
          ),
        ),
      ],
    );
  }
}
