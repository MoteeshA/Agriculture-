import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  static const route = '/dashboard';
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Read optional args from Navigator for display name/email
    final args = ModalRoute.of(context)?.settings.arguments;
    String? displayName;
    String? email;
    if (args is Map) {
      displayName = args['displayName'] as String?;
      email = args['email'] as String?;
    }

    // Fallback: email local-part → else "Farmer"
    final friendlyName = (displayName?.trim().isNotEmpty == true)
        ? displayName!.trim()
        : (email != null && email!.contains('@'))
        ? email!.split('@').first
        : 'Farmer';

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
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile coming soon')),
                  );
                  break;
                case 'refresh':
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
      drawer: const _DashboardDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              _WelcomeCard(friendlyName: friendlyName),
              const SizedBox(height: 20),

              // Quick Stats Row
              const _QuickStatsRow(),
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
                  // EXACT features you mentioned
                  FeatureItem(
                    title: 'Crop Prices',
                    subtitle: 'Mandi & forecast',
                    icon: Icons.price_change_outlined,
                    color: Colors.green,
                    onTap: () => _todo(context, 'Crop Prices'),
                  ),
                  FeatureItem(
                    title: 'Rent Equipment',
                    subtitle: 'Tractor, drone…',
                    icon: Icons.agriculture_outlined,
                    color: Colors.blue,
                    onTap: () => _todo(context, 'Equipment Renting'),
                  ),
                  FeatureItem(
                    title: 'Disease Detect',
                    subtitle: 'Upload leaf photo',
                    icon: Icons.health_and_safety_outlined,
                    color: Colors.orange,
                    onTap: () => _todo(context, 'Crop Disease Detection'),
                  ),
                  FeatureItem(
                    title: 'Growth Monitor',
                    subtitle: 'Yield & weather',
                    icon: Icons.monitor_heart_outlined,
                    color: Colors.purple,
                    onTap: () => _todo(context, 'Growth Monitoring'),
                  ),
                  FeatureItem(
                    title: 'Govt Schemes',
                    subtitle: 'Eligibility & apply',
                    icon: Icons.assignment_turned_in_outlined,
                    color: Colors.teal,
                    onTap: () => _todo(context, 'Government Schemes'),
                  ),
                  FeatureItem(
                    title: 'Community',
                    subtitle: 'Ask & share',
                    icon: Icons.forum_outlined,
                    color: Colors.indigo,
                    onTap: () => _todo(context, 'Community Q&A'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Weather & Advisory Section
              const _WeatherAdvisoryCard(),
              const SizedBox(height: 20),

              // Market Updates
              Text(
                'Market Updates',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const _MarketUpdates(),
            ],
          ),
        ),
      ),
    );
  }

  static void _todo(BuildContext context, String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name — screen coming soon')),
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
            child: Text(initials,
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimary)),
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
  const _DashboardDrawer();

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
                    Text('AgriMitra', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
              onTap: () => DashboardPage._todo(context, 'Crop Prices'),
            ),
            ListTile(
              leading: const Icon(Icons.agriculture_outlined),
              title: const Text('Equipment Rental'),
              onTap: () => DashboardPage._todo(context, 'Equipment Renting'),
            ),
            ListTile(
              leading: const Icon(Icons.local_florist_outlined),
              title: const Text('Crop Health'),
              onTap: () => DashboardPage._todo(context, 'Crop Disease Detection'),
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
                Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
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

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatItem(value: '₹4,250', label: 'Wheat/Q', icon: Icons.trending_up, color: Colors.green),
        _StatItem(value: '28°C', label: 'Temperature', icon: Icons.thermostat, color: Colors.orange),
        _StatItem(value: '65%', label: 'Soil Moisture', icon: Icons.water_drop, color: Colors.blue),
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
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _WeatherAdvisoryCard extends StatelessWidget {
  const _WeatherAdvisoryCard();

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
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Today: Sunny', style: TextStyle(fontWeight: FontWeight.w500)),
                Text('28°C / 18°C', style: TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            const LinearProgressIndicator(
              value: 0.3,
              backgroundColor: Colors.grey,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 4),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Rain probability: 30%'),
                Text('Humidity: 65%'),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Advisory: Ideal conditions for wheat harvesting. Consider irrigating in the evening.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketUpdates extends StatelessWidget {
  const _MarketUpdates();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: const [
          _MarketItem(crop: 'Wheat', price: '₹4,250', change: '+2.5%'),
          _MarketItem(crop: 'Rice', price: '₹3,800', change: '+1.2%'),
          _MarketItem(crop: 'Cotton', price: '₹6,700', change: '-0.8%'),
          _MarketItem(crop: 'Soybean', price: '₹4,900', change: '+3.1%'),
        ],
      ),
    );
  }
}

class _MarketItem extends StatelessWidget {
  final String crop;
  final String price;
  final String change;

  const _MarketItem({
    required this.crop,
    required this.price,
    required this.change,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = change.startsWith('+');

    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(crop, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(price, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(change,
              style: TextStyle(
                  color: isPositive ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w500
              )),
        ],
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
      childAspectRatio: 0.9,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: items
          .map((f) => _FeatureTile(
        title: f.title,
        subtitle: f.subtitle,
        icon: f.icon,
        color: f.color,
        onTap: f.onTap,
      ))
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
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}