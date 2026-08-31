begin;

select extensions.plan(1);

insert into public.clients (id, legal_name, cnpj)
values
  ('91000000-0000-4000-8000-000000000001', 'Cliente Telemetria A', '04252011000110'),
  ('91000000-0000-4000-8000-000000000002', 'Cliente Telemetria B', '11444777000161');

insert into auth.users (id)
values
  ('92000000-0000-4000-8000-000000000001'),
  ('92000000-0000-4000-8000-000000000002');

insert into public.profiles (id, client_id, full_name, role)
values
  ('92000000-0000-4000-8000-000000000001', null, 'Master Telemetria', 'master'),
  ('92000000-0000-4000-8000-000000000002', '91000000-0000-4000-8000-000000000001', 'Cliente Telemetria', 'viewer');

insert into public.locations (id, client_id, name, time_zone)
values
  ('93000000-0000-4000-8000-000000000001', '91000000-0000-4000-8000-000000000001', 'Unidade Telemetria A', 'America/Fortaleza'),
  ('93000000-0000-4000-8000-000000000002', '91000000-0000-4000-8000-000000000002', 'Unidade Telemetria B', 'America/Fortaleza');

insert into public.cold_rooms (id, client_id, location_id, name, category)
values
  ('94000000-0000-4000-8000-000000000001', '91000000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000001', 'Câmara Telemetria A', 'flv'),
  ('94000000-0000-4000-8000-000000000002', '91000000-0000-4000-8000-000000000002', '93000000-0000-4000-8000-000000000002', 'Câmara Telemetria B', 'flv');

insert into public.source_mappings (normalized_source, classification, created_by)
values ('agendamento', 'programmed', '92000000-0000-4000-8000-000000000001');

set local role authenticated;
set local request.jwt.claim.sub = '92000000-0000-4000-8000-000000000001';

do $$
declare
  generator_id_value uuid;
  state_controller_id uuid;
  power_controller_id uuid;
  confirmation jsonb;
  before_snapshot jsonb;
  after_snapshot jsonb;
