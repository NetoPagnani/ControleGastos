import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/dinheiro.dart';
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

  /// Sem [existente] cria uma conta nova; com ele, edita (o tipo fica travado).
  Future<void> _abrirFormulario([Conta? existente]) async {
    final apelido = TextEditingController(text: existente?.apelido ?? '');
    final limite = TextEditingController(
      text: existente?.limiteCentavos == null ? '' : reais(existente!.limiteCentavos!),
    );
    final fechamento = TextEditingController(text: existente?.diaFechamento?.toString() ?? '');
    final vencimento = TextEditingController(text: existente?.diaVencimento?.toString() ?? '');
    var tipo = existente?.tipo ?? 'conta_debito';
    String? erro;

    final criar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(existente == null ? 'Nova conta' : 'Editar conta'),
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
                  onChanged: existente != null ? null : (v) => setStateDialog(() => tipo = v!),
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
                if (erro != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(erro!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                // Valida aqui pra nao perder o que a pessoa digitou: o
                // banco recusa cartao sem fechamento/vencimento.
                final f = int.tryParse(fechamento.text);
                final v = int.tryParse(vencimento.text);
                setStateDialog(() {
                  erro = apelido.text.trim().isEmpty
                      ? 'Dê um apelido para a conta'
                      : tipo == 'cartao_credito' && (f == null || f < 1 || f > 31 || v == null || v < 1 || v > 31)
                          ? 'Fechamento e vencimento são dias entre 1 e 31'
                          : null;
                });
                if (erro == null) Navigator.pop(context, true);
              },
              child: Text(existente == null ? 'Criar' : 'Salvar'),
            ),
          ],
        ),
      ),
    );

    if (criar != true) return;

    final ehCartao = tipo == 'cartao_credito';
    if (existente != null) {
      await _contas.editar(
        id: existente.id,
        apelido: apelido.text.trim(),
        limiteCentavos: ehCartao ? centavosDeTexto(limite.text) : null,
        diaFechamento: ehCartao ? int.tryParse(fechamento.text) : null,
        diaVencimento: ehCartao ? int.tryParse(vencimento.text) : null,
      );
      return;
    }
    await _contas.criar(
      usuarioId: usuarioAtualId,
      apelido: apelido.text.trim(),
      tipo: tipo,
      limiteCentavos: ehCartao ? centavosDeTexto(limite.text) : null,
      diaFechamento: ehCartao ? int.tryParse(fechamento.text) : null,
      diaVencimento: ehCartao ? int.tryParse(vencimento.text) : null,
    );
  }

  Future<void> _confirmarArquivar(Conta conta) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Arquivar ${conta.apelido}?'),
        content: const Text('Ela some das listas, mas os gastos já lançados continuam no histórico.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Arquivar')),
        ],
      ),
    );
    if (ok == true) await _contas.arquivar(conta.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Nada de FloatingActionButton aqui: o "+" de lancar gasto da
      // TelaPrincipal ocupa o mesmo canto e um cobriria o outro.
      appBar: AppBar(
        title: const Text('Contas'),
        actions: [
          TextButton.icon(
            onPressed: _abrirFormulario,
            icon: const Icon(Icons.add),
            label: const Text('Nova conta'),
          ),
        ],
      ),
      body: StreamBuilder<List<Conta>>(
        stream: _contas.observarAtivas(usuarioAtualId),
        builder: (context, snap) {
          final lista = snap.data ?? const <Conta>[];
          if (lista.isEmpty) {
            return const Center(child: Text('Nenhuma conta ainda. Toque em "Nova conta" para criar.'));
          }
          return ListView(
            children: [
              for (final conta in lista)
                ListTile(
                  title: Text(conta.apelido),
                  subtitle: Text(
                    conta.tipo == 'cartao_credito'
                        ? 'Fecha dia ${conta.diaFechamento} · vence dia ${conta.diaVencimento} · limite R\$ ${reais(conta.limiteCentavos ?? 0)}'
                        : _tipos[conta.tipo] ?? conta.tipo,
                  ),
                  onTap: () => _abrirFormulario(conta),
                  trailing: IconButton(
                    icon: const Icon(Icons.archive_outlined),
                    tooltip: 'Arquivar',
                    onPressed: () => _confirmarArquivar(conta),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
