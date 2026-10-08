begin;
select extensions.plan(1);

insert into public.clients (id, legal_name, cnpj)
values ('d4100000-0000-4000-8000-000000000001', 'Cliente Origens', '04252011000110');
insert into auth.users (id) values
  ('d4200000-0000-4000-8000-000000000001'),
  ('d4200000-0000-4000-8000-000000000002'),
  ('d4200000-0000-4000-8000-000000000003');
insert into public.profiles (id, client_id, full_name, role, is_active) values
  ('d4200000-0000-4000-8000-000000000001', null, 'Master Origens', 'master', true),
  ('d4200000-0000-4000-8000-000000000002', 'd4100000-0000-4000-8000-000000000001', 'Leitor Origens', 'viewer', true),
  ('d4200000-0000-4000-8000-000000000003', null, 'Master Inativo', 'master', false);
insert into public.locations (id, client_id, name, time_zone)
values ('d4300000-0000-4000-8000-000000000001', 'd4100000-0000-4000-8000-000000000001', 'Unidade Origens', 'America/Fortaleza');
insert into public.cold_rooms (id, client_id, location_id, name, category)
values ('d4400000-0000-4000-8000-000000000001', 'd4100000-0000-4000-8000-000000000001', 'd4300000-0000-4000-8000-000000000001', 'Câmara Origens', 'outros');

-- Historical classifications must survive the migration until explicitly saved.
insert into public.source_mappings (normalized_source, classification, created_by) values
  ('cronômetros regressivos', 'programmed', 'd4200000-0000-4000-8000-000000000001'),
  ('dispositivo-inching', 'programmed', 'd4200000-0000-4000-8000-000000000001'),
  ('ortusolis@ortusolis.com.br', 'test', 'd4200000-0000-4000-8000-000000000001'),
  ('teste antigo spec14', 'test', 'd4200000-0000-4000-8000-000000000001');

-- Applications are deliberately not directly granted to authenticated users.
create function pg_temp.application_snapshot(g uuid) returns jsonb
language sql security definer set search_path = '' as $$
  select coalesce(jsonb_agg(to_jsonb(a) order by id), '[]'::jsonb)
  from public.applications a where generator_id = g;
$$;

create function pg_temp.audit_snapshot() returns setof public.audit_logs
language sql security definer set search_path = '' as $$ select * from public.audit_logs; $$;

set local role authenticated;
set local request.jwt.claim.sub = 'd4200000-0000-4000-8000-000000000001';

do $$
declare
  g uuid;
  manual_g uuid;
  s uuid;
  manual_s uuid;
  states jsonb;
  manual_states jsonb;
  result jsonb;
  raw_snapshot jsonb;
  application_snapshot jsonb;
  logs bigint;
