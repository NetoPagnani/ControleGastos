import 'package:firebase_auth/firebase_auth.dart';

/// Id de quem esta logado agora. Os repositorios recebem o usuarioId como
/// parametro, entao trocar o servico de login so mexeu aqui.
///
/// So e chamado depois do login (o AuthGate garante isso), entao o erro
/// abaixo nao deveria acontecer na pratica.
String get usuarioAtualId {
  final usuario = FirebaseAuth.instance.currentUser;
  if (usuario == null) {
    throw StateError('usuarioAtualId chamado sem sessao — fora do AuthGate?');
  }
  return usuario.uid;
}
