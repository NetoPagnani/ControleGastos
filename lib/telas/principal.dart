import 'package:flutter/material.dart';
import 'package:powersync/powersync.dart' show PowerSyncDatabase;

import 'contas.dart';
import 'configuracoes.dart';
import 'gastos.dart';
import 'lancar_gasto.dart';

/// Casca de navegacao da Fase 3: Gastos, Contas e Configuracoes, mais o
/// botao central de lancar. Inicio e Graficos entram na Fase 4.
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
      TelaGastos(db: widget.db),
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
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Gastos'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'Contas'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Config'),
        ],
      ),
    );
  }
}
