# Migração para o Firebase — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trocar Supabase + PowerSync por Firebase Authentication + Cloud Firestore sem mudar o que o usuário vê, mantendo o uso offline.

**Architecture:** Os repositórios de `lib/dados` mantêm as mesmas classes, funções e retornos, mas passam a ler e gravar em `usuarios/{uid}/...` no Firestore, e os relatórios somam em Dart. O login sai das telas e vai para uma classe `Autenticacao` que recebe o `FirebaseAuth`, para que o `AuthGate` possa ser testado com um auth simulado.

**Tech Stack:** Flutter, `firebase_core`, `firebase_auth`, `cloud_firestore`, `google_sign_in` (v7), `provider`; testes com `fake_cloud_firestore` e `firebase_auth_mocks`.

**Spec:** `docs/superpowers/specs/2026-10-26-migracao-firebase-design.md`

## Global Constraints

- Plano Spark (gratuito): nada de Cloud Functions nem de recurso pago.
- Dinheiro em centavos inteiros (`int`); datas gravadas como texto `AAAA-MM-DD` (`formatarData`).
- `arquivada` e `ativa` gravados como `bool`.
- Caminho dos dados: `usuarios/{uid}` com as subcoleções `contas`, `categorias`, `lancamentos`, `recorrencias`; sem campo `usuario_id`.
- Consultas com um campo de filtro só (ou filtro e ordenação no mesmo campo); qualquer outra ordenação é feita em Dart. Nenhum índice composto.
- Gravações não esperam a confirmação do servidor (ver `gravarSemEsperar`, Tarefa 3).
- Toda mensagem na tela em português. Nunca mostrar texto de erro em inglês.
- Commits sem nenhuma linha de coautoria do Claude.
- `lib/firebase_options.dart` e `android/app/google-services.json` ficam fora do git.
- `flutter analyze` sem avisos ao fim das Tarefas 1, 2, 6 e 7. Entre a Tarefa 3 e a 6, as telas ainda montam os repositórios com o PowerSync e `lib/` não compila por inteiro; nessas tarefas, rode só os testes da própria tarefa.

## Review Focus

- **Gravar sem internet:** lançar um gasto offline não pode travar a tela esperando o servidor. Teste em Tarefa 3 (`gravarSemEsperar` com um `Future` que nunca termina).
- **Apagar conta com mais de 500 documentos:** o Firestore limita lotes a 500 operações; nada pode sobrar. Teste em Tarefa 5 (501 lançamentos).
- **Cancelar o login com Google:** fechar a janela do Google não é um erro e não deve mostrar mensagem. Teste em Tarefa 2 (`popup-closed-by-user` e `canceled` → texto vazio).
- **Categoria ou conta arquivada no histórico:** gastos antigos continuam mostrando o nome. Teste em Tarefa 3 (`observarNomes` inclui arquivadas).
- **Limites do período:** um gasto com data igual a `fim` fica fora e um com data igual a `inicio` fica dentro. Teste em Tarefa 3 (`observarPeriodo`) e Tarefa 4 (`totalPeriodo`).

---

### Tarefa 1: Ligar o Firebase ao projeto

Pré-requisito do usuário: projeto criado no console, provedores E-mail/senha e Google ativos, Firestore criado em `southamerica-east1`, `firebase login` feito.

**Files:**
- Create: `lib/firebase_options.dart` (gerado), `android/app/google-services.json` (gerado), `firestore.rules`, `firebase.json`
- Modify: `pubspec.yaml`, `.gitignore`, arquivos Gradle do Android (alterados pelo `flutterfire configure`)

**Interfaces:**
- Produces: `DefaultFirebaseOptions.currentPlatform` em `lib/firebase_options.dart`.

- [ ] **Step 1: Commitar o que está pendente** (`lib/main.dart` e `lib/core/erros_auth.dart`), mensagem `Abre o banco uma vez so e mensagem de sem conexao`.
- [ ] **Step 2: Instalar o FlutterFire CLI**

Run: `dart pub global activate flutterfire_cli`
Expected: `Activated flutterfire_cli`.

- [ ] **Step 3: Gerar a configuração**

Run: `flutterfire configure --platforms=android,web` e escolher o projeto do usuário.
Expected: cria `lib/firebase_options.dart` e `android/app/google-services.json` e adiciona o plugin `com.google.gms.google-services` ao Gradle.

