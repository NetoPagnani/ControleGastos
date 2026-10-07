import 'package:powersync/powersync.dart';

import '../dominio/alertas.dart';
import '../dominio/fatura.dart';
import 'repositorios.dart' show LancamentosRepositorio, formatarData;

/// Resultado dos dois alertas, ja prontos para a tela de Inicio.
class Alertas {
  const Alertas(this.pequenos, this.padrao);
  final List<AlertaPequenos> pequenos;
  final List<AlertaPadrao> padrao;

  bool get vazio => pequenos.isEmpty && padrao.isEmpty;
}

/// Fatura aberta de um cartao: o que ja esta nela e quando fecha/vence.
class FaturaAberta {
  const FaturaAberta({required this.totalCentavos, required this.fechamento, required this.vencimento});
  final int totalCentavos;
  final DateTime fechamento;
  final DateTime vencimento;
}

/// Junta os lancamentos reais com as regras puras da Fase 1. Esta classe
/// faz a consulta; as decisoes (o que conta como alerta, como calcular a
/// fatura) continuam em lib/dominio, sem depender do banco.
class RelatoriosRepositorio {
  RelatoriosRepositorio(this._db) : _lancamentos = LancamentosRepositorio(_db);

  final PowerSyncDatabase _db;
  final LancamentosRepositorio _lancamentos;

  Future<Map<String, int>> somaPorCategoria({
    required String usuarioId,
    required DateTime inicio,
    required DateTime fim,
  }) async {
    final linhas = await _db.getAll(
      'SELECT categoria_id, SUM(valor_centavos) AS soma FROM lancamentos '
      'WHERE usuario_id = ? AND data >= ? AND data < ? AND valor_centavos > 0 '
      'GROUP BY categoria_id',
      [usuarioId, formatarData(inicio), formatarData(fim)],
    );
    return {for (final l in linhas) l['categoria_id'] as String: l['soma'] as int};
  }

  /// Soma de todos os gastos (positivos) no periodo. Estornos (negativos)
  /// abatem do total, mas nao contam como "gasto" para o percentual da renda.
  Future<int> totalPeriodo({required String usuarioId, required DateTime inicio, required DateTime fim}) async {
    final linha = await _db.get(
      'SELECT COALESCE(SUM(valor_centavos), 0) AS total FROM lancamentos '
      'WHERE usuario_id = ? AND data >= ? AND data < ?',
      [usuarioId, formatarData(inicio), formatarData(fim)],
    );
    return linha['total'] as int;
  }

  /// Soma das parcelas de cartao com data depois de hoje: quanto ja esta
  /// travado nos proximos meses.
  Future<int> comprometidoFuturo({required String usuarioId, required DateTime hoje}) async {
    final linha = await _db.get(
      'SELECT COALESCE(SUM(valor_centavos), 0) AS total FROM lancamentos '
      'WHERE usuario_id = ? AND parcelas_total > 1 AND data > ?',
      [usuarioId, formatarData(hoje)],
    );
    return linha['total'] as int;
  }

  /// Quantos meses antes do mes de referencia tem pelo menos um lancamento.
  /// E o "ha quanto tempo essa pessoa usa o app", usado para o alerta D
  /// nao disparar sem uma base de comparacao de verdade.
  Future<int> mesesDeHistorico({required String usuarioId, required DateTime mesReferencia}) async {
    final inicioDoMes = DateTime(mesReferencia.year, mesReferencia.month, 1);
    final linha = await _db.get(
      "SELECT COUNT(DISTINCT substr(data, 1, 7)) AS meses FROM lancamentos "
      "WHERE usuario_id = ? AND data < ?",
      [usuarioId, formatarData(inicioDoMes)],
    );
    return linha['meses'] as int;
  }

  /// Calcula os dois alertas de descontrole para o mes de referencia.
  Future<Alertas> calcularAlertas({required String usuarioId, required DateTime mesReferencia}) async {
    final inicioMes = DateTime(mesReferencia.year, mesReferencia.month, 1);
    final fimMes = DateTime(mesReferencia.year, mesReferencia.month + 1, 1);

    // Alerta B usa os lancamentos crus do mes (ele mesmo filtra e agrupa).
    final lancamentosDoMes = await _lancamentos
        .observarPeriodo(usuarioId: usuarioId, inicio: inicioMes, fim: fimMes)
        .first;
    final pequenos = alertaGastosPequenosQueSomam(lancamentosDoMes);

    // Alerta D compara com a soma dos 3 meses anteriores, por categoria.
    final atual = await somaPorCategoria(usuarioId: usuarioId, inicio: inicioMes, fim: fimMes);
    final historico = <String, List<int>>{};
    for (var i = 1; i <= 3; i++) {
      final inicioAnterior = DateTime(mesReferencia.year, mesReferencia.month - i, 1);
      final fimAnterior = DateTime(mesReferencia.year, mesReferencia.month - i + 1, 1);
      final somaAnterior = await somaPorCategoria(usuarioId: usuarioId, inicio: inicioAnterior, fim: fimAnterior);
      for (final categoriaId in {...atual.keys, ...somaAnterior.keys}) {
        historico.putIfAbsent(categoriaId, () => [0, 0, 0]);
        historico[categoriaId]![i - 1] = somaAnterior[categoriaId] ?? 0;
      }
    }
    final meses = await mesesDeHistorico(usuarioId: usuarioId, mesReferencia: mesReferencia);
    final padrao = alertaFugiuDoPadrao(
      mesesDeHistorico: meses,
      atualPorCategoria: atual,
      ultimos3MesesPorCategoria: historico,
    );

    return Alertas(pequenos, padrao);
  }

  /// Fatura em aberto de um cartao: soma dos lancamentos cujo fechamento
  /// (regra da Fase 1) cai no proximo fechamento a partir de hoje.
  Future<FaturaAberta> faturaAberta({
    required String usuarioId,
    required String contaId,
    required int diaFechamento,
    required int diaVencimento,
    required DateTime hoje,
  }) async {
    final fechamentoAberto = fechamentoDaCompra(hoje, diaFechamento);
    final vencimento = vencimentoDaFatura(fechamentoAberto, diaVencimento);
    // Fechamento anterior a este: tudo que esta nesta fatura comprou depois dele.
    final fechamentoAnterior = fechamentoDaCompra(
      DateTime(fechamentoAberto.year, fechamentoAberto.month - 1, diaFechamento),
      diaFechamento,
    );

    final linha = await _db.get(
      'SELECT COALESCE(SUM(valor_centavos), 0) AS total FROM lancamentos '
      'WHERE usuario_id = ? AND conta_id = ? AND data > ? AND data <= ?',
      [usuarioId, contaId, formatarData(fechamentoAnterior), formatarData(fechamentoAberto)],
    );
    return FaturaAberta(
      totalCentavos: linha['total'] as int,
      fechamento: fechamentoAberto,
      vencimento: vencimento,
    );
  }

  /// Totais dos ultimos [meses] meses (o atual incluso, mais recente por
  /// ultimo), para o grafico de barras.
  Future<List<int>> totaisUltimosMeses({required String usuarioId, required DateTime mesReferencia, int meses = 6}) async {
    final totais = <int>[];
    for (var i = meses - 1; i >= 0; i--) {
      final inicio = DateTime(mesReferencia.year, mesReferencia.month - i, 1);
      final fim = DateTime(mesReferencia.year, mesReferencia.month - i + 1, 1);
      totais.add(await totalPeriodo(usuarioId: usuarioId, inicio: inicio, fim: fim));
    }
    return totais;
  }
}
