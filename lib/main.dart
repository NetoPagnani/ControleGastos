import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:powersync/powersync.dart' show PowerSyncDatabase;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_config.dart';
import 'core/tema.dart';
import 'dados/banco.dart';
import 'telas/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseChavePublica);
  runApp(const ControleGastosApp());
}

class ControleGastosApp extends StatelessWidget {
  const ControleGastosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Controle de Gastos',
      debugShowCheckedModeBanner: false,
      theme: construirTema(),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: FutureBuilder<PowerSyncDatabase>(
        future: abrirBanco(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Scaffold(body: Center(child: Text('Erro ao abrir o banco: ${snap.error}')));
          }
          if (!snap.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return AuthGate(db: snap.data!);
        },
      ),
    );
  }
}
