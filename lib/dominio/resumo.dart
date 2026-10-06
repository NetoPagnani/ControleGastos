/// Percentual dos gastos sobre a renda de referencia.
/// Sem renda cadastrada, retorna null: a tela pede para preencher a renda.
double? percentualDaRenda(int gastosCentavos, int rendaCentavos) {
  if (rendaCentavos <= 0) return null;
  return gastosCentavos / rendaCentavos * 100;
}
