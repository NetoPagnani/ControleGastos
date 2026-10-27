import 'package:flutter/material.dart';

/// O "G" colorido do Google, desenhado a partir do SVG oficial (48x48) do
/// botao "Sign in with Google". Desenhado em codigo para nao precisar de
/// pacote de SVG nem de imagem.
class LogoGoogle extends StatelessWidget {
  const LogoGoogle({super.key, this.tamanho = 18});

  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(dimension: tamanho, child: const CustomPaint(painter: _PintorLogoGoogle()));
  }
}

const _partes = [
  (
    Color(0xFFEA4335),
    'M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 '
        '14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z',
  ),
  (
    Color(0xFF4285F4),
    'M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18'
        'l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z',
  ),
  (
    Color(0xFFFBBC05),
    'M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19'
        'C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z',
  ),
  (
    Color(0xFF34A853),
    'M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3'
        '-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z',
  ),
];

class _PintorLogoGoogle extends CustomPainter {
  const _PintorLogoGoogle();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48, size.height / 48);
    for (final (cor, caminho) in _partes) {
      canvas.drawPath(_caminhoSvg(caminho), Paint()..color = cor);
    }
  }

  @override
  bool shouldRepaint(_PintorLogoGoogle oldDelegate) => false;
}

/// Le so os comandos de caminho SVG que o logo usa: M, C, c, s, l, H, h, v, z.
Path _caminhoSvg(String d) {
  final tokens = RegExp(r'[A-Za-z]|-?\d*\.?\d+').allMatches(d).map((m) => m.group(0)!).toList();
  final path = Path();
  var i = 0;
  var comando = '';
  var x = 0.0, y = 0.0;
  // Ultimo ponto de controle, para o "s" (curva suave) espelhar.
  var cx = 0.0, cy = 0.0;
  double n() => double.parse(tokens[i++]);

  while (i < tokens.length) {
    if (RegExp(r'[A-Za-z]').hasMatch(tokens[i])) comando = tokens[i++];
    switch (comando) {
      case 'M':
        x = n();
        y = n();
        path.moveTo(x, y);
        comando = 'L';
      case 'L':
        x = n();
        y = n();
        path.lineTo(x, y);
      case 'l':
        x += n();
        y += n();
        path.lineTo(x, y);
      case 'H':
        x = n();
        path.lineTo(x, y);
      case 'h':
        x += n();
        path.lineTo(x, y);
      case 'v':
        y += n();
        path.lineTo(x, y);
      case 'C':
        final (x1, y1, x2, y2, x3, y3) = (n(), n(), n(), n(), n(), n());
        path.cubicTo(x1, y1, x2, y2, x3, y3);
        (cx, cy, x, y) = (x2, y2, x3, y3);
      case 'c':
        final (x1, y1, x2, y2, x3, y3) = (x + n(), y + n(), x + n(), y + n(), x + n(), y + n());
        path.cubicTo(x1, y1, x2, y2, x3, y3);
        (cx, cy, x, y) = (x2, y2, x3, y3);
      case 's':
        final (x1, y1) = (2 * x - cx, 2 * y - cy);
        final (x2, y2, x3, y3) = (x + n(), y + n(), x + n(), y + n());
        path.cubicTo(x1, y1, x2, y2, x3, y3);
        (cx, cy, x, y) = (x2, y2, x3, y3);
      case 'z':
        path.close();
      default:
        throw FormatException('Comando SVG nao suportado: $comando');
    }
  }
  return path;
}
