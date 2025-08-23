// lib/screens/govt.dart
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class GovtPage extends StatelessWidget {
  static const route = '/govt';
  const GovtPage({super.key});

  // Official sources
  static final _sources = <_LinkItem>[
    _LinkItem(
      title: 'PIB: Press Releases (English)',
      subtitle: 'Official Government of India press releases',
      url: 'https://pib.gov.in/Allrel.aspx',
    ),
    _LinkItem(
      title: 'MoAFW: Major Schemes',
      subtitle: 'Ministry of Agriculture & Farmers Welfare',
      url: 'https://agriwelfare.gov.in/en/Major',
    ),
  ];

  // Popular central schemes (official pages)
  static final _schemes = <_LinkItem>[
    _LinkItem(
      title: 'PM-KISAN',
      subtitle: 'Pradhan Mantri Kisan Samman Nidhi',
      url: 'https://pmkisan.gov.in/',
      code: 'PMKISAN',
    ),
    _LinkItem(
      title: 'PMFBY',
      subtitle: 'Pradhan Mantri Fasal Bima Yojana (Crop Insurance)',
      url: 'https://pmfby.gov.in/',
      code: 'PMFBY',
    ),
    _LinkItem(
      title: 'Agri Infrastructure Fund (AIF)',
      subtitle: 'Financing facility for agri infra projects',
      url: 'https://www.agriinfra.dac.gov.in/',
      code: 'AIF',
    ),
    _LinkItem(
      title: 'Kisan Credit Card (KCC)',
      subtitle: 'Credit support to farmers',
      url: 'https://www.myscheme.gov.in/schemes/kcc',
      code: 'KCC',
    ),
    _LinkItem(
      title: 'e-NAM',
      subtitle: 'National Agriculture Market',
      url: 'https://www.enam.gov.in/web/',
      code: 'ENAM',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Government Schemes'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Browse'),
              Tab(text: 'Find Schemes'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              // -------- TAB 1: Browse (links) --------
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Header(
                    icon: Icons.assignment_turned_in_outlined,
                    title: 'Official Sources',
                    subtitle:
                    'Browse trusted government pages for the latest updates and scheme details.',
                  ),
                  const SizedBox(height: 8),
                  ..._sources.map((e) => _LinkTile(item: e)),

                  const SizedBox(height: 20),
                  _Header(
                    icon: Icons.account_balance_outlined,
                    title: 'Popular Central Schemes',
                    subtitle:
                    'These are commonly used schemes. Eligibility varies—check the official site.',
                  ),
                  const SizedBox(height: 8),
                  ..._schemes.map((e) => _LinkTile(item: e)),

                  const SizedBox(height: 20),
                  Card(
                    elevation: 0,
                    color: Colors.amber[50],
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Heads-up: Scheme pages sometimes move. If a link doesn’t open, try again later or search the scheme name on the official site.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // -------- TAB 2: Find Schemes (form + recommendations) --------
              _SchemeFinder(allSchemes: _schemes),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------------- Helper widgets/types -------------------------- */

class _Header extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Header({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _LinkItem {
  final String title;
  final String subtitle;
  final String url;
  final String? code;
  const _LinkItem({
    required this.title,
    required this.subtitle,
    required this.url,
    this.code,
  });
}

class _LinkTile extends StatelessWidget {
  final _LinkItem item;
  const _LinkTile({required this.item});

  Uri _forceHttps(Uri u) {
    if (u.scheme.isEmpty) {
      return Uri.parse('https://${u.toString()}');
    }
    if (u.scheme == 'http') {
      return u.replace(scheme: 'https');
    }
    return u;
  }

  /// Try to build a Chrome-specific URI:
  /// - Android: googlechrome://navigate?url=<ENCODED_URL>
  /// - iOS:     googlechromes:// for https, googlechrome:// for http
  Uri? _chromeUriFrom(Uri httpsUri) {
    try {
      if (Platform.isAndroid) {
        final encoded = Uri.encodeComponent(httpsUri.toString());
        return Uri.parse('googlechrome://navigate?url=$encoded');
      } else if (Platform.isIOS) {
        if (httpsUri.scheme == 'https') {
          return Uri.parse(
              httpsUri.toString().replaceFirst('https://', 'googlechromes://'));
        } else if (httpsUri.scheme == 'http') {
          return Uri.parse(
              httpsUri.toString().replaceFirst('http://', 'googlechrome://'));
        } else {
          return null;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _openUrlPreferChrome(BuildContext context, String url) async {
    Uri? base = Uri.tryParse(url);
    if (base == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Invalid URL')));
      }
      return;
    }
    base = _forceHttps(base);

    // 1) Try Chrome-specific scheme first (if available on platform)
    final chromeUri = _chromeUriFrom(base);
    if (chromeUri != null) {
      final okChrome = await launchUrl(chromeUri,
          mode: LaunchMode.externalApplication);
      if (okChrome) return; // Opened in Chrome
    }

    // 2) Fallback: open in external default browser (often Chrome on Android)
    var ok = await launchUrl(base, mode: LaunchMode.externalApplication);
    if (ok) return;

    // 3) Last resort: try in-app browser view
    ok = await launchUrl(base, mode: LaunchMode.inAppBrowserView);
    if (ok) return;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t open ${item.title}')),
      );
    }
  }

  void _copyLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: item.url));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Link copied')));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(item.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(item.subtitle,
            style: Theme.of(context).textTheme.bodySmall),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => _openUrlPreferChrome(context, item.url),
        onLongPress: () => _copyLink(context),
      ),
    );
  }
}

/* ------------------------------ Scheme Finder ------------------------------ */

class _SchemeFinder extends StatefulWidget {
  final List<_LinkItem> allSchemes;
  const _SchemeFinder({required this.allSchemes});
  @override
  State<_SchemeFinder> createState() => _SchemeFinderState();
}

class _SchemeFinderState extends State<_SchemeFinder> {
  final _formKey = GlobalKey<FormState>();

  // Basic criteria (kept intentionally lightweight, fully offline)
  final _incomeCtrl = TextEditingController(); // Annual income (₹)
  final _landCtrl = TextEditingController(); // Land size (acres)
  final _ageCtrl = TextEditingController();

  String? _state;
  bool _isWoman = false;
  bool _isSCST = false;
  bool _isTenantFarmer = false;
  bool _hasBankAccount = true;

  List<_Recommendation> _results = [];

  @override
  void dispose() {
    _incomeCtrl.dispose();
    _landCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  void _compute() {
    final double income =
        double.tryParse(_incomeCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final double land =
        double.tryParse(_landCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final int age = int.tryParse(_ageCtrl.text.trim()) ?? 0;

    final recs = <_Recommendation>[];

    // PM-KISAN
    if (land > 0 && _hasBankAccount) {
      recs.add(_Recommendation(
        code: 'PMKISAN',
        reason:
        'Landholding detected and bank account available (PM-KISAN provides income support to eligible land-owning farmers).',
      ));
    }

    // PMFBY
    if (land > 0 || _isTenantFarmer) {
      recs.add(_Recommendation(
        code: 'PMFBY',
        reason:
        'You are cultivating (owned/tenant) — crop insurance can reduce risk from weather and pest losses.',
      ));
    }

    // KCC
    if (_hasBankAccount) {
      recs.add(_Recommendation(
        code: 'KCC',
        reason:
        'You have/plan a bank account — Kisan Credit Card can provide flexible credit for inputs.',
      ));
    }

    // AIF
    if (land >= 1 || income >= 200000) {
      recs.add(_Recommendation(
        code: 'AIF',
        reason:
        'Scale signals potential for small infra investment (e.g., storage, primary processing).',
      ));
    }

    // e-NAM
    recs.add(_Recommendation(
      code: 'ENAM',
      reason: 'Better market access and price discovery via e-NAM mandis.',
    ));

    // Notes
    final notes = <String>[];
    if (_isWoman) {
      notes.add('Women farmers often receive priority/extra benefits in several schemes.');
    }
    if (_isSCST) {
      notes.add('SC/ST beneficiaries may receive relaxed criteria or higher benefits in select schemes.');
    }
    if (age > 0 && age < 18) {
      notes.add('Some credit/insurance products require guardian co-applicant if under 18.');
    }

    // Map to links + dedupe
    final mapped = <_Recommendation>[];
    for (final r in recs) {
      final match = widget.allSchemes.firstWhere(
            (s) => s.code == r.code,
        orElse: () => const _LinkItem(
          title: 'Learn more',
          subtitle: 'Official scheme page',
          url: 'https://agriwelfare.gov.in/en/Major',
        ),
      );
      mapped.add(r.copyWith(item: match));
    }

    final seen = <String>{};
    final finalList = <_Recommendation>[];
    for (final m in mapped) {
      final key = m.item?.code ?? m.code ?? m.item?.title ?? '';
      if (!seen.contains(key)) {
        seen.add(key);
        finalList.add(m);
      }
    }

    if (notes.isNotEmpty) {
      finalList.add(_Recommendation.noteOnly(notes.join(' ')));
    }

    setState(() => _results = finalList);
  }

  Future<void> _openUrlPreferChrome(BuildContext context, String url) async {
    Uri? base = Uri.tryParse(url);
    if (base == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Invalid URL')));
      }
      return;
    }
    // Ensure https
    if (base.scheme.isEmpty) {
      base = Uri.parse('https://${base.toString()}');
    } else if (base.scheme == 'http') {
      base = base.replace(scheme: 'https');
    }

    // Chrome first
    Uri? chromeUri;
    try {
      if (Platform.isAndroid) {
        chromeUri = Uri.parse(
            'googlechrome://navigate?url=${Uri.encodeComponent(base.toString())}');
      } else if (Platform.isIOS) {
        chromeUri = Uri.parse(
            base.scheme == 'https'
                ? base.toString().replaceFirst('https://', 'googlechromes://')
                : base.toString().replaceFirst('http://', 'googlechrome://'));
      }
    } catch (_) {}

    if (chromeUri != null) {
      final openedChrome =
      await launchUrl(chromeUri, mode: LaunchMode.externalApplication);
      if (openedChrome) return;
    }

    // external default
    var ok = await launchUrl(base, mode: LaunchMode.externalApplication);
    if (ok) return;

    // in-app
    ok = await launchUrl(base, mode: LaunchMode.inAppBrowserView);
    if (ok) return;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t open the link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Header(
            icon: Icons.search_outlined,
            title: 'Find Schemes by Criteria',
            subtitle:
            'Enter a few details to see which central schemes may fit you. This is a quick, offline guide — always verify eligibility on the official site.',
          ),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _incomeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Annual income (₹)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _landCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Land size (acres)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ageCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Age',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _state,
                        decoration: const InputDecoration(
                          labelText: 'State (optional)',
                          border: OutlineInputBorder(),
                        ),
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: null, child: Text('')),
                          DropdownMenuItem(value: 'Andhra Pradesh', child: Text('Andhra Pradesh')),
                          DropdownMenuItem(value: 'Telangana', child: Text('Telangana')),
                          DropdownMenuItem(value: 'Karnataka', child: Text('Karnataka')),
                          DropdownMenuItem(value: 'Maharashtra', child: Text('Maharashtra')),
                          DropdownMenuItem(value: 'Uttar Pradesh', child: Text('Uttar Pradesh')),
                          DropdownMenuItem(value: 'Bihar', child: Text('Bihar')),
                          DropdownMenuItem(value: 'Tamil Nadu', child: Text('Tamil Nadu')),
                          DropdownMenuItem(value: 'Gujarat', child: Text('Gujarat')),
                          DropdownMenuItem(value: 'Rajasthan', child: Text('Rajasthan')),
                          DropdownMenuItem(value: 'Madhya Pradesh', child: Text('Madhya Pradesh')),
                        ],
                        onChanged: (v) => setState(() => _state = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: -8,
                  children: [
                    FilterChip(
                      label: const Text('Woman'),
                      selected: _isWoman,
                      onSelected: (v) => setState(() => _isWoman = v),
                    ),
                    FilterChip(
                      label: const Text('SC/ST'),
                      selected: _isSCST,
                      onSelected: (v) => setState(() => _isSCST = v),
                    ),
                    FilterChip(
                      label: const Text('Tenant farmer'),
                      selected: _isTenantFarmer,
                      onSelected: (v) => setState(() => _isTenantFarmer = v),
                    ),
                    FilterChip(
                      label: const Text('Bank account'),
                      selected: _hasBankAccount,
                      onSelected: (v) => setState(() => _hasBankAccount = v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Check eligible schemes'),
                    onPressed: _compute,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_results.isNotEmpty)
            Text('Possible matches',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          ..._results.map((r) {
            if (r.isNoteOnly) {
              return Card(
                elevation: 0,
                color: Colors.green[50],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(r.reason, style: theme.textTheme.bodySmall),
                ),
              );
            }
            final item = r.item!;
            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text(item.title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.subtitle, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Text('Why: ${r.reason}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey[700])),
                  ],
                ),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _openUrlPreferChrome(context, item.url),
                onLongPress: () {
                  Clipboard.setData(ClipboardData(text: item.url));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied')),
                  );
                },
              ),
            );
          }),

          if (_results.isEmpty)
            Text(
              'Fill the form above and tap "Check eligible schemes" to see suggestions.',
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Recommendation {
  final String? code; // internal scheme code
  final String reason; // why recommended
  final _LinkItem? item; // mapped link item
  final bool isNoteOnly;

  _Recommendation({
    this.code,
    required this.reason,
    this.item,
  }) : isNoteOnly = false;

  _Recommendation.noteOnly(this.reason)
      : code = null,
        item = null,
        isNoteOnly = true;

  _Recommendation copyWith({_LinkItem? item}) =>
      _Recommendation(code: code, reason: reason, item: item);
}
