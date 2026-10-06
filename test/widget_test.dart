import 'package:flutter_test/flutter_test.dart';
import 'package:controle_gastos/main.dart';

void main() {
  testWidgets('app abre na tela inicial', (tester) async {
    await tester.pumpWidget(const ControleGastosApp());
    expect(find.text('Controle de Gastos'), findsOneWidget);
  });
}
