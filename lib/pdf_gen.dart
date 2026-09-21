import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'models.dart';
import 'store.dart';

const _accent = PdfColor.fromInt(0xFF1F4E79);
const _light = PdfColor.fromInt(0xFFEAF1F8);
const _grey = PdfColor.fromInt(0xFF666666);

pw.Widget _t(String s, {double size = 10, bool bold = false, PdfColor? color, pw.TextAlign? align}) =>
    pw.Text(s,
        textAlign: align,
        style: pw.TextStyle(
            fontSize: size,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color));

pw.Widget _cell(String s,
        {bool bold = false, pw.TextAlign align = pw.TextAlign.left, PdfColor? color}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: _t(s, size: 9.5, bold: bold, align: align, color: color),
    );

Future<Uint8List> buildDocPdf(DocModel d) async {
  final st = Store.i;
  final g = 'doc_${d.type.key}';
  final b = 'business';
  final doc = pw.Document();

  final logo = st.imageBytes(st.str(b, 'logo'));
  final sign = st.imageBytes(st.str(b, 'signature'));
  final qr = st.imageBytes(st.str(b, 'paymentQr'));

  final showTax = st.flag(g, 'showTax') && d.type.hasPrices && d.type != DocType.receipt;
  final showDiscount = st.flag(g, 'showDiscount') && d.discountAmt > 0;
  final prices = d.type.hasPrices;

  final businessLines = <String>[
    st.str(b, 'address1'),
    st.str(b, 'address2'),
    st.str(b, 'address3'),
    if (st.str(b, 'phone').isNotEmpty) 'Tel: ${st.str(b, 'phone')}',
    if (st.str(b, 'email').isNotEmpty) st.str(b, 'email'),
    if (st.str(b, 'taxDetails').isNotEmpty) st.str(b, 'taxDetails'),
    st.str(b, 'other'),
  ].where((e) => e.trim().isNotEmpty).toList();

  final title = d.type == DocType.receipt && d.receiptType.isNotEmpty
      ? d.receiptType.toUpperCase()
      : d.type.label.toUpperCase();

  final header = pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    if (logo != null)
      pw.Container(
          width: 60,
          height: 60,
          margin: const pw.EdgeInsets.only(right: 12),
          child: pw.Image(pw.MemoryImage(logo), fit: pw.BoxFit.contain)),
    pw.Expanded(
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _t(st.str(b, 'name').isEmpty ? 'Your Business' : st.str(b, 'name'),
            size: 15, bold: true, color: _accent),
        if (st.str(b, 'category').isNotEmpty) _t(st.str(b, 'category'), color: _grey, size: 9),
        pw.SizedBox(height: 3),
        for (final l in businessLines) _t(l, size: 9),
      ]),
    ),
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
      _t(title, size: 20, bold: true, color: _accent),
      pw.SizedBox(height: 4),
      _t('No: ${d.number}', bold: true),
      _t('Date: ${st.fmtDate(d.date)}'),
      if (d.dueDate != null && d.type != DocType.receipt)
        _t('${d.type.dueLabel}: ${st.fmtDate(d.dueDate)}'),
      if (d.type == DocType.invoice || d.type == DocType.proforma || d.type == DocType.quotation)
        _t('Status: ${d.displayStatus}', color: _grey),
    ]),
  ]);

  final party = pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        color: _light,
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _t(d.type.partyLabel.toUpperCase(), size: 8, bold: true, color: _accent),
          pw.SizedBox(height: 3),
          _t(d.customer.name.isEmpty ? '-' : d.customer.name, bold: true, size: 11),
          if (d.customer.contact.isNotEmpty) _t('Attn: ${d.customer.contact}'),
          if (d.customer.address.isNotEmpty) _t(d.customer.address),
          if (d.customer.phone.isNotEmpty) _t('Tel: ${d.customer.phone}'),
          if (d.customer.email.isNotEmpty) _t(d.customer.email),
          if (d.customer.taxId.isNotEmpty) _t('Tax ID: ${d.customer.taxId}'),
        ]),
      ),
    ),
    if (st.flag(g, 'showShipping') && d.shipping.trim().isNotEmpty) ...[
      pw.SizedBox(width: 10),
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(8),
          color: _light,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            _t('SHIP TO', size: 8, bold: true, color: _accent),
            pw.SizedBox(height: 3),
            _t(d.shipping),
          ]),
        ),
      ),
    ],
  ]);

  // ----------------------------------------------------------- items table
  final col = (String k) => st.str('columns', k);
  final widths = <int, pw.TableColumnWidth>{
    0: const pw.FixedColumnWidth(22),
    1: const pw.FlexColumnWidth(4),
    2: const pw.FixedColumnWidth(42),
    if (prices) 3: const pw.FixedColumnWidth(62),
    if (prices && showTax) 4: const pw.FixedColumnWidth(42),
    if (prices) (showTax ? 5 : 4): const pw.FixedColumnWidth(72),
  };
  pw.Widget head(String s, [pw.TextAlign a = pw.TextAlign.left]) =>
      _cell(s, bold: true, align: a, color: PdfColors.white);

  final rows = <pw.TableRow>[
    pw.TableRow(decoration: const pw.BoxDecoration(color: _accent), children: [
      head('#'),
      head(col('item')),
      head(col('qty'), pw.TextAlign.right),
      if (prices) head(col('price'), pw.TextAlign.right),
      if (prices && showTax) head(col('tax'), pw.TextAlign.right),
      if (prices) head(col('amount'), pw.TextAlign.right),
    ]),
  ];
  for (var i = 0; i < d.items.length; i++) {
    final it = d.items[i];
    rows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
      children: [
        _cell('${i + 1}'),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            _t(it.name, size: 9.5, bold: true),
            if (it.desc.trim().isNotEmpty) _t(it.desc, size: 8.5, color: _grey),
          ]),
        ),
        _cell(_num(it.qty), align: pw.TextAlign.right),
        if (prices) _cell(_num(it.price, 2), align: pw.TextAlign.right),
        if (prices && showTax)
          _cell(it.taxPct == 0 ? '-' : '${_num(it.taxPct)}%', align: pw.TextAlign.right),
        if (prices) _cell(_num(it.amount, 2), align: pw.TextAlign.right),
      ],
    ));
  }

  pw.Widget totalLine(String l, String v, {bool bold = false, PdfColor? color}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          _t(l, bold: bold, color: color, size: bold ? 11 : 10),
          _t(v, bold: bold, color: color, size: bold ? 11 : 10),
        ]),
      );

  final totals = <pw.Widget>[];
  if (prices && d.type != DocType.receipt) {
    totals.add(totalLine('Subtotal', st.fmtMoney(d.subtotal)));
    if (showDiscount) {
      totals.add(totalLine(
          'Discount${d.discountPercent ? ' (${_num(d.discount)}%)' : ''}', '-${st.fmtMoney(d.discountAmt)}'));
    }
    if (showTax && d.taxTotal > 0) totals.add(totalLine('Tax', st.fmtMoney(d.taxTotal)));
    for (final c in d.charges) {
      if (c.amount != 0) totals.add(totalLine(c.label.isEmpty ? 'Other charge' : c.label, st.fmtMoney(c.amount)));
    }
    totals.add(pw.Divider(color: _accent, thickness: 1));
    totals.add(totalLine('TOTAL', st.fmtMoney(d.total), bold: true, color: _accent));
    if (d.type == DocType.invoice && d.paid > 0) {
      totals.add(totalLine('Paid', '-${st.fmtMoney(d.paid)}'));
      totals.add(totalLine('Balance due', st.fmtMoney(d.balance), bold: true));
    }
  }

  // ---------------------------------------------------------- receipt body
  final receiptBox = <pw.Widget>[];
  if (d.type == DocType.receipt) {
    receiptBox.add(pw.Container(
      margin: const pw.EdgeInsets.only(top: 14),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _accent)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _t('AMOUNT RECEIVED', size: 9, color: _grey),
        _t(st.fmtMoney(d.paid), size: 20, bold: true, color: _accent),
        pw.SizedBox(height: 6),
        if (d.paidMethod.isNotEmpty) _t('Payment method: ${d.paidMethod}'),
        if (d.reference.isNotEmpty) _t('Reference: ${d.reference}'),
        if (d.paidDate != null) _t('Payment date: ${st.fmtDate(d.paidDate)}'),
      ]),
    ));
  }

  // ------------------------------------------------------ payment / footer
  final bank = st.str(b, 'bankDetails');
  final showBank = st.flag(g, 'showBank') && bank.trim().isNotEmpty;
  final showQr = st.flag(g, 'showQr') && qr != null;
  final showSign = st.flag(g, 'showSignature');
  final showPay = d.type != DocType.receipt && d.type != DocType.deliveryNote;

  final footer = <pw.Widget>[
    if (showPay && (showBank || showQr))
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 14),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _t('PAYMENT INSTRUCTIONS', size: 8.5, bold: true, color: _accent),
              pw.SizedBox(height: 3),
              if (showBank) _t(bank),
            ]),
          ),
          if (showQr) pw.Container(width: 80, height: 80, child: pw.Image(pw.MemoryImage(qr!))),
        ]),
      ),
    if (d.type.hasTerms && d.terms.trim().isNotEmpty)
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 12),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _t('TERMS & CONDITIONS', size: 8.5, bold: true, color: _accent),
          pw.SizedBox(height: 3),
          _t(d.terms, size: 9),
        ]),
      ),
    if (d.notes.trim().isNotEmpty)
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _t('NOTES', size: 8.5, bold: true, color: _accent),
          pw.SizedBox(height: 3),
          _t(d.notes, size: 9),
        ]),
      ),
    if (st.str(g, 'bottomMsg').trim().isNotEmpty)
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 14),
        alignment: pw.Alignment.center,
        child: _t(st.str(g, 'bottomMsg'), align: pw.TextAlign.center, color: _grey),
      ),
    if (showSign)
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 24),
        alignment: pw.Alignment.centerRight,
        child: pw.Column(children: [
          pw.Container(
            width: 150,
            height: 50,
            child: sign != null ? pw.Image(pw.MemoryImage(sign), fit: pw.BoxFit.contain) : null,
          ),
          pw.Container(width: 150, height: 0.7, color: PdfColors.black),
          pw.SizedBox(height: 2),
          _t(st.str(b, 'contactName').isEmpty ? 'Authorised signature' : st.str(b, 'contactName'),
              size: 9),
        ]),
      ),
  ];

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    build: (ctx) => [
      header,
      pw.SizedBox(height: 14),
      party,
      if (st.str(g, 'topMsg').trim().isNotEmpty)
        pw.Padding(padding: const pw.EdgeInsets.only(top: 12), child: _t(st.str(g, 'topMsg'))),
      pw.SizedBox(height: 12),
      if (d.items.isNotEmpty || d.type != DocType.receipt)
        pw.Table(columnWidths: widths, children: rows),
      if (totals.isNotEmpty)
        pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.SizedBox(width: 220, child: pw.Column(children: totals)),
        ),
      ...receiptBox,
      ...footer,
    ],
  ));
  return doc.save();
}

String _num(double v, [int? dec]) {
  if (dec != null) return v.toStringAsFixed(dec);
  return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

/// Generic tabular report (sales report, statements ...).
Future<Uint8List> buildReportPdf({
  required String title,
  required String subtitle,
  required List<String> headers,
  required List<List<String>> rows,
  required List<String> summary,
}) async {
  final st = Store.i;
  final doc = pw.Document();
  final name = st.str('business', 'name');
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    margin: const pw.EdgeInsets.all(28),
    build: (ctx) => [
      _t(name.isEmpty ? 'Your Business' : name, size: 12, bold: true, color: _accent),
      _t(title, size: 18, bold: true, color: _accent),
      _t(subtitle, color: _grey),
      pw.SizedBox(height: 10),
      pw.Table(
        border: pw.TableBorder(
            horizontalInside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _accent),
            children: [for (final h in headers) _cell(h, bold: true, color: PdfColors.white)],
          ),
          for (final r in rows) pw.TableRow(children: [for (final c in r) _cell(c)]),
        ],
      ),
      pw.SizedBox(height: 12),
      for (final s in summary) _t(s, bold: true, size: 11),
    ],
  ));
  return doc.save();
}
