begin;

select extensions.plan(1);

insert into public.clients (id, legal_name, cnpj)
values
  ('b1000000-0000-4000-8000-000000000001', 'Cliente Sessão A', '04252011000110'),
  ('b1000000-0000-4000-8000-000000000002', 'Cliente Sessão B', '11444777000161');

insert into auth.users (id)
values
  ('b2000000-0000-4000-8000-000000000001'),
  ('b2000000-0000-4000-8000-000000000002'),
  ('b2000000-0000-4000-8000-000000000003');

insert into public.profiles (id, client_id, full_name, role)
values
  ('b2000000-0000-4000-8000-000000000001', null, 'Master Sessões', 'master'),
  ('b2000000-0000-4000-8000-000000000002', 'b1000000-0000-4000-8000-000000000001', 'Cliente Sessão A', 'viewer'),
  ('b2000000-0000-4000-8000-000000000003', 'b1000000-0000-4000-8000-000000000002', 'Cliente Sessão B', 'viewer');

insert into public.locations (id, client_id, name, time_zone)
values
  ('b3000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-000000000001', 'Unidade Sessão A', 'America/Fortaleza'),
  ('b3000000-0000-4000-8000-000000000002', 'b1000000-0000-4000-8000-000000000002', 'Unidade Sessão B', 'America/Fortaleza');

insert into public.cold_rooms (id, client_id, location_id, name, category)
values
  ('b4000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-000000000001', 'b3000000-0000-4000-8000-000000000001', 'Câmara Sessão A', 'flv'),
  ('b4000000-0000-4000-8000-000000000002', 'b1000000-0000-4000-8000-000000000002', 'b3000000-0000-4000-8000-000000000002', 'Câmara Sessão B', 'flv');

insert into public.source_mappings (normalized_source, classification, created_by)
values ('agendamento', 'programmed', 'b2000000-0000-4000-8000-000000000001');

create function pg_temp.audit_count() returns bigint language sql security definer set search_path = '' as 'select count(*) from public.audit_logs';

set local request.jwt.claim.sub = 'b2000000-0000-4000-8000-000000000001';
create function pg_temp.confirm_zone(g uuid, s uuid, p uuid, e jsonb, r jsonb, preview boolean default false)
returns jsonb language plpgsql as $$
begin
  if preview then
    return public.preview_import_session('b1000000-0000-4000-8000-000000000001', 'b3000000-0000-4000-8000-000000000001', 'b4000000-0000-4000-8000-000000000001',
      g,s,'estado.xlsx',repeat('a',64),e,p,'potencia.xlsx',repeat('b',64),r);
  end if;
  return public.confirm_import_session('b1000000-0000-4000-8000-000000000001', 'b3000000-0000-4000-8000-000000000001', 'b4000000-0000-4000-8000-000000000001',
    g,s,'estado.xlsx',repeat('a',64),e,p,'potencia.xlsx',repeat('b',64),r,true);
end;
$$;

