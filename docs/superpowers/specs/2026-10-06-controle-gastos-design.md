# Controle de Gastos — Spec de Design

**Data:** 2026-10-06
**Status:** rascunho aguardando revisão do usuário

---

## 1. Objetivo

Um app de controle de gastos pessoais, mais simples de usar que o Pierre, com lançamento manual e foco em mostrar **onde o dinheiro está vazando**, sem o usuário precisar procurar.

Roda em **Android (principal), Windows e Web**, com **Flutter**. Os dados ficam **sincronizados entre todos os dispositivos** e o app funciona **sem internet**.

### Fora do escopo (nesta versão)

- Conexão com banco / Open Finance
- Saldo de conta bancária
- Orçamentos com limite manual
- Múltiplas moedas
- Compartilhamento entre usuários
- Recorrências — a tabela existe, mas a tela e os alertas ficam para a etapa 2

### Princípio de design

**Lançar um gasto leva no máximo 3 toques:** valor → categoria → conta. Qualquer campo a mais aumenta a chance de a pessoa desistir de usar o app.

---

## 2. Decisões já tomadas

| Tema | Decisão | Motivo |
|---|---|---|
| Plataformas | Flutter: Android, Windows, Web | Pedido do usuário |
| Entrada de dados | Manual | Sem Open Finance (exigiria CNPJ e autorização do BACEN) |
| Backend | Supabase (Postgres + autenticação) | Já criado: projeto `controle-gastos`, São Paulo |
| Sincronização | PowerSync sobre o Supabase | Offline-first; evita escrever fila de sincronização na mão |
| Modo de sync | Sempre que houver internet, em qualquer rede | Pedido do usuário: sem restrição de WiFi |
| Armazenamento local | SQLite (via Drift) | Mesmo banco nas três plataformas, inclusive Web |
| Dinheiro | Inteiro em centavos (`bigint`) | Evita erro de ponto flutuante na travessia SQLite ↔ Postgres |
| Parcelamento | Uma linha por parcela, agrupadas por `compra_id` | Toda consulta vira soma simples |
| Forma de pagamento | Não existe como campo; é implícita pela conta escolhida | Reduz um campo no lançamento |
| Saldo | Fora do escopo | Exige lançar 100% dos gastos; erro se acumula sem correção |
| Renda | Valor de referência em configurações | Destrava o alerta de % comprometido sem exigir lançamentos extras |
| Limite de cartão | Campo no cadastro do cartão | Destrava o alerta de limite comprometido por parcelas |
| Benefício (VR/VA) | Conta livre, sem restringir categoria | Alguns vales aceitam mercado, farmácia e combustível |

---

## 3. Telas

Seis telas. No celular, barra inferior com 4 abas + botão central "+". No PC e na Web, barra lateral com as mesmas seções; o conteúdo se espalha em colunas.

### 3.1 Início
Abre direto no problema.
- Topo: gastos do mês e percentual da renda de referência ("68% da renda").
- **Alertas** em destaque (ver seção 5). Até 3 visíveis; o resto em "ver todos".
- Cartões de crédito: fatura atual, dias até o fechamento, valor já travado em parcelas futuras.

### 3.2 Lançar gasto
- Teclado numérico grande, sem formulário.
- Passo 1: valor. Passo 2: categoria (grade de ícones). Passo 3: conta.
- Data = hoje, editável sob demanda ("toque pra mudar a data").
- Descrição: opcional, campo recolhido.
- Compra parcelada (só em conta de cartão de crédito): aparece um campo "parcelas", padrão 1.
- Sugerir a última conta e a última categoria usadas, pré-selecionadas.

### 3.3 Gráficos
- Seletor: mês / últimos 3 meses / ano.
- Rosca com divisão do período por categoria.
- Lista de categorias com valor, percentual e variação em relação à média (ver 5.2).
- Barras dos últimos 6 meses; o mês atual em destaque quando estiver acima do padrão.

### 3.4 Contas
- Cartões de crédito primeiro: barra de limite usado, fechamento, vencimento, valor travado em parcelas.
- Outras contas embaixo, sem saldo.
- Arquivar conta (nunca apagar, para manter o histórico).

### 3.5 Gastos (lista)
- Histórico agrupado por dia, mais recente primeiro.
- Filtros: categoria, conta, período. Busca por descrição.
- Toque num lançamento: editar ou apagar.
- Parcela: ao editar ou apagar, pergunta "só esta parcela" ou "todas as parcelas".

### 3.6 Configurações
- Renda mensal de referência.
- Categorias: criar, editar nome/ícone/cor, arquivar.
- Contas: criar, editar, arquivar.
- Conta e login.
- Estado da sincronização (último sync, pendentes).
- Exportar dados (CSV).

---

## 4. Modelo de dados

Mesmo schema no Postgres (Supabase) e no SQLite local. Já aplicado no projeto `controle-gastos` (`kcvmwituriyojvrbgalf`), com RLS ativo em todas as tabelas e publicação `powersync`.