begin
  g := public.register_generator_v2(
    'd4100000-0000-4000-8000-000000000001', 'd4300000-0000-4000-8000-000000000001', 'd4400000-0000-4000-8000-000000000001',
    'Gerador Programado Spec14', '2026-08-01', 'Estado Spec14', '2026-08-01', 'Potência Spec14', 'device-spec14', '2026-08-01');
  manual_g := public.register_generator_v2(
    'd4100000-0000-4000-8000-000000000001', 'd4300000-0000-4000-8000-000000000001', 'd4400000-0000-4000-8000-000000000001',
    'Gerador Manual Spec14', '2026-08-01', 'Estado Manual Spec14', '2026-08-01', 'Potência Manual Spec14', 'device-manual-spec14', '2026-08-01');
  insert into public.generator_power_profiles (generator_id, nominal_power_w, valid_from, created_by)
  values (g, 72, '2026-08-01T00:00:00Z', auth.uid()), (manual_g, 72, '2026-08-01T00:00:00Z', auth.uid());
  select id into s from public.controllers where generator_id = g and role = 'state';
  select id into manual_s from public.controllers where generator_id = manual_g and role = 'state';

  select jsonb_agg(jsonb_build_object(
    'occurred_at', '2026-10-08T' || v.stamp || ':00Z', 'occurred_at_raw', v.stamp,
    'operation', v.operation, 'operation_raw', v.operation,
    'source_original', v.source, 'source_normalized', lower(v.source),
    'source_classification', v.classification, 'fingerprint', repeat(v.hash, 64)) order by v.stamp)
  into states from (values
    ('07:00', 'turn_on', 'Cronômetros regressivos', 'programmed', '1'),
    ('07:05', 'turn_off', 'ortusolis@ortusolis.com.br', 'test', '2'),
    ('07:06', 'turn_on', 'ortusolis@ortusolis.com.br', 'test', '3'),
    ('07:07', 'turn_off', 'Teste antigo spec14', 'test', '4'),
    ('07:10', 'turn_off', 'Dispositivo-Inching', 'programmed', '5')
  ) v(stamp, operation, source, classification, hash);

  perform public.confirm_xlsx_import(
    'd4100000-0000-4000-8000-000000000001', 'd4300000-0000-4000-8000-000000000001', 'd4400000-0000-4000-8000-000000000001',
    g, s, 'programado.xlsx', repeat('a', 64), states);
  if jsonb_array_length(pg_temp.application_snapshot(g)) <> 1 then
    raise exception 'legacy events broke the programmed pair';
  end if;
  select jsonb_agg(to_jsonb(e) - 'source_classification' order by id) into raw_snapshot
    from public.raw_events e where generator_id = g;
  application_snapshot := pg_temp.application_snapshot(g);

  perform public.set_source_mapping(' ORTUSOLIS@ORTUSOLIS.COM.BR ', 'manual');
  if (select jsonb_agg(to_jsonb(e) - 'source_classification' order by id) from public.raw_events e where generator_id = g)
      is distinct from raw_snapshot
    or pg_temp.application_snapshot(g)
      is distinct from application_snapshot then
    raise exception 'manual remapping changed raw values or the programmed application';
  end if;
  if (select count(*) from public.raw_events where generator_id = g and source_classification = 'manual') <> 2
    or exists (select 1 from public.inconsistencies where generator_id = g and status = 'pending'
      and type in ('unknown_source', 'unmatched_turn_on', 'unmatched_turn_off', 'consecutive_turn_on')) then
    raise exception 'manual commands interfered with programmed pairing';
  end if;
  if not exists (select 1 from public.source_mappings where normalized_source = 'teste antigo spec14' and classification = 'test') then
    raise exception 'unrelated legacy mapping was converted';
  end if;
  if not exists (select 1 from pg_temp.audit_snapshot() where actor_id = auth.uid() and entity_type = 'source_mappings'
    and metadata->>'normalized_source' = 'ortusolis@ortusolis.com.br'
    and metadata->>'previous_classification' = 'test' and metadata->>'classification' = 'manual'
    and metadata->'affected_generator_ids' @> jsonb_build_array(g)) then
    raise exception 'mapping transition lacks audit provenance';
  end if;
  logs := (select count(*) from pg_temp.audit_snapshot());
  perform public.set_source_mapping('ortusolis@ortusolis.com.br', 'manual');
  if (select count(*) from pg_temp.audit_snapshot()) <> logs then
    raise exception 'identical mapping duplicated audit';
  end if;

  select jsonb_agg(jsonb_build_object(
    'occurred_at', '2026-10-08T' || v.stamp || ':00Z', 'occurred_at_raw', v.stamp,
    'operation', v.operation, 'operation_raw', v.operation,
    'source_original', 'ortusolis@ortusolis.com.br', 'source_normalized', 'ortusolis@ortusolis.com.br',
    'source_classification', 'manual', 'fingerprint', repeat(v.hash, 64)) order by v.stamp)
  into manual_states from (values ('19:00', 'turn_on', '6'), ('19:10', 'turn_off', '7')) v(stamp, operation, hash);
  result := public.confirm_xlsx_import(
    'd4100000-0000-4000-8000-000000000001', 'd4300000-0000-4000-8000-000000000001', 'd4400000-0000-4000-8000-000000000001',
    manual_g, manual_s, 'manual.xlsx', repeat('b', 64), manual_states);
  if (result->>'inserted_rows')::int <> 2
    or pg_temp.application_snapshot(manual_g) <> '[]'::jsonb
    or exists (select 1 from public.inconsistencies where generator_id = manual_g and status = 'pending')
    or not exists (select 1 from public.client_daily_status where generator_id = manual_g and status_date = '2026-10-08' and status = 'no_data') then
    raise exception 'manual-only import produced a programmed result or a pending inconsistency';
  end if;
  result := public.confirm_xlsx_import(
    'd4100000-0000-4000-8000-000000000001', 'd4300000-0000-4000-8000-000000000001', 'd4400000-0000-4000-8000-000000000001',
    g, s, 'programado.xlsx', repeat('a', 64), states);
  if not (result->>'already_confirmed')::boolean or (select count(*) from public.raw_events where generator_id = g) <> 5 then
    raise exception 'reimport after classification change duplicated raw events';
  end if;

  perform public.set_source_mapping('ortusolis@ortusolis.com.br', 'programmed');
  if jsonb_array_length(pg_temp.application_snapshot(manual_g)) <> 1 then
    raise exception 'programmed remapping failed to reconstruct applications';
  end if;
  perform public.set_source_mapping('ortusolis@ortusolis.com.br', 'unknown');
  if pg_temp.application_snapshot(manual_g) <> '[]'::jsonb
    or (select count(*) from public.inconsistencies where generator_id = manual_g and status = 'pending' and type = 'unknown_source') <> 2 then
    raise exception 'unknown remapping failed to reconstruct pending inconsistencies';
  end if;
  perform public.set_source_mapping('ortusolis@ortusolis.com.br', 'manual');
  if exists (select 1 from public.inconsistencies where generator_id = manual_g and status = 'pending')
    or pg_temp.application_snapshot(manual_g) <> '[]'::jsonb then
    raise exception 'manual remapping failed to resolve previous derived results';
  end if;
  if not exists (select 1 from public.list_source_values() where normalized_source = 'ortusolis@ortusolis.com.br'
    and classification = 'manual' and event_count = 4) then
    raise exception 'administrative query disagrees with reprocessed history';
  end if;

  begin
    perform public.set_source_mapping('novo teste spec14', 'test');
    raise exception 'new test mapping accepted';
  exception when check_violation then null;
  end;
  begin
    perform public.set_source_mapping('origem nula spec14', null);
    raise exception 'null classification accepted';
  exception when check_violation then null;
  end;
