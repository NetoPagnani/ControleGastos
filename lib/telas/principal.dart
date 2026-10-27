import 'package:flutter/material.dart';

import '../dados/gravacao.dart';
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

/// O botao de lancar gasto so aparece onde se olha os gastos: Inicio e
/// Gastos. Nas outras abas ele cobria conteudo e nao tinha relacao com a tela.
bool mostraBotaoLancar(int aba) => aba <= 1;

const _telas = [
  TelaInicio(),
  TelaGastos(),
  TelaGraficos(),
  TelaContas(),
  TelaConfiguracoes(),
];

/// Casca de navegacao. Em janela estreita (celular) usa barra inferior;
/// em janela larga (navegador redimensionado, tablet) usa barra lateral —
/// mesmas telas, so o menu muda de lugar, como o Windows nativo faria.
///
/// O botao de lancar gasto fica aqui, no Scaffold que envolve as 5 abas,
/// e aparece so nas abas de mostraBotaoLancar.
class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  int _aba = 0;
  static const _larguraMinimaParaBarraLateral = 700.0;

  @override
  void initState() {
    super.initState();
    erroDeGravacao.addListener(_avisarErroDeGravacao);
  }

  @override
  void dispose() {
    erroDeGravacao.removeListener(_avisarErroDeGravacao);
    super.dispose();
  }

  /// Gravacoes nao esperam o servidor (ver gravacao.dart); se uma falhar
  /// depois, o aviso aparece aqui, em qualquer aba.
  void _avisarErroDeGravacao() {
    final texto = erroDeGravacao.value;
    if (texto == null || !mounted) return;
    erroDeGravacao.value = null;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _lancar() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const TelaLancarGasto()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conteudo = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: IndexedStack(index: _aba, children: _telas),
      ),
    );

    return LayoutBuilder(
      builder: (context, restricoes) {
        final telaLarga = restricoes.maxWidth >= _larguraMinimaParaBarraLateral;

        if (!telaLarga) {
          return Scaffold(
            body: conteudo,
            floatingActionButton: mostraBotaoLancar(_aba)
                ? FloatingActionButton(onPressed: _lancar, child: const Icon(Icons.add))
                : null,
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
                leading: mostraBotaoLancar(_aba)
                    ? FloatingActionButton(onPressed: _lancar, child: const Icon(Icons.add))
                    : null,
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
