import 'package:controle_gastos/dominio/alertas.dart';
import 'package:controle_gastos/dominio/modelos.dart';
import 'package:flutter_test/flutter_test.dart';

Lancamento pequeno(int valorCentavos, {String categoria = 'delivery'}) =>
    Lancamento(
      id: 'x',
      contaId: 'c',
      categoriaId: categoria,
      valorCentavos: valorCentavos,
      data: DateTime(2026, 10, 5),
      compraId: 'x',
    );

void main() {
  group('alerta de gastos pequenos que somam', () {
    test('dispara com exatamente 10 lancamentos e R\$ 300', () {
      final lista = List.generate(10, (_) => pequeno(3000));
      final alertas = alertaGastosPequenosQueSomam(lista);
      expect(alertas, hasLength(1));
      expect(alertas.first.quantidade, 10);
      expect(alertas.first.somaCentavos, 30000);
    });

    test('nao dispara com 9 lancamentos', () {
      final lista = List.generate(9, (_) => pequeno(5000));
      expect(alertaGastosPequenosQueSomam(lista), isEmpty);
    });

    test('nao dispara com 10 lancamentos somando menos de R\$ 300', () {
      final lista = List.generate(10, (i) => pequeno(i == 0 ? 2900 : 3000));
      expect(alertaGastosPequenosQueSomam(lista), isEmpty);
    });

    test('ignora lancamento acima de R\$ 50', () {
      final lista = [
        ...List.generate(9, (_) => pequeno(3000)),
        pequeno(5001),
      ];
      expect(alertaGastosPequenosQueSomam(lista), isEmpty);
    });

    test('agrupa por categoria, nao soma categorias diferentes', () {
      final lista = [
        ...List.generate(10, (_) => pequeno(3000, categoria: 'delivery')),
        ...List.generate(10, (_) => pequeno(100, categoria: 'cafe')),
      ];
      final alertas = alertaGastosPequenosQueSomam(lista);
      expect(alertas.map((a) => a.categoriaId), ['delivery']);
    });
  });

  group('alerta de fugiu do padrao', () {
    // Historico: soma dos 3 meses anteriores (em centavos).
    test('sem 3 meses de historico fica quieto', () {
      final alertas = alertaFugiuDoPadrao(
        mesesDeHistorico: 2,
        atualPorCategoria: {'transporte': 29000},
        ultimos3MesesPorCategoria: {'transporte': [12800, 12800, 12800]},
      );
      expect(alertas, isEmpty);
    });

    test('dispara quando dobra em relacao a media', () {
      // media 12800 (R\$ 128), atual 29000 (R\$ 290): ratio ~2,27 e diferenca R\$ 162.
      final alertas = alertaFugiuDoPadrao(
        mesesDeHistorico: 3,
        atualPorCategoria: {'transporte': 29000},
        ultimos3MesesPorCategoria: {'transporte': [12800, 12800, 12800]},
      );
      expect(alertas, hasLength(1));
      expect(alertas.first.mediaCentavos, 12800);
      expect(alertas.first.atualCentavos, 29000);
    });

    test('nao dispara com gasto igual a media', () {
      final alertas = alertaFugiuDoPadrao(
        mesesDeHistorico: 3,
        atualPorCategoria: {'transporte': 12800},
        ultimos3MesesPorCategoria: {'transporte': [12800, 12800, 12800]},
      );
      expect(alertas, isEmpty);
    });

    test('nao dispara se a diferenca for menor que R\$ 100 mesmo com ratio alto', () {
      // media 2000 (R\$ 20), atual 3500 (R\$ 35): ratio 1,75 mas diferenca R\$ 15.
      final alertas = alertaFugiuDoPadrao(
        mesesDeHistorico: 3,
        atualPorCategoria: {'lazer': 3500},
        ultimos3MesesPorCategoria: {'lazer': [2000, 2000, 2000]},
      );
      expect(alertas, isEmpty);
    });
  });
}
