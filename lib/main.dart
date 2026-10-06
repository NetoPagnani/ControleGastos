import 'package:flutter/material.dart';

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
      home: const Scaffold(
        body: Center(child: Text('Controle de Gastos')),
      ),
    );
  }
}
