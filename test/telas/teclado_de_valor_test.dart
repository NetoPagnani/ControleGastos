import 'package:controle_gastos/telas/teclado_de_valor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> teclas;
  late int confirmacoes;

  Future<void> mostrar(WidgetTester tester) async {
    teclas = [];
    confirmacoes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TecladoDeValor(onTecla: teclas.add, onConfirmar: () => confirmacoes++),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('numeros do teclado do computador e do teclado numerico entram no valor', (tester) async {
    await mostrar(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad2);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    expect(teclas, ['1', '2', '0']);
  });

  testWidgets('backspace apaga e Enter continua', (tester) async {
    await mostrar(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
    expect(teclas, ['⌫']);
    expect(confirmacoes, 2);
  });

  testWidgets('tocar nas teclas da tela continua funcionando', (tester) async {
    await mostrar(tester);
    await tester.tap(find.text('7'));
    await tester.tap(find.text('⌫'));
    expect(teclas, ['7', '⌫']);
  });
}
