import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';

/// Liga o banco local do PowerSync ao Supabase. O PowerSync usa o proprio
/// token de sessao do Supabase Auth — nao existe um login separado so
/// para o PowerSync.
class ConectorSupabase extends PowerSyncBackendConnector {
  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    final sessao = Supabase.instance.client.auth.currentSession;
    if (sessao == null) return null;
    return PowerSyncCredentials(endpoint: AppConfig.powersyncUrl, token: sessao.accessToken);
  }

  /// Chamado pelo PowerSync sempre que ha algo na fila local esperando
  /// para subir. Aplica cada mudanca no Supabase na mesma ordem em que
  /// foi feita no aparelho.
  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transacao = await database.getNextCrudTransaction();
    if (transacao == null) return;

    final cliente = Supabase.instance.client;
    for (final operacao in transacao.crud) {
      final tabela = cliente.from(operacao.table);
      switch (operacao.op) {
        case UpdateType.put:
          final dados = Map<String, dynamic>.of(operacao.opData ?? {});
          dados['id'] = operacao.id;
          await tabela.upsert(dados);
        case UpdateType.patch:
          await tabela.update(operacao.opData!).eq('id', operacao.id);
        case UpdateType.delete:
          await tabela.delete().eq('id', operacao.id);
      }
    }
    await transacao.complete();
  }
}
