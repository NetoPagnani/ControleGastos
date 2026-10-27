import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nested/nested.dart' show SingleChildWidget;
import 'package:provider/provider.dart';

import 'autenticacao.dart';
import 'relatorios.dart';
import 'repositorios.dart';

/// Injecao de dependencia (padrao Provider): os repositorios sao montados
/// uma vez so, aqui, em vez de cada tela criar o seu com
/// `XRepositorio(widget.db)`. As telas so pedem o que precisam com
/// `context.read<XRepositorio>()` — nao sabem como o repositorio e
/// construido, nem precisam receber `db` de tela em tela.
List<SingleChildWidget> provedoresDeDados(FirebaseFirestore db, Autenticacao auth) {
  return [
    Provider<FirebaseFirestore>.value(value: db),
    Provider<Autenticacao>.value(value: auth),
    Provider<PerfilRepositorio>(create: (_) => PerfilRepositorio(db)),
    Provider<CategoriasRepositorio>(create: (_) => CategoriasRepositorio(db)),
    Provider<ContasRepositorio>(create: (_) => ContasRepositorio(db)),
    Provider<LancamentosRepositorio>(create: (_) => LancamentosRepositorio(db)),
    Provider<RelatoriosRepositorio>(create: (_) => RelatoriosRepositorio(db)),
  ];
}
