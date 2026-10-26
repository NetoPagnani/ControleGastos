import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/dinheiro.dart';
import '../core/usuario_atual.dart';
import '../dados/repositorios.dart';
import '../dominio/modelos.dart';
import 'editar_lancamento.dart';

const nomesDosMeses = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

const _diasDaSemana = ['segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];

/// Historico de um mes, agrupado por dia, mais recente primeiro.
/// Filtra por categoria e conta, busca na descricao. Toque para editar.
class TelaGastos extends StatefulWidget {
  const TelaGastos({super.key});

  @override
  State<TelaGastos> createState() => _TelaGastosState();
}

class _TelaGastosState extends State<TelaGastos> {
  late final _lancamentos = context.read<LancamentosRepositorio>();
  late final _categorias = context.read<CategoriasRepositorio>();
  late final _contas = context.read<ContasRepositorio>();

  // Streams guardados no estado: recriar a cada build reiniciaria a
  // consulta a cada letra digitada na busca.
  late final _nomesCategorias = _categorias.observarNomes(usuarioAtualId);
  late final _nomesContas = _contas.observarNomes(usuarioAtualId);
  late Stream<List<Lancamento>> _doMes;

  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);
  String? _categoriaFiltro;
  String? _contaFiltro;
  String _busca = '';

  @override
  void initState() {
    super.initState();
    _carregarMes();
  }

  void _carregarMes() {
    _doMes = _lancamentos.observarPeriodo(
      usuarioId: usuarioAtualId,
      inicio: _mes,
      fim: DateTime(_mes.year, _mes.month + 1),
    );
  }

  void _mudarMes(int delta) {
    setState(() {
      _mes = DateTime(_mes.year, _mes.month + delta);
      _carregarMes();
    });
  }

  bool _passaNosFiltros(Lancamento l, Map<String, String> nomeCategoria) {
    if (_categoriaFiltro != null && l.categoriaId != _categoriaFiltro) return false;
    if (_contaFiltro != null && l.contaId != _contaFiltro) return false;
    if (_busca.isEmpty) return true;
    final alvo = '${l.descricao ?? ''} ${nomeCategoria[l.categoriaId] ?? ''}'.toLowerCase();
    return alvo.contains(_busca.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final hoje = DateTime.now();
    final ehMesAtual = _mes.year == hoje.year && _mes.month == hoje.month;

    return Scaffold(
      appBar: AppBar(title: const Text('Gastos')),
      body: StreamBuilder<Map<String, String>>(
        stream: _nomesCategorias,
        builder: (context, categoriasSnap) {
          final nomeCategoria = categoriasSnap.data ?? const <String, String>{};
          return StreamBuilder<Map<String, String>>(
            stream: _nomesContas,
            builder: (context, contasSnap) {
              final nomeConta = contasSnap.data ?? const <String, String>{};
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        tooltip: 'Mês anterior',
                        onPressed: () => _mudarMes(-1),
                      ),
                      Text(
                        '${nomesDosMeses[_mes.month - 1]} ${_mes.year}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        tooltip: 'Próximo mês',
                        // Mes futuro so tem parcelas, mas vale poder olhar.
                        onPressed: () => _mudarMes(1),
                      ),
                      if (!ehMesAtual)
                        TextButton(
                          onPressed: () => setState(() {
                            _mes = DateTime(hoje.year, hoje.month);
                            _carregarMes();
                          }),
                          child: const Text('Hoje'),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Buscar na descrição',
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _busca = v.trim()),
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        _Filtro(
                          rotulo: 'Categoria',
                          opcoes: nomeCategoria,
                          valor: _categoriaFiltro,
                          aoMudar: (v) => setState(() => _categoriaFiltro = v),
                        ),
                        const SizedBox(width: 8),
                        _Filtro(
                          rotulo: 'Conta',
                          opcoes: nomeConta,
                          valor: _contaFiltro,
                          aoMudar: (v) => setState(() => _contaFiltro = v),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<List<Lancamento>>(
                      stream: _doMes,
                      builder: (context, snap) {
                        final lista = [
                          for (final l in snap.data ?? const <Lancamento>[])
                            if (_passaNosFiltros(l, nomeCategoria)) l,
                        ];
                        if (lista.isEmpty) {
                          final filtrando = _busca.isNotEmpty || _categoriaFiltro != null || _contaFiltro != null;
                          return Center(
                            child: Text(filtrando ? 'Nada encontrado com esses filtros.' : 'Nenhum gasto neste mês.'),
                          );
                        }
                        return _ListaPorDia(lista: lista, nomeCategoria: nomeCategoria, nomeConta: nomeConta);
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Filtro extends StatelessWidget {
  const _Filtro({required this.rotulo, required this.opcoes, required this.valor, required this.aoMudar});

  final String rotulo;
  final Map<String, String> opcoes;
  final String? valor;
  final ValueChanged<String?> aoMudar;

  @override
  Widget build(BuildContext context) {
    final ordenadas = opcoes.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    return PopupMenuButton<String>(
      tooltip: 'Filtrar por ${rotulo.toLowerCase()}',
      onSelected: (v) => aoMudar(v.isEmpty ? null : v),
      itemBuilder: (context) => [
        PopupMenuItem(value: '', child: Text('Todas · $rotulo')),
        for (final e in ordenadas) PopupMenuItem(value: e.key, child: Text(e.value)),
      ],
      child: Chip(
        avatar: Icon(valor == null ? Icons.filter_list : Icons.check, size: 18),
        label: Text(valor == null ? rotulo : (opcoes[valor] ?? rotulo)),
        onDeleted: valor == null ? null : () => aoMudar(null),
      ),
    );
  }
}

class _ListaPorDia extends StatelessWidget {
  const _ListaPorDia({required this.lista, required this.nomeCategoria, required this.nomeConta});

  final List<Lancamento> lista;
  final Map<String, String> nomeCategoria;
  final Map<String, String> nomeConta;

  @override
  Widget build(BuildContext context) {
    // Lista ja vem ordenada por data desc; agrupa dias consecutivos.
    final dias = <DateTime, List<Lancamento>>{};
    for (final l in lista) {
      dias.putIfAbsent(DateTime(l.data.year, l.data.month, l.data.day), () => []).add(l);
    }
    final total = lista.fold<int>(0, (s, l) => s + l.valorCentavos);

    return ListView(
      padding: const EdgeInsets.only(bottom: 88), // espaco do botao "+"
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('${lista.length} lançamentos · R\$ ${reais(total)}', style: const TextStyle(color: Colors.grey)),
        ),
        for (final dia in dias.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${dia.key.day.toString().padLeft(2, '0')}/${dia.key.month.toString().padLeft(2, '0')} · '
                    '${_diasDaSemana[dia.key.weekday - 1]}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text('R\$ ${reais(dia.value.fold<int>(0, (s, l) => s + l.valorCentavos))}',
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          for (final l in dia.value)
            ListTile(
              title: Text(
                l.descricao?.isNotEmpty == true ? l.descricao! : (nomeCategoria[l.categoriaId] ?? 'Categoria'),
              ),
              subtitle: Text([
                if (l.descricao?.isNotEmpty == true) nomeCategoria[l.categoriaId] ?? 'Categoria',
                nomeConta[l.contaId] ?? 'Conta',
                if (l.parcelasTotal > 1) 'parcela ${l.parcelaNum}/${l.parcelasTotal}',
              ].join(' · ')),
              trailing: Text('R\$ ${reais(l.valorCentavos)}'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => TelaEditarLancamento(lancamento: l)),
              ),
            ),
        ],
      ],
    );
  }
}
