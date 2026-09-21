import 'dart:convert';

enum DocType { quotation, invoice, purchaseOrder, proforma, deliveryNote, receipt }

extension DocTypeX on DocType {
  String get key => name;
  String get label => const {
        DocType.quotation: 'Quotation',
        DocType.invoice: 'Invoice',
        DocType.purchaseOrder: 'Purchase Order',
        DocType.proforma: 'Proforma Invoice',
        DocType.deliveryNote: 'Delivery Note',
        DocType.receipt: 'Receipt',
      }[this]!;
  String get plural => this == DocType.proforma ? 'Proforma Invoices' : '${label}s';
  String get partyLabel => const {
        DocType.quotation: 'Quote To',
        DocType.invoice: 'Bill To',
        DocType.purchaseOrder: 'Vendor / Supplier',
        DocType.proforma: 'Bill To',
        DocType.deliveryNote: 'Deliver To',
        DocType.receipt: 'Received From',
      }[this]!;
  String get defaultPrefix => const {
        DocType.quotation: 'QUO-',
        DocType.invoice: 'INV-',
        DocType.purchaseOrder: 'PO-',
        DocType.proforma: 'PI-',
        DocType.deliveryNote: 'DN-',
        DocType.receipt: 'REC-',
      }[this]!;
  String get dueLabel => const {
        DocType.quotation: 'Valid until',
        DocType.invoice: 'Due date',
        DocType.purchaseOrder: 'Delivery date',
        DocType.proforma: 'Due date',
        DocType.deliveryNote: 'Delivery date',
        DocType.receipt: 'Date',
      }[this]!;
  List<String> get statuses => const {
        DocType.quotation: ['Draft', 'Sent', 'Accepted', 'Rejected'],
        DocType.purchaseOrder: ['Draft', 'Sent', 'Received', 'Cancelled'],
        DocType.proforma: ['Draft', 'Sent', 'Converted'],
        DocType.deliveryNote: ['Draft', 'Delivered'],
        DocType.invoice: <String>[],
        DocType.receipt: <String>[],
      }[this]!;
  bool get hasPrices => this != DocType.deliveryNote;
  bool get hasExtras => this != DocType.deliveryNote && this != DocType.receipt;
  bool get hasTerms => this != DocType.receipt;
  bool get hasPaid => this == DocType.invoice || this == DocType.receipt;
}

int _uidCounter = DateTime.now().microsecondsSinceEpoch;
int nextUid() => _uidCounter++;

double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

class Party {
  int? id;
  String name, contact, email, phone, address, shipping, taxId;
  Party({
    this.id,
    this.name = '',
    this.contact = '',
    this.email = '',
    this.phone = '',
    this.address = '',
    this.shipping = '',
    this.taxId = '',
  });
  Map<String, dynamic> toJson() => {
        'name': name,
        'contact': contact,
        'email': email,
        'phone': phone,
        'address': address,
        'shipping': shipping,
        'taxId': taxId,
      };
  factory Party.fromJson(Map<String, dynamic> j, [int? id]) => Party(
        id: id,
        name: j['name'] ?? '',
        contact: j['contact'] ?? '',
        email: j['email'] ?? '',
        phone: j['phone'] ?? '',
        address: j['address'] ?? '',
        shipping: j['shipping'] ?? '',
        taxId: j['taxId'] ?? '',
      );
}

class LineItem {
  int uid = nextUid();
  int? id; // set when stored as a saved product
  String name, desc;
  double qty, price, taxPct;
  LineItem({this.id, this.name = '', this.desc = '', this.qty = 1, this.price = 0, this.taxPct = 0});
  double get amount => qty * price;
  double get tax => amount * taxPct / 100;
  Map<String, dynamic> toJson() =>
      {'name': name, 'desc': desc, 'qty': qty, 'price': price, 'taxPct': taxPct};
  factory LineItem.fromJson(Map<String, dynamic> j, [int? id]) => LineItem(
        id: id,
        name: j['name'] ?? '',
        desc: j['desc'] ?? '',
        qty: _d(j['qty']),
        price: _d(j['price']),
        taxPct: _d(j['taxPct']),
      );
  LineItem copy() => LineItem(name: name, desc: desc, qty: qty, price: price, taxPct: taxPct);
}