begin
  generator_id_value := public.register_generator_v2(
    '91000000-0000-4000-8000-000000000001',
    '93000000-0000-4000-8000-000000000001',
    '94000000-0000-4000-8000-000000000001',
    'Gerador Telemetria',
    '2026-08-01',
    'Controlador Estado',
    '2026-08-01',
    'Controlador Potência',
    'ebd862b9f547471587payu',
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

  if state_controller_id is null or power_controller_id is null then
    raise exception 'o cadastro atômico não criou os dois papéis';
  end if;

  if (
    select generator.telemetry_status
    from public.generators as generator
    where generator.id = generator_id_value
  ) <> 'ready' then
    raise exception 'o gerador com dois papéis não ficou pronto';
  end if;

  begin
    perform public.register_controller_v2(
      generator_id_value,
      'state',
      'Estado sobreposto',
      '2026-08-15'
    );
    raise exception 'foi aceita sobreposição no mesmo papel';
  exception when check_violation or exclusion_violation then null;
  end;

  confirmation := public.confirm_xlsx_import(
    '91000000-0000-4000-8000-000000000001',
    '93000000-0000-4000-8000-000000000001',
    '94000000-0000-4000-8000-000000000001',
    generator_id_value,
    state_controller_id,
    'estado.xlsx',
    repeat('1', 64),
    jsonb_build_array(
      jsonb_build_object(
        'occurred_at', '2026-08-27T10:00:00.000Z',
        'occurred_at_raw', '27/08/2026 07:00:00',
        'operation', 'turn_on',
        'operation_raw', 'Ligou',
        'source_original', 'Agendamento',
        'source_normalized', 'agendamento',
        'source_classification', 'programmed',
        'fingerprint', repeat('2', 64)
      ),
      jsonb_build_object(
        'occurred_at', '2026-08-27T10:30:00.000Z',
        'occurred_at_raw', '27/08/2026 07:30:00',
        'operation', 'turn_off',
        'operation_raw', 'Desligou',
        'source_original', 'Agendamento',
        'source_normalized', 'agendamento',
        'source_classification', 'programmed',
        'fingerprint', repeat('3', 64)
      )
    )
  );

  if (confirmation ->> 'inserted_rows')::integer <> 2 then
    raise exception 'a importação de estado regrediu';
  end if;

  confirmation := public.confirm_power_xlsx_import(
    '91000000-0000-4000-8000-000000000001',
    '93000000-0000-4000-8000-000000000001',
    '94000000-0000-4000-8000-000000000001',
    generator_id_value,
    power_controller_id,
    'potencia.xlsx',
    repeat('4', 64),
    jsonb_build_array(
      jsonb_build_object(
        'occurred_at', '2026-08-27T10:00:32.813Z',
        'occurred_at_raw', '2026-08-27 07:00:32:813',
        'power_w', 71.80,
        'power_raw', '71.80W',
        'device_name', 'Charbon 2',
        'device_id', 'ebd862b9f547471587payu',
        'device_id_normalized', 'ebd862b9f547471587payu',
        'event_type', 'Report',
        'event_name', 'Power',
        'event_detail', '71.80W',
        'request_from', 'Device',
        'source_detail', '',
        'fingerprint', repeat('5', 64)
      ),
      jsonb_build_object(
        'occurred_at', '2026-08-27T10:30:08.064Z',
        'occurred_at_raw', '2026-08-27 07:30:08:064',
        'power_w', 0,
        'power_raw', '0.00W',
        'device_name', 'Charbon 2',
        'device_id', 'ebd862b9f547471587payu',
        'device_id_normalized', 'ebd862b9f547471587payu',
        'event_type', 'Report',
        'event_name', 'Power',
        'event_detail', '0.00W',
        'request_from', 'Device',
        'source_detail', '',
        'fingerprint', repeat('6', 64)
      )
    )
  );

  if (confirmation ->> 'inserted_rows')::integer <> 2
    or not exists (
      select 1
      from public.application_power_verifications as verification
      where verification.generator_id = generator_id_value
        and verification.status = 'verified'
        and verification.power_on_reading_id is not null
        and verification.power_off_reading_id is not null
    ) then
    raise exception 'o exemplo de potência não produziu verificação confirmada';
  end if;

  if (
    select daily_status.power_evidence_status
    from public.client_daily_status as daily_status
    where daily_status.generator_id = generator_id_value
      and daily_status.status_date = '2026-08-27'
  ) <> 'confirmed' then
    raise exception 'a evidência qualitativa confirmada não foi publicada';
  end if;

  select jsonb_build_object(
    'readings', (
      select jsonb_agg(to_jsonb(reading) order by reading.id)
      from public.power_readings as reading
      where reading.generator_id = generator_id_value
    ),
    'verifications', (
      select jsonb_agg(to_jsonb(verification) order by verification.application_id)
      from public.application_power_verifications as verification
      where verification.generator_id = generator_id_value
    ),
    'daily', (
      select jsonb_agg(to_jsonb(daily_status) order by daily_status.status_date)
      from public.client_daily_status as daily_status
      where daily_status.generator_id = generator_id_value
    )
  ) into before_snapshot;

  perform public.reprocess_generator_telemetry(generator_id_value);

  select jsonb_build_object(
    'readings', (
      select jsonb_agg(to_jsonb(reading) order by reading.id)
      from public.power_readings as reading
      where reading.generator_id = generator_id_value
    ),
    'verifications', (
      select jsonb_agg(to_jsonb(verification) order by verification.application_id)
      from public.application_power_verifications as verification
      where verification.generator_id = generator_id_value
    ),
    'daily', (
      select jsonb_agg(to_jsonb(daily_status) order by daily_status.status_date)
      from public.client_daily_status as daily_status
      where daily_status.generator_id = generator_id_value
    )
  ) into after_snapshot;

  if before_snapshot is distinct from after_snapshot then
    raise exception 'o reprocessamento de potência não é temporalmente idempotente';
  end if;

  confirmation := public.confirm_power_xlsx_import(
    '91000000-0000-4000-8000-000000000001',
    '93000000-0000-4000-8000-000000000001',
    '94000000-0000-4000-8000-000000000001',
    generator_id_value,
    power_controller_id,
    'potencia-extra.xlsx',
    repeat('7', 64),
    jsonb_build_array(
      jsonb_build_object(
        'occurred_at', '2026-08-27T11:00:00.000Z',
        'occurred_at_raw', '2026-08-27 08:00:00:000',
        'power_w', 40,
        'power_raw', '40.00W',
        'device_name', 'Charbon 2',
        'device_id', 'ebd862b9f547471587payu',
        'device_id_normalized', 'ebd862b9f547471587payu',
        'event_type', 'Report',
        'event_name', 'Power',
        'event_detail', '40.00W',
        'request_from', 'Device',
        'source_detail', '',
        'fingerprint', repeat('8', 64)
      ),
      jsonb_build_object(
        'occurred_at', '2026-08-27T11:30:00.000Z',
        'occurred_at_raw', '2026-08-27 08:30:00:000',
        'power_w', 0,
        'power_raw', '0.00W',
        'device_name', 'Charbon 2',
        'device_id', 'ebd862b9f547471587payu',
        'device_id_normalized', 'ebd862b9f547471587payu',
        'event_type', 'Report',
        'event_name', 'Power',
        'event_detail', '0.00W',
        'request_from', 'Device',
        'source_detail', '',
        'fingerprint', repeat('9', 64)
      )
    )
  );

  if not exists (
    select 1
    from public.inconsistencies as inconsistency
    where inconsistency.generator_id = generator_id_value
      and inconsistency.type = 'unexpected_power'
      and inconsistency.status = 'pending'
  ) then
    raise exception 'a potência ligada sem aplicação não gerou inconsistência';
  end if;

  if (
    select daily_status.power_evidence_status
    from public.client_daily_status as daily_status
    where daily_status.generator_id = generator_id_value
      and daily_status.status_date = '2026-08-27'
  ) <> 'requires_review' then
    raise exception 'a potência inesperada não alterou a evidência qualitativa';
  end if;

  begin
    perform public.confirm_power_xlsx_import(
      '91000000-0000-4000-8000-000000000001',
      '93000000-0000-4000-8000-000000000001',
      '94000000-0000-4000-8000-000000000001',
      generator_id_value,
      power_controller_id,
      'dispositivo-incorreto.xlsx',
      repeat('a', 64),
      jsonb_build_array(jsonb_build_object(
        'occurred_at', '2026-08-27T12:00:00.000Z',
        'occurred_at_raw', '2026-08-27 09:00:00:000',
        'power_w', 10,
        'power_raw', '10W',
        'device_name', 'Outro',
        'device_id', 'device-errado',
        'device_id_normalized', 'device-errado',
        'event_type', 'Report',
        'event_name', 'Power',
        'event_detail', '10W',
        'request_from', '',
        'source_detail', '',
        'fingerprint', repeat('b', 64)
      ))
    );
    raise exception 'foi aceito Device ID divergente';
  exception when check_violation then null;
  end;
end;
$$;

reset role;
set local role authenticated;
set local request.jwt.claim.sub = '92000000-0000-4000-8000-000000000002';

do $$
begin
  if exists (select 1 from public.power_readings)
    or exists (select 1 from public.application_power_verifications) then
    raise exception 'o cliente acessou telemetria técnica';
  end if;

  if not exists (
    select 1
    from public.client_daily_status
    where client_id = '91000000-0000-4000-8000-000000000001'
      and power_evidence_status = 'requires_review'
  ) then
    raise exception 'o cliente não recebeu a publicação qualitativa autorizada';
  end if;
end;
$$;

reset role;

do $$
begin
  if has_table_privilege('anon', 'public.power_readings', 'select')
    or has_table_privilege('anon', 'public.application_power_verifications', 'select') then
    raise exception 'anon recebeu acesso à telemetria técnica';
  end if;

  if not exists (
    select 1
    from public.controllers
    where role = 'state'
  ) then
    raise exception 'o papel state não é o padrão compatível com o legado';
  end if;
end;
$$;

select extensions.pass('spec 10 dual controller and power telemetry tests passed');
select * from extensions.finish();

rollback;
