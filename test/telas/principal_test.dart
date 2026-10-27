import 'package:controle_gastos/telas/principal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('botao de lancar so aparece no Inicio e em Gastos', () {
    // Abas: 0 Inicio, 1 Gastos, 2 Graficos, 3 Contas, 4 Config.
    expect([for (var aba = 0; aba < 5; aba++) mostraBotaoLancar(aba)], [true, true, false, false, false]);
  });
}
