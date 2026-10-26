-- Exclusao de conta pelo proprio usuario (exigencia do Google Play para
-- apps com login). Apaga os dados das tabelas do app e o usuario do Auth.
-- Roda como dono da funcao (security definer) porque o usuario comum nao
-- tem permissao em auth.users; o alvo e sempre auth.uid(), nunca um
-- parametro, entao ninguem consegue apagar a conta de outra pessoa.
create or replace function public.apagar_minha_conta()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  alvo uuid := auth.uid();
begin
  if alvo is null then
    raise exception 'sem sessao';
  end if;

  delete from public.lancamentos where usuario_id = alvo;
  delete from public.recorrencias where usuario_id = alvo;
  delete from public.categorias where usuario_id = alvo;
  delete from public.contas where usuario_id = alvo;
  delete from public.perfis where id = alvo;
  delete from auth.users where id = alvo;
end;
$$;

revoke all on function public.apagar_minha_conta() from public, anon;
grant execute on function public.apagar_minha_conta() to authenticated;
