import 'package:supabase_flutter/supabase_flutter.dart';

/// Id de quem esta logado agora. Antes da Fase 5 era um valor fixo; a
/// Fase 5 trocou por isso, e nenhum repositorio precisou mudar — todos
/// ja recebiam o usuarioId como parametro.
///
/// So e chamado depois do login (o AuthGate garante isso), entao o erro
/// abaixo nao deveria acontecer na pratica.
String get usuarioAtualId {
  final usuario = Supabase.instance.client.auth.currentUser;
  if (usuario == null) {
    throw StateError('usuarioAtualId chamado sem sessao — fora do AuthGate?');
  }
  return usuario.id;
}
