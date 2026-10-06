import 'package:controle_gastos/dominio/resumo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('percentual da renda', () {
    expect(percentualDaRenda(273400, 400000), closeTo(68.35, 0.001));
  });

  test('sem renda cadastrada nao calcula percentual', () {
    expect(percentualDaRenda(273400, 0), isNull);
  });
}
