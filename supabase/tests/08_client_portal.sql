begin;

select extensions.plan(1);

insert into public.clients (id, legal_name, cnpj, is_active)
values
  ('a1000000-0000-4000-8000-000000000001', 'Cliente Portal A', '90909090909090', true),
  ('a1000000-0000-4000-8000-000000000002', 'Cliente Portal B', '91919191919191', true);

insert into auth.users (id)
values
  ('a2000000-0000-4000-8000-000000000001'),
  ('a2000000-0000-4000-8000-000000000002'),
  ('a2000000-0000-4000-8000-000000000003'),
  ('a2000000-0000-4000-8000-000000000004');

insert into public.profiles (id, client_id, full_name, role, is_active)
values
  ('a2000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 'Admin Portal A', 'client_admin', true),
  ('a2000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000001', 'Operador Portal A', 'operator', true),
  ('a2000000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-000000000001', 'Leitor Portal A', 'viewer', true),
  ('a2000000-0000-4000-8000-000000000004', 'a1000000-0000-4000-8000-000000000002', 'Leitor Portal B', 'viewer', true);

insert into public.locations (id, client_id, name)
values
  ('a3000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 'Unidade Portal Norte'),
  ('a3000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000001', 'Unidade Portal Sul'),
  ('a3000000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-000000000002', 'Unidade Portal B');

insert into public.cold_rooms (id, client_id, location_id, name, category)
values
  ('a4000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'Câmara Portal 1', 'outros'),
  ('a4000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000002', 'Câmara Portal 2', 'outros'),
  ('a4000000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-000000000002', 'a3000000-0000-4000-8000-000000000003', 'Câmara Portal B', 'outros');

insert into public.generators (id, client_id, identifier)
values
  ('a5000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 'Gerador Portal Verificação'),
  ('a5000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000001', 'Gerador Portal Aguardando'),
  ('a5000000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-000000000001', 'Gerador Portal Sem Dados'),
  ('a5000000-0000-4000-8000-000000000004', 'a1000000-0000-4000-8000-000000000001', 'Gerador Portal Concluído'),
  ('a5000000-0000-4000-8000-000000000005', 'a1000000-0000-4000-8000-000000000002', 'Gerador Portal B');

insert into public.client_daily_status (
  client_id,
  location_id,
  cold_room_id,
  generator_id,
  status_date,
  status,
  updated_at
)
values
  ('a1000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', '2026-08-24', 'verification_required', '2026-08-24 14:15:00+00'),
  ('a1000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000002', '2026-08-24', 'awaiting_update', '2026-08-23 18:30:00+00'),
  ('a1000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000002', 'a4000000-0000-4000-8000-000000000002', 'a5000000-0000-4000-8000-000000000003', '2026-08-24', 'no_data', '2026-08-24 10:45:00+00'),
  ('a1000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000002', 'a4000000-0000-4000-8000-000000000002', 'a5000000-0000-4000-8000-000000000004', '2026-08-24', 'completed', '2026-08-24 11:00:00+00'),
  ('a1000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000002', 'a4000000-0000-4000-8000-000000000002', 'a5000000-0000-4000-8000-000000000004', '2026-08-23', 'completed', '2026-08-23 11:00:00+00'),
  ('a1000000-0000-4000-8000-000000000002', 'a3000000-0000-4000-8000-000000000003', 'a4000000-0000-4000-8000-000000000003', 'a5000000-0000-4000-8000-000000000005', '2026-08-24', 'completed', '2026-08-24 12:00:00+00');

do $$
declare
  public_status_columns text[];
begin
  select array_agg(column_name order by ordinal_position)
  into public_status_columns
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'client_daily_status';

  if public_status_columns <> array[
    'client_id',
    'location_id',
    'cold_room_id',
    'generator_id',
    'status_date',
    'status',
    'updated_at',
    'power_evidence_status'
  ] then
    raise exception 'a publicação diária expõe colunas inesperadas: %', public_status_columns;
  end if;

  if has_table_privilege('authenticated', 'public.applications', 'select')
    or has_table_privilege('authenticated', 'public.audit_logs', 'select') then
    raise exception 'o papel autenticado recebeu leitura de tabelas técnicas';
  end if;
end
$$;

set local role authenticated;
set local request.jwt.claim.sub = 'a2000000-0000-4000-8000-000000000001';

do $$
begin
  if (select count(*) from public.clients) <> 1
    or (select count(*) from public.locations) <> 2
    or (select count(*) from public.cold_rooms) <> 2
    or (select count(*) from public.generators) <> 4
    or (select count(*) from public.client_daily_status) <> 5 then
    raise exception 'client_admin não recebeu somente a hierarquia do próprio cliente';
  end if;

  if exists (
    select 1
    from public.client_daily_status
    where client_id = 'a1000000-0000-4000-8000-000000000002'
  ) then
    raise exception 'alterar o cliente no filtro revelou registros de outra empresa';
  end if;

  if (
    select count(*)
    from public.client_daily_status
    where status_date between '2026-08-23' and '2026-08-24'
      and location_id = 'a3000000-0000-4000-8000-000000000002'
      and cold_room_id = 'a4000000-0000-4000-8000-000000000002'
      and generator_id = 'a5000000-0000-4000-8000-000000000004'
  ) <> 2 then
    raise exception 'os filtros combinados do histórico não retornaram o período esperado';
  end if;

  if (
    select status
    from public.client_daily_status
    where status_date = '2026-08-24'
    order by case status
      when 'verification_required' then 1
      when 'awaiting_update' then 2
      when 'no_data' then 3
      when 'completed' then 4
      else 5
    end
    limit 1
  ) <> 'verification_required' then
    raise exception 'a massa não respeita a precedência da consolidação pública';
  end if;

  if (
    select (max(updated_at) at time zone 'America/Fortaleza')::date
    from public.client_daily_status
  ) <> '2026-08-24'::date then
    raise exception 'a data segura do cabeçalho não corresponde à última atualização';
  end if;

  if exists (select 1 from public.raw_events)
    or exists (select 1 from public.import_batches)
    or exists (select 1 from public.inconsistencies)
    or exists (select 1 from public.generator_assignments) then
    raise exception 'o cliente acessou detalhes operacionais protegidos';
  end if;
end
$$;

reset role;
set local role authenticated;
set local request.jwt.claim.sub = 'a2000000-0000-4000-8000-000000000002';

do $$
begin
  if (select count(*) from public.client_daily_status) <> 5 then
    raise exception 'operator não recebeu a mesma consulta do client_admin';
  end if;
end
$$;

reset role;
set local role authenticated;
set local request.jwt.claim.sub = 'a2000000-0000-4000-8000-000000000003';

do $$
begin
  if (select count(*) from public.client_daily_status) <> 5 then
    raise exception 'viewer não recebeu a mesma consulta dos demais papéis do cliente';
  end if;
end
$$;

reset role;
set local role authenticated;
set local request.jwt.claim.sub = 'a2000000-0000-4000-8000-000000000004';

do $$
begin
  if (select count(*) from public.clients) <> 1
    or (select count(*) from public.client_daily_status) <> 1
    or exists (
      select 1
      from public.client_daily_status
      where client_id = 'a1000000-0000-4000-8000-000000000001'
    ) then
    raise exception 'o segundo cliente acessou registros do Cliente Portal A';
  end if;
end
$$;

reset role;

select extensions.pass('spec 08 client portal tests passed');
select * from extensions.finish();

rollback;
