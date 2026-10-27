import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../dados/repositorios.dart';

/// Os lancamentos sao o que mais muda; olhar so eles basta para dizer se
/// ainda ha algo esperando o servidor.
Stream<QuerySnapshot<Map<String, dynamic>>> _observar(FirebaseFirestore db, String usuarioId) =>
    colecaoDoUsuario(db, usuarioId, 'lancamentos').snapshots(includeMetadataChanges: true);

Future<bool> temGravacoesPendentes(FirebaseFirestore db, String usuarioId) async =>
    (await _observar(db, usuarioId).first).metadata.hasPendingWrites;

/// Uma linha com o estado da sincronizacao, usada em Configuracoes e no
/// Diagnostico.
class StatusSincronizacao extends StatelessWidget {
  const StatusSincronizacao({super.key, required this.usuarioId});

  final String usuarioId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _observar(context.read<FirebaseFirestore>(), usuarioId),
      builder: (context, snap) {
        final meta = snap.data?.metadata;
        final (icone, texto) = switch (meta) {
          null => (Icons.cloud_queue, 'Verificando…'),
          SnapshotMetadata(hasPendingWrites: true) => (Icons.cloud_upload_outlined, 'Alterações esperando envio'),
          SnapshotMetadata(isFromCache: true) => (Icons.cloud_off_outlined, 'Sem conexão · tudo continua salvo no aparelho'),
          _ => (Icons.cloud_done_outlined, 'Sincronizado'),
        };
        return ListTile(contentPadding: EdgeInsets.zero, leading: Icon(icone), title: Text(texto));
      },
    );
  }
}
