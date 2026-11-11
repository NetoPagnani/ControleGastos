import 'modelos.dart';

/// Percentual dos gastos sobre as entradas do mes.
/// Sem entradas informadas, retorna null: a tela pede para informar.
double? percentualDaRenda(int gastosCentavos, int rendaCentavos) {
  if (rendaCentavos <= 0) return null;
  return gastosCentavos / rendaCentavos * 100;
}

/// Mes como texto AAAA-MM: e a chave das entradas guardadas por mes.
String chaveDoMes(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// Entrou, gastou e sobra de uma conta no mes.
class SobraDaConta {
  const SobraDaConta({required this.conta, required this.entrou, required this.gastou});

  final Conta conta;
  final int entrou;
  final int gastou;

  int get sobra => entrou - gastou;
}

class ResumoDoMes {
  const ResumoDoMes({required this.contas, required this.gastoCartoes, required this.entrouTotal, required this.gastouTotal});

  /// Contas que recebem dinheiro (tudo menos cartao de credito).
  final List<SobraDaConta> contas;

  /// Cartao de credito nao recebe entrada: o app nao sabe de qual conta a
  /// fatura vai ser paga, entao o gasto dele so pesa na sobra total.
  final int gastoCartoes;
  final int entrouTotal;
  final int gastouTotal;

  int get sobraTotal => entrouTotal - gastouTotal;
}

ResumoDoMes resumoDoMes({
  required List<Conta> contas,
  required Map<String, int> entradas,
  required List<Lancamento> lancamentos,
}) {
  final gastoPorConta = <String, int>{};
  var gastouTotal = 0;
  for (final l in lancamentos) {
    gastoPorConta[l.contaId] = (gastoPorConta[l.contaId] ?? 0) + l.valorCentavos;
    gastouTotal += l.valorCentavos;
  }
  final linhas = [
    for (final c in contas)
      if (c.tipo != 'cartao_credito') SobraDaConta(conta: c, entrou: entradas[c.id] ?? 0, gastou: gastoPorConta[c.id] ?? 0),
  ];
  return ResumoDoMes(
    contas: linhas,
    gastoCartoes: [
      for (final c in contas)
        if (c.tipo == 'cartao_credito') gastoPorConta[c.id] ?? 0,
    ].fold(0, (a, b) => a + b),
    entrouTotal: linhas.fold(0, (soma, c) => soma + c.entrou),
    gastouTotal: gastouTotal,
  );
}

/// Entradas de [mes] por conta. Mes ainda nao informado sugere os valores
/// do ultimo mes informado antes dele, para a pessoa so confirmar.
({Map<String, int> valores, bool informado}) entradasDoMes(Map<String, Map<String, int>> todas, String mes) {
  final doMes = todas[mes];
  if (doMes != null) return (valores: doMes, informado: true);
  final anteriores = todas.keys.where((m) => m.compareTo(mes) < 0).toList()..sort();
  return (valores: anteriores.isEmpty ? <String, int>{} : todas[anteriores.last]!, informado: false);
}
