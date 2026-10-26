import '../core/dinheiro.dart';
import '../dominio/modelos.dart';
import 'repositorios.dart' show formatarData;

/// Monta o CSV de exportacao. Separador ";" e valor com virgula: e o que
/// o Excel em portugues abre direto, sem assistente de importacao.
String gerarCsv({
  required List<Lancamento> lancamentos,
  required Map<String, String> nomeCategoria,
  required Map<String, String> nomeConta,
}) {
  final b = StringBuffer('data;valor;categoria;conta;descricao;parcela\r\n');
  for (final l in lancamentos) {
    b.write([
      formatarData(l.data),
      reais(l.valorCentavos).replaceAll('.', ''),
      _campo(nomeCategoria[l.categoriaId] ?? ''),
      _campo(nomeConta[l.contaId] ?? ''),
      _campo(l.descricao ?? ''),
      l.parcelasTotal > 1 ? '${l.parcelaNum}/${l.parcelasTotal}' : '',
    ].join(';'));
    b.write('\r\n');
  }
  return b.toString();
}

String _campo(String texto) {
  if (!texto.contains(RegExp('[;"\r\n]'))) return texto;
  return '"${texto.replaceAll('"', '""')}"';
}
