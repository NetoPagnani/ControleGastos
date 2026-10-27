import 'package:controle_gastos/dados/repositorios.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// As gravacoes nao esperam o servidor (gravarSemEsperar); um giro do
/// loop de eventos garante que o Firestore falso ja aplicou.
Future<void> assentar() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeFirebaseFirestore db;
  late CategoriasRepositorio categorias;
  late PerfilRepositorio perfil;
  late ContasRepositorio contas;
  late LancamentosRepositorio lancamentos;

  setUp(() {
    db = FakeFirebaseFirestore();
    categorias = CategoriasRepositorio(db, usuarioAtual: () => 'u1');
    perfil = PerfilRepositorio(db, usuarioAtual: () => 'u1');
    contas = ContasRepositorio(db, usuarioAtual: () => 'u1');
    lancamentos = LancamentosRepositorio(db, usuarioAtual: () => 'u1');
  });

  Future<void> lancar(DateTime data, {int total = 100, int parcelas = 1, String conta = 'c', String cat = 'k'}) async {
    await lancamentos.lancarCompra(
      usuarioId: 'u1',
      contaId: conta,
      categoriaId: cat,
      totalCentavos: total,
      data: data,
      parcelas: parcelas,
    );
    await assentar();
  }

  test('garantirPadroes cria as 9 categorias e nao duplica', () async {
    await categorias.garantirPadroes('u1');
    await assentar();
    await categorias.garantirPadroes('u1');
    await assentar();
    final lista = await categorias.observarAtivas('u1').first;
    expect(lista.map((c) => c.nome), CategoriasRepositorio.padroes);
  });

  test('garantirPadroes nao desfaz nome editado', () async {
    await categorias.garantirPadroes('u1');
    await assentar();
    final id = CategoriasRepositorio.idPadrao('u1', 'Lazer');
    await categorias.renomear(id, 'Diversão');
    await assentar();
    await categorias.garantirPadroes('u1');
    await assentar();
    expect((await categorias.observarNomes('u1').first)[id], 'Diversão');
  });

  test('observarNomes inclui categoria arquivada', () async {
    await categorias.garantirPadroes('u1');
    await assentar();
    final id = CategoriasRepositorio.idPadrao('u1', 'Lazer');
    await categorias.arquivar(id);
    await assentar();
    expect((await categorias.observarAtivas('u1').first).any((c) => c.id == id), isFalse);
    expect((await categorias.observarNomes('u1').first)[id], 'Lazer');
  });

  test('criar categoria vai para o fim da ordem', () async {
    await categorias.garantirPadroes('u1');
    await assentar();
    await categorias.criar('u1', 'Pets');
    await assentar();
    expect((await categorias.observarAtivas('u1').first).last.nome, 'Pets');
  });

  test('renda: 0 sem perfil, depois o valor definido', () async {
    expect(await perfil.observarRendaCentavos('u1').first, 0);
    await perfil.garantirPerfil('u1');
    await assentar();
    await perfil.definirRendaCentavos('u1', 500000);
    await assentar();
    await perfil.garantirPerfil('u1'); // nao zera
    await assentar();
    expect(await perfil.observarRendaCentavos('u1').first, 500000);
  });

  test('conta: editar muda os dados; arquivada sai das ativas e fica nos nomes', () async {
    final id = await contas.criar(
        usuarioId: 'u1', apelido: 'Nubank', tipo: 'cartao', diaFechamento: 5, diaVencimento: 12);
    await assentar();
    await contas.editar(id: id, apelido: 'Roxinho', limiteCentavos: 100000, diaFechamento: 6, diaVencimento: 13);
    await assentar();
    final ativa = (await contas.observarAtivas('u1').first).single;
    expect([ativa.apelido, ativa.tipo, ativa.limiteCentavos, ativa.diaFechamento, ativa.diaVencimento],
        ['Roxinho', 'cartao', 100000, 6, 13]);
    await contas.arquivar(id);
    await assentar();
    expect(await contas.observarAtivas('u1').first, isEmpty);
    expect((await contas.observarNomes('u1').first)[id], 'Roxinho');
  });

  test('compra em 3x cria 3 parcelas com o mesmo compra_id', () async {
    await lancar(DateTime(2026, 1, 31), total: 10000, parcelas: 3);
    final todos = await lancamentos.todos('u1');
    expect(todos.map((l) => l.valorCentavos), [3333, 3333, 3334]);
    expect(todos.map((l) => l.compraId).toSet().length, 1);
    expect(todos.map((l) => l.parcelaNum), [1, 2, 3]);
    expect(todos.map((l) => l.parcelasTotal).toSet(), {3});
    expect(todos.map((l) => l.data), [DateTime(2026, 1, 31), DateTime(2026, 2, 28), DateTime(2026, 3, 31)]);
  });

  test('compra simples usa o proprio id como compra_id', () async {
    await lancar(DateTime(2026, 1, 10));
    final l = (await lancamentos.todos('u1')).single;
    expect(l.compraId, l.id);
  });

  test('apagarCompra apaga todas as parcelas; apagarParcela so uma', () async {
    await lancar(DateTime(2026, 1, 10), parcelas: 2);
    await lancar(DateTime(2026, 1, 11));
    final todos = await lancamentos.todos('u1');
    final compra2x = todos.firstWhere((l) => l.parcelasTotal == 2).compraId;
    await lancamentos.apagarCompra(compra2x);
    await assentar();
    expect(await lancamentos.todos('u1'), hasLength(1));
    await lancamentos.apagarParcela((await lancamentos.todos('u1')).single.id);
    await assentar();
    expect(await lancamentos.todos('u1'), isEmpty);
  });

  test('editarCompra muda conta, categoria e descricao de todas as parcelas', () async {
    await lancar(DateTime(2026, 1, 10), parcelas: 2);
    final compra = (await lancamentos.todos('u1')).first.compraId;
    await lancamentos.editarCompra(compraId: compra, contaId: 'c2', categoriaId: 'k2', descricao: 'TV');
    await assentar();
    for (final l in await lancamentos.todos('u1')) {
      expect([l.contaId, l.categoriaId, l.descricao], ['c2', 'k2', 'TV']);
    }
  });

  test('editarParcela muda so aquela parcela', () async {
    await lancar(DateTime(2026, 1, 10), total: 200, parcelas: 2);
    final primeira = (await lancamentos.todos('u1')).first;
    await lancamentos.editarParcela(
        id: primeira.id, contaId: 'c2', categoriaId: 'k2', valorCentavos: 150, data: DateTime(2026, 1, 12), descricao: 'x');
    await assentar();
    final todos = await lancamentos.todos('u1');
    expect([todos[0].contaId, todos[0].valorCentavos, todos[0].data, todos[0].descricao],
        ['c2', 150, DateTime(2026, 1, 12), 'x']);
    expect([todos[1].contaId, todos[1].valorCentavos], ['c', 100]);
  });

  test('ultimaEscolha devolve conta e categoria do ultimo criado', () async {
    expect(await lancamentos.ultimaEscolha('u1'), isNull);
    await lancar(DateTime(2026, 1, 10), conta: 'c1', cat: 'k1');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await lancar(DateTime(2026, 1, 5), conta: 'c2', cat: 'k2');
    final e = await lancamentos.ultimaEscolha('u1');
    expect([e!.contaId, e.categoriaId], ['c2', 'k2']);
  });

  test('observarPeriodo: inicio incluso, fim excluso, mais recente primeiro', () async {
    for (final d in [DateTime(2026, 3, 1), DateTime(2026, 3, 15), DateTime(2026, 4, 1)]) {
      await lancar(d);
    }
    final lista = await lancamentos
        .observarPeriodo(usuarioId: 'u1', inicio: DateTime(2026, 3, 1), fim: DateTime(2026, 4, 1))
        .first;
    expect(lista.map((l) => l.data), [DateTime(2026, 3, 15), DateTime(2026, 3, 1)]);
  });

  test('dados de outro usuario nao aparecem', () async {
    await lancamentos.lancarCompra(
        usuarioId: 'u2', contaId: 'c', categoriaId: 'k', totalCentavos: 100, data: DateTime(2026, 1, 1));
    await assentar();
    expect(await lancamentos.todos('u1'), isEmpty);
    expect(await lancamentos.todos('u2'), hasLength(1));
  });
}
