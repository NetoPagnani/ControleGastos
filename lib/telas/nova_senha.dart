import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/erros_auth.dart';

/// Aberta quando a pessoa clica no link de recuperacao de senha que chegou
/// por e-mail. O Supabase ja criou uma sessao temporaria so para isto.
class TelaNovaSenha extends StatefulWidget {
  const TelaNovaSenha({super.key});

  @override
  State<TelaNovaSenha> createState() => _TelaNovaSenhaState();
}

class _TelaNovaSenhaState extends State<TelaNovaSenha> {
  final _senha = TextEditingController();
  final _confirmar = TextEditingController();
  bool _carregando = false;
  String? _erro;

  Future<void> _salvar() async {
    if (_senha.text.length < 6) {
      setState(() => _erro = 'A senha precisa ter pelo menos 6 caracteres.');
      return;
    }
    if (_senha.text != _confirmar.text) {
      setState(() => _erro = 'As senhas digitadas são diferentes.');
      return;
    }
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: _senha.text));
      // Sai e volta pro login normal, agora com a senha nova.
      await Supabase.instance.client.auth.signOut();
    } on AuthException catch (e) {
      setState(() => _erro = mensagemAuth(e));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova senha')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Defina sua nova senha', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: _senha,
                  decoration: const InputDecoration(labelText: 'Nova senha'),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmar,
                  decoration: const InputDecoration(labelText: 'Confirmar nova senha'),
                  obscureText: true,
                  onSubmitted: (_) => _salvar(),
                ),
                const SizedBox(height: 16),
                if (_erro != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_erro!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _carregando ? null : _salvar,
                    child: _carregando
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Salvar nova senha'),
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
