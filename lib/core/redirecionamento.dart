import 'package:flutter/foundation.dart' show kIsWeb;

/// Para onde o Supabase manda a pessoa de volta depois do login com
/// Google ou do link de "esqueci minha senha".
///
/// Na Web e a propria pagina. No Android e um link do app, registrado no
/// AndroidManifest.xml — `Uri.base` la vira `file:///` e o link quebrava.
/// Os dois enderecos precisam estar em Authentication > URL Configuration
/// > Redirect URLs no painel do Supabase.
const linkDoApp = 'controlegastos://login-callback';

String get urlDeRetornoAuth => kIsWeb ? Uri.base.removeFragment().toString() : linkDoApp;