- [ ] **Step 4: Adicionar pacotes**

Run: `flutter pub add firebase_core firebase_auth cloud_firestore google_sign_in` e `flutter pub add --dev fake_cloud_firestore firebase_auth_mocks`.
Se o build do Android reclamar de `minSdk`, trocar `minSdk = flutter.minSdkVersion` por `minSdk = 23` em `android/app/build.gradle.kts`.

- [ ] **Step 5: Ignorar os arquivos gerados**: acrescentar `lib/firebase_options.dart` ao `.gitignore` e `app/google-services.json` ao `android/.gitignore`.

- [ ] **Step 6: Escrever `firestore.rules`** com exatamente as regras da seção 3 da spec, e `firebase.json`:

```json
{ "firestore": { "rules": "firestore.rules" } }
```

- [ ] **Step 7: Publicar as regras**

Run: `firebase deploy --only firestore:rules`
Expected: `Deploy complete!`

- [ ] **Step 8: Conferir que compila**

Run: `flutter analyze` e `flutter build web`
Expected: sem avisos; build termina.

- [ ] **Step 9: Commit** `pubspec.yaml`, `pubspec.lock`, `.gitignore`, `android/.gitignore`, Gradle, `firestore.rules`, `firebase.json` com a mensagem `Firebase configurado no projeto`.

---

### Tarefa 2: Mensagens de erro do Firebase Auth

**Files:**
- Modify: `lib/core/erros_auth.dart`
- Test: `test/core/erros_auth_test.dart`

**Interfaces:**
- Produces: `String mensagemAuth(FirebaseAuthException e)`; devolve `''` quando não há nada a mostrar (login cancelado pela pessoa).

- [ ] **Step 1: Escrever os testes**

```dart
String m(String code) => mensagemAuth(FirebaseAuthException(code: code));

test('credenciais erradas', () {
  for (final c in ['invalid-credential', 'wrong-password', 'user-not-found']) {
    expect(m(c), 'E-mail ou senha incorretos.');
  }
});
test('e-mail em uso', () => expect(m('email-already-in-use'), 'Já existe uma conta com esse e-mail.'));
test('senha fraca', () => expect(m('weak-password'), 'Senha muito fraca. Use pelo menos 6 caracteres.'));
test('e-mail invalido', () => expect(m('invalid-email'), 'Digite um e-mail válido.'));
test('muitas tentativas', () => expect(m('too-many-requests'), 'Muitas tentativas seguidas. Espere um pouco e tente de novo.'));
test('sem internet', () => expect(m('network-request-failed'), 'Sem conexão com o servidor. Verifique sua internet e tente de novo.'));
test('login antigo', () => expect(m('requires-recent-login'), 'Por segurança, entre de novo para continuar.'));
test('cancelou o Google', () {
  expect(m('popup-closed-by-user'), '');
  expect(m('canceled'), '');
});
test('desconhecido', () => expect(m('qualquer-coisa'), 'Não foi possível completar a ação. Tente novamente em instantes.'));
```

- [ ] **Step 2: Rodar e ver falhar** — `flutter test test/core/erros_auth_test.dart`; falha de compilação (o tipo ainda é `AuthException` do Supabase).
- [ ] **Step 3: Reescrever `mensagemAuth`** como um `switch (e.code)` com os textos acima, sem nada do Supabase.
- [ ] **Step 4: Rodar e ver passar.**
- [ ] **Step 5: Commit** `Mensagens de erro do Firebase Auth`.

(Para `login.dart` e `nova_senha.dart` continuarem compilando até a Tarefa 6, mantenha a função antiga no mesmo arquivo com o nome `mensagemAuthSupabase` e troque as chamadas nessas duas telas para ela. Ela sai na Tarefa 7.)

---

### Tarefa 3: Repositórios no Firestore

**Files:**
- Create: `lib/dados/gravacao.dart`
- Modify: `lib/dados/repositorios.dart`
- Test: `test/dados/gravacao_test.dart`, `test/dados/repositorios_test.dart`

