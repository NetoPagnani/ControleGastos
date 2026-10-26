import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:powersync/powersync.dart' show PowerSyncDatabase;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_config.dart';
import 'core/tema.dart';
import 'dados/banco.dart';
import 'dados/provedores.dart';
import 'telas/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseChavePublica);
  runApp(const ControleGastosApp());
}

class ControleGastosApp extends StatefulWidget {
  const ControleGastosApp({super.key});

  @override
  State<ControleGastosApp> createState() => _ControleGastosAppState();
}

class _ControleGastosAppState extends State<ControleGastosApp> {
  // Aberto uma vez so. Chamar abrirBanco() dentro do build criava uma
  // instancia nova do PowerSync a cada reconstrucao (hot reload, por exemplo).
  late final Future<PowerSyncDatabase> _banco = abrirBanco();

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
        future: _banco,
        builder: (context, snap) {
          if (snap.hasError) {
            return Scaffold(body: Center(child: Text('Erro ao abrir o banco: ${snap.error}')));
          }
          if (!snap.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          // Repositorios montados aqui, uma vez, e disponiveis pra
          // qualquer tela abaixo na arvore (ver dados/provedores.dart).
          return MultiProvider(
            providers: provedoresDeDados(snap.data!),
            child: const AuthGate(),
          );
        },
      ),
    );
  }
}
