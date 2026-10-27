import 'package:firebase_auth/firebase_auth.dart';

/// O Firebase manda codigos de erro em ingles. Aqui a gente traduz os
/// mais comuns; o que nao reconhece cai num texto generico em portugues —
/// nunca mostra ingles cru na tela. Texto vazio = nada a mostrar (a
/// pessoa fechou a janela do Google de proposito).
String mensagemAuth(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
      return 'E-mail ou senha incorretos.';
    case 'email-already-in-use':
      return 'Já existe uma conta com esse e-mail.';
    case 'weak-password':
      return 'Senha muito fraca. Use pelo menos 6 caracteres.';
    case 'invalid-email':
      return 'Digite um e-mail válido.';
    case 'too-many-requests':
      return 'Muitas tentativas seguidas. Espere um pouco e tente de novo.';
    case 'network-request-failed':
      return 'Sem conexão com o servidor. Verifique sua internet e tente de novo.';
    case 'requires-recent-login':
      return 'Por segurança, entre de novo para continuar.';
    case 'popup-closed-by-user':
    case 'canceled':
      return '';
  }
  return 'Não foi possível completar a ação. Tente novamente em instantes.';
}