### perfis
| Campo | Tipo | Observação |
|---|---|---|
| id | uuid | = id do usuário no auth |
| nome | text | |
| renda_mensal_centavos | bigint | valor de referência |

### contas
| Campo | Tipo | Observação |
|---|---|---|
| id | uuid | gerado no cliente |
| usuario_id | uuid | |
| apelido | text | |
| tipo | text | `conta_debito`, `cartao_credito`, `dinheiro`, `beneficio`, `carteira_digital` |
| cor, icone | text | |
| arquivada | boolean | |
| limite_centavos | bigint | só cartão de crédito |
| dia_fechamento | smallint 1–31 | só cartão de crédito |
| dia_vencimento | smallint 1–31 | só cartão de crédito |

Constraints no banco: cartão exige fechamento e vencimento; conta que não é cartão não pode ter esses campos.

### categorias
| Campo | Tipo | Observação |
|---|---|---|
| id | uuid | ver 4.1 para as padrão |
| usuario_id | uuid | |
| nome, icone, cor | text | |
| ordem | smallint | |
| arquivada | boolean | |

### lancamentos
| Campo | Tipo | Observação |
|---|---|---|
| id | uuid | gerado no cliente |
| usuario_id | uuid | |
| conta_id | uuid | |
| categoria_id | uuid | |
| valor_centavos | bigint | negativo = estorno; zero não é permitido |
| descricao | text | opcional |
| data | date | data da compra (ou da parcela) |
| compra_id | uuid | agrupa parcelas; em gasto simples, igual ao próprio id |
| parcela_num, parcelas_total | smallint | 1 e 1 em gasto simples |

### recorrencias (etapa 2)
Campos já criados: descrição, valor, dia do mês, início, fim, ativa, conta, categoria.

### 4.1 Categorias padrão e offline

Categorias padrão: Alimentação, Transporte, Casa, Saúde, Lazer, Compras, Educação, Assinaturas, Outros.

Elas são criadas **no aparelho**, no primeiro uso, para existir mesmo sem internet. Para não duplicar quando o mesmo usuário usa dois aparelhos offline, **o id de cada categoria padrão é determinístico**: UUID v5 calculado a partir de `usuario_id` + nome em minúsculas. Dois aparelhos geram o mesmo id, e a sincronização vira um upsert idempotente, sem duplicata.

### 4.2 Parcelas

- Valor dividido em centavos. Sobra vai para a **última** parcela, para a soma fechar exatamente.
  Ex.: R$ 100,00 em 3x → 33,33 + 33,33 + 33,34.
- Data da parcela: mesmo dia do mês da compra, avançando um mês por parcela. Dia 31 em mês curto cai no último dia do mês.
- Todas as parcelas recebem o mesmo `compra_id`.

### 4.3 O que não é salvo

Totais, faturas, percentuais e médias **não ficam gravados**. São calculados na hora a partir dos lançamentos. Um total salvo fica desatualizado quando um lançamento antigo é editado.

---

## 5. Regras de cálculo

Todos os limiares abaixo são **constantes configuráveis** no código, não valores espalhados.

### 5.1 Alerta B — "Muitos gastos pequenos" (destaque principal)

Um alerta aparece quando, **no mês corrente**, uma mesma categoria tem:
- pelo menos **10** lançamentos de valor até **R$ 50,00**, e
- soma desses lançamentos de pelo menos **R$ 300,00**.

Texto: "23× delivery = R$ 680" → categoria + quantidade + soma. Assim o alerta funciona sem o app precisar saber o estabelecimento.

*Limitação conhecida:* sem o nome do estabelecimento, o alerta agrupa por categoria, não por loja. Se quiser agrupar por loja no futuro, o campo `descricao` precisa ser preenchido de forma consistente.

### 5.2 Alerta D — "Fugiu do padrão" (destaque principal)

Compara o **mês corrente** com a **média dos 3 meses anteriores**, por categoria.

- Só dispara com **pelo menos 3 meses de histórico** naquela categoria. Antes disso, não há padrão e o alerta fica quieto.
- Dispara quando o mês atual é **≥ 1,5×** a média **e** a diferença é **≥ R$ 100,00**.

Texto: "Transporte dobrou — R$ 290 este mês, sua média é R$ 128".

A variação mostrada nos gráficos (3.3) usa a mesma base de cálculo.

### 5.3 Percentual da renda

`gastos do mês ÷ renda_mensal_referência`. Se a renda estiver zerada, a tela mostra o total sem percentual e pede para preencher a renda.

### 5.4 Fatura do cartão

Para um cartão com fechamento no dia **F** e vencimento no dia **V**:
- Uma compra no dia **d** pertence à fatura que fecha no dia F **do mês de d**, se d ≤ F. Caso contrário, pertence à fatura que fecha no dia F **do mês seguinte**.
- O vencimento da fatura cai no dia V do mês seguinte ao fechamento.
- Dias inexistentes no mês (ex.: 31 em fevereiro) usam o último dia do mês.

