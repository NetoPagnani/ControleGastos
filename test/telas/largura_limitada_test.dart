import 'package:controle_gastos/telas/largura_limitada.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<double> larguraDoConteudo(WidgetTester tester, Size tela) async {
    tester.view.physicalSize = tela;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LarguraLimitada(child: SizedBox.expand(key: Key('conteudo'))))),
    );
    return tester.getSize(find.byKey(const Key('conteudo'))).width;
  }

  testWidgets('no computador o conteudo nao passa da largura de celular', (tester) async {
    expect(await larguraDoConteudo(tester, const Size(1400, 900)), LarguraLimitada.maxima);
  });

  testWidgets('no celular o conteudo usa a tela toda', (tester) async {
    expect(await larguraDoConteudo(tester, const Size(390, 800)), 390);
  });
}
