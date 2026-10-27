import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/erros_auth.dart';
import '../dados/autenticacao.dart';

/// Conta criada com e-mail e senha so entra depois de confirmar o e-mail.
/// O AuthGate troca esta tela pelo app quando o Firebase confirmar.
class TelaConfirmarEmail extends StatefulWidget {
  const TelaConfirmarEmail({super.key, required this.email});

  final String email;

  @override
  State<TelaConfirmarEmail> createState() => _TelaConfirmarEmailState();
}

class _TelaConfirmarEmailState extends State<TelaConfirmarEmail> {
  late final _auth = context.read<Autenticacao>();
  bool _carregando = false;
  String? _aviso;

  Future<void> _executar(Future<void> Function() acao) async {
    setState(() {
      _carregando = true;
      _aviso = null;
    });
    try {
      await acao();
    } on FirebaseAuthException catch (e) {
      final m = mensagemAuth(e);
      if (m.isNotEmpty && mounted) setState(() => _aviso = m);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _jaConfirmei() => _executar(() async {
        await _auth.recarregar();
        // Confirmado: o AuthGate ja vai trocar de tela sozinho.
        if (!(_auth.atual?.emailVerified ?? false) && mounted) {
          setState(() => _aviso = 'Ainda não recebemos a confirmação.');
        }
      });

  Future<void> _reenviar() => _executar(() async {
        await _auth.reenviarConfirmacao();
        if (mounted) setState(() => _aviso = 'E-mail reenviado.');
      });

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
                const Icon(Icons.mark_email_unread_outlined, size: 48),
                const SizedBox(height: 16),
                const Text('Confirme seu e-mail', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(
                  'Enviamos um link de confirmação para ${widget.email}. '
                  'Abra o e-mail e toque no link para continuar.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (_aviso != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_aviso!, textAlign: TextAlign.center),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _carregando ? null : _jaConfirmei,
                    child: const Text('Já confirmei'),
                  ),
                ),
                TextButton(onPressed: _carregando ? null : _reenviar, child: const Text('Reenviar e-mail')),
                TextButton(onPressed: _carregando ? null : _auth.sair, child: const Text('Sair')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
