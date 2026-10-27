import 'dart:async';

import 'package:controle_gastos/dados/gravacao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nao espera o servidor', () {
    final nunca = Completer<void>().future;
    gravarSemEsperar(nunca); // se esperasse, o teste nunca terminaria
  });

  test('falha vira aviso', () async {
    gravarSemEsperar(Future.error(Exception('x')));
    await Future<void>.delayed(Duration.zero);
    expect(erroDeGravacao.value, 'Não foi possível salvar uma alteração. Tente de novo.');
  });
}
