import 'package:flutter/material.dart';

import 'telas/diagnostico.dart';

void main() {
  runApp(const ControleGastosApp());
}

class ControleGastosApp extends StatelessWidget {
  const ControleGastosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Controle de Gastos',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF10B981), useMaterial3: true),
      // Temporario (Fase 2): tela de diagnostico do banco local.
      // A Fase 3 troca isto pelas telas reais.
      home: const TelaDiagnostico(),
    );
  }
}
