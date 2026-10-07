import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';

import 'esquema.dart';

/// Abre o banco local do PowerSync. Esse e o mesmo banco que sincroniza
/// com o Supabase, entao nao existe um segundo banco separado.
///
/// Sem [caminho], usa o padrao do app. Os testes passam um caminho proprio.
Future<PowerSyncDatabase> abrirBanco({String? caminho}) async {
  final destino = caminho ?? await _caminhoPadrao();
  final db = PowerSyncDatabase(schema: esquema, path: destino);
  await db.initialize();
  return db;
}

Future<String> _caminhoPadrao() async {
  // Na Web o PowerSync guarda o arquivo no navegador, so precisa do nome.
  if (kIsWeb) return 'controle_gastos.db';
  final pasta = await getApplicationSupportDirectory();
  return '${pasta.path}/controle_gastos.db';
}
