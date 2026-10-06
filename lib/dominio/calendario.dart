/// Quantos dias tem o mes. O dia 0 do mes seguinte e o ultimo dia deste mes.
int diasNoMes(int ano, int mes) => DateTime(ano, mes + 1, 0).day;

/// Data no dia pedido, limitada ao ultimo dia do mes quando o mes e menor.
/// Ex.: dia 31 em fevereiro vira 28 (ou 29 em ano bissexto).
DateTime dataNoMes(int ano, int mes, int dia) {
  final ultimo = diasNoMes(ano, mes);
  return DateTime(ano, mes, dia > ultimo ? ultimo : dia);
}
