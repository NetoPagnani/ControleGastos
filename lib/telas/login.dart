import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/erros_auth.dart';
import '../core/redirecionamento.dart';

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
  String? _aviso;

  Future<void> _entrarOuCriar() async {
    setState(() {
      _carregando = true;
      _erro = null;
      _aviso = null;
    });
    try {
      final auth = Supabase.instance.client.auth;
      if (_criandoConta) {
        await auth.signUp(
          email: _email.text.trim(),
          password: _senha.text,
          emailRedirectTo: urlDeRetornoAuth,
        );
      } else {
        await auth.signInWithPassword(email: _email.text.trim(), password: _senha.text);
      }
    } on AuthException catch (e) {
      setState(() => _erro = mensagemAuthSupabase(e));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _entrarComGoogle() async {
    setState(() {
      _carregando = true;
      _erro = null;
      _aviso = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: urlDeRetornoAuth,
      );
    } on AuthException catch (e) {
      setState(() => _erro = mensagemAuthSupabase(e));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _esqueciSenha() async {
    final controlador = TextEditingController(text: _email.text);
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recuperar senha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Digite o e-mail da sua conta. Vamos mandar um link pra você criar uma senha nova.'),
            const SizedBox(height: 12),
            TextField(
              controller: controlador,
              decoration: const InputDecoration(labelText: 'E-mail'),
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enviar link')),
        ],
      ),
    );

    if (confirmou != true || controlador.text.trim().isEmpty) return;

    setState(() {
      _carregando = true;
      _erro = null;
      _aviso = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        controlador.text.trim(),
        redirectTo: urlDeRetornoAuth,
      );
      // Mensagem igual tenha dado certo ou o e-mail nao exista: assim
      // ninguem descobre por aqui quais e-mails tem conta no app.
      setState(() => _aviso = 'Se esse e-mail tiver uma conta, enviamos um link de recuperação pra ele.');
    } on AuthException catch (e) {
      setState(() => _erro = mensagemAuthSupabase(e));
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
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _carregando ? null : _esqueciSenha,
                    child: const Text('Esqueci minha senha'),
                  ),
                ),
                if (_erro != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_erro!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                if (_aviso != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_aviso!, textAlign: TextAlign.center),
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
