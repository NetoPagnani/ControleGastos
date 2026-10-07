/// Uma linha da tabela de lancamentos. Uma parcela = uma linha.
class Lancamento {
  const Lancamento({
    required this.id,
    required this.contaId,
    required this.categoriaId,
    required this.valorCentavos,
    required this.data,
    required this.compraId,
    this.descricao,
    this.parcelaNum = 1,
    this.parcelasTotal = 1,
  });

  final String id;
  final String contaId;
  final String categoriaId;
  final int valorCentavos;
  final DateTime data;
  final String compraId;
  final String? descricao;
  final int parcelaNum;
  final int parcelasTotal;
}

class Conta {
  const Conta({
    required this.id,
    required this.apelido,
    required this.tipo,
    this.limiteCentavos,
    this.diaFechamento,
    this.diaVencimento,
  });

  final String id;
  final String apelido;
  final String tipo;
  final int? limiteCentavos;
  final int? diaFechamento;
  final int? diaVencimento;
}

class Categoria {
  const Categoria({required this.id, required this.nome, required this.ordem});

  final String id;
  final String nome;
  final int ordem;
}
