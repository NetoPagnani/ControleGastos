import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../dados/autenticacao.dart';
import 'status_sincronizacao.dart';

/// Ferramenta de desenvolvimento (so aparece em modo debug): quem esta
/// logado e se ha alteracoes esperando o servidor. As regras de calculo
/// tem testes automatizados; os repositorios tambem, com Firestore falso.
class TelaDiagnostico extends StatelessWidget {
  const TelaDiagnostico({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = context.read<Autenticacao>().atual;
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnóstico')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(contentPadding: EdgeInsets.zero, title: const Text('E-mail'), subtitle: Text(usuario?.email ?? '-')),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Id do usuário'),
            subtitle: SelectableText(usuario?.uid ?? '-'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('E-mail confirmado'),
            subtitle: Text((usuario?.emailVerified ?? false) ? 'Sim' : 'Não'),
          ),
          if (usuario != null) StatusSincronizacao(usuarioId: usuario.uid),
        ],
      ),
    );
  }
}
