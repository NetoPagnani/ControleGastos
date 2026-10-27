import 'package:controle_gastos/dados/repositorios.dart';
import 'package:controle_gastos/telas/gastos.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  late LancamentosRepositorio repo;

  setUp(() {
    repo = LancamentosRepositorio(FakeFirebaseFirestore(), usuarioAtual: () => 'u1');
  });

  Future<void> mostrar(WidgetTester tester) async {
    final l = (await repo.todos('u1')).first;
    await tester.pumpWidget(
      Provider<LancamentosRepositorio>.value(
        value: repo,
        child: MaterialApp(
          home: Scaffold(
            body: LinhaDeGasto(lancamento: l, nomeCategoria: const {}, nomeConta: const {}),
          ),
        ),
      ),
    );
  }

  Future<void> arrastar(WidgetTester tester) async {
    await tester.drag(find.byType(LinhaDeGasto), const Offset(-600, 0));
    await tester.pumpAndSettle();
  }

  Future<void> lancar({int parcelas = 1}) async {
    await repo.lancarCompra(
      usuarioId: 'u1',
      contaId: 'c',
      categoriaId: 'k',
      totalCentavos: 300,
      data: DateTime(2026, 3, 1),
      parcelas: parcelas,
    );
    await Future<void>.delayed(Duration.zero);
  }

  testWidgets('arrastar pede confirmacao e apaga o gasto', (tester) async {
    await tester.runAsync(lancar);
    await tester.runAsync(() => mostrar(tester));
    await arrastar(tester);
    expect(find.text('Apagar este gasto?'), findsOneWidget);
    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => repo.todos('u1')), isEmpty);
  });

  testWidgets('cancelar a confirmacao nao apaga', (tester) async {
    await tester.runAsync(lancar);
    await tester.runAsync(() => mostrar(tester));
    await arrastar(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => repo.todos('u1')), hasLength(1));
    expect(find.byType(LinhaDeGasto), findsOneWidget);
  });

  testWidgets('parcela pergunta se apaga so ela ou a compra inteira', (tester) async {
    await tester.runAsync(() => lancar(parcelas: 3));
    await tester.runAsync(() => mostrar(tester));
    await arrastar(tester);
    await tester.tap(find.text('Apagar todas as parcelas'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => repo.todos('u1')), isEmpty);
  });
}