Tela de Início mostra a fatura **em aberto** (a que ainda vai fechar) e o próximo vencimento.

### 5.5 Comprometido em parcelas

Soma das parcelas de cartão com `data` posterior a hoje, separadas por mês. Mostrado como "R$ 2.180 travados em parcelas até mai/26".

### 5.6 Duas lentes sobre o mesmo gasto

- **Gráficos e alertas** usam a **data da compra**: "quanto eu gastei".
- **Fatura** usa o **ciclo do cartão**: "quanto vou pagar".

As duas telas trazem um rótulo explícito para o usuário não achar que é erro.

---

## 6. Sincronização e offline

- Todo dado é lido e gravado no **SQLite local**. A interface nunca espera a rede.
- O **PowerSync** replica o SQLite com o Supabase em segundo plano, quando há conexão.
- Sem restrição de WiFi: sincroniza em qualquer rede disponível.
- **IDs gerados no cliente** (UUID v4), exceto categorias padrão (4.1).
- **Conflito:** última escrita vence, comparando `atualizado_em`. Um único usuário editando os próprios dados torna isso raro e de baixo impacto.
- Indicador discreto na tela de Configurações com último sincronismo e quantidade de alterações pendentes. Nada de aviso intrusivo.

### Configuração do PowerSync — pendente

Ainda falta o usuário criar a conta no PowerSync e apontar o Supabase para ele. Quando isso acontecer:
- o endereço da conexão Postgres é colado **direto no painel do PowerSync**, sem passar pelo chat;
- as regras de sincronização (quais tabelas e linhas cada usuário recebe) são escritas por mim, a partir do `usuario_id`.

A camada de sincronização fica atrás de uma interface própria no código. Se o PowerSync precisar ser trocado por uma fila própria, só essa camada muda.

---

## 7. Arquitetura do app (Flutter)

Camadas separadas, com dependências em uma direção só:

```
UI (telas, widgets)
   ↓ usa
Casos de uso / regras (cálculos das seções 5.x — Dart puro, sem Flutter)
   ↓ usa
Repositórios (interface)
   ↓ implementados por
Drift (SQLite local)  ←→  Sincronização (PowerSync, atrás de interface)
```

- **Regras de cálculo** (parcelas, fatura, alertas) são Dart puro. Podem ser testadas sem abrir o app.
- **Repositórios** expõem streams: a tela reage quando um lançamento muda, sem recarregar manualmente.
- **Configuração** (URL do projeto e chave pública do Supabase) fica num arquivo separado, ignorado pelo git. Nenhuma credencial vai para o código versionado.

### Stack

- Flutter (versão estável atual)
- Drift — SQLite, incluindo Web
- PowerSync Flutter SDK
- supabase_flutter — autenticação
- Gráficos: `fl_chart`
- Versões exatas são fixadas na implementação, não nesta spec.

---

## 8. Autenticação

**Pendente de decisão.** Opções:
- E-mail e senha (padrão proposto): simples, funciona nas três plataformas, sem configurar provedor externo.
- Login com Google: mais rápido no celular, precisa de configuração no Google Cloud.

Enquanto não for decidido, a implementação começa por e-mail e senha.

---

## 9. Testes

- **Regras de cálculo** (seção 5): testes unitários cobrindo:
  - parcelas com sobra de centavos e dia 31;
  - fatura antes e depois do fechamento, e virada de ano;
  - alerta B no limiar exato (10 lançamentos, R$ 300);
  - alerta D com menos de 3 meses de histórico (deve ficar quieto).
- **Sincronização:** teste com o banco local em modo avião, lançando e reabrindo o app; depois, conferindo o reflexo no Supabase.
- **Categorias padrão:** dois dispositivos criando offline não geram duplicata.
- **Segurança:** teste de que um usuário não lê lançamentos de outro (RLS).

---

## 10. Perguntas em aberto

1. **Autenticação:** e-mail e senha ou Google? (padrão proposto: e-mail e senha)
2. **Limiares dos alertas:** 10 lançamentos ≤ R$ 50 e R$ 300 para o alerta B; 1,5× e R$ 100 para o alerta D. Podem ser ajustados depois do uso real.
3. **Conta do PowerSync:** a ser criada pelo usuário.

---

## 11. Ordem de implementação (sugerida)

1. Projeto Flutter vazio nas três plataformas, com configuração separada.
2. Regras de cálculo (seção 5) com testes.
3. Banco local (Drift) com o mesmo schema.
4. Telas com dados locais, sem sincronização: Lançar, Gastos, Contas, Configurações.
5. Início e Gráficos.
6. Autenticação.
7. PowerSync: conexão, regras de sincronização, testes offline.
8. Revisão de layout para Windows e Web (barra lateral).
