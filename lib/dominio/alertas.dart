import 'modelos.dart';

/// Alerta B: muitos gastos pequenos da mesma categoria no periodo.
class AlertaPequenos {
  const AlertaPequenos({
    required this.categoriaId,
    required this.quantidade,
    required this.somaCentavos,
  });

  final String categoriaId;
  final int quantidade;
  final int somaCentavos;
}

/// Alerta D: categoria cujo gasto atual fugiu da media dos 3 meses anteriores.
class AlertaPadrao {
  const AlertaPadrao({
    required this.categoriaId,
    required this.atualCentavos,
    required this.mediaCentavos,
  });

  final String categoriaId;
  final int atualCentavos;
  final int mediaCentavos;
}

/// Limiares. Ficam juntos para ajuste depois do uso real.
const limitePequenoCentavos = 5000; // ate R$ 50
const minQuantidadePequenos = 10;
const minSomaPequenosCentavos = 30000; // R$ 300
const minMesesHistorico = 3;
const minDiferencaPadraoCentavos = 10000; // R$ 100

/// Lancamentos do periodo (ja filtrados pelo mes). Estornos (valor <= 0)
/// nao entram no alerta.
List<AlertaPequenos> alertaGastosPequenosQueSomam(List<Lancamento> lancamentos) {
  final quantidade = <String, int>{};
  final soma = <String, int>{};

  for (final l in lancamentos) {
    if (l.valorCentavos <= 0 || l.valorCentavos > limitePequenoCentavos) continue;
    quantidade[l.categoriaId] = (quantidade[l.categoriaId] ?? 0) + 1;
    soma[l.categoriaId] = (soma[l.categoriaId] ?? 0) + l.valorCentavos;
  }

  return [
    for (final cat in quantidade.keys)
      if (quantidade[cat]! >= minQuantidadePequenos &&
          soma[cat]! >= minSomaPequenosCentavos)
        AlertaPequenos(
          categoriaId: cat,
          quantidade: quantidade[cat]!,
          somaCentavos: soma[cat]!,
        ),
  ];
}

/// [ultimos3MesesPorCategoria] traz os totais dos 3 meses anteriores ao atual.
/// Sem 3 meses de historico nao ha padrao, entao o alerta fica quieto.
///
/// Dispara quando, com media = soma / 3:
///   atual >= 1,5 x media      ->  atual * 2 >= soma
///   atual - media >= R$ 100   ->  atual * 3 - soma >= 30000
/// Tudo em inteiros, sem perda de precisao.
List<AlertaPadrao> alertaFugiuDoPadrao({
  required int mesesDeHistorico,
  required Map<String, int> atualPorCategoria,
  required Map<String, List<int>> ultimos3MesesPorCategoria,
}) {
  if (mesesDeHistorico < minMesesHistorico) return [];

  return [
    for (final entry in atualPorCategoria.entries)
      if (_fugiu(entry.value, ultimos3MesesPorCategoria[entry.key] ?? const [0, 0, 0]))
        AlertaPadrao(
          categoriaId: entry.key,
          atualCentavos: entry.value,
          mediaCentavos: _soma(ultimos3MesesPorCategoria[entry.key] ?? const [0, 0, 0]) ~/ 3,
        ),
  ];
}

bool _fugiu(int atual, List<int> ultimos3) {
  final soma = _soma(ultimos3);
  return atual * 2 >= soma && atual * 3 - soma >= minDiferencaPadraoCentavos * 3;
}

int _soma(List<int> valores) => valores.fold(0, (a, b) => a + b);
