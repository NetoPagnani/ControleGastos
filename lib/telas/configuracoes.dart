import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/dinheiro.dart';
import '../core/erros_auth.dart';
import '../core/usuario_atual.dart';
import '../dados/autenticacao.dart';
import '../dados/conta_usuario.dart';
import '../dados/exportacao.dart';
import '../dados/repositorios.dart';
import '../dominio/modelos.dart';
import 'diagnostico.dart';
import 'privacidade.dart';
import 'status_sincronizacao.dart';

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

  late final _db = context.read<FirebaseFirestore>();
  late final _auth = context.read<Autenticacao>();
  late final _versao = PackageInfo.fromPlatform();

  Future<void> _salvarRenda() async {
    final centavos = centavosDeTexto(_rendaController.text);
    if (centavos == null || centavos < 0) return;
    await _perfil.definirRendaCentavos(usuarioAtualId, centavos);
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

  void _avisar(String texto) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _exportarCsv() async {
    final usuarioId = usuarioAtualId;
    final lancamentos = await context.read<LancamentosRepositorio>().todos(usuarioId);
    if (!mounted) return;
    final nomeCategoria = await _categorias.observarNomes(usuarioId).first;
    if (!mounted) return;
    final nomeConta = await context.read<ContasRepositorio>().observarNomes(usuarioId).first;
    if (lancamentos.isEmpty) {
      _avisar('Ainda não há gastos para exportar.');
      return;
    }
    final csv = gerarCsv(lancamentos: lancamentos, nomeCategoria: nomeCategoria, nomeConta: nomeConta);
    // BOM no inicio: sem ele o Excel abre os acentos quebrados.
    final bytes = utf8.encode('\uFEFF$csv');
    final hoje = formatarData(DateTime.now());
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'text/csv', name: 'gastos-$hoje.csv')],
        fileNameOverrides: ['gastos-$hoje.csv'],
        subject: 'Controle de Gastos · exportação',
      ),
    );
  }

  /// O que ja sincronizou volta no proximo login; o que nao sincronizou
  /// nao chega mais ao servidor depois de sair, entao avisa.
  Future<void> _sair() async {
    final pendentes = await temGravacoesPendentes(_db, usuarioAtualId);
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: Text(
          !pendentes
              ? 'Seus dados ficam salvos na nuvem e voltam quando você entrar de novo.'
              : 'Há alterações que ainda não foram sincronizadas e serão perdidas. '
                    'Conecte-se à internet e espere sincronizar para não perder nada.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sair')),
        ],
      ),
    );
    if (ok != true) return;
    await _auth.sair();
  }

  Future<void> _apagarConta() async {
    final confirmacao = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar conta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Todos os seus gastos, contas e categorias serão apagados de forma definitiva, '
              'neste aparelho e na nuvem. Não dá para desfazer.',
            ),
            const SizedBox(height: 12),
            const Text('Digite APAGAR para confirmar:'),
            TextField(controller: confirmacao, autofocus: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, confirmacao.text.trim().toUpperCase() == 'APAGAR'),
            child: const Text('Apagar tudo'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      // Dados primeiro: as regras do Firestore so deixam apagar enquanto o
      // login existe. Espera o servidor; sem internet, falha aqui.
      await apagarDadosDoUsuario(_db, usuarioAtualId);
      await _apagarLogin();
    } on FirebaseAuthException catch (e) {
      final m = mensagemAuth(e);
      if (m.isNotEmpty) _avisar(m);
    } catch (_) {
      _avisar('Não foi possível apagar agora. Verifique a internet e tente de novo.');
    }
  }

  /// O Firebase so apaga o login se ele for recente; se nao for, pede
  /// para entrar de novo e tenta outra vez.
  Future<void> _apagarLogin() async {
    try {
      await _auth.apagarUsuario();
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') rethrow;
      if (_auth.entrouComGoogle) {
        await _auth.reautenticarComGoogle();
      } else {
        final senha = await _pedirSenha();
        if (senha == null) return;
        await _auth.reautenticarComSenha(senha);
      }
      await _auth.apagarUsuario();
    }
  }

  Future<String?> _pedirSenha() {
    final controlador = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirme sua senha'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Senha'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, controlador.text), child: const Text('Continuar')),
        ],
      ),
    );
  }

  Future<void> _renomearCategoria(Categoria c) async {
    final controlador = TextEditingController(text: c.nome);
    final nome = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renomear categoria'),
        content: TextField(controller: controlador, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, controlador.text.trim()), child: const Text('Salvar')),
        ],
      ),
    );
    if (nome != null && nome.isNotEmpty && nome != c.nome) await _categorias.renomear(c.id, nome);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        actions: [
          // Ferramenta de desenvolvimento: fica fora da versao da loja.
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report_outlined),
              tooltip: 'Diagnóstico do banco',
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => const TelaDiagnostico())),
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
                  _auth.atual?.email ?? '',
                  style: const TextStyle(color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(onPressed: _sair, icon: const Icon(Icons.logout, size: 18), label: const Text('Sair')),
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
                      onTap: () => _renomearCategoria(c),
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
          const Divider(height: 32),
          const Text('Sincronização', style: TextStyle(fontWeight: FontWeight.bold)),
          StatusSincronizacao(usuarioId: usuarioAtualId),
          const Divider(height: 32),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.download_outlined),
            title: const Text('Exportar gastos (CSV)'),
            subtitle: const Text('Abre no Excel ou no Planilhas Google'),
            onTap: _exportarCsv,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Política de privacidade'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const TelaPrivacidade())),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
            title: Text('Apagar conta', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            subtitle: const Text('Remove todos os seus dados de forma definitiva'),
            onTap: _apagarConta,
          ),
          const SizedBox(height: 16),
          FutureBuilder<PackageInfo>(
            future: _versao,
            builder: (context, snap) => Center(
              child: Text(
                snap.hasData ? 'Controle de Gastos ${snap.data!.version} (${snap.data!.buildNumber})' : '',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 88),
        ],
      ),
    );
  }
}
