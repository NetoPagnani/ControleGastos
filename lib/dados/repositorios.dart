import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

import '../dominio/modelos.dart';
import '../dominio/parcelamento.dart';

const _uuid = Uuid();

String agoraIso() => DateTime.now().toUtc().toIso8601String();

/// Data como texto YYYY-MM-DD, formato que o Postgres (date) aceita.
String formatarData(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class CategoriasRepositorio {
  CategoriasRepositorio(this._db);

  final PowerSyncDatabase _db;

  static const padroes = [
    'Alimentação', 'Transporte', 'Casa', 'Saúde', 'Lazer',
    'Compras', 'Educação', 'Assinaturas', 'Outros',
  ];

  /// Id determinístico: mesmo usuario + mesmo nome gera o mesmo id em
  /// qualquer aparelho. Assim, dois aparelhos offline nao duplicam a categoria.
  static String idPadrao(String usuarioId, String nome) =>
      _uuid.v5(Namespace.url.value, '$usuarioId:${nome.toLowerCase()}');

  Future<void> garantirPadroes(String usuarioId) async {
    final agora = agoraIso();
    await _db.writeTransaction((tx) async {
      for (var i = 0; i < padroes.length; i++) {
        await tx.execute(
          'INSERT OR IGNORE INTO categorias '
          '(id, usuario_id, nome, icone, cor, ordem, arquivada, criado_em, atualizado_em) '
          'VALUES (?, ?, ?, NULL, NULL, ?, 0, ?, ?)',
          [idPadrao(usuarioId, padroes[i]), usuarioId, padroes[i], i, agora, agora],
        );
      }
    });
  }

  Stream<List<Categoria>> observarAtivas(String usuarioId) {
    return _db
        .watch(
          'SELECT id, nome, ordem FROM categorias '
          'WHERE usuario_id = ? AND arquivada = 0 ORDER BY ordem, nome',
          parameters: [usuarioId],
        )
        .map((rs) => [
              for (final r in rs)
                Categoria(
                  id: r['id'] as String,
                  nome: r['nome'] as String,
                  ordem: r['ordem'] as int,
                ),
            ]);
  }

  /// Categoria criada pela pessoa (fora das 9 padrao). Id aleatorio: nao
  /// precisa ser deterministico porque so existe depois que a pessoa pediu.
  Future<void> criar(String usuarioId, String nome) async {
    final agora = agoraIso();
    final maiorOrdem = await _db.get(
      'SELECT COALESCE(MAX(ordem), -1) AS maior FROM categorias WHERE usuario_id = ?',
      [usuarioId],
    );
    await _db.execute(
      'INSERT INTO categorias (id, usuario_id, nome, icone, cor, ordem, arquivada, criado_em, atualizado_em) '
      'VALUES (?, ?, ?, NULL, NULL, ?, 0, ?, ?)',
      [_uuid.v4(), usuarioId, nome, (maiorOrdem['maior'] as int) + 1, agora, agora],
    );
  }

  Future<void> arquivar(String id) async {
    await _db.execute(
      'UPDATE categorias SET arquivada = 1, atualizado_em = ? WHERE id = ?',
      [agoraIso(), id],
    );
  }
}

class PerfilRepositorio {
  PerfilRepositorio(this._db);

  final PowerSyncDatabase _db;

  /// Renda de referencia. Nao e transacao, so um numero que a pessoa ajusta
  /// quando muda de salario; destrava o percentual comprometido no Inicio.
  Stream<int> observarRendaCentavos(String usuarioId) {
    return _db
        .watch('SELECT renda_mensal_centavos FROM perfis WHERE id = ?', parameters: [usuarioId])
        .map((rs) => rs.isEmpty ? 0 : (rs.first['renda_mensal_centavos'] as int? ?? 0));
  }

  Future<void> definirRendaCentavos(String usuarioId, int centavos) async {
    final agora = agoraIso();
    await _db.execute(
      'INSERT INTO perfis (id, nome, renda_mensal_centavos, criado_em, atualizado_em) '
      'VALUES (?, NULL, ?, ?, ?) '
      'ON CONFLICT(id) DO UPDATE SET renda_mensal_centavos = excluded.renda_mensal_centavos, '
      'atualizado_em = excluded.atualizado_em',
      [usuarioId, centavos, agora, agora],
    );
  }
}

class ContasRepositorio {
  ContasRepositorio(this._db);

  final PowerSyncDatabase _db;

  Future<String> criar({
    required String usuarioId,
    required String apelido,
    required String tipo,
    int? limiteCentavos,
    int? diaFechamento,
    int? diaVencimento,
  }) async {
    final id = _uuid.v4();
    final agora = agoraIso();
    await _db.execute(
      'INSERT INTO contas (id, usuario_id, apelido, tipo, cor, icone, arquivada, '
      'limite_centavos, dia_fechamento, dia_vencimento, criado_em, atualizado_em) '
      'VALUES (?, ?, ?, ?, NULL, NULL, 0, ?, ?, ?, ?, ?)',
      [id, usuarioId, apelido, tipo, limiteCentavos, diaFechamento, diaVencimento, agora, agora],
    );
    return id;
  }

  Future<void> arquivar(String id) async {
    await _db.execute(
      'UPDATE contas SET arquivada = 1, atualizado_em = ? WHERE id = ?',
      [agoraIso(), id],
    );
  }

  Stream<List<Conta>> observarAtivas(String usuarioId) {
    return _db
        .watch(
          'SELECT id, apelido, tipo, limite_centavos, dia_fechamento, dia_vencimento '
          'FROM contas WHERE usuario_id = ? AND arquivada = 0 ORDER BY apelido',
          parameters: [usuarioId],
        )
        .map((rs) => [
              for (final r in rs)
                Conta(
                  id: r['id'] as String,
                  apelido: r['apelido'] as String,
                  tipo: r['tipo'] as String,
                  limiteCentavos: r['limite_centavos'] as int?,
                  diaFechamento: r['dia_fechamento'] as int?,
                  diaVencimento: r['dia_vencimento'] as int?,
                ),
            ]);
  }
}

class LancamentosRepositorio {
  LancamentosRepositorio(this._db);

  final PowerSyncDatabase _db;

  /// Lanca uma compra. Se for parcelada, cria uma linha por parcela,
  /// todas com o mesmo compra_id, usando as regras da Fase 1.
  Future<void> lancarCompra({
    required String usuarioId,
    required String contaId,
    required String categoriaId,
    required int totalCentavos,
    required DateTime data,
    int parcelas = 1,
    String? descricao,
  }) async {
    final ids = List.generate(parcelas, (_) => _uuid.v4());
    // Compra simples: o compra_id e o proprio id, como na spec.
    final compraId = parcelas == 1 ? ids.first : _uuid.v4();
    final valores = dividirEmParcelas(totalCentavos, parcelas);
    final datas = datasDasParcelas(data, parcelas);
    final agora = agoraIso();

    await _db.writeTransaction((tx) async {
      for (var i = 0; i < parcelas; i++) {
        await tx.execute(
          'INSERT INTO lancamentos (id, usuario_id, conta_id, categoria_id, valor_centavos, '
          'descricao, data, compra_id, parcela_num, parcelas_total, criado_em, atualizado_em) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            ids[i], usuarioId, contaId, categoriaId, valores[i], descricao,
            formatarData(datas[i]), compraId, i + 1, parcelas, agora, agora,
          ],
        );
      }
    });
  }

  /// Apaga uma compra inteira (todas as parcelas de uma vez).
  Future<void> apagarCompra(String compraId) async {
    await _db.execute('DELETE FROM lancamentos WHERE compra_id = ?', [compraId]);
  }

  /// Apaga so uma parcela.
  Future<void> apagarParcela(String id) async {
    await _db.execute('DELETE FROM lancamentos WHERE id = ?', [id]);
  }

  /// Lancamentos com data entre [inicio] (incluso) e [fim] (excluso).
  Stream<List<Lancamento>> observarPeriodo({
    required String usuarioId,
    required DateTime inicio,
    required DateTime fim,
  }) {
    return _db
        .watch(
          'SELECT id, conta_id, categoria_id, valor_centavos, descricao, data, compra_id, '
          'parcela_num, parcelas_total FROM lancamentos '
          'WHERE usuario_id = ? AND data >= ? AND data < ? ORDER BY data DESC',
          parameters: [usuarioId, formatarData(inicio), formatarData(fim)],
        )
        .map((rs) => [
              for (final r in rs)
                Lancamento(
                  id: r['id'] as String,
                  contaId: r['conta_id'] as String,
                  categoriaId: r['categoria_id'] as String,
                  valorCentavos: r['valor_centavos'] as int,
                  descricao: r['descricao'] as String?,
                  data: DateTime.parse(r['data'] as String),
                  compraId: r['compra_id'] as String,
                  parcelaNum: r['parcela_num'] as int,
                  parcelasTotal: r['parcelas_total'] as int,
                ),
            ]);
  }
}
