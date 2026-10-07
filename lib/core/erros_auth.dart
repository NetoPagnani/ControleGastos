import 'package:supabase_flutter/supabase_flutter.dart';

/// O Supabase manda mensagem de erro em ingles. Aqui a gente traduz as
/// mais comuns; o que nao reconhece cai num texto generico em portugues —
/// nunca mostra ingles cru na tela.
String mensagemAuth(AuthException e) {
  switch (e.code) {
    case 'invalid_credentials':
      return 'E-mail ou senha incorretos.';
    case 'email_not_confirmed':
      return 'Confirme seu e-mail antes de entrar — veja sua caixa de entrada.';
    case 'user_already_exists':
    case 'email_exists':
      return 'Já existe uma conta com esse e-mail.';
    case 'weak_password':
      return 'Senha muito fraca. Use pelo menos 6 caracteres.';
    case 'over_email_send_rate_limit':
    case 'over_request_rate_limit':
      return 'Muitas tentativas seguidas. Espere um pouco e tente de novo.';
    case 'user_not_found':
      return 'Não existe conta com esse e-mail.';
    case 'same_password':
      return 'A nova senha precisa ser diferente da atual.';
    case 'validation_failed':
      return 'Verifique os dados preenchidos.';
  }

  final msg = e.message.toLowerCase();
  if (msg.contains('invalid login credentials')) return 'E-mail ou senha incorretos.';
  if (msg.contains('already registered') || msg.contains('already exists')) {
    return 'Já existe uma conta com esse e-mail.';
  }
  if (msg.contains('password') && msg.contains('least')) {
    return 'Senha muito curta. Use pelo menos 6 caracteres.';
  }
  if (msg.contains('rate limit')) return 'Muitas tentativas seguidas. Espere um pouco e tente de novo.';
  if (msg.contains('email') && msg.contains('invalid')) return 'Digite um e-mail válido.';

  return 'Não foi possível completar a ação. Tente novamente em instantes.';
}
