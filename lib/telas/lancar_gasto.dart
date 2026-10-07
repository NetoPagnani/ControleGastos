import 'package:flutter/material.dart';
import 'package:powersync/powersync.dart' show PowerSyncDatabase;

import '../core/usuario_atual.dart';
import '../dados/repositorios.dart';
import '../dominio/modelos.dart';

/// Lancar um gasto: valor -> categoria -> conta. 3 toques no caminho feliz.
class TelaLancarGasto extends StatefulWidget {
  const TelaLancarGasto({super.key, required this.db});

  final PowerSyncDatabase db;

  @override
  State<TelaLancarGasto> createState() => _TelaLancarGastoState();
}

class _TelaLancarGastoState extends State<TelaLancarGasto> {
  int _etapa = 0;
  int _centavos = 0;
  Categoria? _categoria;
  Conta? _conta;
  int _parcelas = 1;
  DateTime _data = DateTime.now();

  late final _categorias = CategoriasRepositorio(widget.db);
  late final _contas = ContasRepositorio(widget.db);
  late final _lancamentos = LancamentosRepositorio(widget.db);

  String get _valorFormatado {
    final reais = _centavos ~/ 100;
    final cent = (_centavos % 100).toString().padLeft(2, '0');
    return 'R\$ $reais,$cent';
  }

  void _apertarTecla(String tecla) {
    setState(() {
      if (tecla == '⌫') {
        _centavos ~/= 10;
      } else if (_centavos < 100000000) {
        _centavos = _centavos * 10 + int.parse(tecla);
      }
    });
  }

  Future<void> _confirmar() async {
    await _lancamentos.lancarCompra(
      usuarioId: usuarioAtualId,
      contaId: _conta!.id,
      categoriaId: _categoria!.id,
      totalCentavos: _centavos,
      data: _data,
      parcelas: _parcelas,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (escolhida != null) setState(() => _data = escolhida);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo gasto'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: switch (_etapa) {
        0 => _passoValor(),
        1 => _passoCategoria(),
        _ => _passoConta(),
      },
    );
  }

  Widget _passoValor() {
    const teclas = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Text(_valorFormatado, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
          ),
        ),
        TextButton(
          onPressed: _escolherData,
          child: Text(
            _data.day == DateTime.now().day &&
                    _data.month == DateTime.now().month &&
                    _data.year == DateTime.now().year
                ? 'hoje · toque pra mudar a data'
                : '${_data.day}/${_data.month}/${_data.year} · toque pra mudar',
          ),
        ),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final t in teclas)
              t.isEmpty
                  ? const SizedBox.shrink()
                  : InkWell(
                      onTap: () => _apertarTecla(t),
                      child: Center(child: Text(t, style: const TextStyle(fontSize: 26))),
                    ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _centavos > 0 ? () => setState(() => _etapa = 1) : null,
              child: const Text('Continuar'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _passoCategoria() {
    return StreamBuilder<List<Categoria>>(
      stream: _categorias.observarAtivas(usuarioAtualId),
      builder: (context, snap) {
        final lista = snap.data ?? const [];
        if (lista.isEmpty) return const Center(child: CircularProgressIndicator());
        return Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.count(
            crossAxisCount: 3,
            children: [
              for (final c in lista)
                InkWell(
                  onTap: () => setState(() {
                    _categoria = c;
                    _etapa = 2;
                  }),
                  child: Card(
                    color: _categoria?.id == c.id ? Theme.of(context).colorScheme.primaryContainer : null,
                    child: Center(child: Text(c.nome, textAlign: TextAlign.center)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _passoConta() {
    return StreamBuilder<List<Conta>>(
      stream: _contas.observarAtivas(usuarioAtualId),
      builder: (context, snap) {
        final lista = snap.data ?? const [];
        if (lista.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Cadastre uma conta em Contas antes de lançar um gasto.', textAlign: TextAlign.center),
            ),
          );
        }
        return Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  for (final conta in lista)
                    RadioListTile<String>(
                      value: conta.id,
                      groupValue: _conta?.id,
                      title: Text(conta.apelido),
                      subtitle: Text(_rotuloTipo(conta.tipo)),
                      onChanged: (_) => setState(() {
                        _conta = conta;
                        _parcelas = 1;
                      }),
                    ),
                ],
              ),
            ),
            if (_conta?.tipo == 'cartao_credito')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text('Parcelas:'),
                    Expanded(
                      child: Slider(
                        value: _parcelas.toDouble(),
                        min: 1,
                        max: 24,
                        divisions: 23,
                        label: '${_parcelas}x',
                        onChanged: (v) => setState(() => _parcelas = v.round()),
                      ),
                    ),
                    Text('${_parcelas}x'),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _conta != null ? _confirmar : null,
                  child: const Text('Lançar'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _rotuloTipo(String tipo) => switch (tipo) {
        'conta_debito' => 'Conta · débito e Pix',
        'cartao_credito' => 'Cartão de crédito',
        'dinheiro' => 'Dinheiro',
        'beneficio' => 'Vale alimentação/refeição',
        'carteira_digital' => 'Carteira digital',
        _ => tipo,
      };
}
