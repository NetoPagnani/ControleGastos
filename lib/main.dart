import 'package:flutter/material.dart';
import 'package:powersync/powersync.dart' show PowerSyncDatabase;

import 'core/usuario_atual.dart';
import 'dados/banco.dart';
import 'dados/repositorios.dart';
import 'telas/principal.dart';

void main() {
  runApp(const ControleGastosApp());
}

class ControleGastosApp extends StatelessWidget {
  const ControleGastosApp({super.key});

  Future<PowerSyncDatabase> _iniciar() async {
    final db = await abrirBanco();
    // Sem login ainda (Fase 5): garante as categorias padrao uma vez.
    await CategoriasRepositorio(db).garantirPadroes(usuarioAtualId);
    return db;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Controle de Gastos',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF10B981), useMaterial3: true),
      home: FutureBuilder<PowerSyncDatabase>(
        future: _iniciar(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Scaffold(body: Center(child: Text('Erro ao abrir o banco: ${snap.error}')));
          }
          if (!snap.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return TelaPrincipal(db: snap.data!);
        },
      ),
    );
  }
}
