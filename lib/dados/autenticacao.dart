import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

/// Tudo de login num lugar so. As telas falam com esta classe, nunca com o
/// FirebaseAuth direto; assim o AuthGate pode ser testado com um auth falso.
class Autenticacao {
  Autenticacao(this._auth);

  final FirebaseAuth _auth;
  bool _googleIniciado = false;

  /// Avisa login, logout e tambem quando o e-mail passa a confirmado
  /// (depois de [recarregar]).
  Stream<User?> get usuario => _auth.userChanges();

  User? get atual => _auth.currentUser;

  Future<void> criarConta(String email, String senha) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: senha);
    await cred.user?.sendEmailVerification();
  }

  Future<void> entrar(String email, String senha) =>
      _auth.signInWithEmailAndPassword(email: email, password: senha);

  Future<void> entrarComGoogle() async {
    if (kIsWeb) {
      await _auth.signInWithPopup(GoogleAuthProvider());
      return;
    }
    await _auth.signInWithCredential(await _credencialGoogle());
  }

  /// No Android, o client id do servidor vem do google-services.json
  /// (default_web_client_id), por isso o initialize vai sem parametros.
  Future<AuthCredential> _credencialGoogle() async {
    if (!_googleIniciado) {
      await GoogleSignIn.instance.initialize();
      _googleIniciado = true;
    }
    try {
      final conta = await GoogleSignIn.instance.authenticate();
      return GoogleAuthProvider.credential(idToken: conta.authentication.idToken);
    } on GoogleSignInException catch (e) {
      // Mesmo codigo que o mensagemAuth entende como "nao mostrar nada".
      if (e.code == GoogleSignInExceptionCode.canceled) throw FirebaseAuthException(code: 'canceled');
      rethrow;
    }
  }

  Future<void> enviarRedefinicaoDeSenha(String email) => _auth.sendPasswordResetEmail(email: email);

  Future<void> reenviarConfirmacao() async => _auth.currentUser?.sendEmailVerification();

  Future<void> recarregar() async => _auth.currentUser?.reload();

  bool get entrouComGoogle =>
      _auth.currentUser?.providerData.any((p) => p.providerId == GoogleAuthProvider.PROVIDER_ID) ?? false;

  Future<void> reautenticarComSenha(String senha) async {
    final u = _auth.currentUser!;
    await u.reauthenticateWithCredential(EmailAuthProvider.credential(email: u.email!, password: senha));
  }

  Future<void> reautenticarComGoogle() async {
    final u = _auth.currentUser!;
    if (kIsWeb) {
      await u.reauthenticateWithPopup(GoogleAuthProvider());
      return;
    }
    await u.reauthenticateWithCredential(await _credencialGoogle());
  }

  Future<void> apagarUsuario() => _auth.currentUser!.delete();

  Future<void> sair() async {
    await _auth.signOut();
    if (!kIsWeb && _googleIniciado) await GoogleSignIn.instance.signOut();
  }
}
