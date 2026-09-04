begin;

select extensions.plan(1);

insert into public.clients (id, legal_name, cnpj)
values
  ('d1000000-0000-4000-8000-000000000001', 'Cliente Avaliação A', '04252011000110'),
  ('d1000000-0000-4000-8000-000000000002', 'Cliente Avaliação B', '11444777000161');

insert into auth.users (id)
values ('d2000000-0000-4000-8000-000000000001');

insert into public.profiles (id, client_id, full_name, role)
values (
  'd2000000-0000-4000-8000-000000000001',
  null,
  'Master Avaliação',
  'master'
);

insert into public.locations (id, client_id, name, time_zone)
values (
  'd3000000-0000-4000-8000-000000000001',
  'd1000000-0000-4000-8000-000000000001',
  'Unidade Avaliação',
  'America/Fortaleza'
);

insert into public.cold_rooms (
  id,
  client_id,
  location_id,
  name,
  category
)
values (
  'd4000000-0000-4000-8000-000000000001',
  'd1000000-0000-4000-8000-000000000001',
  'd3000000-0000-4000-8000-000000000001',
  'Câmara Avaliação',
  'outros'
);

insert into public.generators (id, client_id, identifier)
values
  (
    'd5000000-0000-4000-8000-000000000001',
    'd1000000-0000-4000-8000-000000000001',
    'Gerador Avaliação'
  ),
  (
    'd5000000-0000-4000-8000-000000000002',
    'd1000000-0000-4000-8000-000000000002',
    'Gerador Outro Contexto'
  );

insert into public.controllers (
  id,
  client_id,
  generator_id,
  identifier,
  activated_at,
  role
)
values (
  'd6000000-0000-4000-8000-000000000001',
  'd1000000-0000-4000-8000-000000000001',
  'd5000000-0000-4000-8000-000000000001',
  'Estado Avaliação',
  '2025-01-01 00:00:00+00',
  'state'
);

insert into public.controllers (
  id,
  client_id,
  generator_id,
  identifier,
  activated_at,
  role,
  external_device_id,
  power_on_threshold_w,
  power_off_threshold_w,
  correlation_tolerance_seconds
)
values (
  'd6000000-0000-4000-8000-000000000002',
  'd1000000-0000-4000-8000-000000000001',
  'd5000000-0000-4000-8000-000000000001',
  'Potência Avaliação',
  '2025-01-01 00:00:00+00',
  'power_telemetry',
  'device-evaluation',
  5,
  1,
  120
);

insert into public.generator_power_profiles (
  id,
  generator_id,
  nominal_power_w,
  valid_from,
  valid_until,
  created_by
)
values
  (
    'd7000000-0000-4000-8000-000000000001',
    'd5000000-0000-4000-8000-000000000001',
    72.000,
    '2026-01-01 00:00:00+00',
    '2026-06-01 00:00:00+00',
    'd2000000-0000-4000-8000-000000000001'
  ),
  (
    'd7000000-0000-4000-8000-000000000002',
    'd5000000-0000-4000-8000-000000000001',
    100.000,
    '2026-06-01 00:00:00+00',
    null,
    'd2000000-0000-4000-8000-000000000001'
  ),
  (
    'd7000000-0000-4000-8000-000000000003',
    'd5000000-0000-4000-8000-000000000002',
    90.000,
    '2026-01-01 00:00:00+00',
    null,
    'd2000000-0000-4000-8000-000000000001'
  );

