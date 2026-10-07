import 'package:flutter_test/flutter_test.dart';
import 'package:controle_gastos/main.dart';

void main() {
  testWidgets('app abre na tela de diagnostico (temporaria da Fase 2)', (tester) async {
    await tester.pumpWidget(const ControleGastosApp());
    expect(find.text('Diagnostico — Fase 2'), findsOneWidget);
  });
}
