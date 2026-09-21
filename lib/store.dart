import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// Local storage: SQLite for records, SharedPreferences for settings/account.
class Store {
  static final Store i = Store._();
  Store._();

  late Database db;
  late SharedPreferences prefs;
  late Directory dir;
  Map<String, dynamic> settings = {};
  Map<String, dynamic> account = {};

  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    dir = await getApplicationDocumentsDirectory();
    db = await openDatabase(
      p.join(await getDatabasesPath(), 'billing.db'),
      version: 1,
      onCreate: (d, v) async {
        await d.execute('CREATE TABLE customers(id INTEGER PRIMARY KEY AUTOINCREMENT, json TEXT)');
        await d.execute('CREATE TABLE products(id INTEGER PRIMARY KEY AUTOINCREMENT, json TEXT)');
        await d.execute(
            'CREATE TABLE docs(id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT, json TEXT)');
      },
    );
    settings = _dec(prefs.getString('settings'));
    account = _dec(prefs.getString('account'));
  }

  Map<String, dynamic> _dec(String? s) =>
      s == null ? {} : Map<String, dynamic>.from(jsonDecode(s));

  // ---------------------------------------------------------------- settings
  Map<String, dynamic> defaults(String g) {
    if (g == 'general') {
      return {'currency': 'RM', 'dateFormat': 'dd/MM/yyyy', 'decimals': 2};
    }
    if (g == 'columns') {
      return {
        'item': 'Item',
        'description': 'Description',
        'qty': 'Qty',
        'price': 'Price',
        'tax': 'Tax %',
        'amount': 'Amount',
      };
    }
    if (g.startsWith('doc_')) {
      final t = DocType.values.firstWhere((e) => 'doc_${e.key}' == g);
      return {
        'prefix': t.defaultPrefix,
        'serial': 1,
        'showDiscount': true,
        'showTax': true,
        'showShipping': false,
        'topMsg': '',
        'bottomMsg': 'Thank you for your business.',
        'showBank': true,
        'showQr': true,
        'showSignature': true,
        'terms': '',
        'receiptType': 'Payment Receipt',
      };
    }
    return {};
  }

  dynamic get(String g, String k) => (settings[g] as Map?)?[k] ?? defaults(g)[k];
  String str(String g, String k) => '${get(g, k) ?? ''}';
  bool flag(String g, String k) => get(g, k) == true;

  Future<void> set(String g, String k, dynamic v) async {
    final m = Map<String, dynamic>.from((settings[g] as Map?) ?? {});
    m[k] = v;
    settings[g] = m;
    await prefs.setString('settings', jsonEncode(settings));
  }

  Future<void> setMany(String g, Map<String, dynamic> vals) async {
    final m = Map<String, dynamic>.from((settings[g] as Map?) ?? {});
    m.addAll(vals);
    settings[g] = m;
    await prefs.setString('settings', jsonEncode(settings));
  }

  String get currency => str('general', 'currency');
  String fmtMoney(double v) {
    final dec = (get('general', 'decimals') as num).toInt();
    final f = NumberFormat.currency(symbol: '', decimalDigits: dec);
    final s = f.format(v.abs()).trim();
    return '${v < 0 ? '-' : ''}$currency $s'.trim();
  }

  String fmtDate(DateTime? d) {
    if (d == null) return '';
    try {
      return DateFormat(str('general', 'dateFormat')).format(d);
    } catch (_) {
      return DateFormat('dd/MM/yyyy').format(d);
    }
  }

  String nextNumber(DocType t) {
    final g = 'doc_${t.key}';
    final serial = (get(g, 'serial') as num).toInt();
    return '${str(g, 'prefix')}${serial.toString().padLeft(4, '0')}';
  }

  Future<void> _bump(DocType t) async {
    final g = 'doc_${t.key}';
    await set(g, 'serial', (get(g, 'serial') as num).toInt() + 1);
  }

  // ------------------------------------------------------------------ images
  Future<String> saveImage(String src, String name) async {
    final ext = p.extension(src).isEmpty ? '.png' : p.extension(src);
    final dest = p.join(dir.path, '${name}_${DateTime.now().millisecondsSinceEpoch}$ext');
    await File(src).copy(dest);
    return dest;
  }

  Future<String> saveBytes(Uint8List bytes, String name) async {
    final dest = p.join(dir.path, '${name}_${DateTime.now().millisecondsSinceEpoch}.png');
    await File(dest).writeAsBytes(bytes);
    return dest;
  }

  Uint8List? imageBytes(String path) {
    if (path.isEmpty) return null;
    final f = File(path);
    return f.existsSync() ? f.readAsBytesSync() : null;
  }

  // --------------------------------------------------------------- customers
  Future<List<Party>> customers() async {
    final rows = await db.query('customers');
    final l = rows
        .map((r) => Party.fromJson(jsonDecode(r['json'] as String), r['id'] as int))
        .toList();
    l.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return l;
  }

  Future<Party> saveCustomer(Party c) async {
    if (c.id == null) {
      c.id = await db.insert('customers', {'json': jsonEncode(c.toJson())});
    } else {
      await db.update('customers', {'json': jsonEncode(c.toJson())},
          where: 'id=?', whereArgs: [c.id]);
    }
    return c;
  }

  Future<void> deleteCustomer(int id) => db.delete('customers', where: 'id=?', whereArgs: [id]);

  // ---------------------------------------------------------------- products
  Future<List<LineItem>> products() async {
    final rows = await db.query('products');
    final l = rows
        .map((r) => LineItem.fromJson(jsonDecode(r['json'] as String), r['id'] as int))
        .toList();
    l.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return l;
  }

  Future<LineItem> saveProduct(LineItem c) async {
    final j = jsonEncode(c.toJson());
    if (c.id == null) {
      c.id = await db.insert('products', {'json': j});
    } else {
      await db.update('products', {'json': j}, where: 'id=?', whereArgs: [c.id]);
    }
    return c;
  }

  Future<void> deleteProduct(int id) => db.delete('products', where: 'id=?', whereArgs: [id]);

  // --------------------------------------------------------------- documents
  Future<List<DocModel>> docs(DocType t) async {
    final rows = await db.query('docs', where: 'type=?', whereArgs: [t.key], orderBy: 'id DESC');
    return rows
        .map((r) => DocModel.fromJson(t, jsonDecode(r['json'] as String), r['id'] as int))
        .toList();
  }

  Future<int> docCount(DocType t) async {
    final r = await db.rawQuery('SELECT COUNT(*) c FROM docs WHERE type=?', [t.key]);
    return (r.first['c'] as int?) ?? 0;
  }

  Future<void> saveDoc(DocModel d) async {
    final j = jsonEncode(d.toJson());
    if (d.id == null) {
      final isAuto = d.number == nextNumber(d.type);
      d.id = await db.insert('docs', {'type': d.type.key, 'json': j});
      if (isAuto) await _bump(d.type);
    } else {
      await db.update('docs', {'json': j}, where: 'id=?', whereArgs: [d.id]);
    }
  }

  Future<void> deleteDoc(int id) => db.delete('docs', where: 'id=?', whereArgs: [id]);

  // ----------------------------------------------------------------- account
  bool get hasAccount => account['email'] != null;
  bool get loggedIn => hasAccount && prefs.getBool('loggedIn') == true;

  String _hash(String pw) =>
      sha256.convert(utf8.encode('qim-salt:$pw')).toString();

  Future<void> _saveAccount() => prefs.setString('account', jsonEncode(account));

  Future<void> register(String name, String phone, String email, String pw) async {
    account = {'name': name, 'phone': phone, 'email': email.trim(), 'pw': _hash(pw), 'photo': ''};
    await _saveAccount();
    await prefs.setBool('loggedIn', true);
  }

  Future<bool> login(String email, String pw) async {
    final ok = account['email'] != null &&
        account['email'].toString().toLowerCase() == email.trim().toLowerCase() &&
        account['pw'] == _hash(pw);
    if (ok) await prefs.setBool('loggedIn', true);
    return ok;
  }

  Future<void> logout() => prefs.setBool('loggedIn', false);

  bool checkPassword(String pw) => account['pw'] == _hash(pw);

  Future<void> changePassword(String pw) async {
    account['pw'] = _hash(pw);
    await _saveAccount();
  }

  Future<void> updateAccount(Map<String, dynamic> vals) async {
    account.addAll(vals);
    await _saveAccount();
  }

  Future<void> deleteAccount() async {
    await db.delete('docs');
    await db.delete('customers');
    await db.delete('products');
    for (final f in dir.listSync()) {
      if (f is File && RegExp(r'\.(png|jpg|jpeg|webp)$', caseSensitive: false).hasMatch(f.path)) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
    await prefs.clear();
    settings = {};
    account = {};
  }
}