insert into public.import_batches (
  id,
  client_id,
  location_id,
  cold_room_id,
  generator_id,
  controller_id,
  data_kind,
  file_name,
  file_sha256,
  status,
  total_rows,
  inserted_rows,
  period_start,
  period_end,
  created_by,
  confirmed_at
)
values
  (
    'd8000000-0000-4000-8000-000000000001',
    'd1000000-0000-4000-8000-000000000001',
    'd3000000-0000-4000-8000-000000000001',
    'd4000000-0000-4000-8000-000000000001',
    'd5000000-0000-4000-8000-000000000001',
    'd6000000-0000-4000-8000-000000000001',
    'state_events',
    'estado-avaliacao.xlsx',
    repeat('1', 64),
    'confirmed',
    12,
    12,
    '2025-12-31 10:00:00+00',
    '2026-06-01 10:30:00+00',
    'd2000000-0000-4000-8000-000000000001',
    '2026-06-01 11:00:00+00'
  ),
  (
    'd8000000-0000-4000-8000-000000000002',
    'd1000000-0000-4000-8000-000000000001',
    'd3000000-0000-4000-8000-000000000001',
    'd4000000-0000-4000-8000-000000000001',
    'd5000000-0000-4000-8000-000000000001',
    'd6000000-0000-4000-8000-000000000002',
    'power_readings',
    'potencia-avaliacao.xlsx',
    repeat('2', 64),
    'confirmed',
    10,
    10,
    '2025-12-31 10:00:10+00',
    '2026-06-01 10:30:10+00',
    'd2000000-0000-4000-8000-000000000001',
    '2026-06-01 11:00:00+00'
  );

insert into public.raw_events (
  import_batch_id,
  generator_id,
  controller_id,
  occurred_at,
  occurred_at_raw,
  operation,
  operation_raw,
  source_original,
  source_normalized,
  source_classification,
  fingerprint
)
select
  'd8000000-0000-4000-8000-000000000001',
  'd5000000-0000-4000-8000-000000000001',
  'd6000000-0000-4000-8000-000000000001',
  source.occurred_at,
  source.occurred_at::text,
  source.operation,
  source.operation,
  'Agendamento',
  'agendamento',
  'programmed',
  lpad(source.fingerprint_seed, 64, '0')
from (
  values
    ('2025-12-31 10:00:00+00'::timestamptz, 'turn_on', '1'),
    ('2025-12-31 10:30:00+00'::timestamptz, 'turn_off', '2'),
    ('2026-01-10 10:00:00+00'::timestamptz, 'turn_on', '3'),
    ('2026-01-10 10:30:00+00'::timestamptz, 'turn_off', '4'),
    ('2026-01-11 10:00:00+00'::timestamptz, 'turn_on', '5'),
    ('2026-01-11 10:30:00+00'::timestamptz, 'turn_off', '6'),
    ('2026-01-12 10:00:00+00'::timestamptz, 'turn_on', '7'),
    ('2026-01-12 10:30:00+00'::timestamptz, 'turn_off', '8'),
    ('2026-01-13 10:00:00+00'::timestamptz, 'turn_on', '9'),
    ('2026-01-13 10:30:00+00'::timestamptz, 'turn_off', '10'),
    ('2026-06-01 10:00:00+00'::timestamptz, 'turn_on', '11'),
    ('2026-06-01 10:30:00+00'::timestamptz, 'turn_off', '12')
) as source(occurred_at, operation, fingerprint_seed);

insert into public.applications (
  generator_id,
  controller_id,
  start_event_id,
  end_event_id,
  public_date
)
select
  'd5000000-0000-4000-8000-000000000001',
  'd6000000-0000-4000-8000-000000000001',
  start_event.id,
  end_event.id,
  (period.start_at at time zone 'America/Fortaleza')::date
from (
  values
    (
      '2025-12-31 10:00:00+00'::timestamptz,
      '2025-12-31 10:30:00+00'::timestamptz
    ),
    (
      '2026-01-10 10:00:00+00'::timestamptz,
      '2026-01-10 10:30:00+00'::timestamptz
    ),
    (
      '2026-01-11 10:00:00+00'::timestamptz,
      '2026-01-11 10:30:00+00'::timestamptz
    ),
    (
      '2026-01-12 10:00:00+00'::timestamptz,
      '2026-01-12 10:30:00+00'::timestamptz
    ),
    (
      '2026-01-13 10:00:00+00'::timestamptz,
      '2026-01-13 10:30:00+00'::timestamptz
    ),
    (
      '2026-06-01 10:00:00+00'::timestamptz,
      '2026-06-01 10:30:00+00'::timestamptz
    )
) as period(start_at, end_at)
join public.raw_events as start_event
  on start_event.generator_id = 'd5000000-0000-4000-8000-000000000001'
  and start_event.occurred_at = period.start_at
