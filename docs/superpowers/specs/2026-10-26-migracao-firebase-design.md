# Migração para o Firebase — Spec de Design

**Data:** 2026-10-26
**Status:** rascunho aguardando revisão do usuário

---

## 1. Objetivo

Trocar o backend do app de **Supabase + PowerSync** para **Firebase (Authentication + Cloud Firestore)**.

O motivo é que o plano gratuito do Supabase pausa o projeto depois de cerca de 7 dias sem uso, e aí o app para de logar e de sincronizar até alguém restaurar o projeto no painel. O plano gratuito do Firebase (Spark) não pausa.

### Critérios de sucesso

- O app funciona igual para quem usa: mesmas telas, mesmos cálculos, mesmo uso offline no Android e na Web.
- Tudo cabe no plano Spark, sem cartão e sem Cloud Functions.
- Nenhuma referência ao Supabase ou ao PowerSync sobra no código, no `pubspec.yaml`, no README ou na política de privacidade.
- `flutter analyze` sem avisos e todos os testes passando.

### Fora do escopo

- **Migrar dados do Supabase.** Os dados atuais são de teste, então o app começa do zero no Firebase.
- Mudanças de tela ou de funcionalidade além das exigidas pela troca de login.
- Apagar o projeto do Supabase. Isso fica a critério do usuário depois que o Firebase estiver em uso.

---

## 2. Decisões

| Tema | Decisão | Motivo |
|---|---|---|
| Backend | Firebase Authentication + Cloud Firestore, plano Spark | Não pausa por inatividade |
| Sincronização | Cache local do Firestore (persistência ligada no Android e na Web) | Substitui o PowerSync, funciona offline e sincroniza sozinho |
| Relatórios | Ler os lançamentos do período e somar em Dart | Funciona offline; as consultas `sum()`/`count()` do Firestore sempre vão ao servidor |
| Dados existentes | Começar do zero | Só havia dados de teste |
| Confirmação de e-mail | Obrigatória para conta com e-mail e senha | Igual ao comportamento atual |
| Local do Firestore | `southamerica-east1` (São Paulo) | Mesmo local do Supabase atual |
| Dinheiro e datas | Inalterados: centavos inteiros e texto `AAAA-MM-DD` | As regras de `lib/dominio` e os filtros por período continuam valendo |

---

## 3. Modelo de dados no Firestore

Cada usuário tem um documento, e todos os dados dele ficam em subcoleções:

```
usuarios/{uid}                 nome, renda_mensal_centavos, criado_em, atualizado_em
  contas/{id}                  apelido, tipo, cor, icone, arquivada, limite_centavos,
                               dia_fechamento, dia_vencimento, criado_em, atualizado_em
  categorias/{id}              nome, icone, cor, ordem, arquivada, criado_em, atualizado_em
  lancamentos/{id}             conta_id, categoria_id, valor_centavos, descricao, data,
                               compra_id, parcela_num, parcelas_total, criado_em, atualizado_em
  recorrencias/{id}            conta_id, categoria_id, descricao, valor_centavos, dia_do_mes,
                               inicio, fim, ativa, criado_em, atualizado_em
```

- Os nomes e tipos dos campos são os mesmos das tabelas atuais (`lib/dados/esquema.dart`).
- O campo `usuario_id` deixa de existir, porque o dono está no caminho do documento.
- `arquivada` e `ativa` passam a ser booleanos (`true`/`false`) em vez de `0`/`1`.
- Os ids continuam sendo UUIDs gerados no app, para que as parcelas de uma compra possam ser criadas offline num único lote.

### Regras de segurança

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /usuarios/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
    match /usuarios/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

Ficam no repositório em `firestore.rules` e são publicadas com `firebase deploy --only firestore:rules`.

### Consultas

| Uso | Consulta |
|---|---|
| Lançamentos de um período | `lancamentos` com `data >= inicio` e `data <= fim` |
| Comprometido futuro | `lancamentos` com `data > hoje` |
| Parcelas de uma compra | `lancamentos` com `compra_id == x` |
| Última conta e categoria usadas | `lancamentos` ordenado por `criado_em` desc, limite 1 |
| Contas e categorias ativas | `contas` / `categorias` com `arquivada == false` |

Todas usam um campo só ou um campo com ordenação, então não precisam de índices compostos.

---

## 4. Login (Firebase Authentication)

### Fluxos

- **Criar conta:** `createUserWithEmailAndPassword`, seguido de `sendEmailVerification`.
- **Entrar:** `signInWithEmailAndPassword`.
- **Confirmação obrigatória:** o `AuthGate` tem três estados:
  1. sem usuário → tela de login;
  2. usuário com e-mail e senha e `emailVerified == false` → tela nova **"Confirme seu e-mail"**, com os botões "Já confirmei" (recarrega o usuário e confere de novo), "Reenviar e-mail" e "Sair";
  3. usuário confirmado, ou que entrou com Google → app.
- **Esqueci minha senha:** `sendPasswordResetEmail`. A troca de senha acontece na página padrão do Firebase, então a tela `nova_senha.dart` e o link `controlegastos://login-callback` saem do projeto.
- **Google:**
  - Web: `signInWithPopup(GoogleAuthProvider())`.
  - Android: pacote `google_sign_in`, com a credencial passada ao `signInWithCredential`. Exige cadastrar no Firebase o SHA-1 da chave de debug, da chave de upload e da chave de assinatura do Google Play.
