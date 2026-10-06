import 'package:controle_gastos/dominio/parcelamento.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dividirEmParcelas', () {
    test('sobra de centavos vai para a ultima parcela', () {
      expect(dividirEmParcelas(10000, 3), [3333, 3333, 3334]);
    });

    test('soma das parcelas sempre fecha com o total', () {
      final partes = dividirEmParcelas(12345, 12);
      expect(partes.reduce((a, b) => a + b), 12345);
    });

    test('compra em 1x nao divide', () {
      expect(dividirEmParcelas(4200, 1), [4200]);
    });
  });

  group('datasDasParcelas', () {
    test('avanca um mes mantendo o dia da compra', () {
      expect(datasDasParcelas(DateTime(2026, 11, 15), 3), [
        DateTime(2026, 11, 15),
        DateTime(2026, 12, 15),
        DateTime(2027, 1, 15),
      ]);
    });

    test('dia 31 em mes curto cai no ultimo dia, sem perder o 31 original', () {
      expect(datasDasParcelas(DateTime(2026, 1, 31), 3), [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
      ]);
    });
  });
}
