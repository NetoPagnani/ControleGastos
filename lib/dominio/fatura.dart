import 'calendario.dart';

/// Fechamento da fatura que recebe uma compra feita em [data].
/// Compra ate o dia de fechamento entra na fatura que fecha no mesmo mes.
/// Depois do fechamento, entra na fatura do mes seguinte.
DateTime fechamentoDaCompra(DateTime data, int diaFechamento) {
  final fechamentoDoMes = dataNoMes(data.year, data.month, diaFechamento);
  if (!data.isAfter(fechamentoDoMes)) return fechamentoDoMes;
  return dataNoMes(data.year, data.month + 1, diaFechamento);
}

/// Vencimento da fatura: cai no dia de vencimento do mes seguinte ao fechamento.
DateTime vencimentoDaFatura(DateTime fechamento, int diaVencimento) {
  return dataNoMes(fechamento.year, fechamento.month + 1, diaVencimento);
}