class Charge {
  int uid = nextUid();
  String label;
  double amount;
  Charge({this.label = '', this.amount = 0});
  Map<String, dynamic> toJson() => {'label': label, 'amount': amount};
  factory Charge.fromJson(Map<String, dynamic> j) =>
      Charge(label: j['label'] ?? '', amount: _d(j['amount']));
}

class DocModel {
  int? id;
  DocType type;
  String number;
  DateTime date;
  DateTime? dueDate;
  Party customer;
  List<LineItem> items;
  List<Charge> charges;
  double discount;
  bool discountPercent;
  String shipping, terms, notes, status;
  double paid;
  String paidMethod;
  DateTime? paidDate;
  String receiptType, reference;

  DocModel({
    this.id,
    required this.type,
    required this.number,
    DateTime? date,
    this.dueDate,
    Party? customer,
    List<LineItem>? items,
    List<Charge>? charges,
    this.discount = 0,
    this.discountPercent = false,
    this.shipping = '',
    this.terms = '',
    this.notes = '',
    this.status = 'Draft',
    this.paid = 0,
    this.paidMethod = '',
    this.paidDate,
    this.receiptType = '',
    this.reference = '',
  })  : date = date ?? DateTime.now(),
        customer = customer ?? Party(),
        items = items ?? [],
        charges = charges ?? [];

  double get subtotal => items.fold(0.0, (s, i) => s + i.amount);
  double get discountAmt => discountPercent ? subtotal * discount / 100 : discount;
  double get taxTotal {
    final ratio = subtotal == 0 ? 1.0 : (subtotal - discountAmt) / subtotal;
    return items.fold(0.0, (s, i) => s + i.tax * ratio);
  }

  double get chargesTotal => charges.fold(0.0, (s, c) => s + c.amount);
  double get total => subtotal - discountAmt + taxTotal + chargesTotal;
  double get balance => total - paid;

  String get displayStatus {
    if (type == DocType.invoice) {
      if (total > 0 && paid >= total - 0.005) return 'Paid';
      if (paid > 0) return 'Partial';
      if (dueDate != null && dueDate!.isBefore(DateTime.now())) return 'Overdue';
      return 'Unpaid';
    }
    if (type == DocType.receipt) return 'Received';
    return status;
  }

  Map<String, dynamic> toJson() => {
        'number': number,
        'date': date.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'customer': customer.toJson(),
        'customerId': customer.id,
        'items': items.map((e) => e.toJson()).toList(),
        'charges': charges.map((e) => e.toJson()).toList(),
        'discount': discount,
        'discountPercent': discountPercent,
        'shipping': shipping,
        'terms': terms,
        'notes': notes,
        'status': status,
        'paid': paid,
        'paidMethod': paidMethod,
        'paidDate': paidDate?.toIso8601String(),
        'receiptType': receiptType,
        'reference': reference,
      };

  factory DocModel.fromJson(DocType type, Map<String, dynamic> j, int id) {
    final c = Party.fromJson(Map<String, dynamic>.from(j['customer'] ?? {}), j['customerId']);
    return DocModel(
      id: id,
      type: type,
      number: j['number'] ?? '',
      date: DateTime.tryParse(j['date'] ?? '') ?? DateTime.now(),
      dueDate: j['dueDate'] == null ? null : DateTime.tryParse(j['dueDate']),
      customer: c,
      items: ((j['items'] ?? []) as List)
          .map((e) => LineItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      charges: ((j['charges'] ?? []) as List)
          .map((e) => Charge.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      discount: _d(j['discount']),
      discountPercent: j['discountPercent'] ?? false,
      shipping: j['shipping'] ?? '',
      terms: j['terms'] ?? '',
      notes: j['notes'] ?? '',
      status: j['status'] ?? 'Draft',
      paid: _d(j['paid']),
      paidMethod: j['paidMethod'] ?? '',
      paidDate: j['paidDate'] == null ? null : DateTime.tryParse(j['paidDate']),
      receiptType: j['receiptType'] ?? '',
      reference: j['reference'] ?? '',
    );
  }

  /// Deep copy via JSON, used for duplicate / convert.
  DocModel clone() => DocModel.fromJson(type, jsonDecode(jsonEncode(toJson())), id ?? 0)..id = null;
}
