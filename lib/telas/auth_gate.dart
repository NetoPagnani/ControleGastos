import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../dados/autenticacao.dart';
import '../dados/repositorios.dart';
import 'confirmar_email.dart';
import 'login.dart';
import 'principal.dart';

/// Tres estados: sem login → tela de login; e-mail ainda nao confirmado →
/// tela de confirmacao; confirmado → garante perfil e categorias padrao e
/// mostra o app. So depois disso o resto das telas pode usar usuarioAtualId.
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
  late final Future<void> _futuro = _preparar();

  Future<void> _preparar() async {
    // Le tudo do context antes de qualquer await: usar o context depois
    // de um gap assincrono nao e seguro (o widget pode ja ter sumido).
    final perfil = context.read<PerfilRepositorio>();
    final categorias = context.read<CategoriasRepositorio>();

    await perfil.garantirPerfil(widget.usuarioId);
    await categorias.garantirPadroes(widget.usuarioId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _futuro,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return const TelaPrincipal();
      },
    );
  }
}