**Interfaces:**
- Consumes: `usuarioAtualId` de `lib/core/usuario_atual.dart` (como padrão do construtor).
- Produces:
  - `final ValueNotifier<String?> erroDeGravacao` e `void gravarSemEsperar(Future<void> escrita)` em `gravacao.dart`. `gravarSemEsperar` não espera `escrita`; se ela falhar, coloca em `erroDeGravacao.value` o texto `'Não foi possível salvar uma alteração. Tente de novo.'`.
  - `CollectionReference<Map<String, dynamic>> colecaoDoUsuario(FirebaseFirestore db, String usuarioId, String nome)` em `repositorios.dart` → `db.collection('usuarios').doc(usuarioId).collection(nome)`.
  - Construtores `CategoriasRepositorio(FirebaseFirestore db, {String Function()? usuarioAtual})`, e o mesmo para `PerfilRepositorio`, `ContasRepositorio`, `LancamentosRepositorio`. `usuarioAtual` tem como padrão `() => usuarioAtualId` e é usado pelas funções que recebem só o `id` (`arquivar`, `renomear`, `editar`, `apagarCompra`, `apagarParcela`, `editarParcela`, `editarCompra`).
  - Todas as funções públicas atuais mantêm nome, parâmetros e retorno.

- [ ] **Step 1: Teste de `gravarSemEsperar`**

```dart
test('nao espera o servidor', () {
  final nunca = Completer<void>().future;
  gravarSemEsperar(nunca); // se esperasse, o teste nunca terminaria
});
test('falha vira aviso', () async {
  gravarSemEsperar(Future.error(Exception('x')));
  await Future<void>.delayed(Duration.zero);
  expect(erroDeGravacao.value, 'Não foi possível salvar uma alteração. Tente de novo.');
});
```

- [ ] **Step 2: Rodar, ver falhar, implementar `gravacao.dart`, rodar e ver passar.**

- [ ] **Step 3: Testes dos repositórios** em `test/dados/repositorios_test.dart`, com `final db = FakeFirebaseFirestore();` e `usuarioAtual: () => 'u1'`:

```dart
test('garantirPadroes cria as 9 categorias e nao duplica', () async {
  await categorias.garantirPadroes('u1');
  await categorias.garantirPadroes('u1');
  final lista = await categorias.observarAtivas('u1').first;
  expect(lista.map((c) => c.nome), CategoriasRepositorio.padroes);
});
test('observarNomes inclui categoria arquivada', () async {
  await categorias.garantirPadroes('u1');
  final id = CategoriasRepositorio.idPadrao('u1', 'Lazer');
  await categorias.arquivar(id);
  expect((await categorias.observarAtivas('u1').first).any((c) => c.id == id), isFalse);
  expect((await categorias.observarNomes('u1').first)[id], 'Lazer');
});
test('criar categoria vai para o fim da ordem', () async {
  await categorias.garantirPadroes('u1');
  await categorias.criar('u1', 'Pets');
  expect((await categorias.observarAtivas('u1').first).last.nome, 'Pets');
});
test('renda: 0 sem perfil, depois o valor definido', () async {
  expect(await perfil.observarRendaCentavos('u1').first, 0);
  await perfil.garantirPerfil('u1');
  await perfil.definirRendaCentavos('u1', 500000);
  await perfil.garantirPerfil('u1'); // nao zera
  expect(await perfil.observarRendaCentavos('u1').first, 500000);
});
test('conta arquivada sai das ativas e fica nos nomes', () async {
  final id = await contas.criar(usuarioId: 'u1', apelido: 'Nubank', tipo: 'cartao', diaFechamento: 5, diaVencimento: 12);
  await contas.arquivar(id);
  expect(await contas.observarAtivas('u1').first, isEmpty);
  expect((await contas.observarNomes('u1').first)[id], 'Nubank');
});
test('compra em 3x cria 3 parcelas com o mesmo compra_id', () async {
  await lancamentos.lancarCompra(usuarioId: 'u1', contaId: 'c', categoriaId: 'k',
      totalCentavos: 10000, data: DateTime(2026, 1, 31), parcelas: 3);
  final todos = await lancamentos.todos('u1');
  expect(todos.map((l) => l.valorCentavos), [3334, 3333, 3333]);
  expect(todos.map((l) => l.compraId).toSet().length, 1);
  expect(todos.map((l) => l.parcelaNum), [1, 2, 3]);
});
test('apagarCompra apaga todas as parcelas; apagarParcela so uma', () async { /* 2x e 1x; conferir com todos() */ });
test('editarCompra muda conta, categoria e descricao de todas as parcelas', () async { /* ... */ });
test('editarParcela muda so aquela parcela', () async { /* ... */ });
test('ultimaEscolha devolve conta e categoria do ultimo criado', () async { /* null sem lancamentos */ });
test('observarPeriodo: inicio incluso, fim excluso, mais recente primeiro', () async {
  for (final d in [DateTime(2026, 3, 1), DateTime(2026, 3, 15), DateTime(2026, 4, 1)]) {
    await lancamentos.lancarCompra(usuarioId: 'u1', contaId: 'c', categoriaId: 'k', totalCentavos: 100, data: d);
  }
  final lista = await lancamentos.observarPeriodo(usuarioId: 'u1', inicio: DateTime(2026, 3, 1), fim: DateTime(2026, 4, 1)).first;
  expect(lista.map((l) => l.data), [DateTime(2026, 3, 15), DateTime(2026, 3, 1)]);
});
test('dados de outro usuario nao aparecem', () async { /* lancar para u2, todos('u1') vazio */ });
```

