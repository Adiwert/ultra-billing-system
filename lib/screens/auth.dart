import 'package:flutter/material.dart';

import '../store.dart';
import '../widgets.dart';
import 'home.dart';

/// Local account: register on first run, log in afterwards.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final st = Store.i;
  String name = '', phone = '', email = '', pw = '', pw2 = '';
  String? error;

  bool get register => !st.hasAccount;

  Future<void> _submit() async {
    setState(() => error = null);
    if (register) {
      if (name.trim().isEmpty || !email.contains('@')) {
        return setState(() => error = 'Enter your name and a valid email.');
      }
      if (pw.length < 6) return setState(() => error = 'Password must be at least 6 characters.');
      if (pw != pw2) return setState(() => error = 'Passwords do not match.');
      await st.register(name.trim(), phone.trim(), email, pw);
    } else {
      if (!await st.login(email, pw)) {
        return setState(() => error = 'Incorrect email or password.');
      }
    }
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Icon(Icons.receipt_long, size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 8),
                Text('Quote & Invoice Maker',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(register ? 'Create your account' : 'Welcome back',
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                if (register) ...[
                  Field('Name', name, (v) => name = v),
                  Field('Phone number', phone, (v) => phone = v, type: TextInputType.phone),
                ],
                Field('Email', email, (v) => email = v, type: TextInputType.emailAddress),
                Field('Password', pw, (v) => pw = v, obscure: true, type: TextInputType.visiblePassword),
                if (register)
                  Field('Confirm password', pw2, (v) => pw2 = v,
                      obscure: true, type: TextInputType.visiblePassword),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                FilledButton(onPressed: _submit, child: Text(register ? 'Create account' : 'Log in')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
