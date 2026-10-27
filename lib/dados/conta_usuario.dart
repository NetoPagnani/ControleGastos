import 'package:cloud_firestore/cloud_firestore.dart';

import 'repositorios.dart' show colecaoDoUsuario;

const _subcolecoes = ['contas', 'categorias', 'lancamentos', 'recorrencias'];

/// O Firestore aceita no maximo 500 operacoes por lote.
const _tamanhoDoLote = 500;

/// Apaga tudo do usuario na nuvem: as subcolecoes e depois o documento
/// do perfil. Ao contrario das gravacoes normais, espera o servidor
/// confirmar — so depois disso e seguro apagar o login.
Future<void> apagarDadosDoUsuario(FirebaseFirestore db, String usuarioId) async {
  for (final nome in _subcolecoes) {
    final docs = (await colecaoDoUsuario(db, usuarioId, nome).get()).docs;
    for (var i = 0; i < docs.length; i += _tamanhoDoLote) {
      final lote = db.batch();
      for (final d in docs.skip(i).take(_tamanhoDoLote)) {
        lote.delete(d.reference);
      }
      await lote.commit();
    }
  }
  await db.collection('usuarios').doc(usuarioId).delete();
}
