import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../widgets.dart';

/// Customers and saved products, in two tabs.
class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Customers & Products'),
            bottom: const TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [Tab(text: 'Customers'), Tab(text: 'Products')],
            ),
          ),
          body: const TabBarView(children: [_CustomerList(), _ProductList()]),
        ),
      );
}

class _CustomerList extends StatefulWidget {
  const _CustomerList();
  @override
  State<_CustomerList> createState() => _CustomerListState();
}

class _CustomerListState extends State<_CustomerList> {
  List<Party> all = [];
  String q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await Store.i.customers();
    if (mounted) setState(() => all = l);
  }

  @override
  Widget build(BuildContext context) {
    final list = all.where((c) => c.name.toLowerCase().contains(q.toLowerCase())).toList();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerEditScreen()));
          _load();
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add customer'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search), hintText: 'Search customers', border: OutlineInputBorder()),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('No customers yet'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final c = list[i];
                    return ListTile(
                      leading: CircleAvatar(child: Text(c.name.isEmpty ? '?' : c.name[0].toUpperCase())),
                      title: Text(c.name),
                      subtitle: Text([c.phone, c.email].where((e) => e.isNotEmpty).join(' • ')),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (await confirm(context, 'Delete customer?',
                              'Existing documents keep their copy of the details.')) {
                            await Store.i.deleteCustomer(c.id!);
                            _load();
                          }
                        },
                      ),
                      onTap: () async {
                        await Navigator.push(
                            context, MaterialPageRoute(builder: (_) => CustomerEditScreen(customer: c)));
                        _load();
                      },
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class CustomerEditScreen extends StatefulWidget {
  final Party? customer;
  const CustomerEditScreen({super.key, this.customer});
  @override
  State<CustomerEditScreen> createState() => _CustomerEditScreenState();
}

class _CustomerEditScreenState extends State<CustomerEditScreen> {
  late final Party c = widget.customer ?? Party();

  Future<void> _save() async {
    if (c.name.trim().isEmpty) return toast(context, 'Customer name is required');
    await Store.i.saveCustomer(c);
    if (mounted) Navigator.pop(context, c);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.customer == null ? 'New customer' : 'Edit customer'),
          actions: [TextButton(onPressed: _save, child: const Text('Save', style: TextStyle(color: Colors.white)))],
        ),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Field('Customer / company name *', c.name, (v) => c.name = v),
            Field('Contact person', c.contact, (v) => c.contact = v),
            Field('Phone', c.phone, (v) => c.phone = v, type: TextInputType.phone),
            Field('Email', c.email, (v) => c.email = v, type: TextInputType.emailAddress),
            Field('Billing address', c.address, (v) => c.address = v, maxLines: 4),
            Field('Shipping address', c.shipping, (v) => c.shipping = v, maxLines: 4),
            Field('Tax / registration no.', c.taxId, (v) => c.taxId = v),
          ]),
        ),
      );
}

class _ProductList extends StatefulWidget {
  const _ProductList();
  @override
  State<_ProductList> createState() => _ProductListState();
}

class _ProductListState extends State<_ProductList> {
  List<LineItem> all = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await Store.i.products();
    if (mounted) setState(() => all = l);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductEditScreen()));
            _load();
          },
          icon: const Icon(Icons.add),
          label: const Text('Add product'),
        ),
        body: all.isEmpty
            ? const Center(child: Text('No saved products yet'))
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: all.length,
                itemBuilder: (_, i) {
                  final p = all[i];
                  return ListTile(
                    title: Text(p.name),
                    subtitle: Text(p.desc, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(Store.i.fmtMoney(p.price)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (await confirm(context, 'Delete product?', p.name)) {
                            await Store.i.deleteProduct(p.id!);
                            _load();
                          }
                        },
                      ),
                    ]),
                    onTap: () async {
                      await Navigator.push(
                          context, MaterialPageRoute(builder: (_) => ProductEditScreen(product: p)));
                      _load();
                    },
                  );
                },
              ),
      );
}

class ProductEditScreen extends StatefulWidget {
  final LineItem? product;
  const ProductEditScreen({super.key, this.product});
  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  late final LineItem p = widget.product ?? LineItem();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.product == null ? 'New product' : 'Edit product'),
          actions: [
            TextButton(
              onPressed: () async {
                if (p.name.trim().isEmpty) return toast(context, 'Product name is required');
                await Store.i.saveProduct(p);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Field('Product name *', p.name, (v) => p.name = v),
            Field('Description', p.desc, (v) => p.desc = v, maxLines: 3),
            Field('Price', numStr(p.price), (v) => p.price = parseNum(v), type: numType),
            Field('Tax %', numStr(p.taxPct), (v) => p.taxPct = parseNum(v), type: numType),
          ]),
        ),
      );
}
