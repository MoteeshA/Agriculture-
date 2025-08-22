// lib/screens/crop_prices.dart
import 'dart:async';
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
  // ---- API ----
  static const String apiKey =
      '579b464db66ec23bdd0000010baed15d539144fa62035eb3cd19e551';

  // Try these in order. We start with the active VARIETY-WISE resource; if it
  // returns 0 or an error payload, we automatically fall back to the older one.
  static const List<String> _baseUrls = [
    // 1) Variety-wise Daily Market Prices Data of Commodity (ACTIVE)
    'https://api.data.gov.in/resource/35985678-0d79-46b4-9ed6-6f13308a1d24',
    // 2) Current Daily Price of Various Commodities (fallback; sometimes empty)
    'https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070',
  ];
  int _baseIdx = 0;

  String get _baseUrl => _baseUrls[_baseIdx];

  // ---- Data ----
  final List<dynamic> _records = [];
  bool _loading = true;
  String _error = '';
  int _offset = 0;
  static const int _pageSize = 500;
  bool _hasMoreServer = true;

  // ---- Filters ----
  String selectedState = '';
  String selectedDistrict = '';
  String selectedMarket = '';
  String selectedCommodity = '';

  DateTime? fromDate;
  DateTime? toDate;

  // If true, when date filter yields 0 results, show data ignoring date range.
  bool autoIgnoreDateWhenEmpty = true;
  bool _showingFallbackNoDate = false;

  // options
  List<String> states = [];
  List<String> districts = [];
  List<String> markets = [];
  List<String> commodities = [];

  // search
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  // sort
  String sortField = 'Market';
  bool sortAscending = true;

  @override
  void initState() {
    super.initState();
    _resetAndFetch();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ===== networking =====
  Future<void> _resetAndFetch() async {
    setState(() {
      _records.clear();
      _offset = 0;
      _hasMoreServer = true;
      _error = '';
      _loading = true;
      _showingFallbackNoDate = false;
      _baseIdx = 0; // always start from the primary resource
    });
    await _fetch();
  }

  Future<void> _fetch({bool append = true}) async {
    if (!_hasMoreServer) {
      setState(() => _loading = false);
      return;
    }

    try {
      final qp = <String, String>{
        'api-key': apiKey,
        'format': 'json',
        'limit': '$_pageSize',
        'offset': '$_offset',
      };

      // Only use equality filters the API reliably supports.
      if (selectedState.isNotEmpty) qp['filters[state]'] = selectedState;
      if (selectedDistrict.isNotEmpty) qp['filters[district]'] = selectedDistrict;
      if (selectedMarket.isNotEmpty) qp['filters[market]'] = selectedMarket;
      if (selectedCommodity.isNotEmpty) qp['filters[commodity]'] = selectedCommodity;

      // ⚠️ DO NOT send date filters server-side (often returns 0).
      // Client-side date filter is applied below in _filteredSorted.

      final uri = Uri.parse(_baseUrl).replace(queryParameters: qp);
      final res = await http.get(uri);

      if (!mounted) return;

      if (res.statusCode != 200) {
        // Try the next dataset if available
        final canFallback = _trySwitchDatasetOnFailure(
          reason: 'HTTP ${res.statusCode}',
          firstPage: _offset == 0 && _records.isEmpty,
        );
        if (canFallback) return;
        setState(() {
          _error = 'Failed: HTTP ${res.statusCode}';
          _loading = false;
        });
        return;
      }

      final body = json.decode(res.body) as Map<String, dynamic>;
      final List<dynamic> recs = (body['records'] as List?) ?? [];

      // When API returns a misleading payload with message, catch it early
      final msg = (body['message'] ?? '').toString().toLowerCase();
      if ((recs.isEmpty) &&
          (msg.contains('resource id doesn\'t exist') ||
              msg.contains('not exist') ||
              msg.contains('error'))) {
        final canFallback = _trySwitchDatasetOnFailure(
          reason: 'Gateway message: ${body['message']}',
          firstPage: _offset == 0 && _records.isEmpty,
        );
        if (canFallback) return;
      }

      if (append) {
        _records.addAll(recs);
      } else {
        _records
          ..clear()
          ..addAll(recs);
      }

      // If first page is empty, try fallback dataset automatically
      if (recs.isEmpty && _offset == 0 && _records.isEmpty) {
        final canFallback = _trySwitchDatasetOnFailure(
          reason: '0 rows from current dataset',
          firstPage: true,
        );
        if (canFallback) return;
      }

      _hasMoreServer = recs.length >= _pageSize;
      if (_hasMoreServer) _offset += _pageSize;

      // rebuild options from whatever we have so far
      states = _uniqueOf(_records, 'state');
      districts = _uniqueOf(
        _records.where((r) => (r['state'] ?? '') == selectedState).toList(),
        'district',
      );
      markets = _uniqueOf(
        _records.where((r) =>
        (r['state'] ?? '') == selectedState &&
            (r['district'] ?? '') == selectedDistrict)
            .toList(),
        'market',
      );
      commodities = _uniqueOf(_records, 'commodity');

      setState(() => _loading = false);
    } catch (e) {
      // Network/parse errors: attempt fallback at first page
      final canFallback = _trySwitchDatasetOnFailure(
        reason: 'Exception: $e',
        firstPage: _offset == 0 && _records.isEmpty,
      );
      if (canFallback) return;

      setState(() {
        _error = 'Error: $e';
        _loading = false;
      });
    }
  }

  bool _trySwitchDatasetOnFailure({required String reason, required bool firstPage}) {
    if (!firstPage) return false;
    if (_baseIdx + 1 < _baseUrls.length) {
      _baseIdx += 1;
      _offset = 0;
      _hasMoreServer = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Primary dataset unavailable ($reason). Switching to fallback source…',
          ),
        ),
      );
      // fire-and-forget next fetch
      _fetch();
      return true;
    }
    return false;
  }

  // ===== helpers =====
  List<String> _uniqueOf(List<dynamic> list, String field) {
    final s = <String>{};
    for (final r in list) {
      final v = r[field]?.toString().trim();
      if (v != null && v.isNotEmpty) s.add(v);
    }
    final out = s.toList()..sort();
    return out;
  }

  String _fmtDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd/$mm/$yy';
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _parseDate(String ddmmyyyy) {
    final p = ddmmyyyy.split('/');
    if (p.length != 3) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
  }

  bool _withinDateRange(dynamic r) {
    if (fromDate == null && toDate == null) return true;
    final s = (r['arrival_date'] ?? '').toString();
    if (s.isEmpty) return false;
    final d = _parseDate(s);

    if (fromDate != null && toDate == null) {
      final start = DateTime(fromDate!.year, fromDate!.month, fromDate!.day);
      return !d.isBefore(start);
    }
    if (fromDate == null && toDate != null) {
      final end = DateTime(toDate!.year, toDate!.month, toDate!.day, 23, 59, 59);
      return !d.isAfter(end);
    }
    final start = DateTime(fromDate!.year, fromDate!.month, fromDate!.day);
    final end = DateTime(toDate!.year, toDate!.month, toDate!.day, 23, 59, 59);
    return (d.isAfter(start) || _isSameDate(d, start)) &&
        (d.isBefore(end) || _isSameDate(d, end));
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() {});
    });
  }

  num _toNum(dynamic v) => num.tryParse((v ?? '').toString()) ?? 0;

  // ===== derived (filter + sort + smart fallback) =====
  List<dynamic> get _filteredSorted {
    _showingFallbackNoDate = false;

    List<dynamic> base = _records;

    // typed text filter
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      base = base.where((r) {
        final hay = [
          r['commodity'],
          r['market'],
          r['district'],
          r['state'],
          r['variety'],
          r['grade'],
        ].map((e) => (e ?? '').toString().toLowerCase()).join(' ');
        return hay.contains(q);
      }).toList();
    }

    // dropdown filters
    base = base.where((r) {
      final sOk = selectedState.isEmpty || (r['state'] ?? '') == selectedState;
      final dOk =
          selectedDistrict.isEmpty || (r['district'] ?? '') == selectedDistrict;
      final mOk = selectedMarket.isEmpty || (r['market'] ?? '') == selectedMarket;
      final cOk = selectedCommodity.isEmpty ||
          (r['commodity'] ?? '') == selectedCommodity;
      return sOk && dOk && mOk && cOk;
    }).toList();

    // date range filter (client-side)
    List<dynamic> withDate = base.where(_withinDateRange).toList();

    // smart fallback: if no rows and a date range is set, ignore date
    if (withDate.isEmpty && (fromDate != null || toDate != null) && autoIgnoreDateWhenEmpty) {
      withDate = base;
      _showingFallbackNoDate = true;
    }

    // sort
    withDate.sort((a, b) {
      int res = 0;
      switch (sortField) {
        case 'Market':
          res = (a['market'] ?? '').toString().compareTo((b['market'] ?? '').toString());
          break;
        case 'Commodity':
          res = (a['commodity'] ?? '').toString().compareTo((b['commodity'] ?? '').toString());
          break;
        case 'District':
          res = (a['district'] ?? '').toString().compareTo((b['district'] ?? '').toString());
          break;
        case 'State':
          res = (a['state'] ?? '').toString().compareTo((b['state'] ?? '').toString());
          break;
        case 'Arrival Date':
          res = _parseDate((a['arrival_date'] ?? '').toString())
              .compareTo(_parseDate((b['arrival_date'] ?? '').toString()));
          break;
        case 'Min Price':
          res = _toNum(a['min_price']).compareTo(_toNum(b['min_price']));
          break;
        case 'Max Price':
          res = _toNum(a['max_price']).compareTo(_toNum(b['max_price']));
          break;
        case 'Modal Price':
          res = _toNum(a['modal_price']).compareTo(_toNum(b['modal_price']));
          break;
      }
      return sortAscending ? res : -res;
    });

    return withDate;
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Variety-wise Daily Market Prices'),
        actions: [
          IconButton(onPressed: _resetAndFetch, icon: const Icon(Icons.refresh))
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _resetAndFetch,
        child: Column(
          children: [
            _filtersCard(scheme),
            _sortRow(scheme),
            if (_showingFallbackNoDate)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'No rows for the selected date range. Showing latest available data for your filters.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _loading && _records.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _error.isNotEmpty
                  ? _errorBox()
                  : _filteredSorted.isEmpty
                  ? const Center(child: Text('No data found'))
                  : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount:
                _filteredSorted.length + (_hasMoreServer ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_hasMoreServer &&
                      index == _filteredSorted.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: _loading
                            ? const CircularProgressIndicator()
                            : OutlinedButton.icon(
                          onPressed: () => _fetch(),
                          icon: const Icon(Icons.expand_more),
                          label: const Text('Load more'),
                        ),
                      ),
                    );
                  }
                  final r = _filteredSorted[index];
                  return _PriceCard(record: r);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBox() => Center(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          FilledButton(onPressed: _resetAndFetch, child: const Text('Retry')),
        ],
      ),
    ),
  );

  Widget _filtersCard(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Column(
        children: [
          // search
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search commodity / market / district / state',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() {});
                },
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),

          // cascading dropdowns
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _dd(
                  hint: 'State',
                  value: selectedState.isEmpty ? null : selectedState,
                  items: [''] + states,
                  onChanged: (v) {
                    selectedState = (v ?? '');
                    selectedDistrict = '';
                    selectedMarket = '';
                    _resetAndFetch();
                  },
                ),
                const SizedBox(width: 8),
                _dd(
                  hint: 'District',
                  value: selectedDistrict.isEmpty ? null : selectedDistrict,
                  items: [''] + districts,
                  onChanged: (v) {
                    selectedDistrict = (v ?? '');
                    selectedMarket = '';
                    _resetAndFetch();
                  },
                ),
                const SizedBox(width: 8),
                _dd(
                  hint: 'Market',
                  value: selectedMarket.isEmpty ? null : selectedMarket,
                  items: [''] + markets,
                  onChanged: (v) {
                    selectedMarket = (v ?? '');
                    _resetAndFetch();
                  },
                ),
                const SizedBox(width: 8),
                _dd(
                  hint: 'Commodity',
                  value: selectedCommodity.isEmpty ? null : selectedCommodity,
                  items: [''] + commodities,
                  onChanged: (v) {
                    selectedCommodity = (v ?? '');
                    _resetAndFetch();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // date range + clear + count
          Row(
            children: [
              FilledButton.icon(
                onPressed: _pickFromDate,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(fromDate == null ? 'From' : _fmtDate(fromDate!)),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _pickToDate,
                icon: const Icon(Icons.calendar_month, size: 18),
                label: Text(toDate == null ? 'To' : _fmtDate(toDate!)),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Clear dates',
                onPressed: () {
                  setState(() {
                    fromDate = null;
                    toDate = null;
                    _showingFallbackNoDate = false;
                  });
                },
                icon: const Icon(Icons.clear),
              ),
              const Spacer(),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withOpacity(.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_filteredSorted.length} results',
                  style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sortRow(ColorScheme scheme) {
    const fields = <String>[
      'Market',
      'Commodity',
      'District',
      'State',
      'Arrival Date',
      'Min Price',
      'Max Price',
      'Modal Price',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Row(
        children: [
          const Text('Sort By:'),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: sortField,
            items: fields
                .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                .toList(),
            onChanged: (v) => setState(() => sortField = v ?? 'Market'),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: sortAscending ? 'Ascending' : 'Descending',
            onPressed: () => setState(() => sortAscending = !sortAscending),
            icon: Icon(sortAscending
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final res = await showDatePicker(
      context: context,
      initialDate: fromDate ?? now,
      firstDate: DateTime(now.year - 15),
      lastDate: now,
    );
    if (res != null) {
      setState(() => fromDate = res);
      await _resetAndFetch();
    }
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final res = await showDatePicker(
      context: context,
      initialDate: toDate ?? fromDate ?? now,
      firstDate: DateTime(now.year - 15),
      lastDate: now,
    );
    if (res != null) {
      setState(() => toDate = res);
      await _resetAndFetch();
    }
  }

  Widget _dd({
    required String hint,
    required List<String> items,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isDense: true,
          value: value,
          hint: Text(hint),
          items: items
              .map((e) => DropdownMenuItem<String>(
            value: e.isEmpty ? '' : e,
            child: e.isEmpty ? Text('All $hint') : Text(e),
          ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ===== card =====
class _PriceCard extends StatelessWidget {
  final dynamic record;
  const _PriceCard({required this.record});

  @override
  Widget build(BuildContext context) {
    String _s(String k, [String d = 'N/A']) =>
        (record[k]?.toString().trim().isNotEmpty ?? false)
            ? record[k].toString()
            : d;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_s('commodity', 'Unknown Commodity'),
                style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('${_s('market', 'Unknown')}, ${_s('district')} , ${_s('state')}',
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _chip('Min', _s('min_price')),
                _chip('Max', _s('max_price')),
                _chip('Avg', _s('modal_price')),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _kv('Variety', _s('variety')),
                _kv('Grade', _s('grade')),
                _kv('Date', _s('arrival_date')),
                _kv('Code', _s('commodity_code', '-')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String v) =>
      Chip(label: Text('$label: ₹$v'), visualDensity: VisualDensity.compact);

  Widget _kv(String k, String v) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$k: ', style: const TextStyle(fontWeight: FontWeight.w600)),
      Text(v),
    ],
  );
}
