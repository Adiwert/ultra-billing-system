import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'auth.dart';
import 'home.dart' show docIcons;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final st = Store.i;

  Future<void> _go(Widget w) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    if (mounted) setState(() {});
  }

  Widget _tile(IconData i, String t, Widget page, {String? sub}) => ListTile(
        leading: Icon(i),
        title: Text(t),
        subtitle: sub == null ? null : Text(sub),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _go(page),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(children: [
        const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: Text('ACCOUNT', style: TextStyle(fontWeight: FontWeight.bold))),
        _tile(Icons.person_outline, 'Profile', const ProfileScreen(),
            sub: '${st.account['name'] ?? ''}  ${st.account['email'] ?? ''}'),
        _tile(Icons.business, 'Business info', const BusinessScreen(),
            sub: st.str('business', 'name')),
        ListTile(
          leading: const Icon(Icons.workspace_premium_outlined),
          title: const Text('Subscription'),
          subtitle: const Text('Coming soon'),
          onTap: () => toast(context, 'Subscription plans are coming soon.'),
        ),
        const Divider(),
        const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 0), child: Text('DOCUMENT SETTINGS', style: TextStyle(fontWeight: FontWeight.bold))),
        for (final t in DocType.values)
          _tile(docIcons[t]!, '${t.label} settings', DocSettingsScreen(type: t),
              sub: 'Next no: ${st.nextNumber(t)}'),
        _tile(Icons.view_column_outlined, 'Column headings', const ColumnsScreen()),
        _tile(Icons.language, 'Date & currency', const GeneralScreen(),
            sub: '${st.currency}  •  ${st.str('general', 'dateFormat')}'),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Logout'),
          onTap: () async {
            if (await confirm(context, 'Log out?', 'You can log back in with your email and password.', ok: 'Logout')) {
              await st.logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                  context, MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
            }
          },
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}

