import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/dinheiro.dart';
import '../core/usuario_atual.dart';
import '../dados/relatorios.dart';
import '../dados/repositorios.dart';
import '../dominio/alertas.dart';
import '../dominio/modelos.dart';

enum _Periodo { mes, tresMeses, ano }

const _paleta = [
  Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFF6366F1),
  Color(0xFFEF4444), Color(0xFF06B6D4), Color(0xFFEC4899),
  Color(0xFF84CC16), Color(0xFFF97316), Color(0xFF8B5CF6),
];

String _reais(int centavos) => reais(centavos);

class TelaGraficos extends StatefulWidget {
  const TelaGraficos({super.key});

  @override
  State<TelaGraficos> createState() => _TelaGraficosState();
}

class _TelaGraficosState extends State<TelaGraficos> {
  _Periodo _periodo = _Periodo.mes;
  late final _relatorios = context.read<RelatoriosRepositorio>();
  late final _categorias = context.read<CategoriasRepositorio>();

  (DateTime, DateTime) _janela() {
    final agora = DateTime.now();
    final fim = DateTime(agora.year, agora.month + 1, 1);
    final meses = switch (_periodo) {
      _Periodo.mes => 1,
      _Periodo.tresMeses => 3,
      _Periodo.ano => 12,
    };
    final inicio = DateTime(agora.year, agora.month - meses + 1, 1);
    return (inicio, fim);
  }

  @override
  Widget build(BuildContext context) {
    final (inicio, fim) = _janela();
    final agora = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Gráficos')),
      body: StreamBuilder<List<Categoria>>(
        stream: _categorias.observarAtivas(usuarioAtualId),
        builder: (context, catSnap) {
          final nomeCategoria = {for (final c in catSnap.data ?? const <Categoria>[]) c.id: c.nome};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<_Periodo>(
                  segments: const [
                    ButtonSegment(value: _Periodo.mes, label: Text('Mês')),
                    ButtonSegment(value: _Periodo.tresMeses, label: Text('3 meses')),
                    ButtonSegment(value: _Periodo.ano, label: Text('Ano')),
                  ],
                  selected: {_periodo},
                  onSelectionChanged: (s) => setState(() => _periodo = s.first),
                ),
                const SizedBox(height: 16),
                FutureBuilder<Map<String, int>>(
                  future: _relatorios.somaPorCategoria(usuarioId: usuarioAtualId, inicio: inicio, fim: fim),
                  builder: (context, snap) {
                    final porCategoria = snap.data ?? const <String, int>{};
                    if (porCategoria.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('Nenhum gasto neste período.')),
                      );
                    }
                    final total = porCategoria.values.fold<int>(0, (s, v) => s + v);
                    final entradas = porCategoria.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value));

                    return Column(
                      children: [
                        SizedBox(
                          height: 180,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: [
                                for (var i = 0; i < entradas.length; i++)
                                  PieChartSectionData(
                                    value: entradas[i].value.toDouble(),
                                    color: _paleta[i % _paleta.length],
                                    title: '',
                                    radius: 40,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Total: R\$ ${_reais(total)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        FutureBuilder<Alertas>(
                          future: _periodo == _Periodo.mes
                              ? _relatorios.calcularAlertas(usuarioId: usuarioAtualId, mesReferencia: agora)
                              : Future.value(const Alertas([], [])),
                          builder: (context, alertSnap) {
                            final fugiram = {
                              for (final a in alertSnap.data?.padrao ?? const <AlertaPadrao>[]) a.categoriaId,
                            };
                            return Column(
                              children: [
                                for (var i = 0; i < entradas.length; i++)
                                  ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: _paleta[i % _paleta.length],
                                      radius: 8,
                                    ),
                                    title: Text(nomeCategoria[entradas[i].key] ?? 'Categoria'),
                                    subtitle: Text('${(entradas[i].value / total * 100).toStringAsFixed(0)}% do período'),
                                    trailing: Text(
                                      'R\$ ${_reais(entradas[i].value)}',
                                      style: TextStyle(
                                        color: fugiram.contains(entradas[i].key) ? Colors.red : null,
                                        fontWeight: fugiram.contains(entradas[i].key) ? FontWeight.bold : null,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Text('Evolução — últimos 6 meses', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                FutureBuilder<List<int>>(
                  future: _relatorios.totaisUltimosMeses(usuarioId: usuarioAtualId, mesReferencia: agora),
                  builder: (context, snap) {
                    final totais = snap.data ?? const <int>[];
                    if (totais.isEmpty) return const SizedBox(height: 120);
                    final maior = totais.reduce((a, b) => a > b ? a : b).toDouble();
                    return SizedBox(
                      height: 140,
                      child: BarChart(
                        BarChartData(
                          maxY: maior == 0 ? 1 : maior * 1.2,
                          barGroups: [
                            for (var i = 0; i < totais.length; i++)
                              BarChartGroupData(x: i, barRods: [
                                BarChartRodData(
                                  toY: totais[i].toDouble(),
                                  color: i == totais.length - 1 ? Colors.red : Colors.grey,
                                  width: 18,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ]),
                          ],
                          titlesData: const FlTitlesData(
                            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