As datas das parcelas no teste de 3x vêm de `datasDasParcelas`; confira os valores esperados contra `test/dominio/parcelamento_test.dart` em vez de supor.

- [ ] **Step 4: Rodar e ver falhar** — `flutter test test/dados/repositorios_test.dart`.

- [ ] **Step 5: Reescrever `repositorios.dart`** trocando `PowerSyncDatabase` por `FirebaseFirestore`:
  - Gravações por `WriteBatch` (compra parcelada num lote só), entregues a `gravarSemEsperar(batch.commit())`; a função retorna logo em seguida.
  - `garantirPadroes` e `garantirPerfil` usam `set(..., SetOptions(merge: true))` só com os campos de criação, para não sobrescrever renda nem nomes editados. Em `garantirPadroes`, gravar só as categorias cujo documento ainda não existe (ler a coleção antes).
  - `criar` de categoria lê a coleção, calcula a maior `ordem` em Dart e grava `maior + 1`.
  - `observar*` usam `snapshots()`; `observarAtivas` filtra `arquivada == false` e ordena em Dart (categorias por `ordem`, depois `nome`; contas por `apelido`).
  - `observarPeriodo` filtra `data >= formatarData(inicio)` e `data < formatarData(fim)` e ordena em Dart por `data` desc, depois `criado_em` desc.
  - `apagarCompra` consulta `compra_id == compraId` e apaga num lote.
  - `ultimaEscolha` usa `orderBy('criado_em', descending: true).limit(1).get()`.
  - `todos` ordena em Dart por `data`, depois `criado_em`.

- [ ] **Step 6: Rodar e ver passar.** Se algum teste vir dados antigos logo após gravar, acrescente `await Future<void>.delayed(Duration.zero);` depois da gravação no teste.
- [ ] **Step 7: Commit** `Repositorios no Firestore`.

---

### Tarefa 4: Relatórios no Firestore

**Files:**
- Modify: `lib/dados/relatorios.dart`
- Test: `test/dados/relatorios_test.dart`

**Interfaces:**
- Consumes: `LancamentosRepositorio`, `colecaoDoUsuario`, `formatarData` (Tarefa 3).
- Produces: `RelatoriosRepositorio(FirebaseFirestore db)`; todas as funções atuais com os mesmos parâmetros e retornos.

- [ ] **Step 1: Testes** com `FakeFirebaseFirestore`, lançando via `LancamentosRepositorio`:

```dart
test('totalPeriodo soma com estorno, fim excluso', () async {
  // 1000 em 01/03, -200 em 10/03, 500 em 01/04
  expect(await rel.totalPeriodo(usuarioId: 'u1', inicio: DateTime(2026, 3, 1), fim: DateTime(2026, 4, 1)), 800);
});
test('somaPorCategoria ignora estornos', () async {
  // k1: 1000 e -200; k2: 300
  expect(await rel.somaPorCategoria(usuarioId: 'u1', inicio: DateTime(2026, 3, 1), fim: DateTime(2026, 4, 1)),
      {'k1': 1000, 'k2': 300});
});
test('comprometidoFuturo so conta parcelas depois de hoje', () async {
  // compra 3x de 30000 a partir de 10/03; gasto simples de 999 em 20/03; hoje = 15/03
  expect(await rel.comprometidoFuturo(usuarioId: 'u1', hoje: DateTime(2026, 3, 15)), 20000);
});
test('mesesDeHistorico conta meses distintos antes do mes de referencia', () async {
  // gastos em jan (2x), fev e mar; referencia mar
  expect(await rel.mesesDeHistorico(usuarioId: 'u1', mesReferencia: DateTime(2026, 3, 1)), 2);
});
test('faturaAberta soma so o periodo da fatura daquele cartao', () async { /* fechamento dia 5; compras dias 04, 06 e em outro cartao */ });
test('totaisUltimosMeses devolve 6 valores, o atual por ultimo', () async { /* ... */ });
```

- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Reescrever** com uma função privada `Future<List<Lancamento>> _lancamentos({required String usuarioId, String? de, String? ate})` que filtra só por `data` (limites como texto) e devolve a lista; somas, `parcelas_total > 1`, `valor_centavos > 0`, `conta_id` e meses distintos (`data.substring(0, 7)`) são filtrados em Dart. `calcularAlertas` não muda.
- [ ] **Step 4: Rodar e ver passar.**
- [ ] **Step 5: Commit** `Relatorios no Firestore`.

---

### Tarefa 5: Apagar os dados do usuário

**Files:**
- Create: `lib/dados/conta_usuario.dart`
- Test: `test/dados/conta_usuario_test.dart`

**Interfaces:**
- Produces: `Future<void> apagarDadosDoUsuario(FirebaseFirestore db, String usuarioId)` — apaga as quatro subcoleções em lotes de no máximo 500 e depois `usuarios/{usuarioId}`. Esta função **espera** o servidor (precisa de internet), ao contrário das gravações normais.

- [ ] **Step 1: Teste**

```dart
test('apaga tudo do usuario, inclusive mais de 500 lancamentos, e nada de outro', () async {
  final db = FakeFirebaseFirestore();
  for (var i = 0; i < 501; i++) {
    await colecaoDoUsuario(db, 'u1', 'lancamentos').doc('l$i').set({'valor_centavos': 1});
  }
  await colecaoDoUsuario(db, 'u1', 'contas').doc('c').set({'apelido': 'x'});
  await db.collection('usuarios').doc('u1').set({'renda_mensal_centavos': 1});
  await colecaoDoUsuario(db, 'u2', 'contas').doc('c').set({'apelido': 'y'});

  await apagarDadosDoUsuario(db, 'u1');

  for (final nome in ['contas', 'categorias', 'lancamentos', 'recorrencias']) {
    expect((await colecaoDoUsuario(db, 'u1', nome).get()).docs, isEmpty);
  }
  expect((await db.collection('usuarios').doc('u1').get()).exists, isFalse);
  expect((await colecaoDoUsuario(db, 'u2', 'contas').get()).docs, hasLength(1));
});
```

- [ ] **Step 2: Rodar, ver falhar, implementar, rodar e ver passar.**
- [ ] **Step 3: Commit** `Apagar dados do usuario no Firestore`.

---

### Tarefa 6: Login pelo Firebase e ligação do app

**Files:**
- Create: `lib/dados/autenticacao.dart`, `lib/telas/confirmar_email.dart`
- Modify: `lib/main.dart`, `lib/dados/banco.dart`, `lib/dados/provedores.dart`, `lib/core/usuario_atual.dart`, `lib/telas/auth_gate.dart`, `lib/telas/login.dart`, `lib/telas/configuracoes.dart`, `lib/telas/principal.dart`, `lib/telas/diagnostico.dart`
- Test: `test/widget_test.dart`

