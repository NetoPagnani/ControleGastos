import 'package:cloud_firestore/cloud_firestore.dart';

import 'repositorios.dart' show colecaoDoUsuario;

const _subcolecoes = ['contas', 'categorias', 'lancamentos', 'recorrencias'];

/// O Firestore aceita no maximo 500 operacoes por lote.
const _tamanhoDoLote = 500;

/// Sem internet o commit nunca termina; depois disso desiste com erro.
const _limiteDoServidor = Duration(seconds: 20);

/// Apaga a conta inteira. O novo login vem primeiro: se a pessoa cancelar
/// ou errar a senha, nada foi apagado. So depois os dados e, por ultimo,
/// o login (as regras do Firestore so deixam apagar enquanto ele existe).
Future<void> apagarContaCompleta({
  required Future<void> Function() reautenticar,
  required Future<void> Function() apagarDados,
  required Future<void> Function() apagarLogin,
}) async {
  await reautenticar();
  await apagarDados();
  await apagarLogin();
}

/// Apaga tudo do usuario na nuvem: as subcolecoes e depois o documento
/// do perfil. Le direto do servidor (sem internet, falha antes de apagar
/// qualquer coisa) e espera cada lote ser confirmado.
Future<void> apagarDadosDoUsuario(FirebaseFirestore db, String usuarioId) async {
  const doServidor = GetOptions(source: Source.server);
  for (final nome in _subcolecoes) {
    final docs = (await colecaoDoUsuario(db, usuarioId, nome).get(doServidor)).docs;
    for (var i = 0; i < docs.length; i += _tamanhoDoLote) {
      final lote = db.batch();
      for (final d in docs.skip(i).take(_tamanhoDoLote)) {
        lote.delete(d.reference);
      }
      await lote.commit().timeout(_limiteDoServidor);
    }
  }
  await db.collection('usuarios').doc(usuarioId).delete().timeout(_limiteDoServidor);
}
