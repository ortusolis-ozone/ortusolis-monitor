begin;
\ir helpers/temporal-fixtures.sql

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
create function pg_temp.confirm_temporal(g uuid, s uuid, p uuid, e jsonb, r jsonb)
returns jsonb language sql as $$
  select public.confirm_import_session('b1000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000001','b4000000-0000-4000-8000-000000000001',
    g,s,'estado.xlsx',repeat('a',64),e,p,'potencia.xlsx',repeat('b',64),r,true);
$$;
do $$
declare g uuid; s uuid; p uuid; states jsonb; wrong jsonb; readings jsonb; result jsonb; repeated jsonb;
  snapshot jsonb; batch_id uuid; first_session uuid; n integer; revision integer; logs integer;
  loc constant uuid := 'b3000000-0000-4000-8000-000000000001';
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

  update public.locations set telemetry_time_basis='utc' where id=loc;
  states := pg_temp.temporal_rows(loc,states,false);
  select jsonb_agg(j || jsonb_build_object('occurred_at',(j->>'occurred_at')::timestamptz-interval '3 hours',
    'source_timezone','UTC','normalization_version',1)) into readings from jsonb_array_elements(wrong) j;
  readings := pg_temp.temporal_rows(loc,readings,true);
  snapshot := jsonb_set(readings->0->'temporal_context','{origin}','"location_default"');
  select jsonb_agg(jsonb_set(j,'{temporal_context}',snapshot)) into readings from jsonb_array_elements(readings) j;
  -- Missing contract cannot fall back to the local zone or UTC.
  begin
    perform pg_temp.confirm_temporal(g,s,p,states,wrong);
    raise exception 'legacy contract accepted';
  exception when sqlstate 'P1501' then null; end;
  -- Changed config, even when changed back, invalidates the old preview.
  update public.locations set telemetry_time_basis='location' where id=loc;
  update public.locations set telemetry_time_basis='utc' where id=loc;
  begin
    perform pg_temp.confirm_temporal(g,s,p,states,readings);
    raise exception 'ABA configuration accepted';
  exception when sqlstate 'P1501' then null; end;
  readings := pg_temp.temporal_rows(loc,readings,true);
  snapshot := jsonb_set(readings->0->'temporal_context','{origin}','"location_default"');
  select jsonb_agg(jsonb_set(j,'{temporal_context}',snapshot)) into readings from jsonb_array_elements(readings) j;
  logs := (select count(*) from public.audit_logs where action='location_telemetry_configured');
  select telemetry_revision into revision from public.locations where id=loc;
  update public.locations set telemetry_time_basis='utc',telemetry_revision=999,time_zone_revision=999 where id=loc;
  if (select telemetry_revision from public.locations where id=loc) <> revision
    or (select count(*) from public.audit_logs where action='location_telemetry_configured') <> logs then raise exception 'no-op changed revision/audit'; end if;
  -- A forged default with a different source zone is rejected.
  begin
    perform pg_temp.confirm_temporal(g,s,p,states,jsonb_set(readings,'{0,temporal_context,sourceTimezone}','"America/Fortaleza"'));
    raise exception 'forged source accepted';
  exception when sqlstate 'P1501' then null; end;
  result := pg_temp.confirm_temporal(g,s,p,states,readings);
  batch_id := (result->'power_batch'->>'batch_id')::uuid;
  first_session := (result->>'session_id')::uuid;
  if (select temporal_context from public.import_batches where id=batch_id) <> snapshot then raise exception 'batch snapshot missing'; end if;
  if (select temporal_context from public.import_sessions where id=first_session) <> snapshot then raise exception 'session snapshot missing'; end if;
  n := (select count(*) from public.power_readings);
  -- Same interpretation with another origin gets a session, never new readings.
  readings := pg_temp.temporal_rows(loc,readings,true);
  repeated := pg_temp.confirm_temporal(g,s,p,states,readings);
  if (repeated->>'session_id')::uuid = first_session then raise exception 'provenance overwritten'; end if;
  if (repeated->'power_batch'->>'batch_id')::uuid <> batch_id or (select count(*) from public.power_readings) <> n then raise exception 'readings duplicated'; end if;
  if (select temporal_context from public.import_batches where id=batch_id) <> snapshot then raise exception 'batch origin overwritten'; end if;
  if not (pg_temp.confirm_temporal(g,s,p,states,readings)->>'already_confirmed')::boolean then raise exception 'retry not idempotent'; end if;
  -- Editing the default never rewrites historical batches or readings.
  update public.locations set telemetry_time_basis=null where id=loc;
  if (select temporal_context from public.import_batches where id=batch_id) <> snapshot or (select count(*) from public.power_readings) <> n then raise exception 'history changed'; end if;
  begin
    perform pg_temp.confirm_temporal(g,s,p,states,pg_temp.temporal_rows(loc,readings,true));
    raise exception 'unconfigured override accepted';
  exception when sqlstate 'P1501' then null; end;
  update public.locations set telemetry_time_basis='utc',time_zone='Europe/Paris' where id=loc;
  begin
    perform pg_temp.confirm_temporal(g,s,p,states,pg_temp.temporal_rows(loc,readings,true));
    raise exception 'state preview from old zone accepted';
  exception when sqlstate 'P1501' then null; end;
  begin
    update public.locations set time_zone='Invalid/Zone' where id=loc;
    raise exception 'unsupported zone accepted';
  exception when check_violation then null; end;
  -- New locations cannot commit without explicit preference.
  begin
    insert into public.locations(client_id,name,telemetry_time_basis) values('b1000000-0000-4000-8000-000000000001','Sem configuração',null);
    set constraints new_location_requires_time_basis immediate;
    raise exception 'new location without choice accepted';
  exception when check_violation then null; end;
end;
$$;
set local role authenticated;
set local request.jwt.claim.sub = 'b2000000-0000-4000-8000-000000000002';
do $$ begin
  begin
    perform private.validate_import_temporal_context('b3000000-0000-4000-8000-000000000001','[]',true);
    raise exception 'viewer accessed privileged temporal validation';
  exception when insufficient_privilege then null; end;
end; $$;
reset role;
select extensions.pass('15 location defaults, ABA revision, strict contract, immutable provenance and idempotency');
select * from extensions.finish();
rollback;
