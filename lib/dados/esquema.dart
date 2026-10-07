import 'package:powersync/powersync.dart';

/// Espelho das tabelas do Supabase. O PowerSync adiciona a coluna `id`
/// sozinho, entao ela nao aparece aqui. Nomes e tipos precisam bater com o Postgres.
/// Dinheiro e inteiro (centavos); datas sao texto no formato YYYY-MM-DD.
const esquema = Schema([
  Table('perfis', [
    Column.text('nome'),
    Column.integer('renda_mensal_centavos'),
    Column.text('criado_em'),
    Column.text('atualizado_em'),
  ]),
  Table('contas', [
    Column.text('usuario_id'),
    Column.text('apelido'),
    Column.text('tipo'),
    Column.text('cor'),
    Column.text('icone'),
    Column.integer('arquivada'),
    Column.integer('limite_centavos'),
    Column.integer('dia_fechamento'),
    Column.integer('dia_vencimento'),
    Column.text('criado_em'),
    Column.text('atualizado_em'),
  ]),
  Table('categorias', [
    Column.text('usuario_id'),
    Column.text('nome'),
    Column.text('icone'),
    Column.text('cor'),
    Column.integer('ordem'),
    Column.integer('arquivada'),
    Column.text('criado_em'),
    Column.text('atualizado_em'),
  ]),
  Table('lancamentos', [
    Column.text('usuario_id'),
    Column.text('conta_id'),
    Column.text('categoria_id'),
    Column.integer('valor_centavos'),
    Column.text('descricao'),
    Column.text('data'),
    Column.text('compra_id'),
    Column.integer('parcela_num'),
    Column.integer('parcelas_total'),
    Column.text('criado_em'),
    Column.text('atualizado_em'),
  ]),
  Table('recorrencias', [
    Column.text('usuario_id'),
    Column.text('conta_id'),
    Column.text('categoria_id'),
    Column.text('descricao'),
    Column.integer('valor_centavos'),
    Column.integer('dia_do_mes'),
    Column.text('inicio'),
    Column.text('fim'),
    Column.integer('ativa'),
    Column.text('criado_em'),
    Column.text('atualizado_em'),
  ]),
]);
