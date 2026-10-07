import 'dart:io';

import 'package:controle_gastos/dados/repositorios.dart';
import 'package:controle_gastos/dados/banco.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart';

const usuario = 'usuario-teste';

void main() {
  late Directory pasta;
  late PowerSyncDatabase db;

  setUp(() async {
    pasta = Directory.systemTemp.createTempSync('controle_gastos_teste');
    db = await abrirBanco(caminho: '${pasta.path}/teste.db');
  });

  tearDown(() async {
    await db.close();
    pasta.deleteSync(recursive: true);
  });

  group('categorias padrao', () {
    test('garantirPadroes chamado duas vezes nao duplica', () async {
      final repo = CategoriasRepositorio(db);
      await repo.garantirPadroes(usuario);
      await repo.garantirPadroes(usuario);

      final linhas = await db.getAll('SELECT id FROM categorias WHERE usuario_id = ?', [usuario]);
      expect(linhas, hasLength(CategoriasRepositorio.padroes.length));
    });

    test('o mesmo usuario e nome geram o mesmo id em qualquer aparelho', () {
      expect(
        CategoriasRepositorio.idPadrao(usuario, 'Alimentação'),
        CategoriasRepositorio.idPadrao(usuario, 'alimentação'),
      );
    });
  });

  group('lancamentos', () {
    late LancamentosRepositorio lancamentos;

    setUp(() {
      lancamentos = LancamentosRepositorio(db);
    });

    test('compra em 1x gera uma linha e compra_id igual ao proprio id', () async {
      await lancamentos.lancarCompra(
        usuarioId: usuario,
        contaId: 'conta-1',
        categoriaId: 'cat-1',
        totalCentavos: 4200,
        data: DateTime(2026, 10, 5),
      );

      final linhas = await db.getAll('SELECT id, compra_id, valor_centavos FROM lancamentos');
      expect(linhas, hasLength(1));
      expect(linhas.first['compra_id'], linhas.first['id']);
      expect(linhas.first['valor_centavos'], 4200);
    });

    test('compra em 3x gera tres parcelas com o mesmo compra_id e soma exata', () async {
      await lancamentos.lancarCompra(
        usuarioId: usuario,
        contaId: 'conta-1',
        categoriaId: 'cat-1',
        totalCentavos: 10000,
        data: DateTime(2026, 11, 15),
        parcelas: 3,
      );

      final linhas = await db.getAll(
        'SELECT valor_centavos, data, compra_id, parcela_num FROM lancamentos ORDER BY parcela_num',
      );
      expect(linhas.map((r) => r['valor_centavos']), [3333, 3333, 3334]);
      expect(linhas.map((r) => r['data']), ['2026-11-15', '2026-12-15', '2027-01-15']);
      expect(linhas.map((r) => r['compra_id']).toSet(), hasLength(1));
    });

    test('apagarCompra remove todas as parcelas de uma vez', () async {
      await lancamentos.lancarCompra(
        usuarioId: usuario,
        contaId: 'conta-1',
        categoriaId: 'cat-1',
        totalCentavos: 10000,
        data: DateTime(2026, 11, 15),
        parcelas: 3,
      );
      final compraId = (await db.get('SELECT compra_id FROM lancamentos LIMIT 1'))['compra_id'] as String;

      await lancamentos.apagarCompra(compraId);

      final restantes = await db.getAll('SELECT id FROM lancamentos');
      expect(restantes, isEmpty);
    });

    test('observarPeriodo traz so o mes pedido', () async {
      await lancamentos.lancarCompra(
        usuarioId: usuario,
        contaId: 'conta-1',
        categoriaId: 'cat-1',
        totalCentavos: 1000,
        data: DateTime(2026, 10, 5),
      );
      await lancamentos.lancarCompra(
        usuarioId: usuario,
        contaId: 'conta-1',
        categoriaId: 'cat-1',
        totalCentavos: 2000,
        data: DateTime(2026, 11, 5),
      );

      final outubro = await lancamentos
          .observarPeriodo(
            usuarioId: usuario,
            inicio: DateTime(2026, 10, 1),
            fim: DateTime(2026, 11, 1),
          )
          .first;

      expect(outubro.map((l) => l.valorCentavos), [1000]);
    });
  });
}
