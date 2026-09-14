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

create function pg_temp.application_count() returns bigint language sql security definer set search_path = '' as 'select count(*) from public.applications';
set local role authenticated;
set local request.jwt.claim.sub = 'b2000000-0000-4000-8000-000000000001';

do $$
declare
  generator_id_value uuid;
  state_controller_id uuid;
  power_controller_id uuid;
  result jsonb;
  projected jsonb;
  audit_count bigint;
  batch_count integer;
  session_count integer;
  full_state jsonb := jsonb_build_array(
    jsonb_build_object(
      'occurred_at', '2026-08-27T10:00:00.000Z',
      'occurred_at_raw', '27/08/2026 07:00:00',
      'operation', 'turn_on',
      'operation_raw', 'Ligar',
      'source_original', 'Agendamento',
      'source_normalized', 'agendamento',
      'source_classification', 'programmed',
      'fingerprint', repeat('1', 64)
    ),
    jsonb_build_object(
      'occurred_at', '2026-08-27T11:00:00.000Z',
      'occurred_at_raw', '27/08/2026 08:00:00',
      'operation', 'turn_off',
      'operation_raw', 'Desligar',
      'source_original', 'Agendamento',
      'source_normalized', 'agendamento',
      'source_classification', 'programmed',
      'fingerprint', repeat('2', 64)
    )
  );
  full_power jsonb := jsonb_build_array(
    jsonb_build_object(
      'occurred_at', '2026-08-27T09:55:00.000Z',
      'occurred_at_raw', '2026-08-27 06:55:00:000',
      'power_w', 0,
      'power_raw', '0W',
      'device_name', 'Medidor Sessão',
      'device_id', 'device-session',
      'device_id_normalized', 'device-session',
      'event_type', 'Report',
      'event_name', 'Power',
      'event_detail', '0W',
      'request_from', 'Device',
      'source_detail', '',
      'fingerprint', repeat('3', 64)
    ),
    jsonb_build_object(
      'occurred_at', '2026-08-27T10:00:20.000Z',
      'occurred_at_raw', '2026-08-27 07:00:20:000',
      'power_w', 70,
      'power_raw', '70W',
      'device_name', 'Medidor Sessão',
      'device_id', 'device-session',
      'device_id_normalized', 'device-session',
      'event_type', 'Report',
      'event_name', 'Power',
      'event_detail', '70W',
      'request_from', 'Device',
      'source_detail', '',
      'fingerprint', repeat('4', 64)
    ),
    jsonb_build_object(
      'occurred_at', '2026-08-27T11:01:00.000Z',
      'occurred_at_raw', '2026-08-27 08:01:00:000',
      'power_w', 0,
      'power_raw', '0W',
      'device_name', 'Medidor Sessão',
      'device_id', 'device-session',
      'device_id_normalized', 'device-session',
      'event_type', 'Report',
      'event_name', 'Power',
      'event_detail', '0W',
      'request_from', 'Device',
      'source_detail', '',
      'fingerprint', repeat('5', 64)
    )
  );
  reused_state jsonb := jsonb_build_array(
    jsonb_build_object(
      'occurred_at', '2026-08-27T13:00:00.000Z',
      'occurred_at_raw', '27/08/2026 10:00:00',
      'operation', 'turn_on',
      'operation_raw', 'Ligar',
      'source_original', 'Agendamento',
      'source_normalized', 'agendamento',
      'source_classification', 'programmed',
      'fingerprint', repeat('6', 64)
    ),
    jsonb_build_object(
      'occurred_at', '2026-08-27T13:30:00.000Z',
      'occurred_at_raw', '27/08/2026 10:30:00',
      'operation', 'turn_off',
      'operation_raw', 'Desligar',
      'source_original', 'Agendamento',
      'source_normalized', 'agendamento',
      'source_classification', 'programmed',
      'fingerprint', repeat('7', 64)
    )
  );
  reused_power jsonb := jsonb_build_array(
    jsonb_build_object(
      'occurred_at', '2026-08-27T12:59:00.000Z',
      'occurred_at_raw', '2026-08-27 09:59:00:000',
      'power_w', 8,
      'power_raw', '8W',
      'device_name', 'Medidor Sessão',
      'device_id', 'device-session',
      'device_id_normalized', 'device-session',
      'event_type', 'Report',
      'event_name', 'Power',
      'event_detail', '8W',
      'request_from', '',
      'source_detail', '',
      'fingerprint', repeat('8', 64)
    ),
    jsonb_build_object(
      'occurred_at', '2026-08-27T13:31:00.000Z',
      'occurred_at_raw', '2026-08-27 10:31:00:000',
      'power_w', 0,
      'power_raw', '0W',
      'device_name', 'Medidor Sessão',
      'device_id', 'device-session',
      'device_id_normalized', 'device-session',
      'event_type', 'Report',
      'event_name', 'Power',
      'event_detail', '0W',
      'request_from', '',
      'source_detail', '',
      'fingerprint', repeat('9', 64)
    )
  );
  partial_state jsonb := jsonb_build_array(
    jsonb_build_object(
      'occurred_at', '2026-08-27T14:00:00.000Z',
      'occurred_at_raw', '27/08/2026 11:00:00',
      'operation', 'turn_on',
      'operation_raw', 'Ligar',
      'source_original', 'Agendamento',
      'source_normalized', 'agendamento',
      'source_classification', 'programmed',
      'fingerprint', repeat('a', 64)
    ),
    jsonb_build_object(
      'occurred_at', '2026-08-27T15:00:00.000Z',
      'occurred_at_raw', '27/08/2026 12:00:00',
      'operation', 'turn_off',
      'operation_raw', 'Desligar',
      'source_original', 'Agendamento',
      'source_normalized', 'agendamento',
      'source_classification', 'programmed',
      'fingerprint', repeat('b', 64)
    )
  );
  partial_power jsonb := jsonb_build_array(
    jsonb_build_object(
      'occurred_at', '2026-08-27T14:10:00.000Z',
      'occurred_at_raw', '2026-08-27 11:10:00:000',
      'power_w', 8,
      'power_raw', '8W',
      'device_name', 'Medidor Sessão',
      'device_id', 'device-session',
      'device_id_normalized', 'device-session',
      'event_type', 'Report',
      'event_name', 'Power',
      'event_detail', '8W',
      'request_from', '',
      'source_detail', '',
      'fingerprint', repeat('c', 64)
    ),
    jsonb_build_object(
      'occurred_at', '2026-08-27T14:50:00.000Z',
      'occurred_at_raw', '2026-08-27 11:50:00:000',
      'power_w', 0,
      'power_raw', '0W',
      'device_name', 'Medidor Sessão',
      'device_id', 'device-session',
      'device_id_normalized', 'device-session',
      'event_type', 'Report',
      'event_name', 'Power',
      'event_detail', '0W',
      'request_from', '',
      'source_detail', '',
      'fingerprint', repeat('d', 64)
    )
  );
