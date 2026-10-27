import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/tema.dart';
import 'dados/autenticacao.dart';
import 'dados/provedores.dart';
import 'telas/auth_gate.dart';

/// O app recebe o banco e o login prontos (o main.dart cria os de
/// verdade); os testes passam versoes falsas.
class ControleGastosApp extends StatelessWidget {
  const ControleGastosApp({super.key, required this.db, required this.auth});

  final FirebaseFirestore db;
  final FirebaseAuth auth;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // Repositorios montados aqui, uma vez, e disponiveis pra qualquer
      // tela abaixo na arvore (ver dados/provedores.dart).
      providers: provedoresDeDados(db, Autenticacao(auth)),
      child: MaterialApp(
        title: 'Controle de Gastos',
        debugShowCheckedModeBanner: false,
        theme: construirTema(),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const AuthGate(),
      ),
    );
  }
}
