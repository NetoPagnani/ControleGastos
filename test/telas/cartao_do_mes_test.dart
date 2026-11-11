import 'package:controle_gastos/dominio/modelos.dart';
import 'package:controle_gastos/dominio/resumo.dart';
import 'package:controle_gastos/telas/cartao_do_mes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const itau = Conta(id: 'itau', apelido: 'Itaú', tipo: 'conta_debito');
const vr = Conta(id: 'vr', apelido: 'VR', tipo: 'beneficio');
const nubank = Conta(id: 'nu', apelido: 'Nubank', tipo: 'cartao_credito');

Lancamento gasto(String conta, int valor) => Lancamento(
      id: '$conta$valor',
      contaId: conta,
      categoriaId: 'k',
      valorCentavos: valor,
      data: DateTime(2026, 11, 5),
      compraId: '$conta$valor',
    );

Widget emTela(Widget w) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: w)));

void main() {
  final resumo = resumoDoMes(
    contas: const [itau, vr, nubank],
    entradas: const {'itau': 300000, 'vr': 60000},
    lancamentos: [gasto('itau', 80000), gasto('vr', 70000), gasto('nu', 120000)],
  );

  testWidgets('mostra entrou, gastou e sobra de cada conta, cartoes e total', (tester) async {
    await tester.pumpWidget(emTela(CartaoDoMes(nomeDoMes: 'novembro', resumo: resumo, informado: true, onInformar: () {})));
    expect(find.text('Itaú'), findsOneWidget);
    expect(find.textContaining('entrou 3.000,00 · gastou 800,00 · sobra 2.200,00'), findsOneWidget);
    expect(find.textContaining('sobra -100,00'), findsOneWidget);
    expect(find.textContaining('Cartões de crédito: gastou 1.200,00'), findsOneWidget);
    // Cartao (1.200) fora da sobra: 3.600 - 800 - 700.
    expect(find.textContaining('entrou 3.600,00 · gastou 1.500,00 · sobra 2.100,00'), findsOneWidget);
    expect(find.textContaining('fora da sobra'), findsOneWidget);
  });

  testWidgets('sem entradas do mes, pede para informar', (tester) async {
    var pediu = 0;
    await tester.pumpWidget(
      emTela(CartaoDoMes(nomeDoMes: 'novembro', resumo: resumo, informado: false, onInformar: () => pediu++)),
    );
    expect(find.textContaining('Quanto entrou em novembro?'), findsOneWidget);
    await tester.tap(find.text('Informar entradas'));
    expect(pediu, 1);
  });

  testWidgets('janela de entradas vem preenchida, so com contas que nao sao cartao, e devolve os valores', (tester) async {
    Map<String, int>? resultado;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => resultado = await pedirEntradas(
              context,
              nomeDoMes: 'novembro',
              contas: const [itau, vr, nubank],
              sugeridas: const {'itau': 300000},
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Nubank'), findsNothing);
    expect(find.widgetWithText(TextField, '3000,00'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'VR'), '600');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(resultado, {'itau': 300000, 'vr': 60000});
  });
}
