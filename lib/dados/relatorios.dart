import 'package:cloud_firestore/cloud_firestore.dart';

import '../dominio/alertas.dart';
import '../dominio/fatura.dart';
import '../dominio/modelos.dart';
import 'repositorios.dart' show LancamentosRepositorio, colecaoDoUsuario, formatarData;

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
  RelatoriosRepositorio(this._db) : _lancamentosRepo = LancamentosRepositorio(_db);

  final FirebaseFirestore _db;
  final LancamentosRepositorio _lancamentosRepo;

  /// Lancamentos filtrados so por data no Firestore; o resto e somado
  /// aqui. Assim funciona offline (as somas do proprio Firestore sempre
  /// vao ao servidor).
  Future<List<Lancamento>> _lancamentos({
    required String usuarioId,
    DateTime? de,
    DateTime? depoisDe,
    DateTime? antesDe,
    DateTime? ate,
  }) async {
    Query<Map<String, dynamic>> q = colecaoDoUsuario(_db, usuarioId, 'lancamentos');
    if (de != null) q = q.where('data', isGreaterThanOrEqualTo: formatarData(de));
    if (depoisDe != null) q = q.where('data', isGreaterThan: formatarData(depoisDe));
    if (antesDe != null) q = q.where('data', isLessThan: formatarData(antesDe));
    if (ate != null) q = q.where('data', isLessThanOrEqualTo: formatarData(ate));
    final s = await q.get();
    return [for (final d in s.docs) LancamentosRepositorio.deDocumento(d)];
  }

  static int _soma(Iterable<Lancamento> ls) => ls.fold(0, (t, l) => t + l.valorCentavos);

  Future<Map<String, int>> somaPorCategoria({
    required String usuarioId,
    required DateTime inicio,
    required DateTime fim,
  }) async {
    final somas = <String, int>{};
    for (final l in await _lancamentos(usuarioId: usuarioId, de: inicio, antesDe: fim)) {
      if (l.valorCentavos <= 0) continue;
      somas[l.categoriaId] = (somas[l.categoriaId] ?? 0) + l.valorCentavos;
    }
    return somas;
  }

  /// Soma de todos os gastos (positivos) no periodo. Estornos (negativos)
  /// abatem do total, mas nao contam como "gasto" para o percentual da renda.
  Future<int> totalPeriodo({required String usuarioId, required DateTime inicio, required DateTime fim}) async {
    return _soma(await _lancamentos(usuarioId: usuarioId, de: inicio, antesDe: fim));
  }

  /// Soma das parcelas de cartao com data depois de hoje: quanto ja esta
  /// travado nos proximos meses.
  Future<int> comprometidoFuturo({required String usuarioId, required DateTime hoje}) async {
    final futuros = await _lancamentos(usuarioId: usuarioId, depoisDe: hoje);
    return _soma(futuros.where((l) => l.parcelasTotal > 1));
  }

  /// Quantos meses antes do mes de referencia tem pelo menos um lancamento.
  /// E o "ha quanto tempo essa pessoa usa o app", usado para o alerta D
  /// nao disparar sem uma base de comparacao de verdade.
  Future<int> mesesDeHistorico({required String usuarioId, required DateTime mesReferencia}) async {
    final inicioDoMes = DateTime(mesReferencia.year, mesReferencia.month, 1);
    final anteriores = await _lancamentos(usuarioId: usuarioId, antesDe: inicioDoMes);
    return {for (final l in anteriores) formatarData(l.data).substring(0, 7)}.length;
  }

  /// Calcula os dois alertas de descontrole para o mes de referencia.
  Future<Alertas> calcularAlertas({required String usuarioId, required DateTime mesReferencia}) async {
    final inicioMes = DateTime(mesReferencia.year, mesReferencia.month, 1);
    final fimMes = DateTime(mesReferencia.year, mesReferencia.month + 1, 1);

    // Alerta B usa os lancamentos crus do mes (ele mesmo filtra e agrupa).
    final lancamentosDoMes = await _lancamentosRepo
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

    final daFatura = await _lancamentos(usuarioId: usuarioId, depoisDe: fechamentoAnterior, ate: fechamentoAberto);
    return FaturaAberta(
      totalCentavos: _soma(daFatura.where((l) => l.contaId == contaId)),
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
