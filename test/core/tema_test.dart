import 'package:controle_gastos/core/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Botao numa linha (o "Salvar" da renda, em Configuracoes) e nas acoes de
  // um dialogo: com largura minima infinita no tema, a tela inteira quebrava.
  testWidgets('botoes do tema cabem numa linha e num dialogo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: construirTema(),
        home: Scaffold(
          body: Column(
            children: [
              Row(
                children: [
                  const Expanded(child: TextField()),
                  FilledButton(onPressed: () {}, child: const Text('Salvar')),
                  OutlinedButton(onPressed: () {}, child: const Text('Outro')),
                ],
              ),
              AlertDialog(
                actions: [FilledButton(onPressed: () {}, child: const Text('Apagar'))],
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.widgetWithText(FilledButton, 'Salvar')).height, greaterThanOrEqualTo(50));
  });
}