join public.raw_events as end_event
  on end_event.generator_id = 'd5000000-0000-4000-8000-000000000001'
  and end_event.occurred_at = period.end_at;

insert into public.power_readings (
  import_batch_id,
  client_id,
  location_id,
  cold_room_id,
  generator_id,
  controller_id,
  occurred_at,
  occurred_at_raw,
  power_w,
  power_raw,
  device_name,
  device_id,
  device_id_normalized,
  event_type,
  event_name,
  event_detail,
  request_from,
  source_detail,
  fingerprint
)
select
  'd8000000-0000-4000-8000-000000000002',
  'd1000000-0000-4000-8000-000000000001',
  'd3000000-0000-4000-8000-000000000001',
  'd4000000-0000-4000-8000-000000000001',
  'd5000000-0000-4000-8000-000000000001',
  'd6000000-0000-4000-8000-000000000002',
  source.occurred_at,
  source.occurred_at::text,
  source.power_w,
  source.power_w::text || 'W',
  'Medidor Avaliação',
  'device-evaluation',
  'device-evaluation',
  'Report',
  'Power',
  source.power_w::text || 'W',
  'Device',
  '',
  lpad(source.fingerprint_seed, 64, '0')
from (
  values
    ('2025-12-31 10:00:10+00'::timestamptz, 10.000::numeric, '101'),
    ('2025-12-31 10:30:10+00'::timestamptz, 0.000::numeric, '102'),
    ('2026-01-10 10:00:10+00'::timestamptz, 61.200::numeric, '103'),
    ('2026-01-10 10:30:10+00'::timestamptz, 0.000::numeric, '104'),
    ('2026-01-11 10:00:10+00'::timestamptz, 61.199::numeric, '105'),
    ('2026-01-12 10:30:10+00'::timestamptz, 0.000::numeric, '106'),
    ('2026-01-13 10:00:10+00'::timestamptz, 4.999::numeric, '107'),
    ('2026-06-01 10:00:10+00'::timestamptz, 85.000::numeric, '108'),
    ('2026-06-01 10:30:10+00'::timestamptz, 0.000::numeric, '109')
) as source(occurred_at, power_w, fingerprint_seed);

do $$
declare
  app_not_configured bigint;
  app_equal bigint;
  app_below bigint;
  app_missing bigint;
  app_below_threshold bigint;
  app_boundary bigint;
  reading_not_configured_on bigint;
  reading_not_configured_off bigint;
  reading_equal_on bigint;
  reading_equal_off bigint;
  reading_below_on bigint;
  reading_missing_off bigint;
  reading_below_threshold bigint;
  reading_boundary_on bigint;
  reading_boundary_off bigint;
  before_snapshot jsonb;
  after_snapshot jsonb;
