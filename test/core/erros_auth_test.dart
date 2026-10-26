import 'package:controle_gastos/core/erros_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

String m(String code) => mensagemAuth(FirebaseAuthException(code: code));

void main() {
  test('credenciais erradas', () {
    for (final c in ['invalid-credential', 'wrong-password', 'user-not-found']) {
      expect(m(c), 'E-mail ou senha incorretos.');
    }
  });
  test('e-mail em uso', () => expect(m('email-already-in-use'), 'Já existe uma conta com esse e-mail.'));
  test('senha fraca', () => expect(m('weak-password'), 'Senha muito fraca. Use pelo menos 6 caracteres.'));
  test('e-mail invalido', () => expect(m('invalid-email'), 'Digite um e-mail válido.'));
  test('muitas tentativas',
      () => expect(m('too-many-requests'), 'Muitas tentativas seguidas. Espere um pouco e tente de novo.'));
  test('sem internet',
      () => expect(m('network-request-failed'), 'Sem conexão com o servidor. Verifique sua internet e tente de novo.'));
  test('login antigo', () => expect(m('requires-recent-login'), 'Por segurança, entre de novo para continuar.'));
  test('cancelou o Google', () {
    expect(m('popup-closed-by-user'), '');
    expect(m('canceled'), '');
  });
  test('desconhecido',
      () => expect(m('qualquer-coisa'), 'Não foi possível completar a ação. Tente novamente em instantes.'));
}
