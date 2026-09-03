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

set local role authenticated;
set local request.jwt.claim.sub = 'b2000000-0000-4000-8000-000000000001';

do $$
declare
  generator_id_value uuid;
  state_controller_id uuid;
  power_controller_id uuid;
  result jsonb;
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

  result := public.confirm_import_session(
    'b1000000-0000-4000-8000-000000000001',
    'b3000000-0000-4000-8000-000000000001',
    'b4000000-0000-4000-8000-000000000001',
    generator_id_value,
    state_controller_id,
    'estado-completo.xlsx',
    repeat('e', 64),
    full_state,
    power_controller_id,
    'potencia-completa.xlsx',
    repeat('f', 64),
    full_power,
    false
  );

  if result ->> 'status' <> 'confirmed'
    or result ->> 'coverage_status' <> 'full'
    or (result ->> 'already_confirmed')::boolean
    or (result #>> '{state_batch,inserted_rows}')::integer <> 2
    or (result #>> '{power_batch,inserted_rows}')::integer <> 3
    or (select count(*) from public.import_sessions where status = 'confirmed') <> 1
    or (select count(*) from public.import_batches where status = 'confirmed') <> 2
    or (select count(*) from public.raw_events) <> 2
    or (select count(*) from public.power_readings) <> 3 then
    raise exception 'a primeira sessão conjunta não foi confirmada corretamente: %', result;
  end if;

  if not exists (
    select 1
    from public.application_power_verifications as verification
    where verification.generator_id = generator_id_value
      and verification.status = 'verified'
  ) then
    raise exception 'a reconstrução conjunta não correlacionou estado e potência';
  end if;

  batch_count := (select count(*) from public.import_batches);
  session_count := (select count(*) from public.import_sessions);

  result := public.confirm_import_session(
    'b1000000-0000-4000-8000-000000000001',
    'b3000000-0000-4000-8000-000000000001',
    'b4000000-0000-4000-8000-000000000001',
    generator_id_value,
    state_controller_id,
    'estado-completo.xlsx',
    repeat('e', 64),
    full_state,
    power_controller_id,
    'potencia-completa.xlsx',
    repeat('f', 64),
    full_power,
    false
  );

  if not (result ->> 'already_confirmed')::boolean
    or (select count(*) from public.import_batches) <> batch_count
    or (select count(*) from public.import_sessions) <> session_count
    or (select count(*) from public.raw_events) <> 2
    or (select count(*) from public.power_readings) <> 3 then
    raise exception 'a reapresentação do mesmo par não foi idempotente: %', result;
  end if;

  result := public.confirm_xlsx_import(
    'b1000000-0000-4000-8000-000000000001',
    'b3000000-0000-4000-8000-000000000001',
    'b4000000-0000-4000-8000-000000000001',
    generator_id_value,
    state_controller_id,
    'estado-reutilizado.xlsx',
    repeat('0', 64),
    reused_state
  );

  result := public.confirm_import_session(
    'b1000000-0000-4000-8000-000000000001',
    'b3000000-0000-4000-8000-000000000001',
    'b4000000-0000-4000-8000-000000000001',
    generator_id_value,
    state_controller_id,
    'estado-reutilizado.xlsx',
    repeat('0', 64),
    reused_state,
    power_controller_id,
    'potencia-nova.xlsx',
    repeat('1a', 32),
    reused_power,
    false
  );

  if not (result #>> '{state_batch,already_confirmed}')::boolean
    or (result #>> '{power_batch,already_confirmed}')::boolean
    or result ->> 'coverage_status' <> 'full' then
    raise exception 'a sessão não reutilizou somente o lote de estado: %', result;
  end if;

  batch_count := (select count(*) from public.import_batches);
  begin
    perform public.confirm_import_session(
      'b1000000-0000-4000-8000-000000000001',
      'b3000000-0000-4000-8000-000000000001',
      'b4000000-0000-4000-8000-000000000001',
      generator_id_value,
      state_controller_id,
      'estado-parcial.xlsx',
      repeat('2a', 32),
      partial_state,
      power_controller_id,
      'potencia-parcial.xlsx',
      repeat('3a', 32),
      partial_power,
      false
    );
    raise exception 'a cobertura parcial foi aceita sem ciência';
  exception when check_violation then null;
  end;

  if (select count(*) from public.import_batches) <> batch_count then
    raise exception 'o aviso não confirmado deixou lote parcial';
  end if;

  result := public.confirm_import_session(
    'b1000000-0000-4000-8000-000000000001',
    'b3000000-0000-4000-8000-000000000001',
    'b4000000-0000-4000-8000-000000000001',
    generator_id_value,
    state_controller_id,
    'estado-parcial.xlsx',
    repeat('2a', 32),
    partial_state,
    power_controller_id,
    'potencia-parcial.xlsx',
    repeat('3a', 32),
    partial_power,
    true
  );

  if result ->> 'coverage_status' <> 'partial'
    or not (result ->> 'coverage_warning_acknowledged')::boolean then
    raise exception 'a cobertura parcial confirmada não preservou a ciência: %', result;
  end if;

  batch_count := (select count(*) from public.import_batches);
  begin
    perform public.confirm_import_session(
      'b1000000-0000-4000-8000-000000000001',
      'b3000000-0000-4000-8000-000000000001',
      'b4000000-0000-4000-8000-000000000001',
      generator_id_value,
      state_controller_id,
      'estado-sem-intersecao.xlsx',
      repeat('4a', 32),
      jsonb_build_array(jsonb_build_object(
        'occurred_at', '2026-08-27T16:00:00.000Z',
        'occurred_at_raw', '27/08/2026 13:00:00',
        'operation', 'turn_on',
        'operation_raw', 'Ligar',
        'source_original', 'Agendamento',
        'source_normalized', 'agendamento',
        'source_classification', 'programmed',
        'fingerprint', repeat('e1', 32)
      )),
      power_controller_id,
      'potencia-sem-intersecao.xlsx',
      repeat('5a', 32),
      jsonb_build_array(jsonb_build_object(
        'occurred_at', '2026-08-27T18:00:00.000Z',
        'occurred_at_raw', '2026-08-27 15:00:00:000',
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
        'fingerprint', repeat('f1', 32)
      )),
      true
    );
    raise exception 'períodos sem interseção foram aceitos';
  exception when check_violation then null;
  end;

  if (select count(*) from public.import_batches) <> batch_count then
    raise exception 'a ausência de interseção deixou lotes parciais';
  end if;

  begin
    perform public.confirm_import_session(
      'b1000000-0000-4000-8000-000000000001',
      'b3000000-0000-4000-8000-000000000001',
      'b4000000-0000-4000-8000-000000000001',
      generator_id_value,
      state_controller_id,
      'estado-rollback.xlsx',
      repeat('6a', 32),
      jsonb_build_array(jsonb_build_object(
        'occurred_at', '2026-08-27T20:00:00.000Z',
        'occurred_at_raw', '27/08/2026 17:00:00',
        'operation', 'turn_on',
        'operation_raw', 'Ligar',
        'source_original', 'Agendamento',
        'source_normalized', 'agendamento',
        'source_classification', 'programmed',
        'fingerprint', repeat('2b', 32)
      )),
      power_controller_id,
      'potencia-invalida.xlsx',
      repeat('7a', 32),
      jsonb_build_array(jsonb_build_object(
        'occurred_at', '2026-08-27T20:00:00.000Z',
        'occurred_at_raw', '2026-08-27 17:00:00:000',
        'power_w', 10,
        'power_raw', '10W',
        'device_name', 'Outro medidor',
        'device_id', 'device-wrong',
        'device_id_normalized', 'device-wrong',
        'event_type', 'Report',
        'event_name', 'Power',
        'event_detail', '10W',
        'request_from', '',
        'source_detail', '',
        'fingerprint', repeat('3b', 32)
      )),
      false
    );
    raise exception 'uma segunda fonte inválida foi aceita';
  exception when check_violation then null;
  end;

  if exists (
    select 1
    from public.import_batches
    where file_sha256 in (repeat('6a', 32), repeat('7a', 32))
  ) or exists (
    select 1 from public.raw_events where fingerprint = repeat('2b', 32)
  ) then
    raise exception 'a falha na segunda fonte deixou a primeira confirmada';
  end if;

  perform public.confirm_xlsx_import(
    'b1000000-0000-4000-8000-000000000001',
    'b3000000-0000-4000-8000-000000000001',
    'b4000000-0000-4000-8000-000000000001',
    generator_id_value,
    state_controller_id,
    'lote-legado-sem-sessao.xlsx',
    repeat('8a', 32),
    jsonb_build_array(jsonb_build_object(
      'occurred_at', '2026-08-27T22:00:00.000Z',
      'occurred_at_raw', '27/08/2026 19:00:00',
      'operation', 'turn_on',
      'operation_raw', 'Ligar',
      'source_original', 'Agendamento',
      'source_normalized', 'agendamento',
      'source_classification', 'programmed',
      'fingerprint', repeat('4b', 32)
    ))
  );

  if not exists (
    select 1
    from public.import_batches as batch
    where batch.file_sha256 = repeat('8a', 32)
      and not exists (
        select 1
        from public.import_sessions as session
        where session.state_batch_id = batch.id
          or session.power_batch_id = batch.id
      )
  ) then
    raise exception 'o lote legado sem sessão não foi preservado';
  end if;

  perform public.record_failed_import_session(
    'b1000000-0000-4000-8000-000000000001',
    'b3000000-0000-4000-8000-000000000001',
    'b4000000-0000-4000-8000-000000000001',
    generator_id_value,
    state_controller_id,
    'estado-falhou.xlsx',
    repeat('9a', 32),
    '2026-08-28T10:00:00.000Z',
    '2026-08-28T11:00:00.000Z',
    power_controller_id,
    'potencia-falhou.xlsx',
    repeat('ab', 32),
    '2026-08-28T10:00:00.000Z',
    '2026-08-28T11:00:00.000Z',
    'Falha controlada sem conteúdo bruto'
  );

  if not exists (
    select 1
    from public.import_sessions
    where status = 'failed'
      and state_batch_id is null
      and power_batch_id is null
      and error_message = 'Falha controlada sem conteúdo bruto'
  ) then
    raise exception 'a tentativa malsucedida não foi registrada separadamente';
  end if;

  begin
    update public.import_sessions
    set coverage_status = 'partial'
    where status = 'confirmed';
    raise exception 'uma sessão confirmada foi alterada';
  exception
    when insufficient_privilege or object_not_in_prerequisite_state then null;
  end;

  begin
    update public.import_batches
    set file_name = 'alterado.xlsx'
    where id = (select state_batch_id from public.import_sessions where status = 'confirmed' limit 1);
    raise exception 'um lote associado à sessão foi alterado';
  exception when object_not_in_prerequisite_state then null;
  end;

  if (select count(*) from public.latest_confirmed_import_batches) <> 2 then
    raise exception 'a visão de última confirmação não retornou os dois papéis';
  end if;
end;
$$;

reset role;

do $$
begin
  if has_table_privilege('anon', 'public.import_sessions', 'select')
    or has_table_privilege('anon', 'public.latest_confirmed_import_batches', 'select')
    or has_function_privilege(
      'anon',
      'public.confirm_import_session(uuid,uuid,uuid,uuid,uuid,text,text,jsonb,uuid,text,text,jsonb,boolean)',
      'execute'
    ) then
    raise exception 'anon recebeu acesso às sessões técnicas';
  end if;

  if has_table_privilege('authenticated', 'public.import_sessions', 'insert')
    or not has_table_privilege('authenticated', 'public.import_sessions', 'select') then
    raise exception 'os privilégios explícitos de import_sessions estão incorretos';
  end if;

  if (
    select count(*)
    from public.audit_logs
    where actor_id = 'b2000000-0000-4000-8000-000000000001'
      and entity_type = 'import_sessions'
      and action = 'import_session_confirmed'
  ) <> 3 or not exists (
    select 1
    from public.audit_logs
    where actor_id = 'b2000000-0000-4000-8000-000000000001'
      and entity_type = 'import_sessions'
      and action = 'import_session_failed'
  ) then
    raise exception 'as sessões confirmadas e falhas não foram auditadas';
  end if;
end;
$$;

set local role authenticated;
set local request.jwt.claim.sub = 'b2000000-0000-4000-8000-000000000002';

do $$
begin
  if exists (select 1 from public.import_sessions)
    or exists (select 1 from public.latest_confirmed_import_batches)
    or exists (select 1 from public.import_batches) then
    raise exception 'o cliente A acessou sessões ou lotes técnicos';
  end if;
end;
$$;

set local request.jwt.claim.sub = 'b2000000-0000-4000-8000-000000000003';

do $$
begin
  if exists (select 1 from public.import_sessions)
    or exists (select 1 from public.latest_confirmed_import_batches)
    or exists (select 1 from public.import_batches) then
    raise exception 'o cliente B acessou sessões ou lotes técnicos';
  end if;
end;
$$;

reset role;

select extensions.pass('spec 11 joint state and power import session tests passed');
select * from extensions.finish();

rollback;
