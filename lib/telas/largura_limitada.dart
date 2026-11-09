import 'package:flutter/material.dart';

/// Telas pensadas para celular (teclado de valor, grade de categorias)
/// ficam com largura de celular e centralizadas numa janela larga; sem
/// isso, no navegador do computador as teclas e os cartoes viravam gigantes.
class LarguraLimitada extends StatelessWidget {
  const LarguraLimitada({super.key, required this.child});

  static const maxima = 480.0;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: maxima), child: child),
    );
  }
}
