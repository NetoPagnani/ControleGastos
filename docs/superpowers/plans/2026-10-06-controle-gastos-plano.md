# Controle de Gastos — Plano de Implementação

**Spec:** [docs/superpowers/specs/2026-10-06-controle-gastos-design.md](../specs/2026-10-06-controle-gastos-design.md)

**Ambiente:** Flutter instalado em `E:\flutter`. Projeto em `E:\Documentos\ControleGastos`.

**Autenticação:** e-mail/senha **e** Google (aprovado).

**Sincronização:** PowerSync (conta criada pelo usuário). Supabase `controle-gastos` (`kcvmwituriyojvrbgalf`, sa-east-1) com schema, RLS e publicação `powersync` já aplicados.

---

## Fase 0 — Base do projeto

1. Criar o projeto Flutter com plataformas `android`, `windows` e `web`.
2. Estrutura de pastas por camada: `lib/core`, `lib/dominio` (regras puras), `lib/dados` (Drift + sync), `lib/telas`.
3. Configuração separada: `config/app_config.dart` lido de arquivo ignorado pelo git, com URL e chave pública do Supabase. Um `app_config.exemplo.dart` versionado com campos vazios.
4. `.gitignore` cobrindo credenciais, builds e `.superpowers/`.
5. Inicializar git e fazer o primeiro commit.

**Critério de pronto:** `flutter run -d windows` abre uma tela vazia; `flutter test` passa.

## Fase 1 — Regras de cálculo (Dart puro, TDD)

Escrever os testes antes de cada regra.

1. Dinheiro em centavos e parcelamento (sobra na última parcela, dia 31 em mês curto).
2. Ciclo da fatura (antes/depois do fechamento, virada de ano).
3. Alerta B — muitos gastos pequenos (limiar exato: 10 lançamentos, R$ 300).
4. Alerta D — fugiu do padrão (menos de 3 meses de histórico fica quieto).
5. Percentual da renda e comprometido em parcelas.

**Critério de pronto:** todos os testes da spec, seção 9, passando.

## Fase 2 — Banco local (Drift)

1. Tabelas espelhando o Supabase (mesmos nomes e tipos).
2. Repositórios com streams para a UI.
3. Categorias padrão com UUID v5 determinístico (`usuario_id` + nome em minúsculas).

**Critério de pronto:** testes de repositório com banco em memória.

## Fase 3 — Telas com dados locais

Ordem: Lançar gasto → Gastos → Contas → Configurações. Sem sincronização ainda.

**Critério de pronto:** lançar, editar, apagar e arquivar funcionando; parcela pergunta "só esta" ou "todas".

## Fase 4 — Início e Gráficos

1. Início: percentual da renda, alertas, cartões com fatura e parcelas travadas.
2. Gráficos: rosca, variação por categoria, barras dos últimos 6 meses.

**Critério de pronto:** números batendo entre Início, Gráficos e Contas para os mesmos dados.

## Fase 5 — Autenticação

1. E-mail e senha.
2. Login com Google (configurar OAuth no Google Cloud e no Supabase).
3. Ao logar pela primeira vez, criar o `perfil` e as categorias padrão.

**Critério de pronto:** teste de RLS — um usuário não vê lançamentos de outro.

## Fase 6 — Sincronização (PowerSync)

1. Conectar o SDK do PowerSync ao banco local.
2. Escrever as regras de sincronização (cada usuário recebe só o próprio `usuario_id`).
3. Você cola a conexão Postgres direto no painel do PowerSync — eu não recebo esse valor.
4. Testes: modo avião → lançar → reabrir → conferir no Supabase; dois aparelhos offline com categorias padrão sem duplicar.

**Critério de pronto:** dado lançado offline aparece no Supabase após reconectar.

## Fase 7 — Layout Windows e Web

Barra lateral no PC e na Web, mesmas telas, conteúdo em colunas.

**Critério de pronto:** telas sem overflow em 375px, 768px e 1440px.

---

## Pontos de atenção

- **Credenciais nunca no chat.** Anon key eu busco pelo conector do Supabase e gravo no arquivo de configuração ignorado pelo git.
- **Migrações:** qualquer mudança de schema vira migração nova. Não edito a que já foi aplicada.
- **Sem commit sem sua aprovação.** Commits locais são feitos a cada fase concluída; push não.

---

## Execução

Este plano pede aprovação antes do início. Escolha como executar:

1. **Inline:** eu executo as fases em sequência nesta sessão, parando ao fim de cada fase para você testar.
2. **Por fase com sua revisão:** igual ao 1, mas só avanço depois que você aprovar explicitamente o critério de pronto de cada fase.
