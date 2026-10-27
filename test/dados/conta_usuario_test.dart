import 'package:controle_gastos/dados/conta_usuario.dart';
import 'package:controle_gastos/dados/repositorios.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('apaga tudo do usuario, inclusive mais de 500 lancamentos, e nada de outro', () async {
    final db = FakeFirebaseFirestore();
    for (var i = 0; i < 501; i++) {
      await colecaoDoUsuario(db, 'u1', 'lancamentos').doc('l$i').set({'valor_centavos': 1});
    }
    await colecaoDoUsuario(db, 'u1', 'contas').doc('c').set({'apelido': 'x'});
    await colecaoDoUsuario(db, 'u1', 'categorias').doc('k').set({'nome': 'x'});
    await colecaoDoUsuario(db, 'u1', 'recorrencias').doc('r').set({'descricao': 'x'});
    await db.collection('usuarios').doc('u1').set({'renda_mensal_centavos': 1});
    await colecaoDoUsuario(db, 'u2', 'contas').doc('c').set({'apelido': 'y'});

    await apagarDadosDoUsuario(db, 'u1');

    for (final nome in ['contas', 'categorias', 'lancamentos', 'recorrencias']) {
      expect((await colecaoDoUsuario(db, 'u1', nome).get()).docs, isEmpty, reason: nome);
    }
    expect((await db.collection('usuarios').doc('u1').get()).exists, isFalse);
    expect((await colecaoDoUsuario(db, 'u2', 'contas').get()).docs, hasLength(1));
  });
}
