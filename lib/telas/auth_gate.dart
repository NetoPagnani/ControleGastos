import 'package:flutter/material.dart';
import 'package:powersync/powersync.dart' show PowerSyncDatabase;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';
import '../dados/conector_sincronizacao.dart';
import '../dados/repositorios.dart';
import 'login.dart';
import 'nova_senha.dart';
import 'principal.dart';

/// Mostra o login enquanto nao ha sessao. Depois de logar, garante o
/// perfil e as categorias padrao do usuario de verdade antes de mostrar
/// o app — e so entao o resto das telas pode usar usuarioAtualId.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snap) {
        // Link de "esqueci minha senha" clicado: o Supabase ja criou uma
        // sessao temporaria so pra isso. Mostra a tela de nova senha antes
        // de qualquer outra coisa, mesmo com sessao ativa.
        if (snap.data?.event == AuthChangeEvent.passwordRecovery) {
          return const TelaNovaSenha();
        }
        final db = context.read<PowerSyncDatabase>();
        final sessao = Supabase.instance.client.auth.currentSession;
        if (sessao == null) {
          // Sem sessao: nao ha para quem sincronizar. Desconectar e
          // seguro mesmo que ja estivesse desconectado.
          db.disconnect();
          return const TelaLogin();
        }
        // Key pelo usuarioId: se a pessoa trocar de conta sem recarregar
        // a pagina, isto refaz a preparacao para o novo usuario.
        return _PreparandoConta(key: ValueKey(sessao.user.id), usuarioId: sessao.user.id);
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
    final db = context.read<PowerSyncDatabase>();

    await perfil.garantirPerfil(widget.usuarioId);
    await categorias.garantirPadroes(widget.usuarioId);
    // Enquanto o PowerSync nao estiver configurado (Fase 6 pendente no
    // painel dele), AppConfig.powersyncUrl fica vazio e o app continua
    // funcionando so localmente, sem tentar conectar.
    if (AppConfig.powersyncUrl.isNotEmpty) {
      await db.connect(connector: ConectorSupabase());
    }
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
