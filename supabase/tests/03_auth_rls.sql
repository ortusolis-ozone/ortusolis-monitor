begin;

insert into public.clients (id, legal_name, cnpj, is_active)
values
  ('10000000-0000-0000-0000-000000000001', 'Cliente RLS A', '33333333333333', true),
  ('10000000-0000-0000-0000-000000000002', 'Cliente RLS B', '44444444444444', true),
  ('10000000-0000-0000-0000-000000000003', 'Cliente RLS inativo', '55555555555555', false);

insert into auth.users (id)
values
  ('20000000-0000-0000-0000-000000000001'),
  ('20000000-0000-0000-0000-000000000002'),
  ('20000000-0000-0000-0000-000000000003'),
  ('20000000-0000-0000-0000-000000000004');

insert into public.profiles (id, client_id, full_name, role, is_active)
values
  ('20000000-0000-0000-0000-000000000001', null, 'Master RLS', 'master', true),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'Cliente A RLS', 'operator', true),
  ('20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000002', 'Cliente B RLS', 'viewer', true),
  ('20000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000003', 'Cliente inativo RLS', 'client_admin', true);

insert into public.locations (id, client_id, name)
values
  ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Local RLS A'),
  ('30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'Local RLS B');

insert into public.cold_rooms (id, client_id, location_id, name, category)
values
  ('40000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'Câmara RLS A', 'outros'),
  ('40000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000002', 'Câmara RLS B', 'outros');

insert into public.generators (id, client_id, identifier)
values
  ('50000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Gerador RLS A'),
  ('50000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'Gerador RLS B');

insert into public.client_daily_status (
  client_id,
  location_id,
  cold_room_id,
  generator_id,
  status_date,
  status
)
values
  ('10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', '2026-08-20', 'completed'),
  ('10000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000002', '2026-08-20', 'verification_required');

do $$
begin
  if has_table_privilege('anon', 'public.clients', 'select') then
    raise exception 'anon recebeu SELECT em dados protegidos';
  end if;

  if not has_table_privilege('authenticated', 'public.clients', 'select')
    or not has_table_privilege('authenticated', 'public.client_daily_status', 'select') then
    raise exception 'authenticated não recebeu as leituras públicas necessárias';
  end if;

  if not has_table_privilege('authenticated', 'public.import_batches', 'select')
    or not has_table_privilege('authenticated', 'public.raw_events', 'select')
    or not has_table_privilege('authenticated', 'public.source_mappings', 'select')
    or not has_table_privilege('authenticated', 'public.inconsistencies', 'select') then
    raise exception 'authenticated não recebeu as leituras protegidas pelo RLS de importação';
  end if;

  if has_table_privilege('authenticated', 'public.applications', 'select')
    or has_table_privilege('authenticated', 'public.audit_logs', 'select') then
    raise exception 'authenticated recebeu SELECT em tabela técnica';
  end if;
end
$$;

set local role authenticated;
set local request.jwt.claim.sub = '20000000-0000-0000-0000-000000000002';

do $$
declare
  affected_rows integer;
begin
  if (select count(*) from public.profiles) <> 1 then
    raise exception 'cliente A acessou perfil de outro usuário';
  end if;

  if (select count(*) from public.clients) <> 1
    or (select count(*) from public.locations) <> 1
    or (select count(*) from public.cold_rooms) <> 1
    or (select count(*) from public.generators) <> 1
    or (select count(*) from public.client_daily_status) <> 1 then
    raise exception 'cliente A não ficou isolado em sua hierarquia';
  end if;

  if exists (
    select 1
    from public.clients
    where id = '10000000-0000-0000-0000-000000000002'
  ) then
    raise exception 'alterar o ID permitiu ao cliente A acessar o cliente B';
  end if;

  if exists (select 1 from public.raw_events)
    or exists (select 1 from public.import_batches)
    or exists (select 1 from public.source_mappings)
    or exists (select 1 from public.inconsistencies) then
    raise exception 'cliente A consultou dados técnicos da importação';
  end if;

  update public.clients
  set legal_name = 'Mutação indevida'
  where id = '10000000-0000-0000-0000-000000000001';

  get diagnostics affected_rows = row_count;

  if affected_rows <> 0 then
    raise exception 'cliente A realizou mutação';
  end if;
end
$$;

reset role;
set local role authenticated;
set local request.jwt.claim.sub = '20000000-0000-0000-0000-000000000003';

do $$
begin
  if (select count(*) from public.clients) <> 1
    or not exists (
      select 1
      from public.clients
      where id = '10000000-0000-0000-0000-000000000002'
    )
    or (select count(*) from public.client_daily_status) <> 1 then
    raise exception 'cliente B não ficou isolado em sua hierarquia';
  end if;
end
$$;

reset role;
set local role authenticated;
set local request.jwt.claim.sub = '20000000-0000-0000-0000-000000000004';

do $$
begin
  if exists (select 1 from public.profiles)
    or exists (select 1 from public.clients)
    or exists (select 1 from public.client_daily_status) then
    raise exception 'usuário de cliente inativo manteve acesso';
  end if;
end
$$;

reset role;
set local role authenticated;
set local request.jwt.claim.sub = '20000000-0000-0000-0000-000000000001';

do $$
begin
  if (select count(*) from public.profiles) <> 4
    or (select count(*) from public.clients) <> 3
    or (select count(*) from public.locations) <> 2
    or (select count(*) from public.client_daily_status) <> 2 then
    raise exception 'Master não acessou todos os dados públicos necessários';
  end if;

  perform 1 from public.import_batches limit 1;
  perform 1 from public.raw_events limit 1;
  perform 1 from public.source_mappings limit 1;
end
$$;

reset role;
rollback;

select 'spec 03 auth and RLS tests passed' as result;
