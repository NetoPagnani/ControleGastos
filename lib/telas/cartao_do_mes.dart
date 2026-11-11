import 'package:flutter/material.dart';

import '../core/dinheiro.dart';
import '../core/tema.dart';
import '../dominio/modelos.dart';
import '../dominio/resumo.dart';

/// Cartao do mes no Inicio: quanto entrou, gastou e sobra em cada conta, os
/// cartoes de credito numa linha propria e o total.
class CartaoDoMes extends StatelessWidget {
  const CartaoDoMes({
    super.key,
    required this.nomeDoMes,
    required this.resumo,
    required this.informado,
    required this.onInformar,
  });

  final String nomeDoMes;
  final ResumoDoMes resumo;

  /// false: as entradas deste mes ainda nao foram informadas.
  final bool informado;
  final VoidCallback onInformar;

  @override
  Widget build(BuildContext context) {
    final percentual = percentualDaRenda(resumo.gastouContas, resumo.entrouTotal);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('R\$ ${reais(resumo.gastouTotal)}', style: estiloValorGrande(tamanho: 28)),
            Text('gastos em $nomeDoMes', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            if (!informado) ...[
              Text('Quanto entrou em $nomeDoMes? Informe as entradas de cada conta para ver quanto sobra.'),
              const SizedBox(height: 8),
              FilledButton(onPressed: onInformar, child: const Text('Informar entradas')),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Text('Entradas de $nomeDoMes', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  TextButton(onPressed: onInformar, child: const Text('editar')),
                ],
              ),
              for (final c in resumo.contas) _linhaDaConta(c),
              if (resumo.gastoCartoes != 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Cartões de crédito: gastou ${reais(resumo.gastoCartoes)} · fora da sobra, pago na fatura',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              const Divider(height: 20),
              _textoDaSobra(
                'Total: entrou ${reais(resumo.entrouTotal)} · gastou ${reais(resumo.gastouContas)} · '
                'sobra ${reais(resumo.sobraTotal)}',
                resumo.sobraTotal,
                negrito: true,
              ),
              if (percentual != null) ...[
                const SizedBox(height: 8),
                Text('${percentual.toStringAsFixed(0)}% das entradas do mês'),
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
          ],
        ),
      ),
    );
  }

  Widget _linhaDaConta(SobraDaConta c) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.conta.apelido),
          _textoDaSobra(
            'entrou ${reais(c.entrou)} · gastou ${reais(c.gastou)} · sobra ${reais(c.sobra)}',
            c.sobra,
          ),
        ],
      ),
    );
  }

  /// Sobra negativa em vermelho: gastou mais do que entrou.
  Widget _textoDaSobra(String texto, int sobra, {bool negrito = false}) {
    return Text(
      texto,
      style: TextStyle(
        color: sobra < 0 ? corAlerta : null,
        fontWeight: negrito ? FontWeight.bold : null,
      ),
    );
  }
}

/// Janela para informar quanto entrou em cada conta no mes. Cartao de
/// credito fica de fora. Vem preenchida com [sugeridas] (o mes anterior).
/// Devolve os valores maiores que zero, ou null se cancelar.
Future<Map<String, int>?> pedirEntradas(
  BuildContext context, {
  required String nomeDoMes,
  required List<Conta> contas,
  required Map<String, int> sugeridas,
}) {
  final queRecebem = [for (final c in contas) if (c.tipo != 'cartao_credito') c];
  final campos = {
    for (final c in queRecebem)
      c.id: TextEditingController(text: sugeridas[c.id] == null ? '' : _paraCampo(sugeridas[c.id]!)),
  };
  return showDialog<Map<String, int>>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Entradas de $nomeDoMes'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Quanto entrou em cada conta neste mês (salário, vale, Pix recebido...).'),
            if (queRecebem.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Cadastre uma conta que não seja cartão de crédito em Contas.'),
              ),
            for (final c in queRecebem)
              TextField(
                controller: campos[c.id],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: c.apelido, prefixText: 'R\$ '),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            for (final c in queRecebem)
              if ((centavosDeTexto(campos[c.id]!.text) ?? 0) > 0) c.id: centavosDeTexto(campos[c.id]!.text)!,
          }),
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
}

/// 300000 -> "3000,00": sem ponto de milhar, mais facil de editar.
String _paraCampo(int centavos) => '${centavos ~/ 100},${(centavos % 100).toString().padLeft(2, '0')}';
