import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models.dart';
import '../pdf_gen.dart';
import '../store.dart';
import '../widgets.dart';
import 'customers.dart';

/// Create / edit any of the six document types.
class DocEditScreen extends StatefulWidget {
  final DocType type;
  final DocModel? doc;
  const DocEditScreen({super.key, required this.type, this.doc});
  @override
  State<DocEditScreen> createState() => _DocEditScreenState();
}

class _DocEditScreenState extends State<DocEditScreen> {
  final st = Store.i;
  late DocModel d;
  bool dirty = false;
  int shipRev = 0, paidRev = 0;

  DocType get t => widget.type;
  String get g => 'doc_${t.key}';

  @override
  void initState() {
    super.initState();
    d = widget.doc ??
        DocModel(
          type: t,
          number: st.nextNumber(t),
          terms: st.str(g, 'terms'),
          receiptType: st.str(g, 'receiptType'),
          dueDate: t == DocType.receipt ? null : DateTime.now().add(const Duration(days: 14)),
          paidDate: t == DocType.receipt ? DateTime.now() : null,
        );
    if (widget.doc == null && t != DocType.receipt && d.items.isEmpty) d.items.add(LineItem());
  }

  void _change(VoidCallback fn) {
    setState(() {
      fn();
      dirty = true;
    });
  }

  Future<bool> _save({bool pop = true}) async {
    if (d.customer.name.trim().isEmpty) {
      toast(context, 'Please choose or enter a customer');
      return false;
    }
    if (t == DocType.receipt && d.paid == 0) d.paid = d.total;
    await st.saveDoc(d);
    dirty = false;
    if (mounted && pop) Navigator.pop(context);
    return true;
  }

  Future<void> _pickDate(DateTime? initial, ValueChanged<DateTime> onPick) async {
    final r = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (r != null) _change(() => onPick(r));
  }

