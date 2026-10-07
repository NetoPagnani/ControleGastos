import 'package:flutter/material.dart';
import 'package:powersync/powersync.dart' show PowerSyncDatabase;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../dados/repositorios.dart';
import 'login.dart';
import 'principal.dart';

/// Mostra o login enquanto nao ha sessao. Depois de logar, garante o
/// perfil e as categorias padrao do usuario de verdade antes de mostrar
/// o app — e so entao o resto das telas pode usar usuarioAtualId.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.db});

  final PowerSyncDatabase db;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snap) {
        final sessao = Supabase.instance.client.auth.currentSession;
        if (sessao == null) return const TelaLogin();
        // Key pelo usuarioId: se a pessoa trocar de conta sem recarregar
        // a pagina, isto refaz a preparacao para o novo usuario.
        return _PreparandoConta(key: ValueKey(sessao.user.id), db: db, usuarioId: sessao.user.id);
      },
    );
  }
}

class _PreparandoConta extends StatefulWidget {
  const _PreparandoConta({super.key, required this.db, required this.usuarioId});

  final PowerSyncDatabase db;
  final String usuarioId;

  @override
  State<_PreparandoConta> createState() => _PreparandoContaState();
}

class _PreparandoContaState extends State<_PreparandoConta> {
  late final Future<void> _futuro = _preparar();

  Future<void> _preparar() async {
    await PerfilRepositorio(widget.db).garantirPerfil(widget.usuarioId);
    await CategoriasRepositorio(widget.db).garantirPadroes(widget.usuarioId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _futuro,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return TelaPrincipal(db: widget.db);
      },
    );
  }
}
