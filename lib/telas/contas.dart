import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/usuario_atual.dart';
import '../dados/repositorios.dart';
import '../dominio/modelos.dart';

const _tipos = {
  'conta_debito': 'Conta · débito e Pix',
  'cartao_credito': 'Cartão de crédito',
  'dinheiro': 'Dinheiro',
  'beneficio': 'Vale alimentação/refeição',
  'carteira_digital': 'Carteira digital',
};

class TelaContas extends StatefulWidget {
  const TelaContas({super.key});

  @override
  State<TelaContas> createState() => _TelaContasState();
}

class _TelaContasState extends State<TelaContas> {
  late final _contas = context.read<ContasRepositorio>();

  Future<void> _abrirFormulario() async {
    final apelido = TextEditingController();
    final limite = TextEditingController();
    final fechamento = TextEditingController();
    final vencimento = TextEditingController();
    var tipo = 'conta_debito';

    final criar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Nova conta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: apelido, decoration: const InputDecoration(labelText: 'Apelido')),
                DropdownButton<String>(
                  value: tipo,
                  isExpanded: true,
                  items: [
                    for (final e in _tipos.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setStateDialog(() => tipo = v!),
                ),
                if (tipo == 'cartao_credito') ...[
                  TextField(
                    controller: limite,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Limite (R\$)'),
                  ),
                  TextField(
                    controller: fechamento,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Dia do fechamento'),
                  ),
                  TextField(
                    controller: vencimento,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Dia do vencimento'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Criar')),
          ],
        ),
      ),
    );

    if (criar != true || apelido.text.trim().isEmpty) return;

    await _contas.criar(
      usuarioId: usuarioAtualId,
      apelido: apelido.text.trim(),
      tipo: tipo,
      limiteCentavos: tipo == 'cartao_credito' ? _reaisParaCentavos(limite.text) : null,
      diaFechamento: tipo == 'cartao_credito' ? int.tryParse(fechamento.text) : null,
      diaVencimento: tipo == 'cartao_credito' ? int.tryParse(vencimento.text) : null,
    );
  }

  int? _reaisParaCentavos(String texto) {
    final valor = double.tryParse(texto.replaceAll(',', '.'));
    return valor == null ? null : (valor * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contas')),
      floatingActionButton: FloatingActionButton(onPressed: _abrirFormulario, child: const Icon(Icons.add)),
      body: StreamBuilder<List<Conta>>(
        stream: _contas.observarAtivas(usuarioAtualId),
        builder: (context, snap) {
          final lista = snap.data ?? const <Conta>[];
          if (lista.isEmpty) {
            return const Center(child: Text('Nenhuma conta ainda. Toque em + para criar.'));
          }
          return ListView(
            children: [
              for (final conta in lista)
                ListTile(
                  title: Text(conta.apelido),
                  subtitle: Text(
                    conta.tipo == 'cartao_credito'
                        ? 'Fecha dia ${conta.diaFechamento} · vence dia ${conta.diaVencimento} · limite R\$ ${((conta.limiteCentavos ?? 0) / 100).toStringAsFixed(2)}'
                        : _tipos[conta.tipo] ?? conta.tipo,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.archive_outlined),
                    tooltip: 'Arquivar',
                    onPressed: () => _contas.arquivar(conta.id),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