**Interfaces:**
- Consumes: `mensagemAuth` (Tarefa 2), repositórios (Tarefa 3), `RelatoriosRepositorio` (Tarefa 4), `apagarDadosDoUsuario` (Tarefa 5), `erroDeGravacao` (Tarefa 3).
- Produces:
  - `Future<FirebaseFirestore> abrirBanco()` em `banco.dart`: define `FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED)` e devolve a instância.
  - `class Autenticacao` com construtor `Autenticacao(FirebaseAuth auth)` e:
    - `Stream<User?> get usuario` (`auth.userChanges()`, que também avisa quando `emailVerified` muda após `reload`)
    - `Future<void> criarConta(String email, String senha)` (cria e chama `sendEmailVerification`)
    - `Future<void> entrar(String email, String senha)`
    - `Future<void> entrarComGoogle()` (Web: `signInWithPopup(GoogleAuthProvider())`; Android: `GoogleSignIn.instance.initialize(serverClientId: <client_id do tipo 3 no google-services.json>)`, `authenticate()`, `GoogleAuthProvider.credential(idToken: ...)`, `signInWithCredential`)
    - `Future<void> enviarRedefinicaoDeSenha(String email)`
    - `Future<void> reenviarConfirmacao()`
    - `Future<void> recarregar()` (`currentUser?.reload()`)
    - `Future<void> reautenticarComSenha(String senha)` e `Future<void> reautenticarComGoogle()`
    - `Future<void> apagarUsuario()` (`currentUser!.delete()`)
    - `Future<void> sair()` (`auth.signOut()` e, fora da Web, `GoogleSignIn.instance.signOut()`)
  - `ControleGastosApp({required FirebaseFirestore db, required FirebaseAuth auth})`.
  - `List<SingleChildWidget> provedoresDeDados(FirebaseFirestore db, Autenticacao auth)` — também fornece `Provider<FirebaseFirestore>` e `Provider<Autenticacao>`.
  - `usuarioAtualId` lê `FirebaseAuth.instance.currentUser`.

- [ ] **Step 1: Teste do AuthGate** em `test/widget_test.dart`:

```dart
testWidgets('sem login mostra a tela de login', (tester) async {
  await tester.pumpWidget(ControleGastosApp(db: FakeFirebaseFirestore(), auth: MockFirebaseAuth()));
  await tester.pumpAndSettle();
  expect(find.byType(TelaLogin), findsOneWidget);
});
testWidgets('e-mail nao confirmado mostra a tela de confirmacao', (tester) async {
  final auth = MockFirebaseAuth(signedIn: true,
      mockUser: MockUser(uid: 'u1', email: 'a@b.com', isEmailVerified: false));
  await tester.pumpWidget(ControleGastosApp(db: FakeFirebaseFirestore(), auth: auth));
  await tester.pumpAndSettle();
  expect(find.byType(TelaConfirmarEmail), findsOneWidget);
});
```

- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: `main.dart`**: `WidgetsFlutterBinding.ensureInitialized()`, `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`, `runApp(ControleGastosApp(db: await abrirBanco(), auth: FirebaseAuth.instance))`. O app monta `MultiProvider(providers: provedoresDeDados(db, Autenticacao(auth)), child: MaterialApp(... home: const AuthGate()))`, com o mesmo tema, idioma e título de hoje.
- [ ] **Step 4: `AuthGate`**: `StreamBuilder<User?>` sobre `context.read<Autenticacao>().usuario`. Sem usuário → `TelaLogin`. Usuário sem `emailVerified` e com provedor `password` → `TelaConfirmarEmail`. Caso contrário, o `_PreparandoConta` atual sem a parte do PowerSync (`garantirPerfil` e `garantirPadroes`, depois `TelaPrincipal`), com `ValueKey(user.uid)`.
- [ ] **Step 5: `TelaConfirmarEmail`**: mostra o e-mail e o texto "Enviamos um link de confirmação para {email}. Abra o e-mail e toque no link para continuar." e três botões: "Já confirmei" (`recarregar()`; se continuar sem confirmar, avisar "Ainda não recebemos a confirmação."), "Reenviar e-mail" (`reenviarConfirmacao()`; avisar "E-mail reenviado.") e "Sair" (`sair()`). Erros usam `mensagemAuth`.
- [ ] **Step 6: `TelaLogin`**: troca as chamadas do Supabase pelos métodos de `Autenticacao`; captura `FirebaseAuthException` e mostra `mensagemAuth(e)` só quando não for vazio. "Esqueci minha senha" chama `enviarRedefinicaoDeSenha` e avisa "Enviamos um link para redefinir sua senha.". Visual igual ao atual.
- [ ] **Step 7: `TelaConfiguracoes`**:
  - "Sair" chama `Autenticacao.sair()`.
  - "Apagar conta" chama `apagarDadosDoUsuario(db, usuarioAtualId)` e depois `apagarUsuario()`. Se der `requires-recent-login`, pede a senha num diálogo (ou chama `reautenticarComGoogle()` se o provedor for `google.com`) e tenta `apagarUsuario()` de novo. Se faltar internet, mostra `mensagemAuth(e)` ou o aviso atual.
  - O e-mail exibido vem de `FirebaseAuth.instance.currentUser?.email`.
