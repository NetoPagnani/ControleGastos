import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Teclado numerico do "Novo gasto". No celular se toca nas teclas da tela;
/// no computador as teclas fisicas (numeros, teclado numerico, Backspace e
/// Enter) fazem a mesma coisa.
class TecladoDeValor extends StatelessWidget {
  const TecladoDeValor({super.key, required this.onTecla, required this.onConfirmar});

  /// Recebe '0' a '9' ou '⌫'.
  final ValueChanged<String> onTecla;
  final VoidCallback onConfirmar;

  static const _teclas = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];

  static final _digitos = {
    for (var i = 0; i <= 9; i++) ...{
      LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + i): '$i',
      LogicalKeyboardKey(LogicalKeyboardKey.numpad0.keyId + i): '$i',
    },
  };

  KeyEventResult _teclaFisica(FocusNode _, KeyEvent evento) {
    if (evento is KeyUpEvent) return KeyEventResult.ignored;
    final tecla = evento.logicalKey;
    final digito = _digitos[tecla];
    if (digito != null) {
      onTecla(digito);
    } else if (tecla == LogicalKeyboardKey.backspace || tecla == LogicalKeyboardKey.delete) {
      onTecla('⌫');
    } else if (evento is KeyDownEvent &&
        (tecla == LogicalKeyboardKey.enter || tecla == LogicalKeyboardKey.numpadEnter)) {
      onConfirmar();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _teclaFisica,
      child: GridView.count(
        crossAxisCount: 3,
        childAspectRatio: 1.7,
        children: [
          for (final t in _teclas)
            t.isEmpty
                ? const SizedBox.shrink()
                : InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onTecla(t),
                    child: Center(
                      child: Text(t, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                    ),
                  ),
        ],
      ),
    );
  }
}
