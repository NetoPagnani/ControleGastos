import 'package:controle_gastos/core/dinheiro.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formata com milhar e centavos', () {
    expect(reais(0), '0,00');
    expect(reais(5), '0,05');
    expect(reais(123456789), '1.234.567,89');
    expect(reais(-1050), '-10,50');
  });

  test('entende o que a pessoa digita', () {
    expect(centavosDeTexto('12,34'), 1234);
    expect(centavosDeTexto('12.34'), 1234);
    expect(centavosDeTexto('1.234,56'), 123456);
    expect(centavosDeTexto('R\$ 3000'), 300000);
    expect(centavosDeTexto(''), isNull);
    expect(centavosDeTexto('abc'), isNull);
  });
}