- [ ] **Step 8: `TelaPrincipal`**: escuta `erroDeGravacao` e mostra o texto num `SnackBar`, zerando o valor em seguida.
- [ ] **Step 9: `TelaDiagnostico`**: substituir o autoteste do PowerSync por uma tela que mostra o e-mail, o uid e "Sincronizado" ou "Alterações esperando envio", a partir de `colecaoDoUsuario(db, uid, 'lancamentos').snapshots(includeMetadataChanges: true)` e `metadata.hasPendingWrites`.
- [ ] **Step 10: Rodar tudo** — `flutter analyze` e `flutter test`; esperado: sem avisos e tudo passando.
- [ ] **Step 11: Commit** `Login e app ligados ao Firebase`.

---

### Tarefa 7: Remover Supabase e PowerSync

**Files:**
- Delete: `lib/dados/esquema.dart`, `lib/dados/conector_sincronizacao.dart`, `lib/core/redirecionamento.dart`, `lib/core/app_config.dart`, `config/app_config.exemplo.dart`, `lib/telas/nova_senha.dart`, `supabase/`, `web/sqlite3.wasm`, `web/powersync_db.worker.js`, `web/powersync_sync.worker.js`
- Modify: `pubspec.yaml`, `.gitignore`, `android/app/src/main/AndroidManifest.xml`, `lib/core/privacidade.dart`, `web/privacidade.html`, `lib/core/erros_auth.dart`, `README.md`

- [ ] **Step 1: Apagar os arquivos listados** e a função `mensagemAuthSupabase`.
- [ ] **Step 2: Pacotes** — `flutter pub remove supabase_flutter powersync`.
- [ ] **Step 3: `AndroidManifest.xml`** — remover o `intent-filter` do esquema `controlegastos` (`login-callback`).
- [ ] **Step 4: `.gitignore`** — remover a linha `lib/core/app_config.dart`.
- [ ] **Step 5: Política de privacidade** (`lib/core/privacidade.dart` e `web/privacidade.html`, mesmo texto): trocar o trecho do Supabase e do PowerSync por "No seu aparelho e, para sincronizar, no Firebase, serviço do Google (banco de dados e login, servidores em São Paulo). A comunicação é criptografada (HTTPS). Cada conta só tem acesso aos próprios dados." Revisar o resto do texto por outras menções.
- [ ] **Step 6: README** — "Rodar": instalar o Firebase CLI e o FlutterFire CLI, `firebase login`, `flutterfire configure`. "Uma vez só": tirar os passos do Supabase; acrescentar publicar as regras (`firebase deploy --only firestore:rules`) e cadastrar no Firebase o SHA-1 das chaves de debug, de upload e de assinatura do Google Play (`keytool -list -v -keystore <arquivo>`; a do Google Play fica em Play Console > Integridade do app). Ficha da loja: trocar "Supabase" por "Firebase".
- [ ] **Step 7: Conferir que nada sobrou**

Run: `git grep -n -i "supabase\|powersync"`
Expected: só ocorrências nos documentos de `docs/superpowers/`.

- [ ] **Step 8: Rodar tudo** — `flutter analyze`, `flutter test` e `flutter build web`; sem avisos, tudo passando.
- [ ] **Step 9: Commit** `Remove Supabase e PowerSync`.

---

### Tarefa 8: Teste manual

- [ ] **Step 1: Chrome** — `flutter run -d chrome --web-port 5000`. Conferir: criar conta → tela de confirmação → confirmar pelo e-mail → "Já confirmei" entra; lançar gasto simples e 3x; Início, Gastos e Gráficos mostram os valores; "Esqueci minha senha" envia e-mail; entrar com Google; sair.
- [ ] **Step 2: Offline** — no DevTools, Network em "Offline": lançar um gasto, a tela não trava, e o diagnóstico mostra "Alterações esperando envio". Voltar online: passa para "Sincronizado".
- [ ] **Step 3: Outro aparelho** — com a mesma conta no Android, o gasto aparece.
- [ ] **Step 4: Regras** — no console do Firebase, Firestore > Regras > Simulador: leitura em `usuarios/OUTRO_UID/lancamentos/x` autenticado como outro uid é negada.
- [ ] **Step 5: Apagar conta** — os dados somem do console e o login deixa de funcionar.
- [ ] **Step 6:** Anotar no README qualquer passo de configuração que tenha faltado e fazer o commit.
