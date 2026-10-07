import 'package:flutter/material.dart';
import 'package:powersync/powersync.dart' show PowerSyncDatabase;

import 'contas.dart';
import 'configuracoes.dart';
import 'gastos.dart';
import 'graficos.dart';
import 'inicio.dart';
import 'lancar_gasto.dart';

const _destinos = [
  (icone: Icons.home, rotulo: 'Início'),
  (icone: Icons.receipt_long, rotulo: 'Gastos'),
  (icone: Icons.pie_chart, rotulo: 'Gráficos'),
  (icone: Icons.account_balance_wallet, rotulo: 'Contas'),
  (icone: Icons.settings, rotulo: 'Config'),
];

/// Casca de navegacao. Em janela estreita (celular) usa barra inferior;
/// em janela larga (navegador redimensionado, tablet) usa barra lateral —
/// mesmas telas, so o menu muda de lugar, como o Windows nativo faria.
class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key, required this.db});

  final PowerSyncDatabase db;

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  int _aba = 0;
  static const _larguraMinimaParaBarraLateral = 700.0;

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
    final conteudo = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: IndexedStack(index: _aba, children: telas),
      ),
    );

    return LayoutBuilder(
      builder: (context, restricoes) {
        final telaLarga = restricoes.maxWidth >= _larguraMinimaParaBarraLateral;

        if (!telaLarga) {
          return Scaffold(
            body: conteudo,
            floatingActionButton: FloatingActionButton(onPressed: _lancar, child: const Icon(Icons.add)),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _aba,
              onDestinationSelected: (i) => setState(() => _aba = i),
              destinations: [
                for (final d in _destinos) NavigationDestination(icon: Icon(d.icone), label: d.rotulo),
              ],
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _aba,
                onDestinationSelected: (i) => setState(() => _aba = i),
                labelType: NavigationRailLabelType.all,
                leading: FloatingActionButton(onPressed: _lancar, child: const Icon(Icons.add)),
                destinations: [
                  for (final d in _destinos) NavigationRailDestination(icon: Icon(d.icone), label: Text(d.rotulo)),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: conteudo),
            ],
          ),
        );
      },
    );
  }
}