do $$
declare g uuid; s uuid; p uuid; states jsonb; wrong jsonb; corrected jsonb; result jsonb; projected jsonb; old_batch uuid; n integer; logs integer; old_data jsonb;
begin
  g := public.register_generator_v2('b1000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000001','b4000000-0000-4000-8000-000000000001',
    'Gerador Fuso','2026-08-01','Estado Fuso','2026-08-01','Potência Fuso','device-zone','2026-08-01',5,1,120);
  insert into public.generator_power_profiles(generator_id, nominal_power_w, valid_from, created_by)
    values(g,72,'2026-08-01T00:00:00Z',auth.uid());
  select id into s from public.controllers where generator_id=g and role='state';
  select id into p from public.controllers where generator_id=g and role='power_telemetry';
  select jsonb_agg(jsonb_build_object('occurred_at',stamp,'occurred_at_raw',raw,'operation',op,'operation_raw',label,
    'source_original','Agendamento','source_normalized','agendamento','source_classification','programmed','fingerprint',repeat(hash,64)))
  into states from (values ('2026-09-11T23:00:00Z','11/09/2026 20:00:00','turn_on','Ligar','1'),
    ('2026-09-11T23:30:00Z','11/09/2026 20:30:00','turn_off','Desligar','2')) v(stamp,raw,op,label,hash);
  select jsonb_agg(jsonb_build_object('occurred_at', stamp::timestamptz + interval '3 hours', 'occurred_at_raw',raw,
    'power_w',watts,'power_raw',watts||'W','device_name','Medidor','device_id','device-zone','device_id_normalized','device-zone',
    'event_type','Report','event_name','Power','event_detail',watts||'W','request_from','Device','source_detail','', 'fingerprint',repeat(hash,64)))
  into wrong from (values ('2026-09-11T19:00:00Z','2026-09-11 19:00:00',0,'3'),
    ('2026-09-11T23:00:00Z','2026-09-11 23:00:00',61.2,'4'),
    ('2026-09-11T23:30:00Z','2026-09-11 23:30:00',0,'5')) v(stamp,raw,watts,hash);
  -- Legacy interpretation: full period coverage, but on/off three hours too late.
  result := pg_temp.confirm_zone(g,s,p,states,wrong);
  old_batch := (result->'power_batch'->>'batch_id')::uuid;
  if (result->'operational_summary'->>'within_expected')::int <> 0 then raise exception 'legacy unexpectedly correlated'; end if;
  select jsonb_agg(to_jsonb(r) order by id) into old_data from public.power_readings r where import_batch_id=old_batch;
  select jsonb_agg(j || jsonb_build_object('occurred_at',(j->>'occurred_at')::timestamptz-interval '3 hours',
    'source_timezone','UTC','normalization_version',1,'fingerprint',md5(j::text)||md5(j::text))) into corrected from jsonb_array_elements(wrong) j;
  -- A late nominal-profile failure must also roll back replacement links.
  update public.generator_power_profiles set valid_from='2026-09-12T03:00:00Z' where generator_id=g;
  logs := (select count(*) from public.audit_logs);
  begin
    perform pg_temp.confirm_zone(g,s,p,states,corrected);
    raise exception 'late failure accepted';
  exception when sqlstate 'P1206' then null; end;
  if exists(select 1 from private.power_reading_replacements) or (select count(*) from public.power_readings) <> 3
    or (select count(*) from public.audit_logs) <> logs then raise exception 'late failure left partial correction'; end if;
  update public.generator_power_profiles set valid_from='2026-08-01T00:00:00Z' where generator_id=g;
  logs := (select count(*) from public.audit_logs);
  projected := pg_temp.confirm_zone(g,s,p,states,corrected,true);
  if (projected->>'within_expected')::int <> 1 then raise exception 'UTC projection failed: %',projected; end if;
  if exists(select 1 from private.power_reading_replacements) or (select count(*) from public.audit_logs) <> logs then raise exception 'preview leaked correction'; end if;
  if (select count(*) from public.power_readings) <> 3 then raise exception 'preview persisted rows'; end if;
  result := pg_temp.confirm_zone(g,s,p,states,corrected);
  if result->'operational_summary' <> projected then raise exception 'preview/confirmation mismatch'; end if;
  if (result->'power_batch'->>'batch_id')::uuid = old_batch then raise exception 'hash reused across zones'; end if;
  if (select count(*) from private.power_reading_replacements) <> 3 or (select count(*) from private.effective_power_readings) <> 3 then raise exception 'both interpretations active'; end if;
  if (select jsonb_agg(to_jsonb(r) order by id) from public.power_readings r where import_batch_id=old_batch) <> old_data then raise exception 'raw history modified'; end if;
  if not exists(select 1 from public.import_batches where id=(result->'power_batch'->>'batch_id')::uuid and source_timezone='UTC' and normalization_version=1) then raise exception 'missing provenance'; end if;
  logs := (select count(*) from public.audit_logs);
  n := (select count(*) from public.power_readings);
  result := pg_temp.confirm_zone(g,s,p,states,corrected);
  if not (result->>'already_confirmed')::boolean or (select count(*) from public.audit_logs) <> logs
    or (select count(*) from public.power_readings) <> n then raise exception 'repeat not idempotent'; end if;
  begin
    perform pg_temp.confirm_zone(g,s,p,states,wrong);
    raise exception 'obsolete file reactivated';
  exception when sqlstate 'P1301' then null; end;
  begin
    perform pg_temp.confirm_zone(g,s,p,states,jsonb_set(corrected,'{1,source_timezone}','"America/Fortaleza"'));
    raise exception 'mixed zones accepted';
  exception when check_violation then null; end;
  if (select count(*) from public.audit_logs where action='power_timezone_corrected') <> 1 then raise exception 'incorrect audit count'; end if;
  -- A differently named/exported overlapping file deduplicates by reading identity.
  result := public.confirm_power_xlsx_import('b1000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000001','b4000000-0000-4000-8000-000000000001',
    g,p,'sobreposto.xlsx',repeat('c',64),jsonb_build_array(corrected->1,corrected->2));
  if (result->>'inserted_rows')::int <> 0 or (result->>'duplicate_rows')::int <> 2
    or (select count(*) from private.effective_power_readings) <> 3 then raise exception 'overlap duplicated readings'; end if;
  if (select count(*) from private.power_reading_replacements) <> 3 then raise exception 'overlap changed corrections'; end if;
end;
$$;
do $$ begin
  if has_table_privilege('authenticated','private.power_reading_replacements','select')
    or has_table_privilege('anon','private.effective_power_readings','select') then raise exception 'technical data exposed'; end if;
end; $$;
set local role authenticated;
set local request.jwt.claim.sub = 'b2000000-0000-4000-8000-000000000002';
do $$ begin
  begin
    perform public.confirm_power_xlsx_import(null,null,null,null,null,'x',repeat('c',64),'[]');
    raise exception 'viewer imported';
  exception when insufficient_privilege then null; end;
end; $$;
reset role;
select extensions.pass('13 UTC conversion, correction, immutable history, atomic preview, idempotency and RLS');
select * from extensions.finish();
rollback;
