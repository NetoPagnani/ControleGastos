import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../dados/repositorios.dart';
import '../dominio/modelos.dart';

/// Para parcela, pergunta se a acao vale so pra ela ou pra compra inteira.
/// 'uma', 'todas' ou null (cancelou). Gasto simples: sempre 'uma'.
Future<String?> perguntarAlcance(BuildContext context, Lancamento lancamento, String verbo) async {
  if (lancamento.parcelasTotal <= 1) return 'uma';
  return showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Essa compra está em parcelas'),
      children: [
        SimpleDialogOption(onPressed: () => Navigator.pop(context, 'uma'), child: Text('$verbo só esta parcela')),
        SimpleDialogOption(onPressed: () => Navigator.pop(context, 'todas'), child: Text('$verbo todas as parcelas')),
      ],
    ),
  );
}

/// Confirma e apaga. Usado pela lixeira da tela de edicao e pelo arrastar
/// na lista de Gastos. Devolve true se apagou.
Future<bool> confirmarEApagar(BuildContext context, Lancamento lancamento) async {
  final lancamentos = context.read<LancamentosRepositorio>();
  final alcance = lancamento.parcelasTotal > 1
      ? await perguntarAlcance(context, lancamento, 'Apagar')
      : await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Apagar este gasto?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(context, 'uma'), child: const Text('Apagar')),
            ],
          ),
        );
  if (alcance == 'uma') await lancamentos.apagarParcela(lancamento.id);
  if (alcance == 'todas') await lancamentos.apagarCompra(lancamento.compraId);
  return alcance != null;
}
