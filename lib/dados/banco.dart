import 'package:cloud_firestore/cloud_firestore.dart';

/// O Firestore guarda uma copia no aparelho (Android e Web) e sincroniza
/// sozinho quando tem internet. Sem limite de cache: os dados de uma
/// pessoa sao pequenos e precisam estar todos disponiveis offline.
Future<FirebaseFirestore> abrirBanco() async {
  final db = FirebaseFirestore.instance;
  db.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
  return db;
}
