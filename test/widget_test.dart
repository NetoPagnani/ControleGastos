import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_gastos/main.dart';

void main() {
  testWidgets('app abre sem travar enquanto o banco carrega', (tester) async {
    await tester.pumpWidget(const ControleGastosApp());
    // Sem plugins nativos no ambiente de teste, a abertura do banco nao
    // termina; o importante aqui e so o app nao travar na primeira tela.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
