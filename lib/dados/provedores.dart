import 'package:nested/nested.dart' show SingleChildWidget;
import 'package:powersync/powersync.dart' show PowerSyncDatabase;
import 'package:provider/provider.dart';

import 'relatorios.dart';
import 'repositorios.dart';

/// Injecao de dependencia (padrao Provider): os repositorios sao montados
/// uma vez so, aqui, em vez de cada tela criar o seu com
/// `XRepositorio(widget.db)`. As telas so pedem o que precisam com
/// `context.read<XRepositorio>()` — nao sabem como o repositorio e
/// construido, nem precisam receber `db` de tela em tela.
List<SingleChildWidget> provedoresDeDados(PowerSyncDatabase db) {
  return [
    Provider<PowerSyncDatabase>.value(value: db),
    Provider<PerfilRepositorio>(create: (_) => PerfilRepositorio(db)),
    Provider<CategoriasRepositorio>(create: (_) => CategoriasRepositorio(db)),
    Provider<ContasRepositorio>(create: (_) => ContasRepositorio(db)),
    Provider<LancamentosRepositorio>(create: (_) => LancamentosRepositorio(db)),
    Provider<RelatoriosRepositorio>(create: (_) => RelatoriosRepositorio(db)),
  ];
}
