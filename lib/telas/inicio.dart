import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/tema.dart';
import '../core/usuario_atual.dart';
import '../dados/relatorios.dart';
import '../dados/repositorios.dart';
import '../dominio/alertas.dart';
import '../dominio/modelos.dart';
import '../dominio/resumo.dart';

String _reais(int centavos) => (centavos / 100).toStringAsFixed(2).replaceAll('.', ',');

/// A tela que o Pierre nao tem: em vez de esperar a pessoa perguntar,
/// mostra o vazamento direto.
class TelaInicio extends StatefulWidget {
  const TelaInicio({super.key});

  @override
  State<TelaInicio> createState() => _TelaInicioState();
}

class _TelaInicioState extends State<TelaInicio> {
  late final _perfil = context.read<PerfilRepositorio>();
  late final _contas = context.read<ContasRepositorio>();
  late final _categorias = context.read<CategoriasRepositorio>();
  late final _relatorios = context.read<RelatoriosRepositorio>();
  late final _lancamentos = context.read<LancamentosRepositorio>();

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final inicioMes = DateTime(agora.year, agora.month, 1);
    final fimMes = DateTime(agora.year, agora.month + 1, 1);

    return Scaffold(
      appBar: AppBar(title: const Text('Início')),
      body: StreamBuilder<List<Lancamento>>(
        stream: _lancamentos.observarPeriodo(usuarioId: usuarioAtualId, inicio: inicioMes, fim: fimMes),
        builder: (context, lancSnap) {
          final totalMes = (lancSnap.data ?? const <Lancamento>[])
              .fold<int>(0, (soma, l) => soma + l.valorCentavos);

          return StreamBuilder<int>(
            stream: _perfil.observarRendaCentavos(usuarioAtualId),
            builder: (context, rendaSnap) {
              final renda = rendaSnap.data ?? 0;

              return StreamBuilder<List<Categoria>>(
                stream: _categorias.observarAtivas(usuarioAtualId),
                builder: (context, catSnap) {
                  final nomeCategoria = {
                    for (final c in catSnap.data ?? const <Categoria>[]) c.id: c.nome,
                  };

                  return StreamBuilder<List<Conta>>(
                    stream: _contas.observarAtivas(usuarioAtualId),
                    builder: (context, contasSnap) {
                      final cartoes = (contasSnap.data ?? const <Conta>[])
                          .where((c) => c.tipo == 'cartao_credito')
                          .toList();

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        // A chave forca recalcular os alertas (Future) quando o mes
                        // muda de total — os StreamBuilders de cima ja cuidam do resto.
                        key: ValueKey(totalMes),
                        children: [
                          _resumoDoMes(totalMes, renda),
                          const SizedBox(height: 16),
                          FutureBuilder<Alertas>(
                            future: _relatorios.calcularAlertas(usuarioId: usuarioAtualId, mesReferencia: agora),
                            builder: (context, alertSnap) {
                              final alertas = alertSnap.data;
                              if (alertas == null) return const SizedBox.shrink();
                              if (alertas.vazio) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text('Nenhum alerta por enquanto.'),
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final a in alertas.padrao) _cartaoAlertaPadrao(a, nomeCategoria),
                                  for (final a in alertas.pequenos) _cartaoAlertaPequenos(a, nomeCategoria),
                                ],
                              );
                            },
                          ),
                          if (cartoes.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text('Cartões', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            for (final cartao in cartoes) _CardFatura(cartao: cartao, key: ValueKey(cartao.id)),
                          ],
                        ],
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

  Widget _resumoDoMes(int totalMes, int renda) {
    final percentual = percentualDaRenda(totalMes, renda);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('R\$ ${_reais(totalMes)}', style: estiloValorGrande(tamanho: 28)),
            const Text('gastos este mês', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 6),
            if (percentual == null)
              const Text('Cadastre sua renda em Configurações para ver o percentual comprometido.')
            else ...[
              Text('${percentual.toStringAsFixed(0)}% da sua renda de referência'),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (percentual / 100).clamp(0, 1),
                  minHeight: 8,
                  color: percentual >= 100 ? corAlerta : corAviso,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cartaoAlertaPadrao(AlertaPadrao a, Map<String, String> nomeCategoria) {
    final nome = nomeCategoria[a.categoriaId] ?? 'Categoria';
    return Card(
      color: corAlertaFundo,
      child: ListTile(
        leading: const Icon(Icons.trending_up, color: corAlerta),
        title: Text('$nome fugiu do padrão'),
        subtitle: Text('R\$ ${_reais(a.atualCentavos)} este mês · sua média é R\$ ${_reais(a.mediaCentavos)}'),
      ),
    );
  }

  Widget _cartaoAlertaPequenos(AlertaPequenos a, Map<String, String> nomeCategoria) {
    final nome = nomeCategoria[a.categoriaId] ?? 'Categoria';
    return Card(
      color: corAvisoFundo,
      child: ListTile(
        leading: const Icon(Icons.repeat, color: corAviso),
        title: Text('${a.quantidade}× $nome = R\$ ${_reais(a.somaCentavos)}'),
        subtitle: const Text('Muitos gastos pequenos que somam'),
      ),
    );
  }
}

/// Fatura aberta de um cartao especifico. Widget proprio para nao empilhar
/// mais um FutureBuilder na arvore da tela de Inicio.
class _CardFatura extends StatefulWidget {
  const _CardFatura({super.key, required this.cartao});

  final Conta cartao;

  @override
  State<_CardFatura> createState() => _CardFaturaState();
}

class _CardFaturaState extends State<_CardFatura> {
  late final _relatorios = context.read<RelatoriosRepositorio>();
  late final _futuro = _carregar();

  Future<(FaturaAberta, int)> _carregar() async {
    final hoje = DateTime.now();
    final fatura = await _relatorios.faturaAberta(
      usuarioId: usuarioAtualId,
      contaId: widget.cartao.id,
      diaFechamento: widget.cartao.diaFechamento!,
      diaVencimento: widget.cartao.diaVencimento!,
      hoje: hoje,
    );
    final comprometido = await _relatorios.comprometidoFuturo(usuarioId: usuarioAtualId, hoje: hoje);
    return (fatura, comprometido);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(FaturaAberta, int)>(
      future: _futuro,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final (fatura, comprometido) = snap.data!;
        final diasAteFechar = fatura.fechamento.difference(DateTime.now()).inDays;
        return Card(
          child: ListTile(
            title: Text(widget.cartao.apelido),
            subtitle: Text(
              'Fatura aberta: R\$ ${_reais(fatura.totalCentavos)} · fecha em $diasAteFechar dias\n'
              'Comprometido em parcelas futuras: R\$ ${_reais(comprometido)}',
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
