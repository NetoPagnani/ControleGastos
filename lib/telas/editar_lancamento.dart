import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/dinheiro.dart';
import '../core/usuario_atual.dart';
import '../dados/repositorios.dart';
import '../dominio/modelos.dart';

/// Editar ou apagar um lancamento. Se for parcela, pergunta se a mudanca
/// vale so pra esta parcela ou pra compra inteira.
class TelaEditarLancamento extends StatefulWidget {
  const TelaEditarLancamento({super.key, required this.lancamento});

  final Lancamento lancamento;

  @override
  State<TelaEditarLancamento> createState() => _TelaEditarLancamentoState();
}

class _TelaEditarLancamentoState extends State<TelaEditarLancamento> {
  late final _lancamentos = context.read<LancamentosRepositorio>();
  late final _categoriasStream = context.read<CategoriasRepositorio>().observarAtivas(usuarioAtualId);
  late final _contasStream = context.read<ContasRepositorio>().observarAtivas(usuarioAtualId);

  late final _valor = TextEditingController(text: reais(widget.lancamento.valorCentavos));
  late final _descricao = TextEditingController(text: widget.lancamento.descricao ?? '');
  late String _categoriaId = widget.lancamento.categoriaId;
  late String _contaId = widget.lancamento.contaId;
  late DateTime _data = widget.lancamento.data;
  String? _erro;

  bool get _ehParcela => widget.lancamento.parcelasTotal > 1;

  /// 'uma', 'todas' ou null (cancelou).
  Future<String?> _perguntarAlcance(String verbo) async {
    if (!_ehParcela) return 'uma';
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Essa compra está em parcelas'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'uma'),
            child: Text('$verbo só esta parcela'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'todas'),
            child: Text('$verbo todas as parcelas'),
          ),
        ],
      ),
    );
  }

  Future<void> _salvar() async {
    final centavos = centavosDeTexto(_valor.text);
    if (centavos == null || centavos == 0) {
      setState(() => _erro = 'Valor inválido');
      return;
    }
    final alcance = await _perguntarAlcance('Alterar');
    if (alcance == null) return;
    final descricao = _descricao.text.trim().isEmpty ? null : _descricao.text.trim();

    if (alcance == 'todas') {
      await _lancamentos.editarCompra(
        compraId: widget.lancamento.compraId,
        contaId: _contaId,
        categoriaId: _categoriaId,
        descricao: descricao,
      );
    } else {
      await _lancamentos.editarParcela(
        id: widget.lancamento.id,
        contaId: _contaId,
        categoriaId: _categoriaId,
        valorCentavos: centavos,
        data: _data,
        descricao: descricao,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _apagar() async {
    final alcance = _ehParcela
        ? await _perguntarAlcance('Apagar')
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
    if (alcance == 'uma') await _lancamentos.apagarParcela(widget.lancamento.id);
    if (alcance == 'todas') await _lancamentos.apagarCompra(widget.lancamento.compraId);
    if (alcance != null && mounted) Navigator.of(context).pop();
  }

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (escolhida != null) setState(() => _data = escolhida);
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lancamento;
    return Scaffold(
      appBar: AppBar(
        title: Text(_ehParcela ? 'Parcela ${l.parcelaNum}/${l.parcelasTotal}' : 'Editar gasto'),
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Apagar', onPressed: _apagar),
        ],
      ),
      body: StreamBuilder<List<Categoria>>(
        stream: _categoriasStream,
        builder: (context, catSnap) => StreamBuilder<List<Conta>>(
          stream: _contasStream,
          builder: (context, contaSnap) {
            final categorias = catSnap.data ?? const <Categoria>[];
            final contas = contaSnap.data ?? const <Conta>[];
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _valor,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: InputDecoration(
                    labelText: _ehParcela ? 'Valor desta parcela' : 'Valor',
                    prefixText: 'R\$ ',
                    errorText: _erro,
                    helperText: 'Negativo para estorno',
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: Text('${_data.day.toString().padLeft(2, '0')}/${_data.month.toString().padLeft(2, '0')}/${_data.year}'),
                  subtitle: _ehParcela ? const Text('Data desta parcela') : null,
                  onTap: _escolherData,
                ),
                const SizedBox(height: 12),
                _Seletor(
                  rotulo: 'Categoria',
                  valor: _categoriaId,
                  opcoes: {for (final c in categorias) c.id: c.nome},
                  aoMudar: (v) => setState(() => _categoriaId = v),
                ),
                const SizedBox(height: 12),
                _Seletor(
                  rotulo: 'Conta',
                  valor: _contaId,
                  opcoes: {for (final c in contas) c.id: c.apelido},
                  aoMudar: (v) => setState(() => _contaId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descricao,
                  decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
                  textCapitalization: TextCapitalization.sentences,
                ),
                if (_ehParcela)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Ao alterar todas as parcelas, só categoria, conta e descrição mudam. '
                      'Valor e data continuam os de cada parcela.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton(onPressed: _salvar, child: const Text('Salvar')),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Seletor extends StatelessWidget {
  const _Seletor({required this.rotulo, required this.valor, required this.opcoes, required this.aoMudar});

  final String rotulo;
  final String valor;
  final Map<String, String> opcoes;
  final ValueChanged<String> aoMudar;

  @override
  Widget build(BuildContext context) {
    // Categoria ou conta arquivada nao aparece na lista ativa; mantem a
    // atual como opcao pra o dropdown nao quebrar.
    final itens = {...opcoes};
    itens.putIfAbsent(valor, () => '(arquivada)');
    return DropdownButtonFormField<String>(
      initialValue: valor,
      isExpanded: true,
      decoration: InputDecoration(labelText: rotulo),
      items: [for (final e in itens.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
      onChanged: (v) {
        if (v != null) aoMudar(v);
      },
    );
  }
}
