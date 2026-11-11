import 'package:controle_gastos/dominio/modelos.dart';
import 'package:controle_gastos/dominio/resumo.dart';
import 'package:flutter_test/flutter_test.dart';

Lancamento gasto(String conta, int valor) => Lancamento(
      id: '$conta$valor',
      contaId: conta,
      categoriaId: 'k',
      valorCentavos: valor,
      data: DateTime(2026, 11, 5),
      compraId: '$conta$valor',
    );

void main() {
  test('percentual da renda', () {
    expect(percentualDaRenda(273400, 400000), closeTo(68.35, 0.001));
  });

  test('sem renda cadastrada nao calcula percentual', () {
    expect(percentualDaRenda(273400, 0), isNull);
  });

  test('chave do mes', () {
    expect(chaveDoMes(DateTime(2026, 3, 31)), '2026-03');
  });

  group('resumoDoMes', () {
    const itau = Conta(id: 'itau', apelido: 'Itaú', tipo: 'conta_debito');
    const vr = Conta(id: 'vr', apelido: 'VR', tipo: 'beneficio');
    const dinheiro = Conta(id: 'din', apelido: 'Dinheiro', tipo: 'dinheiro');
    const nubank = Conta(id: 'nu', apelido: 'Nubank', tipo: 'cartao_credito');

    final r = resumoDoMes(
      contas: const [itau, vr, dinheiro, nubank],
      entradas: const {'itau': 300000, 'vr': 60000},
      lancamentos: [
        gasto('itau', 50000),
        gasto('itau', 30000),
        gasto('vr', 45000),
        gasto('din', 5000),
        gasto('nu', 120000),
        gasto('nu', -20000), // estorno no cartao
      ],
    );

    test('cada conta que nao e cartao mostra entrou, gastou e sobra', () {
      expect([for (final c in r.contas) (c.conta.id, c.entrou, c.gastou, c.sobra)], [
        ('itau', 300000, 80000, 220000),
        ('vr', 60000, 45000, 15000),
        ('din', 0, 5000, -5000),
      ]);
    });

    test('cartao de credito fica so no total dos cartoes', () {
      expect(r.gastoCartoes, 100000);
    });

    test('total soma entradas e todos os gastos', () {
      expect([r.entrouTotal, r.gastouTotal, r.sobraTotal], [360000, 230000, 130000]);
    });

    test('gasto em conta arquivada entra no total', () {
      final comArquivada = resumoDoMes(
        contas: const [itau],
        entradas: const {'itau': 1000},
        lancamentos: [gasto('antiga', 300)],
      );
      expect([comArquivada.gastouTotal, comArquivada.sobraTotal], [300, 700]);
    });
  });

  group('entradasDoMes', () {
    const todas = {
      '2026-09': {'itau': 280000},
      '2026-10': {'itau': 300000, 'vr': 60000},
    };

    test('mes informado usa os proprios valores', () {
      final e = entradasDoMes(todas, '2026-10');
      expect([e.valores, e.informado], [
        {'itau': 300000, 'vr': 60000},
        true,
      ]);
    });

    test('mes sem valores sugere o ultimo mes informado antes dele', () {
      final e = entradasDoMes(todas, '2026-11');
      expect([e.valores, e.informado], [
        {'itau': 300000, 'vr': 60000},
        false,
      ]);
    });

    test('sem nenhum mes anterior, vem vazio', () {
      final e = entradasDoMes(todas, '2026-08');
      expect([e.valores, e.informado], [<String, int>{}, false]);
    });
  });
}
