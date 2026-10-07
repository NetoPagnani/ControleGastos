import 'package:flutter/material.dart';
import 'package:powersync/powersync.dart' show PowerSyncDatabase;

import 'contas.dart';
import 'configuracoes.dart';
import 'gastos.dart';
import 'graficos.dart';
import 'inicio.dart';
import 'lancar_gasto.dart';

/// Casca de navegacao: Inicio, Gastos, Graficos, Contas, Config, mais o
/// botao de lancar. A barra tem 5 abas; o botao de lancar fica flutuante
/// em vez de centralizado, para caber sem notch customizado.
class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key, required this.db});

  final PowerSyncDatabase db;

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  int _aba = 0;

  Future<void> _lancar() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => TelaLancarGasto(db: widget.db)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final telas = [
      TelaInicio(db: widget.db),
      TelaGastos(db: widget.db),
      TelaGraficos(db: widget.db),
      TelaContas(db: widget.db),
      TelaConfiguracoes(db: widget.db),
    ];
    return Scaffold(
      body: IndexedStack(index: _aba, children: telas),
      floatingActionButton: FloatingActionButton(onPressed: _lancar, child: const Icon(Icons.add)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (i) => setState(() => _aba = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Gastos'),
          NavigationDestination(icon: Icon(Icons.pie_chart), label: 'Gráficos'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'Contas'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Config'),
        ],
      ),
    );
  }
}
