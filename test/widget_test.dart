import 'package:controle_gastos/app.dart';
import 'package:controle_gastos/telas/confirmar_email.dart';
import 'package:controle_gastos/telas/login.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sem login mostra a tela de login', (tester) async {
    await tester.pumpWidget(ControleGastosApp(db: FakeFirebaseFirestore(), auth: MockFirebaseAuth()));
    await tester.pumpAndSettle();
    expect(find.byType(TelaLogin), findsOneWidget);
  });

  testWidgets('e-mail nao confirmado mostra a tela de confirmacao', (tester) async {
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1', email: 'a@b.com', isEmailVerified: false),
    );
    await tester.pumpWidget(ControleGastosApp(db: FakeFirebaseFirestore(), auth: auth));
    await tester.pumpAndSettle();
    expect(find.byType(TelaConfirmarEmail), findsOneWidget);
    expect(find.textContaining('a@b.com'), findsOneWidget);
  });
}
