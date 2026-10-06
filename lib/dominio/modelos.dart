/// Uma linha da tabela de lancamentos. Uma parcela = uma linha.
class Lancamento {
  const Lancamento({
    required this.id,
    required this.contaId,
    required this.categoriaId,
    required this.valorCentavos,
    required this.data,
    required this.compraId,
    this.parcelaNum = 1,
    this.parcelasTotal = 1,
  });

  final String id;
  final String contaId;
  final String categoriaId;
  final int valorCentavos;
  final DateTime data;
  final String compraId;
  final int parcelaNum;
  final int parcelasTotal;
}
