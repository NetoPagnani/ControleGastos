import 'calendario.dart';

/// Divide um valor em centavos em [n] parcelas inteiras.
/// A sobra de centavos vai para a ultima parcela, para a soma fechar exata.
/// Ex.: 10000 em 3 -> [3333, 3333, 3334]
List<int> dividirEmParcelas(int totalCentavos, int n) {
  assert(n >= 1);
  final base = totalCentavos ~/ n;
  final sobra = totalCentavos % n;
  return List.generate(n, (i) => i == n - 1 ? base + sobra : base);
}

/// Data de cada parcela: mesmo dia da compra, um mes por parcela.
/// Usa o dia original da compra em todas, para o dia 31 nao "escorregar"
/// para o dia 28 nas parcelas seguintes.
List<DateTime> datasDasParcelas(DateTime inicio, int n) {
  return List.generate(n, (i) {
    final mes = inicio.month + i;
    return dataNoMes(inicio.year, mes, inicio.day);
  });
}
