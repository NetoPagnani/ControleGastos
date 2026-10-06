import 'package:controle_gastos/dominio/fatura.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Cartao com fechamento dia 28 e vencimento dia 5.
  test('compra antes do fechamento entra na fatura do mesmo mes', () {
    expect(fechamentoDaCompra(DateTime(2026, 10, 27), 28), DateTime(2026, 10, 28));
  });

  test('compra no dia do fechamento ainda entra nessa fatura', () {
    expect(fechamentoDaCompra(DateTime(2026, 10, 28), 28), DateTime(2026, 10, 28));
  });

  test('compra depois do fechamento vai para a fatura do mes seguinte', () {
    expect(fechamentoDaCompra(DateTime(2026, 10, 29), 28), DateTime(2026, 11, 28));
  });

  test('virada de ano', () {
    expect(fechamentoDaCompra(DateTime(2026, 12, 30), 28), DateTime(2027, 1, 28));
  });

  test('vencimento cai no mes seguinte ao fechamento', () {
    expect(vencimentoDaFatura(DateTime(2026, 11, 28), 5), DateTime(2026, 12, 5));
  });

  test('vencimento na virada de ano', () {
    expect(vencimentoDaFatura(DateTime(2026, 12, 28), 5), DateTime(2027, 1, 5));
  });

  test('fechamento dia 31 em mes com 30 dias usa o ultimo dia', () {
    expect(fechamentoDaCompra(DateTime(2026, 4, 10), 31), DateTime(2026, 4, 30));
  });
}