- **Sair:** `signOut`, e também `GoogleSignIn().signOut()` no Android.
- **Apagar conta:** o app apaga os documentos do usuário (subcoleções em lotes de até 500 e depois o documento `usuarios/{uid}`) e em seguida chama `user.delete()`. Se o Firebase responder `requires-recent-login`, o app pede a senha de novo (ou o login com Google), refaz o login e tenta outra vez.

### Mensagens de erro

`lib/core/erros_auth.dart` passa a receber `FirebaseAuthException` e traduzir pelo `code`, sempre em português. Códigos mínimos: `invalid-credential`, `wrong-password`, `user-not-found`, `email-already-in-use`, `weak-password`, `invalid-email`, `too-many-requests`, `network-request-failed`, `requires-recent-login`, `popup-closed-by-user`. O que não for reconhecido cai no texto genérico.

---

## 5. Mudanças por arquivo

| Arquivo | Mudança |
|---|---|
| `lib/dominio/*` | Não muda |
| `lib/dados/repositorios.dart` | Reescrito para o Firestore, com as mesmas classes, funções e retornos |
| `lib/dados/relatorios.dart` | Busca os lançamentos do período e soma em Dart, com as mesmas funções e retornos |
| `lib/dados/banco.dart` | Inicia o Firestore com persistência ligada e devolve a instância |
| `lib/dados/provedores.dart` | Monta os repositórios com o `FirebaseFirestore` no lugar do `PowerSyncDatabase` |
| `lib/dados/exportacao.dart` | Ajustado se depender do tipo do banco |
| `lib/dados/esquema.dart`, `lib/dados/conector_sincronizacao.dart` | Removidos |
| `lib/core/usuario_atual.dart` | Lê o usuário do `FirebaseAuth` |
| `lib/core/erros_auth.dart` | Traduz `FirebaseAuthException` |
| `lib/core/redirecionamento.dart` | Removido |
| `lib/core/app_config.dart` e `config/app_config.exemplo.dart` | Substituídos por `lib/firebase_options.dart`, gerado pelo `flutterfire configure` |
| `lib/core/privacidade.dart`, `web/privacidade.html` | Texto troca Supabase/PowerSync por Firebase (Google) |
| `lib/main.dart` | `Firebase.initializeApp` no lugar de `Supabase.initialize` |
| `lib/telas/auth_gate.dart` | Três estados (seção 4) |
| `lib/telas/confirmar_email.dart` | Nova tela |
| `lib/telas/login.dart` | Firebase no lugar do Supabase |
| `lib/telas/nova_senha.dart` | Removida |
| `lib/telas/configuracoes.dart` | Sair e apagar conta pelo Firebase |
| `lib/telas/diagnostico.dart` | Mostra o usuário logado e se há gravações esperando sincronizar |
| `supabase/` | Removida |
| `android/` | Plugin `google-services` e `google-services.json`; sai o filtro do link `controlegastos://` do `AndroidManifest.xml` |
| `web/` | Saem `sqlite3.wasm`, `powersync_db.worker.js` e `powersync_sync.worker.js` |
| `pubspec.yaml` | Saem `supabase_flutter` e `powersync`; entram `firebase_core`, `firebase_auth`, `cloud_firestore` e `google_sign_in`; entra `fake_cloud_firestore` nas dependências de teste |
| `firestore.rules`, `firebase.json` | Novos (seção 3) |
| `README.md` | Configuração do Firebase no lugar do Supabase, incluindo os SHA-1 para o login com Google |

O `firebase_options.dart` e o `google-services.json` só contêm identificadores públicos do projeto, mas seguem o mesmo cuidado do `app_config.dart` atual e ficam fora do git, com um exemplo documentado no README.

---

## 6. Erros e offline

- **Sem internet:** leitura e gravação funcionam pelo cache local, e o Firestore envia as gravações quando a conexão volta. Só o login, o cadastro, a redefinição de senha e o apagar conta precisam de internet, e mostram "Sem conexão com o servidor" quando ela falta.
- **Permissão negada** ao gravar (não deveria acontecer com as regras acima): o app mostra uma mensagem em português e não fecha.
- **Gravações offline não confirmam na hora:** as funções de gravação não esperam a confirmação do servidor, senão o app trava sem internet. Elas aplicam a gravação local e seguem em frente.

---

## 7. Testes

- Os testes de `test/dominio` não mudam.
- Testes novos para `repositorios.dart` e `relatorios.dart` com `fake_cloud_firestore`: lançar compra parcelada, apagar compra e parcela, editar, última escolha, soma por categoria, total do período, comprometido futuro, fatura aberta e totais dos últimos meses.
- `test/widget_test.dart` continua conferindo que o app mostra o carregamento sem travar.
- Regras de segurança: conferidas manualmente. Um usuário logado tentando ler `usuarios/{outro uid}` precisa receber permissão negada.
- Teste manual no Chrome e no Android: criar conta, confirmar e-mail, lançar, ver relatórios, ficar offline, lançar, voltar online, abrir em outro aparelho, entrar com Google, esqueci a senha e apagar conta.

---

## 8. Ordem de execução

1. Ligar o Firebase ao app (`flutterfire configure`) e trocar o login (`main.dart`, `auth_gate`, `login`, tela de confirmação, `configuracoes`, `erros_auth`).
2. Reescrever repositórios e relatórios, com os testes novos.
3. Remover Supabase e PowerSync (código, pacotes, arquivos da Web, `supabase/`), atualizar política de privacidade e README, e publicar as regras do Firestore.
4. Teste manual no Chrome e no Android.

### Pré-requisitos do usuário no console do Firebase

- Projeto criado.
- Authentication: provedores **E-mail/senha** e **Google** ativados.
- Firestore criado em `southamerica-east1`, modo de produção.
- `firebase login` feito no terminal.