end;
$$;

reset role;
-- A late reprocessing failure must roll back both the mapping and its audit.
create function pg_temp.reject_manual_reclassification() returns trigger language plpgsql as $$
begin
  if new.source_normalized = 'ortusolis@ortusolis.com.br' and new.source_classification = 'unknown' then
    raise exception 'spec14 injected reprocessing failure' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
create trigger spec14_reprocessing_failure before update on public.raw_events
for each row execute function pg_temp.reject_manual_reclassification();
set local role authenticated;

do $$
declare logs bigint := (select count(*) from pg_temp.audit_snapshot());
begin
  begin
    perform public.set_source_mapping('ortusolis@ortusolis.com.br', 'unknown');
    raise exception 'expected injected failure';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'spec14 injected reprocessing failure' then raise; end if;
  end;
  if (select count(*) from pg_temp.audit_snapshot()) <> logs
    or not exists (select 1 from public.source_mappings where normalized_source = 'ortusolis@ortusolis.com.br' and classification = 'manual' and is_active)
    or exists (select 1 from public.raw_events where source_normalized = 'ortusolis@ortusolis.com.br' and source_classification <> 'manual') then
    raise exception 'failed remapping left partial changes';
  end if;
end;
$$;

set local request.jwt.claim.sub = 'd4200000-0000-4000-8000-000000000002';
do $$
begin
  begin
    perform public.set_source_mapping('ortusolis@ortusolis.com.br', 'programmed');
    raise exception 'client remapped an origin';
  exception when insufficient_privilege then null;
  end;
  begin
    perform count(*) from public.audit_logs;
    raise exception 'client can read mapping audit';
  exception when insufficient_privilege then null;
  end;
  if exists (select 1 from public.source_mappings)
    or exists (select 1 from public.raw_events) then
    raise exception 'client can read technical origins or mapping audit';
  end if;
end;
$$;

set local request.jwt.claim.sub = 'd4200000-0000-4000-8000-000000000003';
do $$
begin
  begin
    perform public.set_source_mapping('ortusolis@ortusolis.com.br', 'programmed');
    raise exception 'inactive Master remapped an origin';
  exception when insufficient_privilege then null;
  end;
end;
$$;
reset role;

select extensions.pass('spec14: manual origins, history, pairing, audit, rollback and isolation');
select * from extensions.finish();
rollback;