begin
  select application.id
  into strict app_not_configured
  from public.applications as application
  join public.raw_events as event on event.id = application.start_event_id
  where event.occurred_at = '2025-12-31 10:00:00+00';

  select application.id
  into strict app_equal
  from public.applications as application
  join public.raw_events as event on event.id = application.start_event_id
  where event.occurred_at = '2026-01-10 10:00:00+00';

  select application.id
  into strict app_below
  from public.applications as application
  join public.raw_events as event on event.id = application.start_event_id
  where event.occurred_at = '2026-01-11 10:00:00+00';

  select application.id
  into strict app_missing
  from public.applications as application
  join public.raw_events as event on event.id = application.start_event_id
  where event.occurred_at = '2026-01-12 10:00:00+00';

  select application.id
  into strict app_below_threshold
  from public.applications as application
  join public.raw_events as event on event.id = application.start_event_id
  where event.occurred_at = '2026-01-13 10:00:00+00';

  select application.id
  into strict app_boundary
  from public.applications as application
  join public.raw_events as event on event.id = application.start_event_id
  where event.occurred_at = '2026-06-01 10:00:00+00';

  select id into strict reading_not_configured_on
  from public.power_readings
  where occurred_at = '2025-12-31 10:00:10+00';

  select id into strict reading_not_configured_off
  from public.power_readings
  where occurred_at = '2025-12-31 10:30:10+00';

  select id into strict reading_equal_on
  from public.power_readings
  where occurred_at = '2026-01-10 10:00:10+00';

  select id into strict reading_equal_off
  from public.power_readings
  where occurred_at = '2026-01-10 10:30:10+00';

  select id into strict reading_below_on
  from public.power_readings
  where occurred_at = '2026-01-11 10:00:10+00';

  select id into strict reading_missing_off
  from public.power_readings
  where occurred_at = '2026-01-12 10:30:10+00';

  select id into strict reading_below_threshold
  from public.power_readings
  where occurred_at = '2026-01-13 10:00:10+00';

  select id into strict reading_boundary_on
  from public.power_readings
  where occurred_at = '2026-06-01 10:00:10+00';

  select id into strict reading_boundary_off
  from public.power_readings
  where occurred_at = '2026-06-01 10:30:10+00';

  insert into public.application_power_verifications (
    application_id,
    generator_id,
    controller_id,
    power_on_reading_id,
    power_off_reading_id,
    status,
    technical_reason,
    source_updated_at
  )
  values
    (
      app_not_configured,
      'd5000000-0000-4000-8000-000000000001',
      'd6000000-0000-4000-8000-000000000002',
      reading_not_configured_on,
      reading_not_configured_off,
      'verified',
      'power_transitions_correlated',
      '2025-12-31 10:30:10+00'
    ),
    (
      app_equal,
      'd5000000-0000-4000-8000-000000000001',
      'd6000000-0000-4000-8000-000000000002',
      reading_equal_on,
      reading_equal_off,
      'verified',
      'power_transitions_correlated',
      '2026-01-10 10:30:10+00'
    ),
    (
      app_below,
      'd5000000-0000-4000-8000-000000000001',
      'd6000000-0000-4000-8000-000000000002',
      reading_below_on,
      null,
      'missing_power_off',
      'off_transition_not_found_within_tolerance',
      '2026-01-11 10:30:10+00'
    ),
    (
      app_missing,
      'd5000000-0000-4000-8000-000000000001',
      'd6000000-0000-4000-8000-000000000002',
      null,
      reading_missing_off,
      'missing_power_on',
      'on_transition_not_found_within_tolerance',
      '2026-01-12 10:30:10+00'
    ),
    (
      app_below_threshold,
      'd5000000-0000-4000-8000-000000000001',
      'd6000000-0000-4000-8000-000000000002',
      reading_below_threshold,
      null,
      'missing_power_off',
      'off_transition_not_found_within_tolerance',
      '2026-01-13 10:30:10+00'
    ),
    (
      app_boundary,
      'd5000000-0000-4000-8000-000000000001',
      'd6000000-0000-4000-8000-000000000002',
      reading_boundary_on,
      reading_boundary_off,
      'verified',
      'power_transitions_correlated',
      '2026-06-01 10:30:10+00'
    );

  if (
    select count(*)
    from private.operational_power_evaluations(
      'd5000000-0000-4000-8000-000000000001'
    )
  ) <> 6 then
    raise exception 'a função não retornou uma avaliação por aplicação';
  end if;

  if not exists (
    select 1
    from private.operational_power_evaluations(
      'd5000000-0000-4000-8000-000000000001'
    ) as evaluation
    where evaluation.application_id = app_equal
      and evaluation.operational_power_status = 'within_expected'
      and evaluation.power_profile_id
        = 'd7000000-0000-4000-8000-000000000001'
      and evaluation.reference_power_reading_id = reading_equal_on
      and evaluation.nominal_power_w_snapshot = 72
      and evaluation.minimum_acceptable_power_w_snapshot = 61.2
      and evaluation.observed_power_w_snapshot = 61.2
      and evaluation.operational_reason
        = 'reference_power_at_or_above_minimum'
  ) then
    raise exception 'a igualdade no mínimo não ficou dentro do esperado';
  end if;

  if not exists (
    select 1
    from private.operational_power_evaluations(
      'd5000000-0000-4000-8000-000000000001'
    ) as evaluation
    where evaluation.application_id = app_below
      and evaluation.operational_power_status = 'below_expected'
      and evaluation.observed_power_w_snapshot = 61.199
      and evaluation.minimum_acceptable_power_w_snapshot = 61.2
  ) then
    raise exception '61,199 W não ficou abaixo do mínimo de 61,2 W';
  end if;

  if not exists (
    select 1
    from private.operational_power_evaluations(
      'd5000000-0000-4000-8000-000000000001'
    ) as evaluation
    where evaluation.application_id = app_missing
      and evaluation.operational_power_status = 'not_evaluable'
      and evaluation.reference_power_reading_id is null
      and evaluation.observed_power_w_snapshot is null
      and evaluation.operational_reason
        = 'on_transition_not_found_within_tolerance'
  ) then
    raise exception 'a ausência da leitura ligada não preservou o motivo técnico';
  end if;

  if not exists (
    select 1
    from private.operational_power_evaluations(
      'd5000000-0000-4000-8000-000000000001'
    ) as evaluation
    where evaluation.application_id = app_below_threshold
      and evaluation.operational_power_status = 'not_evaluable'
      and evaluation.reference_power_reading_id is null
      and evaluation.operational_reason = 'power_on_reading_not_valid'
  ) then
    raise exception 'uma leitura abaixo do limite ligado foi promovida';
  end if;

  if not exists (
    select 1
    from private.operational_power_evaluations(
      'd5000000-0000-4000-8000-000000000001'
    ) as evaluation
    where evaluation.application_id = app_not_configured
      and evaluation.operational_power_status = 'not_configured'
      and evaluation.power_profile_id is null
      and evaluation.nominal_power_w_snapshot is null
      and evaluation.minimum_acceptable_power_w_snapshot is null
      and evaluation.reference_power_reading_id = reading_not_configured_on
      and evaluation.observed_power_w_snapshot = 10
  ) then
    raise exception 'a ausência de perfil não produziu not_configured';
  end if;

  if not exists (
    select 1
    from private.operational_power_evaluations(
      'd5000000-0000-4000-8000-000000000001'
    ) as evaluation
    where evaluation.application_id = app_boundary
      and evaluation.operational_power_status = 'within_expected'
      and evaluation.power_profile_id
        = 'd7000000-0000-4000-8000-000000000002'
      and evaluation.nominal_power_w_snapshot = 100
      and evaluation.minimum_acceptable_power_w_snapshot = 85
      and evaluation.observed_power_w_snapshot = 85
  ) then
    raise exception 'a fronteira da nova vigência não selecionou o perfil novo';
  end if;

  if (
    select evaluation.observed_power_w_snapshot
    from private.operational_power_evaluations(
      'd5000000-0000-4000-8000-000000000001'
    ) as evaluation
    where evaluation.application_id = app_equal
  ) <> 61.2 then
    raise exception 'a leitura desligada de 0 W participou da avaliação';
  end if;

  select jsonb_agg(to_jsonb(evaluation) order by evaluation.application_id)
  into before_snapshot
  from private.operational_power_evaluations(
    'd5000000-0000-4000-8000-000000000001'
  ) as evaluation;

  select jsonb_agg(to_jsonb(evaluation) order by evaluation.application_id)
  into after_snapshot
  from private.operational_power_evaluations(
    'd5000000-0000-4000-8000-000000000001'
  ) as evaluation;

  if before_snapshot is distinct from after_snapshot then
    raise exception 'a avaliação não é determinística para as mesmas fontes';
  end if;

  update public.application_power_verifications as verification
  set
    operational_power_status = evaluation.operational_power_status,
    power_profile_id = evaluation.power_profile_id,
    reference_power_reading_id = evaluation.reference_power_reading_id,
    nominal_power_w_snapshot = evaluation.nominal_power_w_snapshot,
    minimum_acceptable_power_w_snapshot
      = evaluation.minimum_acceptable_power_w_snapshot,
    observed_power_w_snapshot = evaluation.observed_power_w_snapshot,
    operational_reason = evaluation.operational_reason
  from private.operational_power_evaluations(
    'd5000000-0000-4000-8000-000000000001'
  ) as evaluation
  where verification.application_id = evaluation.application_id;

  if not exists (
    select 1
    from public.application_power_verifications as verification
    where verification.application_id = app_below
      and verification.status = 'missing_power_off'
      and verification.operational_power_status = 'below_expected'
      and verification.reference_power_reading_id = reading_below_on
  ) then
    raise exception 'a avaliação operacional sobrecarregou a correlação';
  end if;

  begin
    update public.application_power_verifications
    set operational_power_status = 'within_expected'
    where application_id = app_below;
    raise exception 'um resultado incompatível com os snapshots foi aceito';
  exception when check_violation then null;
  end;

  begin
    update public.application_power_verifications
    set power_profile_id = 'd7000000-0000-4000-8000-000000000003'
    where application_id = app_equal;
    raise exception 'um perfil de outro gerador foi aceito';
  exception when foreign_key_violation then null;
  end;

  begin
    update public.application_power_verifications
    set reference_power_reading_id = reading_equal_off
    where application_id = app_equal;
    raise exception 'uma leitura diferente da correlação foi usada como referência';
  exception when check_violation then null;
  end;

  begin
    insert into public.application_power_verifications (
      application_id,
      generator_id,
      controller_id,
      power_on_reading_id,
      power_off_reading_id,
      status,
      technical_reason,
      source_updated_at
    )
    values (
      app_equal,
      'd5000000-0000-4000-8000-000000000001',
      'd6000000-0000-4000-8000-000000000002',
      reading_equal_on,
      reading_equal_off,
      'verified',
      'power_transitions_correlated',
      '2026-01-10 10:30:10+00'
    );
    raise exception 'mais de uma avaliação foi aceita para a aplicação';
  exception when unique_violation then null;
  end;
end;
$$;

do $$
begin
  if has_function_privilege(
    'anon',
    'private.operational_power_evaluations(uuid)',
    'execute'
  ) or has_function_privilege(
    'authenticated',
    'private.operational_power_evaluations(uuid)',
    'execute'
  ) then
    raise exception 'a função técnica foi exposta pela Data API';
  end if;

  if (
    select count(*)
    from pg_catalog.pg_constraint as constraint_record
    where constraint_record.conrelid
      = 'public.application_power_verifications'::regclass
      and constraint_record.contype = 'p'
      and constraint_record.conkey = array[
        (
          select attribute.attnum
          from pg_catalog.pg_attribute as attribute
          where attribute.attrelid
            = 'public.application_power_verifications'::regclass
            and attribute.attname = 'application_id'
        )::smallint
      ]::smallint[]
  ) <> 1 then
    raise exception 'a unicidade da avaliação por aplicação não está garantida';
  end if;
end;
$$;

select extensions.pass('spec 12.2 operational power evaluation tests passed');
select * from extensions.finish();

rollback;
