import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../pdf_gen.dart';
import '../store.dart';
import '../widgets.dart';

/// Reports & statements, downloadable as PDF or CSV.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final st = Store.i;
  DocType type = DocType.invoice;
  DateTimeRange? range;
  Party? customer; // null = all customers
  List<Party> customers = [];
  List<DocModel> rows = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    range = DateTimeRange(start: DateTime(now.year, now.month, 1), end: DateTime(now.year, now.month + 1, 0));
    _load();
  }

  Future<void> _load() async {
    final c = await st.customers();
    final all = await st.docs(type);
    final r = range!;
    final end = DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59);
    final l = all.where((d) {
      if (d.date.isBefore(r.start) || d.date.isAfter(end)) return false;
      if (customer != null) {
        final same = customer!.id != null && d.customer.id == customer!.id;
        if (!same && d.customer.name != customer!.name) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (mounted) {
      setState(() {
        customers = c;
        rows = l;
      });
    }
  }

  double get totalSum => rows.fold(0.0, (s, d) => s + (type == DocType.receipt ? d.paid : d.total));
  double get paidSum => rows.fold(0.0, (s, d) => s + d.paid);
  bool get showPaid => type == DocType.invoice;

  List<String> get headers => [
        'Date',
        'Number',
        'Customer',
        'Status',
        if (type != DocType.deliveryNote) type == DocType.receipt ? 'Amount received' : 'Total',
        if (showPaid) 'Paid',
        if (showPaid) 'Balance',
      ];

  List<List<String>> get table => [
        for (final d in rows)
          [
            st.fmtDate(d.date),
            d.number,
            d.customer.name,
            d.displayStatus,
            if (type != DocType.deliveryNote) st.fmtMoney(type == DocType.receipt ? d.paid : d.total),
            if (showPaid) st.fmtMoney(d.paid),
            if (showPaid) st.fmtMoney(d.balance),
          ],
      ];

  List<String> get summary => [
        '${rows.length} ${type.plural.toLowerCase()}',
        if (type != DocType.deliveryNote) 'Total: ${st.fmtMoney(totalSum)}',
        if (showPaid) 'Paid: ${st.fmtMoney(paidSum)}     Outstanding: ${st.fmtMoney(totalSum - paidSum)}',
      ];

  String get title => customer == null ? '${type.label} report' : 'Statement – ${customer!.name} (${type.plural})';
  String get subtitle => 'Period: ${st.fmtDate(range!.start)} to ${st.fmtDate(range!.end)}';

  String _csvCell(String s) => '"${s.replaceAll('"', '""')}"';

  Future<void> _pdf() async {
    final bytes = await buildReportPdf(
        title: title, subtitle: subtitle, headers: headers, rows: table, summary: summary);
    await Printing.sharePdf(bytes: bytes, filename: '${title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.pdf');
  }

  Future<void> _csv() async {
    final buf = StringBuffer()..writeln(headers.map(_csvCell).join(','));
    for (final r in table) {
      buf.writeln(r.map(_csvCell).join(','));
    }
    final name = '${title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.csv';
    final f = File(p.join(st.dir.path, name));
    await f.writeAsString(buf.toString());
    await Share.shareXFiles([XFile(f.path, mimeType: 'text/csv')], subject: title);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports & statements')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          DropdownButtonFormField<DocType>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Report on', border: OutlineInputBorder()),
            items: [for (final t in DocType.values) DropdownMenuItem(value: t, child: Text(t.plural))],
            onChanged: (v) {
              type = v ?? type;
              _load();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: customer?.id,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Customer (choose one for a customer statement)', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('All customers')),
              for (final c in customers) DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
            ],
            onChanged: (v) {
              customer = v == null ? null : customers.firstWhere((c) => c.id == v);
              _load();
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range),
            label: Text('${st.fmtDate(range!.start)}  –  ${st.fmtDate(range!.end)}'),
            onPressed: () async {
              final r = await showDateRangePicker(
                  context: context, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDateRange: range);
              if (r != null) {
                range = r;
                _load();
              }
            },
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            ActionChip(label: const Text('This month'), onPressed: () => _quick(0)),
            ActionChip(label: const Text('Last month'), onPressed: () => _quick(1)),
            ActionChip(label: const Text('This year'), onPressed: () => _quick(-1)),
          ]),
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final s in summary) Text(s, style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          Row(children: [
            Expanded(
                child: FilledButton.icon(
                    onPressed: rows.isEmpty ? null : _pdf,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Download PDF'))),
            const SizedBox(width: 8),
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: rows.isEmpty ? null : _csv,
                    icon: const Icon(Icons.table_chart_outlined),
                    label: const Text('Download CSV'))),
          ]),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No documents in this period')))
          else
            for (final d in rows)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${d.number} • ${d.customer.name}'),
                subtitle: Text('${st.fmtDate(d.date)} • ${d.displayStatus}'),
                trailing: type == DocType.deliveryNote
                    ? null
                    : Text(st.fmtMoney(type == DocType.receipt ? d.paid : d.total),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
        ]),
      ),
    );
  }

  void _quick(int k) {
    final n = DateTime.now();
    if (k == 0) {
      range = DateTimeRange(start: DateTime(n.year, n.month, 1), end: DateTime(n.year, n.month + 1, 0));
    } else if (k == 1) {
      range = DateTimeRange(start: DateTime(n.year, n.month - 1, 1), end: DateTime(n.year, n.month, 0));
    } else {
      range = DateTimeRange(start: DateTime(n.year, 1, 1), end: DateTime(n.year, 12, 31));
    }
    _load();
  }
}
