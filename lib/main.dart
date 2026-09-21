import 'package:flutter/material.dart';

import 'screens/auth.dart';
import 'screens/home.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.i.init();
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});
  static _AppState of(BuildContext c) => c.findAncestorStateOfType<_AppState>()!;
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  void refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1F4E79));
    return MaterialApp(
      title: 'Quote & Invoice Maker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        appBarTheme: AppBarTheme(backgroundColor: scheme.primary, foregroundColor: scheme.onPrimary),
        inputDecorationTheme: const InputDecorationTheme(isDense: true),
      ),
      builder: (context, child) {
        // Keep text scaling sane so layouts fit small and large screens.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.3)),
          child: child!,
        );
      },
      home: Store.i.loggedIn ? const HomeScreen() : const AuthScreen(),
    );
  }
}
