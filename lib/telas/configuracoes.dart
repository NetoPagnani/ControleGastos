import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/usuario_atual.dart';
import '../dados/repositorios.dart';
import '../dominio/modelos.dart';
import 'diagnostico.dart';

class TelaConfiguracoes extends StatefulWidget {
  const TelaConfiguracoes({super.key});

  @override
  State<TelaConfiguracoes> createState() => _TelaConfiguracoesState();
}

class _TelaConfiguracoesState extends State<TelaConfiguracoes> {
  late final _perfil = context.read<PerfilRepositorio>();
  late final _categorias = context.read<CategoriasRepositorio>();
  final _rendaController = TextEditingController();
  final _novaCategoriaController = TextEditingController();

  Future<void> _salvarRenda() async {
    final valor = double.tryParse(_rendaController.text.replaceAll(',', '.'));
    if (valor == null) return;
    await _perfil.definirRendaCentavos(usuarioAtualId, (valor * 100).round());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Renda salva')));
    }
  }

  Future<void> _criarCategoria() async {
    final nome = _novaCategoriaController.text.trim();
    if (nome.isEmpty) return;
    await _categorias.criar(usuarioAtualId, nome);
    _novaCategoriaController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        actions: [
          // Temporario: atalho para a tela de diagnostico da Fase 2.
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'Diagnóstico do banco',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const TelaDiagnostico()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  Supabase.instance.client.auth.currentUser?.email ?? '',
                  style: const TextStyle(color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: () => Supabase.instance.client.auth.signOut(),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Sair'),
              ),
            ],
          ),
          const Divider(height: 24),
          const Text('Renda mensal de referência', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text(
            'Não é lançamento, é só um número pra calcular o quanto você já comprometeu no mês.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          StreamBuilder<int>(
            stream: _perfil.observarRendaCentavos(usuarioAtualId),
            builder: (context, snap) {
              final atual = snap.data ?? 0;
              if (_rendaController.text.isEmpty && atual > 0) {
                _rendaController.text = (atual / 100).toStringAsFixed(2);
              }
              return Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _rendaController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(prefixText: 'R\$ '),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _salvarRenda, child: const Text('Salvar')),
                ],
              );
            },
          ),
          const Divider(height: 32),
          const Text('Categorias', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _novaCategoriaController,
                  decoration: const InputDecoration(labelText: 'Nova categoria'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _criarCategoria, child: const Text('Adicionar')),
            ],
          ),
          StreamBuilder<List<Categoria>>(
            stream: _categorias.observarAtivas(usuarioAtualId),
            builder: (context, snap) {
              final lista = snap.data ?? const <Categoria>[];
              return Column(
                children: [
                  for (final c in lista)
                    ListTile(
                      title: Text(c.nome),
                      trailing: IconButton(
                        icon: const Icon(Icons.archive_outlined),
                        tooltip: 'Arquivar',
                        onPressed: () => _categorias.arquivar(c.id),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
