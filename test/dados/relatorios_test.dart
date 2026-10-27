import 'package:controle_gastos/dados/relatorios.dart';
import 'package:controle_gastos/dados/repositorios.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late LancamentosRepositorio lancamentos;
  late RelatoriosRepositorio rel;

  setUp(() {
    db = FakeFirebaseFirestore();
    lancamentos = LancamentosRepositorio(db, usuarioAtual: () => 'u1');
    rel = RelatoriosRepositorio(db);
  });

  Future<void> lancar(DateTime data, int total, {int parcelas = 1, String conta = 'c', String cat = 'k'}) async {
    await lancamentos.lancarCompra(
      usuarioId: 'u1',
      contaId: conta,
      categoriaId: cat,
      totalCentavos: total,
      data: data,
      parcelas: parcelas,
    );
    await Future<void>.delayed(Duration.zero);
  }

  test('totalPeriodo soma com estorno, inicio incluso e fim excluso', () async {
    await lancar(DateTime(2026, 3, 1), 1000);
    await lancar(DateTime(2026, 3, 10), -200);
    await lancar(DateTime(2026, 4, 1), 500);
    expect(await rel.totalPeriodo(usuarioId: 'u1', inicio: DateTime(2026, 3, 1), fim: DateTime(2026, 4, 1)), 800);
  });

  test('somaPorCategoria ignora estornos', () async {
    await lancar(DateTime(2026, 3, 1), 1000, cat: 'k1');
    await lancar(DateTime(2026, 3, 2), -200, cat: 'k1');
    await lancar(DateTime(2026, 3, 3), 300, cat: 'k2');
    expect(await rel.somaPorCategoria(usuarioId: 'u1', inicio: DateTime(2026, 3, 1), fim: DateTime(2026, 4, 1)),
        {'k1': 1000, 'k2': 300});
  });

  test('comprometidoFuturo so conta parcelas depois de hoje', () async {
    await lancar(DateTime(2026, 3, 10), 30000, parcelas: 3);
    await lancar(DateTime(2026, 3, 20), 999);
    expect(await rel.comprometidoFuturo(usuarioId: 'u1', hoje: DateTime(2026, 3, 15)), 20000);
  });

  test('mesesDeHistorico conta meses distintos antes do mes de referencia', () async {
    await lancar(DateTime(2026, 1, 5), 100);
    await lancar(DateTime(2026, 1, 20), 100);
    await lancar(DateTime(2026, 2, 5), 100);
    await lancar(DateTime(2026, 3, 5), 100);
    expect(await rel.mesesDeHistorico(usuarioId: 'u1', mesReferencia: DateTime(2026, 3, 1)), 2);
  });

  test('faturaAberta soma so o periodo da fatura daquele cartao', () async {
    await lancar(DateTime(2026, 3, 5), 1, conta: 'cartao'); // fatura anterior
    await lancar(DateTime(2026, 3, 6), 10, conta: 'cartao');
    await lancar(DateTime(2026, 4, 5), 100, conta: 'cartao');
    await lancar(DateTime(2026, 4, 6), 1000, conta: 'cartao'); // proxima fatura
    await lancar(DateTime(2026, 3, 20), 10000, conta: 'outro');
    final f = await rel.faturaAberta(
        usuarioId: 'u1', contaId: 'cartao', diaFechamento: 5, diaVencimento: 12, hoje: DateTime(2026, 3, 10));
    expect(f.totalCentavos, 110);
    expect(f.fechamento, DateTime(2026, 4, 5));
    expect(f.vencimento, DateTime(2026, 5, 12));
  });

  test('totaisUltimosMeses devolve 6 valores, o atual por ultimo', () async {
    await lancar(DateTime(2025, 10, 31), 7); // fora da janela
    await lancar(DateTime(2025, 11, 1), 1);
    await lancar(DateTime(2026, 2, 10), 20);
    await lancar(DateTime(2026, 4, 30), 300);
    expect(await rel.totaisUltimosMeses(usuarioId: 'u1', mesReferencia: DateTime(2026, 4, 15)), [1, 0, 0, 20, 0, 300]);
  });

  test('dados de outro usuario nao entram nas somas', () async {
    await lancamentos.lancarCompra(
        usuarioId: 'u2', contaId: 'c', categoriaId: 'k', totalCentavos: 500, data: DateTime(2026, 3, 1));
    await Future<void>.delayed(Duration.zero);
    expect(await rel.totalPeriodo(usuarioId: 'u1', inicio: DateTime(2026, 3, 1), fim: DateTime(2026, 4, 1)), 0);
  });
}