  Future<void> _pickCustomer() async {
    final list = await st.customers();
    if (!mounted) return;
    final res = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PickerSheet<Party>(
        title: 'Select customer',
        items: list,
        label: (c) => c.name,
        sub: (c) => [c.phone, c.email].where((e) => e.isNotEmpty).join(' • '),
        addLabel: 'Add new customer',
      ),
    );
    Party? chosen;
    if (res == 'add') {
      if (!mounted) return;
      chosen = await Navigator.push<Party>(
          context, MaterialPageRoute(builder: (_) => const CustomerEditScreen()));
    } else if (res is Party) {
      chosen = res;
    }
    final c = chosen;
    if (c != null) {
      _change(() {
        d.customer = Party.fromJson(c.toJson(), c.id);
        d.shipping = c.shipping.isNotEmpty ? c.shipping : c.address;
        shipRev++;
      });
    }
  }

  Future<void> _pickProduct() async {
    final list = await st.products();
    if (!mounted) return;
    final res = await showModalBottomSheet<LineItem>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PickerSheet<LineItem>(
        title: 'Saved products',
        items: list,
        label: (p) => p.name,
        sub: (p) => st.fmtMoney(p.price),
      ),
    );
    if (res != null) {
      _change(() {
        final i = res.copy();
        if (d.items.length == 1 && d.items.first.name.isEmpty && d.items.first.price == 0) {
          d.items.clear();
        }
        d.items.add(i);
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (!dirty) return true;
    final r = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('Save this document before leaving?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'discard'), child: const Text('Discard')),
          TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, 'save'), child: const Text('Save')),
        ],
      ),
    );
    if (r == 'save') return _save(pop: false);
    return r == 'discard';
  }

  @override
  Widget build(BuildContext context) {
    final prices = t.hasPrices;
    final showTax = st.flag(g, 'showTax') && prices && t != DocType.receipt;
    final showDiscount = st.flag(g, 'showDiscount') && t.hasExtras;
    final cols = 'columns';

    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _onWillPop()) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.doc == null ? 'New ${t.label}' : d.number),
          actions: [
            IconButton(
              tooltip: 'PDF preview / share',
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () async {
                await Printing.layoutPdf(onLayout: (_) => buildDocPdf(d), name: d.number);
              },
            ),
            TextButton(
                onPressed: _save, child: const Text('Save', style: TextStyle(color: Colors.white))),
          ],
        ),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            // ------------------------------------------------ header info
            LayoutBuilder(builder: (ctx, cons) {
              final wide = cons.maxWidth > 480;
              final numF = Field('${t.label} number', d.number, (v) => _change(() => d.number = v));
              final date = _DateTile('Date', st.fmtDate(d.date), () => _pickDate(d.date, (v) => d.date = v));
              final due = t == DocType.receipt
                  ? const SizedBox.shrink()
                  : _DateTile(t.dueLabel, st.fmtDate(d.dueDate),
                      () => _pickDate(d.dueDate, (v) => d.dueDate = v));
              if (wide) {
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: numF),
                  const SizedBox(width: 8),
                  Expanded(child: date),
                  const SizedBox(width: 8),
                  Expanded(child: due),
                ]);
              }
              return Column(children: [numF, date, if (t != DocType.receipt) due]);
            }),
            if (t.statuses.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  initialValue: t.statuses.contains(d.status) ? d.status : t.statuses.first,
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                  items: [for (final s in t.statuses) DropdownMenuItem(value: s, child: Text(s))],
                  onChanged: (v) => _change(() => d.status = v ?? d.status),
                ),
              ),

            // --------------------------------------------------- customer
            SectionTitle(t.partyLabel),
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(d.customer.name.isEmpty ? 'Tap to choose or add customer' : d.customer.name),
                subtitle: d.customer.name.isEmpty
                    ? null
                    : Text([d.customer.contact, d.customer.phone, d.customer.address]
                        .where((e) => e.isNotEmpty)
                        .join('\n')),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickCustomer,
              ),
            ),
            if (st.flag(g, 'showShipping') && t != DocType.receipt) ...[
              const SizedBox(height: 8),
              Field('Shipping address', d.shipping, (v) => _change(() => d.shipping = v),
                  maxLines: 3, key: ValueKey('ship$shipRev')),
            ],

            // ------------------------------------------------- products
            SectionTitle(t == DocType.receipt ? 'Payment for (optional)' : 'Products / services',
                trailing: TextButton.icon(
                    onPressed: _pickProduct,
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Saved'))),
            for (final it in d.items)
              Card(
                key: ValueKey(it.uid),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 4, 0),
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: Field(st.str(cols, 'item'), it.name, (v) => _change(() => it.name = v))),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _change(() => d.items.remove(it)),
                      ),
                    ]),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Field(st.str(cols, 'description'), it.desc, (v) => _change(() => it.desc = v),
                          maxLines: 3),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                            child: Field(st.str(cols, 'qty'), numStr(it.qty), (v) => _change(() => it.qty = parseNum(v)),
                                type: numType)),
                        if (prices) ...[
                          const SizedBox(width: 8),
                          Expanded(
                              flex: 2,
                              child: Field(st.str(cols, 'price'), numStr(it.price),
                                  (v) => _change(() => it.price = parseNum(v)),
                                  type: numType)),
                        ],
                        if (showTax) ...[
                          const SizedBox(width: 8),
                          Expanded(
                              child: Field(st.str(cols, 'tax'), numStr(it.taxPct),
                                  (v) => _change(() => it.taxPct = parseNum(v)),
                                  type: numType)),
                        ],
                      ]),
                    ),
                    if (prices)
                      Padding(
                        padding: const EdgeInsets.only(right: 12, bottom: 8),
                        child: Row(children: [
                          TextButton(
                            onPressed: it.name.trim().isEmpty
                                ? null
                                : () async {
                                    await st.saveProduct(it.copy());
                                    if (context.mounted) toast(context, 'Saved to products');
                                  },
                            child: const Text('Save to products'),
                          ),
                          const Spacer(),
                          Text('${st.str(cols, 'amount')}: ${st.fmtMoney(it.amount)}',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ]),
                      ),
                  ]),
                ),
              ),
            OutlinedButton.icon(
                onPressed: () => _change(() => d.items.add(LineItem())),
                icon: const Icon(Icons.add),
                label: const Text('Add item')),

            // ---------------------------------------------- other charges
            if (t.hasExtras) ...[
              SectionTitle('Other charges',
                  trailing: TextButton.icon(
                      onPressed: () => _change(() => d.charges.add(Charge())),
                      icon: const Icon(Icons.add),
                      label: const Text('Add'))),
              for (final c in d.charges)
                Row(key: ValueKey(c.uid), crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                      flex: 3,
                      child: Field('Label (e.g. Shipping)', c.label, (v) => _change(() => c.label = v))),
                  const SizedBox(width: 8),
                  Expanded(
                      flex: 2,
                      child: Field('Amount', numStr(c.amount), (v) => _change(() => c.amount = parseNum(v)),
                          type: numType)),
                  IconButton(
                      onPressed: () => _change(() => d.charges.remove(c)),
                      icon: const Icon(Icons.delete_outline)),
                ]),
              if (showDiscount) ...[
                const SizedBox(height: 4),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                      child: Field('Discount', numStr(d.discount), (v) => _change(() => d.discount = parseNum(v)),
                          type: numType)),
                  const SizedBox(width: 8),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(value: false, label: Text(st.currency.isEmpty ? '\$' : st.currency)),
                      const ButtonSegment(value: true, label: Text('%')),
                    ],
                    selected: {d.discountPercent},
                    onSelectionChanged: (s) => _change(() => d.discountPercent = s.first),
                  ),
                ]),
              ],
            ],

            // ------------------------------------------------------ totals
            if (prices && t != DocType.receipt)
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    _Line('Subtotal', st.fmtMoney(d.subtotal)),
                    if (showDiscount && d.discountAmt > 0) _Line('Discount', '-${st.fmtMoney(d.discountAmt)}'),
                    if (showTax) _Line('Tax', st.fmtMoney(d.taxTotal)),
                    if (d.chargesTotal != 0) _Line('Other charges', st.fmtMoney(d.chargesTotal)),
                    const Divider(),
                    _Line('TOTAL', st.fmtMoney(d.total), bold: true),
                    if (t == DocType.invoice && d.paid > 0) ...[
                      _Line('Paid', '-${st.fmtMoney(d.paid)}'),
                      _Line('Balance due', st.fmtMoney(d.balance), bold: true),
                    ],
                  ]),
                ),
              ),

            // ---------------------------------------------------- paid info
            if (t.hasPaid) ...[
              SectionTitle(t == DocType.invoice ? 'Paid info' : 'Payment received'),
              Field(t == DocType.invoice ? 'Amount paid' : 'Amount received', numStr(d.paid),
                  (v) => _change(() => d.paid = parseNum(v)),
                  key: ValueKey('paid$paidRev'),
                  type: numType,
                  hint: t == DocType.receipt ? 'Leave empty to use ${st.fmtMoney(d.total)}' : null),
              Field('Payment method (cash, bank transfer, e-wallet...)', d.paidMethod,
                  (v) => _change(() => d.paidMethod = v)),
              _DateTile('Payment date', st.fmtDate(d.paidDate), () => _pickDate(d.paidDate, (v) => d.paidDate = v)),
              if (t == DocType.invoice && d.total > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                      onPressed: () => _change(() {
                        d.paid = d.total;
                        paidRev++;
                      }),
                      child: const Text('Mark as fully paid')),
                ),
              if (t == DocType.receipt) ...[
                Field('Receipt type', d.receiptType, (v) => _change(() => d.receiptType = v)),
                Field('Reference (e.g. invoice number)', d.reference, (v) => _change(() => d.reference = v)),
              ],
            ],

            // ------------------------------------------------ terms/notes
            if (t.hasTerms) ...[
              const SectionTitle('Terms & conditions'),
              Field('Terms & conditions', d.terms, (v) => _change(() => d.terms = v), maxLines: 6),
            ],
            const SectionTitle('Notes'),
            Field('Notes (shown on document)', d.notes, (v) => _change(() => d.notes = v), maxLines: 3),
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Save')),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                if (d.customer.name.trim().isEmpty) return toast(context, 'Please choose a customer first');
                final bytes = await buildDocPdf(d);
                await Printing.sharePdf(bytes: bytes, filename: '${d.number}.pdf');
              },
              icon: const Icon(Icons.share),
              label: const Text('Share as PDF'),
            ),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String l, v;
  final bool bold;
  const _Line(this.l, this.v, {this.bold = false});
  @override
  Widget build(BuildContext context) {
    final s = TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 16 : 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: s), Text(v, style: s)]),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label, value;
  final VoidCallback onTap;
  const _DateTile(this.label, this.value, this.onTap);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: InputDecoration(
                labelText: label, border: const OutlineInputBorder(), suffixIcon: const Icon(Icons.calendar_today, size: 18)),
            child: Text(value.isEmpty ? 'Not set' : value),
          ),
        ),
      );
}

/// Searchable bottom sheet. Pops the chosen item, or the string 'add'.
class _PickerSheet<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) label;
  final String Function(T) sub;
  final String? addLabel;
  const _PickerSheet(
      {required this.title, required this.items, required this.label, required this.sub, this.addLabel});
  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final list = widget.items.where((e) => widget.label(e).toLowerCase().contains(q.toLowerCase())).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(child: Text(widget.title, style: Theme.of(context).textTheme.titleMedium)),
              if (widget.addLabel != null)
                TextButton.icon(
                    onPressed: () => Navigator.pop(context, 'add'),
                    icon: const Icon(Icons.add),
                    label: Text(widget.addLabel!)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              onChanged: (v) => setState(() => q = v),
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search), hintText: 'Search', border: OutlineInputBorder()),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('Nothing here yet'))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) => ListTile(
                      title: Text(widget.label(list[i])),
                      subtitle: Text(widget.sub(list[i])),
                      onTap: () => Navigator.pop(context, list[i]),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}