// ------------------------------------------------------------------ profile
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final st = Store.i;
  late String name = '${st.account['name'] ?? ''}';
  late String phone = '${st.account['phone'] ?? ''}';
  late String email = '${st.account['email'] ?? ''}';
  late String photo = '${st.account['photo'] ?? ''}';

  Future<void> _changePassword() async {
    String cur = '', n1 = '', n2 = '';
    String? err;
    await showDialog(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (dc, setD) => AlertDialog(
          title: const Text('Change password'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Field('Current password', cur, (v) => cur = v, obscure: true, type: TextInputType.visiblePassword),
              Field('New password', n1, (v) => n1 = v, obscure: true, type: TextInputType.visiblePassword),
              Field('Confirm new password', n2, (v) => n2 = v, obscure: true, type: TextInputType.visiblePassword),
              if (err != null) Text(err!, style: TextStyle(color: Theme.of(dc).colorScheme.error)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (!st.checkPassword(cur)) return setD(() => err = 'Current password is incorrect.');
                if (n1.length < 6) return setD(() => err = 'New password must be at least 6 characters.');
                if (n1 != n2) return setD(() => err = 'Passwords do not match.');
                await st.changePassword(n1);
                if (dc.mounted) Navigator.pop(dc);
                if (mounted) toast(context, 'Password changed');
              },
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Delete account?',
        'This permanently erases your account, business info, customers, products and ALL documents on this device.',
        ok: 'Delete everything')) {
      return;
    }
    await st.deleteAccount();
    if (!mounted) return;
    App.of(context).refresh();
    Navigator.pushAndRemoveUntil(
        context, MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            ImageField('Profile picture', photo, (p) {
              photo = p;
              st.updateAccount({'photo': p});
            }, circle: true, size: 88),
            Field('Name', name, (v) => name = v),
            Field('Phone number', phone, (v) => phone = v, type: TextInputType.phone),
            Field('Email', email, (v) => email = v, type: TextInputType.emailAddress),
            FilledButton(
              onPressed: () async {
                await st.updateAccount({'name': name.trim(), 'phone': phone.trim(), 'email': email.trim()});
                if (mounted) toast(context, 'Profile saved');
              },
              child: const Text('Save profile'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
                onPressed: _changePassword, icon: const Icon(Icons.lock_outline), label: const Text('Change password')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _delete,
              icon: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
              label: Text('Delete account', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ]),
        ),
      );
}

// ----------------------------------------------------------------- business
const businessCategories = [
  'Retail', 'Wholesale', 'Services', 'Consulting', 'Construction', 'Manufacturing', 'Food & Beverage',
  'IT / Software', 'Education', 'Healthcare', 'Transport & Logistics', 'Freelancer', 'Other',
];

class BusinessScreen extends StatefulWidget {
  const BusinessScreen({super.key});
  @override
  State<BusinessScreen> createState() => _BusinessScreenState();
}

class _BusinessScreenState extends State<BusinessScreen> {
  final st = Store.i;
  static const g = 'business';

  Field _f(String label, String key, {int lines = 1, TextInputType? type}) =>
      Field(label, st.str(g, key), (v) => st.set(g, key, v), maxLines: lines, type: type);

  @override
  Widget build(BuildContext context) {
    final cat = st.str(g, 'category');
    return Scaffold(
      appBar: AppBar(title: const Text('Business info')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          ImageField('Company logo', st.str(g, 'logo'), (p) => st.set(g, 'logo', p)),
          _f('Business name', 'name'),
          _f('Contact name', 'contactName'),
          _f('Email', 'email', type: TextInputType.emailAddress),
          _f('Phone number', 'phone', type: TextInputType.phone),
          _f('Address line 1', 'address1'),
          _f('Address line 2', 'address2'),
          _f('Address line 3', 'address3'),
          _f('Other info (website, registration no. ...)', 'other', lines: 3),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              initialValue: businessCategories.contains(cat) ? cat : null,
              decoration: const InputDecoration(labelText: 'Business category', border: OutlineInputBorder()),
              items: [for (final c in businessCategories) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => st.set(g, 'category', v ?? ''),
            ),
          ),
          _f('Tax details (e.g. SST / GST / VAT no.)', 'taxDetails', lines: 2),
          const SectionTitle('Signature'),
          ImageField('Signature', st.str(g, 'signature'), (p) => st.set(g, 'signature', p), signatureDraw: true),
          const SectionTitle('Payment instructions'),
          _f('Bank details (bank, account name, account no.)', 'bankDetails', lines: 4),
          ImageField('Payment QR code', st.str(g, 'paymentQr'), (p) => st.set(g, 'paymentQr', p), size: 110),
          const Text('Changes are saved automatically.', style: TextStyle(color: Colors.grey)),
        ]),
      ),
    );
  }
}

// -------------------------------------------------------- document settings
class DocSettingsScreen extends StatefulWidget {
  final DocType type;
  const DocSettingsScreen({super.key, required this.type});
  @override
  State<DocSettingsScreen> createState() => _DocSettingsScreenState();
}

class _DocSettingsScreenState extends State<DocSettingsScreen> {
  final st = Store.i;
  DocType get t => widget.type;
  String get g => 'doc_${t.key}';

