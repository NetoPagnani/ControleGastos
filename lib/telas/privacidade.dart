import 'package:flutter/material.dart';

import '../core/privacidade.dart';

class TelaPrivacidade extends StatelessWidget {
  const TelaPrivacidade({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Política de privacidade')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(politicaDePrivacidade.trim()),
      ),
    );
  }
}
