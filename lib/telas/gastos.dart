import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/usuario_atual.dart';
import '../dados/repositorios.dart';
import '../dominio/modelos.dart';

/// Historico do mes, mais recente primeiro. Toque para apagar.
class TelaGastos extends StatefulWidget {
  const TelaGastos({super.key});

  @override
  State<TelaGastos> createState() => _TelaGastosState();
}

class _TelaGastosState extends State<TelaGastos> {
  late final _lancamentos = context.read<LancamentosRepositorio>();
  late final _categorias = context.read<CategoriasRepositorio>();
  late final _contas = context.read<ContasRepositorio>();

  Future<void> _apagar(Lancamento l) async {
    if (l.parcelasTotal > 1) {
      final escolha = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Essa compra está em parcelas'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'uma'),
              child: const Text('Apagar só esta parcela'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'todas'),
              child: const Text('Apagar todas as parcelas'),
            ),
          ],
        ),
      );
      if (escolha == 'uma') await _lancamentos.apagarParcela(l.id);
      if (escolha == 'todas') await _lancamentos.apagarCompra(l.compraId);
    } else {
      await _lancamentos.apagarParcela(l.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final inicio = DateTime(agora.year, agora.month, 1);
    final fim = DateTime(agora.year, agora.month + 1, 1);

    return Scaffold(
      appBar: AppBar(title: const Text('Gastos')),
      body: StreamBuilder<List<Categoria>>(
        stream: _categorias.observarAtivas(usuarioAtualId),
        builder: (context, categoriasSnap) {
          final nomeCategoria = {for (final c in categoriasSnap.data ?? const <Categoria>[]) c.id: c.nome};
          return StreamBuilder<List<Conta>>(
            stream: _contas.observarAtivas(usuarioAtualId),
            builder: (context, contasSnap) {
              final nomeConta = {for (final c in contasSnap.data ?? const <Conta>[]) c.id: c.apelido};
              return StreamBuilder<List<Lancamento>>(
                stream: _lancamentos.observarPeriodo(usuarioId: usuarioAtualId, inicio: inicio, fim: fim),
                builder: (context, snap) {
                  final lista = snap.data ?? const <Lancamento>[];
                  if (lista.isEmpty) {
                    return const Center(child: Text('Nenhum gasto neste mês ainda.'));
                  }
                  return ListView.separated(
                    itemCount: lista.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final l = lista[i];
                      final reais = (l.valorCentavos / 100).toStringAsFixed(2).replaceAll('.', ',');
                      final parcela = l.parcelasTotal > 1 ? ' · ${l.parcelaNum}/${l.parcelasTotal}' : '';
                      return ListTile(
                        title: Text(nomeCategoria[l.categoriaId] ?? 'Categoria'),
                        subtitle: Text('${nomeConta[l.contaId] ?? 'Conta'}$parcela · ${l.data.day}/${l.data.month}'),
                        trailing: Text('R\$ $reais'),
                        onTap: () => _apagar(l),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
