import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models.dart';
import '../pdf_gen.dart';
import '../store.dart';
import '../widgets.dart';
import 'doc_edit.dart';

/// Which document types each type can be converted into.
const convertTargets = {
  DocType.quotation: [DocType.invoice, DocType.proforma, DocType.purchaseOrder],
  DocType.proforma: [DocType.invoice],
  DocType.invoice: [DocType.receipt, DocType.deliveryNote],
  DocType.purchaseOrder: [DocType.deliveryNote],
  DocType.deliveryNote: <DocType>[],
  DocType.receipt: <DocType>[],
};

class DocListScreen extends StatefulWidget {
  final DocType type;
  const DocListScreen({super.key, required this.type});
  @override
  State<DocListScreen> createState() => _DocListScreenState();
}

class _DocListScreenState extends State<DocListScreen> {
  final st = Store.i;
  List<DocModel> all = [];
  String q = '';

  DocType get type => widget.type;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await st.docs(type);
    if (mounted) setState(() => all = l);
  }

  Future<void> _open(DocModel? d, {DocType? asType}) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => DocEditScreen(type: asType ?? type, doc: d)));
    _load();
  }

  Future<void> _convert(DocModel d, DocType to) async {
    final c = d.clone();
    c.type = to;
    c.number = st.nextNumber(to);
    c.date = DateTime.now();
    c.status = 'Draft';
    c.terms = st.str('doc_${to.key}', 'terms').isNotEmpty ? st.str('doc_${to.key}', 'terms') : c.terms;
    if (to == DocType.receipt) {
      c.paid = d.type == DocType.invoice ? (d.paid > 0 ? d.paid : d.total) : d.total;
      c.receiptType = st.str('doc_receipt', 'receiptType');
      c.reference = 'Ref: ${d.number}';
      c.paidDate = DateTime.now();
    } else if (to != DocType.invoice) {
      c.paid = 0;
    }
    if (to == DocType.invoice) {
      c.paid = 0;
      c.paidDate = null;
    }
    await st.saveDoc(c);
    if (!mounted) return;
    toast(context, 'Created ${to.label} ${c.number}');
    final target = to;
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => DocEditScreen(type: target, doc: c)));
    _load();
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Paid':
      case 'Accepted':
      case 'Received':
      case 'Delivered':
        return Colors.green;
      case 'Overdue':
      case 'Rejected':
      case 'Cancelled':
        return Colors.red;
      case 'Partial':
      case 'Sent':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = all.where((d) {
      final s = q.toLowerCase();
      return s.isEmpty || d.number.toLowerCase().contains(s) || d.customer.name.toLowerCase().contains(s);
    }).toList();
    return Scaffold(
      appBar: AppBar(title: Text(type.plural)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(null),
        icon: const Icon(Icons.add),
        label: Text('New ${type.label}'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search), hintText: 'Search number or customer', border: OutlineInputBorder()),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text('No ${type.plural.toLowerCase()} yet'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final d = list[i];
                    final status = d.displayStatus;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        onTap: () => _open(d),
                        title: Text('${d.number}  •  ${d.customer.name.isEmpty ? 'No customer' : d.customer.name}',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Row(children: [
                          Text(st.fmtDate(d.date)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                                color: _statusColor(status).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(status, style: TextStyle(fontSize: 12, color: _statusColor(status))),
                          ),
                        ]),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(st.fmtMoney(type == DocType.receipt ? d.paid : d.total),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'pdf') {
                                final bytes = await buildDocPdf(d);
                                await Printing.sharePdf(bytes: bytes, filename: '${d.number}.pdf');
                              } else if (v == 'print') {
                                await Printing.layoutPdf(onLayout: (_) => buildDocPdf(d), name: d.number);
                              } else if (v == 'dup') {
                                final c = d.clone()..number = st.nextNumber(type);
                                c.date = DateTime.now();
                                await st.saveDoc(c);
                                _load();
                              } else if (v == 'del') {
                                if (await confirm(context, 'Delete ${d.number}?', 'This cannot be undone.')) {
                                  await st.deleteDoc(d.id!);
                                  _load();
                                }
                              } else if (v.startsWith('to_')) {
                                _convert(d, DocType.values.firstWhere((t) => 'to_${t.key}' == v));
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'pdf', child: Text('Share PDF')),
                              const PopupMenuItem(value: 'print', child: Text('Print / preview')),
                              const PopupMenuItem(value: 'dup', child: Text('Duplicate')),
                              for (final t in convertTargets[type]!)
                                PopupMenuItem(value: 'to_${t.key}', child: Text('Convert to ${t.label}')),
                              const PopupMenuItem(value: 'del', child: Text('Delete')),
                            ],
                          ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
