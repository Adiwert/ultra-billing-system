import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'customers.dart';
import 'doc_list.dart';
import 'reports.dart';
import 'settings.dart';

const docIcons = {
  DocType.quotation: Icons.request_quote_outlined,
  DocType.invoice: Icons.receipt_long_outlined,
  DocType.purchaseOrder: Icons.shopping_cart_outlined,
  DocType.proforma: Icons.description_outlined,
  DocType.deliveryNote: Icons.local_shipping_outlined,
  DocType.receipt: Icons.payments_outlined,
};

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [const _Dashboard(), const CustomersScreen(), const ReportsScreen(), const SettingsScreen()];
    return Scaffold(
      body: SafeArea(top: false, child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Documents'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Customers'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}

class _Dashboard extends StatefulWidget {
  const _Dashboard();
  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  Map<DocType, int> counts = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = <DocType, int>{};
    for (final t in DocType.values) {
      m[t] = await Store.i.docCount(t);
    }
    if (mounted) setState(() => counts = m);
  }

  @override
  Widget build(BuildContext context) {
    final name = Store.i.str('business', 'name');
    return Scaffold(
      appBar: AppBar(title: Text(name.isEmpty ? 'Quote & Invoice Maker' : name)),
      body: GridView.extent(
        padding: const EdgeInsets.all(16),
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
        children: [
          for (final t in DocType.values)
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => DocListScreen(type: t)));
                  _load();
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(docIcons[t], size: 36, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 8),
                    Text(t.plural, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${counts[t] ?? 0}', style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
