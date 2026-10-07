import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// E-mail/senha e Google. O AuthGate troca esta tela pelo app assim que
/// o Supabase Auth confirmar a sessao.
class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _criandoConta = false;
  bool _carregando = false;
  String? _erro;

  Future<void> _entrarOuCriar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final auth = Supabase.instance.client.auth;
      if (_criandoConta) {
        await auth.signUp(email: _email.text.trim(), password: _senha.text);
      } else {
        await auth.signInWithPassword(email: _email.text.trim(), password: _senha.text);
      }
    } on AuthException catch (e) {
      setState(() => _erro = e.message);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _entrarComGoogle() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOAuth(OAuthProvider.google);
    } on AuthException catch (e) {
      setState(() => _erro = e.message);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Controle de Gastos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _senha,
                  decoration: const InputDecoration(labelText: 'Senha'),
                  obscureText: true,
                  onSubmitted: (_) => _entrarOuCriar(),
                ),
                const SizedBox(height: 16),
                if (_erro != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_erro!, style: const TextStyle(color: Colors.red)),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _carregando ? null : _entrarOuCriar,
                    child: _carregando
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_criandoConta ? 'Criar conta' : 'Entrar'),
                  ),
                ),
                TextButton(
                  onPressed: _carregando ? null : () => setState(() => _criandoConta = !_criandoConta),
                  child: Text(_criandoConta ? 'Já tenho conta' : 'Criar uma conta nova'),
                ),
                const Divider(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _carregando ? null : _entrarComGoogle,
                    icon: const Icon(Icons.login),
                    label: const Text('Entrar com Google'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
