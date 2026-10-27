import 'package:flutter/foundation.dart';

/// Aviso de gravacao que falhou depois que a tela ja seguiu em frente. A
/// TelaPrincipal mostra o texto e zera o valor.
final erroDeGravacao = ValueNotifier<String?>(null);

/// O Firestore so completa a gravacao quando o servidor confirma; sem
/// internet isso nunca acontece. A gravacao local ja vale na hora, entao
/// o app nao espera: so fica de olho para avisar se der erro.
void gravarSemEsperar(Future<void> escrita) {
  escrita.catchError((Object e) {
    debugPrint('Gravacao falhou: $e');
    erroDeGravacao.value = 'Não foi possível salvar uma alteração. Tente de novo.';
  });
}
