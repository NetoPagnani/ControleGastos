/// 1234 -> "12,34". Sem simbolo: a tela decide se poe "R$ " na frente.
String reais(int centavos) {
  final negativo = centavos < 0;
  final abs = centavos.abs();
  final inteiro = (abs ~/ 100).toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => '.',
      );
  final cent = (abs % 100).toString().padLeft(2, '0');
  return '${negativo ? '-' : ''}$inteiro,$cent';
}

/// Texto digitado pela pessoa -> centavos. Aceita "12,34", "12.34" e
/// "1.234,56". Devolve null se nao der pra entender.
int? centavosDeTexto(String texto) {
  var t = texto.trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (t.isEmpty) return null;
  if (t.contains(',')) {
    // Formato brasileiro: ponto e milhar, virgula e decimal.
    t = t.replaceAll('.', '').replaceAll(',', '.');
  }
  final valor = double.tryParse(t);
  return valor == null ? null : (valor * 100).round();
}