  Widget _sw(String label, String key, {String? sub}) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: sub == null ? null : Text(sub),
        value: st.flag(g, key),
        onChanged: (v) async {
          await st.set(g, key, v);
          setState(() {});
        },
      );

  @override
  Widget build(BuildContext context) {
    final isReceipt = t == DocType.receipt;
    final isDN = t == DocType.deliveryNote;
    final l = t.label.toLowerCase();
    return Scaffold(
      appBar: AppBar(title: Text('${t.label} settings')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Field('Number prefix', st.str(g, 'prefix'), (v) => st.set(g, 'prefix', v),
              type: TextInputType.text),
          Field('Serial number (next number)', st.str(g, 'serial'),
              (v) => st.set(g, 'serial', int.tryParse(v.trim()) ?? 1),
              type: TextInputType.number, hint: 'Next: ${st.nextNumber(t)}'),
          if (isReceipt)
            Field('Receipt type', st.str(g, 'receiptType'), (v) => st.set(g, 'receiptType', v),
                hint: 'e.g. Payment Receipt, Official Receipt'),
          if (!isReceipt && !isDN) ...[
            _sw('Discount display', 'showDiscount'),
            _sw('Tax display', 'showTax'),
          ],
          if (!isReceipt) _sw('Shipping address display', 'showShipping'),
          if (!isReceipt) ...[
            Field('Top message', st.str(g, 'topMsg'), (v) => st.set(g, 'topMsg', v),
                maxLines: 3, hint: 'Shown above the item table'),
            Field('Bottom message', st.str(g, 'bottomMsg'), (v) => st.set(g, 'bottomMsg', v),
                maxLines: 3, hint: 'Shown at the end of the $l'),
            Field('Default terms & conditions', st.str(g, 'terms'), (v) => st.set(g, 'terms', v), maxLines: 5),
          ],
          if (!isReceipt && !isDN) ...[
            _sw('Payment instruction – bank information', 'showBank'),
            _sw('Payment instruction – bank QR', 'showQr'),
          ],
          _sw('Signature display', 'showSignature'),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------- column headings
class ColumnsScreen extends StatelessWidget {
  const ColumnsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final st = Store.i;
    const labels = {
      'item': 'Item column',
      'description': 'Description column',
      'qty': 'Quantity column',
      'price': 'Price column',
      'tax': 'Tax column',
      'amount': 'Amount column',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Column headings')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          for (final e in labels.entries)
            Field(e.value, st.str('columns', e.key), (v) => st.set('columns', e.key, v)),
          TextButton(
            onPressed: () async {
              await st.settings.remove('columns');
              await st.set('columns', 'item', st.defaults('columns')['item']);
              if (context.mounted) {
                Navigator.pop(context);
                toast(context, 'Column headings reset');
              }
            },
            child: const Text('Reset to default'),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------- date & currency
class GeneralScreen extends StatefulWidget {
  const GeneralScreen({super.key});
  @override
  State<GeneralScreen> createState() => _GeneralScreenState();
}

class _GeneralScreenState extends State<GeneralScreen> {
  final st = Store.i;
  static const formats = ['dd/MM/yyyy', 'MM/dd/yyyy', 'yyyy-MM-dd', 'dd MMM yyyy', 'MMM dd, yyyy'];
  static const currencies = ['RM', 'MYR', 'SGD', 'USD', 'EUR', 'GBP', 'AUD', 'CNY', 'HKD', 'IDR', 'THB', 'INR', 'JPY'];

  @override
  Widget build(BuildContext context) {
    final fmt = st.str('general', 'dateFormat');
    final dec = (st.get('general', 'decimals') as num).toInt();
    return Scaffold(
      appBar: AppBar(title: const Text('Date & currency')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Field('Currency symbol / code', st.currency, (v) => st.set('general', 'currency', v.trim()),
              hint: 'e.g. RM, \$, SGD'),
          Wrap(spacing: 8, children: [
            for (final c in currencies)
              ActionChip(label: Text(c), onPressed: () async {
                await st.set('general', 'currency', c);
                setState(() {});
              }),
          ]),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: formats.contains(fmt) ? fmt : formats.first,
            decoration: const InputDecoration(labelText: 'Date format', border: OutlineInputBorder()),
            items: [
              for (final f in formats)
                DropdownMenuItem(value: f, child: Text('$f   (${_preview(f)})')),
            ],
            onChanged: (v) async {
              await st.set('general', 'dateFormat', v);
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: dec,
            decoration: const InputDecoration(labelText: 'Decimal places', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 0, child: Text('0')),
              DropdownMenuItem(value: 2, child: Text('2')),
              DropdownMenuItem(value: 3, child: Text('3')),
            ],
            onChanged: (v) async {
              await st.set('general', 'decimals', v ?? 2);
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
          Text('Preview: ${st.fmtMoney(1234.5)}  •  ${st.fmtDate(DateTime.now())}'),
        ]),
      ),
    );
  }

  String _preview(String f) => DateFormat(f).format(DateTime(2026, 9, 21));
}