begin
  generator_id_value := public.register_generator_v2(
    'b1000000-0000-4000-8000-000000000001',
    'b3000000-0000-4000-8000-000000000001',
    'b4000000-0000-4000-8000-000000000001',
    'Gerador Sessões',
    '2026-08-01',
    'Controlador Estado Sessões',
    '2026-08-01',
    'Controlador Potência Sessões',
    'device-session',
    '2026-08-01',
    5,
    1,
    120
  );

  select controller.id into state_controller_id
  from public.controllers as controller
  where controller.generator_id = generator_id_value
    and controller.role = 'state';

  select controller.id into power_controller_id
  from public.controllers as controller
  where controller.generator_id = generator_id_value
    and controller.role = 'power_telemetry';

  audit_count := pg_temp.audit_count();
  begin
    perform public.preview_import_session(
    'b1000000-0000-4000-8000-000000000001',
    'b3000000-0000-4000-8000-000000000001',
    'b4000000-0000-4000-8000-000000000001',
    generator_id_value, state_controller_id, 'estado.xlsx', repeat('e', 64), full_state,
    power_controller_id, 'potencia.xlsx', repeat('f', 64), full_power);
    raise exception 'missing nominal profile accepted';
  exception when sqlstate 'P1206' then null;
  end;
  begin
    perform public.confirm_import_session(
    'b1000000-0000-4000-8000-000000000001',
    'b3000000-0000-4000-8000-000000000001',
    'b4000000-0000-4000-8000-000000000001',
    generator_id_value, state_controller_id, 'estado.xlsx', repeat('e', 64), full_state,
    power_controller_id, 'potencia.xlsx', repeat('f', 64), full_power, true);
    raise exception 'missing nominal profile accepted';
  exception when sqlstate 'P1206' then null;
  end;
  begin
    perform public.confirm_xlsx_import(
      'b1000000-0000-4000-8000-000000000001', 'b3000000-0000-4000-8000-000000000001',
      'b4000000-0000-4000-8000-000000000001', generator_id_value, state_controller_id,
      'legacy.xlsx', repeat('a1',32), full_state);
    raise exception 'legacy bypass accepted';
  exception when sqlstate 'P1206' then null;
  end;
  if exists(select 1 from public.import_batches) or exists(select 1 from public.raw_events)
    or exists(select 1 from public.power_readings) or pg_temp.application_count() > 0
    or exists(select 1 from public.import_sessions) or exists(select 1 from public.inconsistencies)
    or pg_temp.audit_count() <> audit_count then
    raise exception 'blocked import left partial data';
  end if;
  -- A profile starting after the application is insufficient, including in preview.
  insert into public.generator_power_profiles(generator_id, nominal_power_w, valid_from, created_by)
  values(generator_id_value, 100, '2026-08-27T13:00:00Z', auth.uid());
  begin
    perform public.preview_import_session(
    'b1000000-0000-4000-8000-000000000001',
    'b3000000-0000-4000-8000-000000000001',
    'b4000000-0000-4000-8000-000000000001',
    generator_id_value, state_controller_id, 'estado.xlsx', repeat('e', 64), full_state,
    power_controller_id, 'potencia.xlsx', repeat('f', 64), full_power);
    raise exception 'partial nominal coverage accepted';
  exception when sqlstate 'P1206' then null;
  end;
  insert into public.generator_power_profiles(generator_id, nominal_power_w, valid_from, valid_until, created_by)
  values(generator_id_value, 72, '2026-08-01T00:00:00Z', '2026-08-27T13:00:00Z', auth.uid());
  -- Three applications: equality at 61.2; low at the exact profile boundary;
  -- no on reading in the third application. Off readings never count as low.
  full_power := jsonb_set(full_power, '{1,power_w}', '61.2');
  full_state := full_state || reused_state || partial_state;
  full_power := full_power || reused_power || partial_power;
  audit_count := pg_temp.audit_count();
  projected := public.preview_import_session(
    'b1000000-0000-4000-8000-000000000001',
    'b3000000-0000-4000-8000-000000000001',
    'b4000000-0000-4000-8000-000000000001',
    generator_id_value, state_controller_id, 'estado.xlsx', repeat('e', 64), full_state,
    power_controller_id, 'potencia.xlsx', repeat('f', 64), full_power);
  if (projected ->> 'within_expected')::int <> 1
    or (projected ->> 'below_expected')::int <> 1
    or (projected ->> 'not_evaluable')::int <> 1
    or jsonb_array_length(projected -> 'profiles') <> 2
    or jsonb_array_length(projected -> 'groups') <> 3 then
    raise exception 'unexpected projected summary: %', projected;
  end if;
  if exists(select 1 from public.import_batches) or exists(select 1 from public.raw_events)
    or exists(select 1 from public.power_readings) or pg_temp.application_count() > 0
    or exists(select 1 from public.import_sessions) or exists(select 1 from public.inconsistencies)
    or pg_temp.audit_count() <> audit_count then
    raise exception 'preview persisted data';
  end if;
  begin
    perform public.confirm_import_session(
    'b1000000-0000-4000-8000-000000000001',
    'b3000000-0000-4000-8000-000000000001',
    'b4000000-0000-4000-8000-000000000001',
    generator_id_value, state_controller_id, 'estado.xlsx', repeat('e', 64), full_state,
    power_controller_id, 'potencia.xlsx', repeat('f', 64), jsonb_set(full_power, '{0,power_w}', '-1'), true);
    raise exception 'invalid second file accepted';
  exception when check_violation then null;
  end;
  if exists(select 1 from public.import_batches) or pg_temp.application_count() > 0
    or pg_temp.audit_count() <> audit_count then
    raise exception 'late failure persisted partial data';
  end if;
  result := public.confirm_import_session(
    'b1000000-0000-4000-8000-000000000001',
    'b3000000-0000-4000-8000-000000000001',
    'b4000000-0000-4000-8000-000000000001',
    generator_id_value, state_controller_id, 'estado.xlsx', repeat('e', 64), full_state,
    power_controller_id, 'potencia.xlsx', repeat('f', 64), full_power, true);
  if result -> 'operational_summary' <> projected then
    raise exception 'preview differs from confirmation: % / %', projected, result;
  end if;
  batch_count := (select count(*) from public.import_batches);
  session_count := (select count(*) from public.import_sessions);
  audit_count := pg_temp.audit_count();
  result := public.confirm_import_session(
    'b1000000-0000-4000-8000-000000000001',
    'b3000000-0000-4000-8000-000000000001',
    'b4000000-0000-4000-8000-000000000001',
    generator_id_value, state_controller_id, 'estado.xlsx', repeat('e', 64), full_state,
    power_controller_id, 'potencia.xlsx', repeat('f', 64), full_power, true);
  if result -> 'operational_summary' <> projected or not (result ->> 'already_confirmed')::boolean
    or (select count(*) from public.import_batches) <> batch_count
    or (select count(*) from public.import_sessions) <> session_count
    or (select count(*) from public.inconsistencies where type = 'power_below_expected' and status <> 'resolved') <> 1 then
    raise exception 'repeat was not idempotent';
  end if;
  result := public.preview_import_session(
    'b1000000-0000-4000-8000-000000000001',
    'b3000000-0000-4000-8000-000000000001',
    'b4000000-0000-4000-8000-000000000001',
    generator_id_value, state_controller_id, 'estado.xlsx', repeat('e', 64), full_state,
    power_controller_id, 'potencia.xlsx', repeat('f', 64), full_power);
  if result <> projected or pg_temp.audit_count() <> audit_count then
    raise exception 'repeat preview changed existing history';
  end if;
end;
$$;
reset role;
do $$
begin
  if has_function_privilege('anon', 'public.preview_import_session(uuid,uuid,uuid,uuid,uuid,text,text,jsonb,uuid,text,text,jsonb)', 'execute')
    or has_function_privilege('authenticated', 'private.import_operational_summary(uuid,uuid[])', 'execute') then
    raise exception 'unexpected preview privileges';
  end if;
end;
$$;
set local role authenticated;
set local request.jwt.claim.sub = 'b2000000-0000-4000-8000-000000000002';
do $$
begin
  begin
    perform public.preview_import_session(null,null,null,null,null,null,null,'[]',null,null,null,'[]');
    raise exception 'viewer accessed preview';
  exception when insufficient_privilege then null;
  end;
end;
$$;
reset role;
select extensions.pass('12.6 canonical preview, nominal coverage, rollback, boundaries and idempotency');
select * from extensions.finish();
rollback;
