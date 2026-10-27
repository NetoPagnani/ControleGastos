import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../dados/autenticacao.dart';
import '../dados/repositorios.dart';
import 'confirmar_email.dart';
import 'login.dart';
import 'principal.dart';

/// Tres estados: sem login → tela de login; e-mail ainda nao confirmado →
/// tela de confirmacao; confirmado → o app (e, em segundo plano, perfil e
/// categorias padrao). Abaixo daqui as telas ja podem usar usuarioAtualId.
/// Quem entra com Google ja vem com o e-mail confirmado pelo Google.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: context.read<Autenticacao>().usuario,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final usuario = snap.data;
        if (usuario == null) return const TelaLogin();
        if (!usuario.emailVerified) return TelaConfirmarEmail(email: usuario.email ?? '');
        // Key pelo uid: se a pessoa trocar de conta sem recarregar a
        // pagina, isto refaz a preparacao para o novo usuario.
        return _PreparandoConta(key: ValueKey(usuario.uid), usuarioId: usuario.uid);
      },
    );
  }
}

class _PreparandoConta extends StatefulWidget {
  const _PreparandoConta({super.key, required this.usuarioId});

  final String usuarioId;

  @override
  State<_PreparandoConta> createState() => _PreparandoContaState();
}

class _PreparandoContaState extends State<_PreparandoConta> {
  StreamSubscription<Object?>? _sincronizacao;

  @override
  void initState() {
    super.initState();
    // Enquanto o app esta aberto, todos os lancamentos ficam sincronizados
    // no cache: os relatorios leem dali (ver relatorios.dart).
    _sincronizacao = colecaoDoUsuario(context.read<FirebaseFirestore>(), widget.usuarioId, 'lancamentos')
        .snapshots()
        .listen((_) {}, onError: (Object _) {});
    // Perfil e categorias padrao em segundo plano: com internet ruim a
    // primeira leitura pode demorar, e o app nao precisa esperar por isso.
    unawaited(_preparar());
  }

  @override
  void dispose() {
    _sincronizacao?.cancel();
    super.dispose();
  }

  Future<void> _preparar() async {
    // Le tudo do context antes de qualquer await: usar o context depois
    // de um gap assincrono nao e seguro (o widget pode ja ter sumido).
    final perfil = context.read<PerfilRepositorio>();
    final categorias = context.read<CategoriasRepositorio>();
    try {
      await perfil.garantirPerfil(widget.usuarioId);
      await categorias.garantirPadroes(widget.usuarioId);
    } catch (e) {
      debugPrint('Preparacao da conta falhou: $e');
    }
  }

  @override
  Widget build(BuildContext context) => const TelaPrincipal();
}
