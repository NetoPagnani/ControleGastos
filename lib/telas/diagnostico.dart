import 'package:flutter/material.dart';

import '../dados/banco.dart';
import '../dados/repositorios.dart';

/// Tela temporaria da Fase 2. Sem Visual Studio nao ha onde rodar um teste
/// automatizado que abra o banco de verdade do PowerSync (nativo exige
/// compilar com CMake; o executor de teste da Web nao serve os workers).
/// Entao as mesmas verificacoes rodam aqui, visiveis no navegador.
/// Sai de cena na Fase 3, quando as telas reais existirem.
const _usuario = 'usuario-diagnostico';

class ResultadoDiagnostico {
  ResultadoDiagnostico(this.titulo, this.ok, [this.detalhe]);
  final String titulo;
  final bool ok;
  final String? detalhe;
}

class TelaDiagnostico extends StatefulWidget {
  const TelaDiagnostico({super.key});

  @override
  State<TelaDiagnostico> createState() => _TelaDiagnosticoState();
}

class _TelaDiagnosticoState extends State<TelaDiagnostico> {
  late final Future<List<ResultadoDiagnostico>> _futuro = _rodar();

  Future<List<ResultadoDiagnostico>> _rodar() async {
    final r = <ResultadoDiagnostico>[];
    final db = await abrirBanco();

    // Comeca limpo, para o diagnostico dar o mesmo resultado em toda carga.
    await db.execute('DELETE FROM lancamentos WHERE usuario_id = ?', [_usuario]);
    await db.execute('DELETE FROM contas WHERE usuario_id = ?', [_usuario]);

    final categorias = CategoriasRepositorio(db);
    final contas = ContasRepositorio(db);
    final lancamentos = LancamentosRepositorio(db);

    // 1. categorias padrao, sem duplicar ao chamar duas vezes.
    await categorias.garantirPadroes(_usuario);
    await categorias.garantirPadroes(_usuario);
    final qtdCategorias = (await db.getAll(
      'SELECT id FROM categorias WHERE usuario_id = ?',
      [_usuario],
    )).length;
    r.add(ResultadoDiagnostico(
      'Categorias padrao sem duplicar (esperado ${CategoriasRepositorio.padroes.length})',
      qtdCategorias == CategoriasRepositorio.padroes.length,
      'encontrado: $qtdCategorias',
    ));

    // 2. id deterministico: mesmo usuario+nome gera o mesmo id.
    final idA = CategoriasRepositorio.idPadrao(_usuario, 'Alimentação');
    final idB = CategoriasRepositorio.idPadrao(_usuario, 'alimentação');
    r.add(ResultadoDiagnostico('Id da categoria e deterministico', idA == idB));

    // 3. criar conta (cartao de credito) para lancar os gastos.
    final contaId = await contas.criar(
      usuarioId: _usuario,
      apelido: 'Cartao diagnostico',
      tipo: 'cartao_credito',
      limiteCentavos: 300000,
      diaFechamento: 28,
      diaVencimento: 5,
    );
    final categoriaId = idA;

    // 4. compra em 3x: 3 linhas, mesmo compra_id, soma exata.
    await lancamentos.lancarCompra(
      usuarioId: _usuario,
      contaId: contaId,
      categoriaId: categoriaId,
      totalCentavos: 10000,
      data: DateTime(2026, 11, 15),
      parcelas: 3,
    );
    final parcelasRows = await db.getAll(
      "SELECT valor_centavos, data, compra_id FROM lancamentos "
      "WHERE usuario_id = ? AND parcelas_total = 3 ORDER BY parcela_num",
      [_usuario],
    );
    final valores = parcelasRows.map((e) => e['valor_centavos'] as int).toList();
    final datas = parcelasRows.map((e) => e['data'] as String).toList();
    final mesmoCompraId = parcelasRows.map((e) => e['compra_id']).toSet().length == 1;
    r.add(ResultadoDiagnostico(
      'Compra em 3x: 3 linhas, sobra na ultima parcela',
      parcelasRows.length == 3 && valores.toString() == '[3333, 3333, 3334]' && mesmoCompraId,
      'valores: $valores · datas: $datas',
    ));

    // 5. compra em 1x: compra_id igual ao proprio id.
    await lancamentos.lancarCompra(
      usuarioId: _usuario,
      contaId: contaId,
      categoriaId: categoriaId,
      totalCentavos: 4200,
      data: DateTime(2026, 10, 5),
    );
    final linha1x = await db.get(
      "SELECT id, compra_id FROM lancamentos WHERE usuario_id = ? AND parcelas_total = 1",
      [_usuario],
    );
    r.add(ResultadoDiagnostico(
      'Compra em 1x: compra_id = proprio id',
      linha1x['id'] == linha1x['compra_id'],
    ));

    // 6. apagar a compra em 3x remove as 3 parcelas de uma vez.
    final compraId3x = parcelasRows.first['compra_id'] as String;
    await lancamentos.apagarCompra(compraId3x);
    final restantesDa3x = await db.getAll(
      'SELECT id FROM lancamentos WHERE compra_id = ?',
      [compraId3x],
    );
    r.add(ResultadoDiagnostico(
      'Apagar a compra remove todas as parcelas',
      restantesDa3x.isEmpty,
    ));

    // 7. observarPeriodo traz so o mes pedido (so sobrou a compra de outubro).
    final outubro = await lancamentos
        .observarPeriodo(
          usuarioId: _usuario,
          inicio: DateTime(2026, 10, 1),
          fim: DateTime(2026, 11, 1),
        )
        .first;
    r.add(ResultadoDiagnostico(
      'observarPeriodo traz so o mes pedido',
      outubro.length == 1 && outubro.first.valorCentavos == 4200,
      'encontrado: ${outubro.map((l) => l.valorCentavos).toList()}',
    ));

    return r;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostico — Fase 2')),
      body: FutureBuilder<List<ResultadoDiagnostico>>(
        future: _futuro,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Erro: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final resultados = snap.data!;
          final todosOk = resultados.every((r) => r.ok);
          return Column(
            children: [
              Container(
                width: double.infinity,
                color: todosOk ? Colors.green.shade100 : Colors.red.shade100,
                padding: const EdgeInsets.all(12),
                child: Text(
                  todosOk ? 'Tudo passou' : 'Alguma verificacao falhou',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final r in resultados)
                      ListTile(
                        leading: Icon(
                          r.ok ? Icons.check_circle : Icons.cancel,
                          color: r.ok ? Colors.green : Colors.red,
                        ),
                        title: Text(r.titulo),
                        subtitle: r.detalhe == null ? null : Text(r.detalhe!),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
