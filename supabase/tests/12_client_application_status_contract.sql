begin;

select extensions.plan(1);

insert into public.clients (id, legal_name, cnpj)
values
  ('c8100000-0000-4000-8000-000000000001', 'Cliente Contrato A', '04252011000110'),
  ('c8100000-0000-4000-8000-000000000002', 'Cliente Contrato B', '11444777000161');

insert into auth.users (id)
values
  ('c8200000-0000-4000-8000-000000000001'),
  ('c8200000-0000-4000-8000-000000000002'),
  ('c8200000-0000-4000-8000-000000000003');

insert into public.profiles (id, client_id, full_name, role)
values
  ('c8200000-0000-4000-8000-000000000001', null, 'Master Contrato', 'master'),
  ('c8200000-0000-4000-8000-000000000002', 'c8100000-0000-4000-8000-000000000001', 'Leitor Contrato A', 'viewer'),
  ('c8200000-0000-4000-8000-000000000003', 'c8100000-0000-4000-8000-000000000002', 'Leitor Contrato B', 'viewer');

insert into public.locations (id, client_id, name, time_zone)
values
  ('c8300000-0000-4000-8000-000000000001', 'c8100000-0000-4000-8000-000000000001', 'Unidade Contrato A', 'America/Fortaleza'),
  ('c8300000-0000-4000-8000-000000000002', 'c8100000-0000-4000-8000-000000000002', 'Unidade Contrato B', 'America/Fortaleza');

insert into public.cold_rooms (id, client_id, location_id, name, category)
values
  ('c8400000-0000-4000-8000-000000000001', 'c8100000-0000-4000-8000-000000000001', 'c8300000-0000-4000-8000-000000000001', 'Câmara Contrato A', 'outros'),
  ('c8400000-0000-4000-8000-000000000002', 'c8100000-0000-4000-8000-000000000002', 'c8300000-0000-4000-8000-000000000002', 'Câmara Contrato B', 'outros');

insert into public.generators (id, client_id, identifier)
values
  ('c8500000-0000-4000-8000-000000000001', 'c8100000-0000-4000-8000-000000000001', 'Gerador Contrato A'),
  ('c8500000-0000-4000-8000-000000000002', 'c8100000-0000-4000-8000-000000000002', 'Gerador Contrato B');

insert into public.controllers (
  id, client_id, generator_id, identifier, activated_at, role
)
values (
  'c8600000-0000-4000-8000-000000000001',
  'c8100000-0000-4000-8000-000000000001',
  'c8500000-0000-4000-8000-000000000001',
  'Estado Contrato A',
  '2026-01-01 00:00:00+00',
  'state'
);

insert into public.controllers (
  id, client_id, generator_id, identifier, activated_at, role,
  external_device_id, power_on_threshold_w, power_off_threshold_w,
  correlation_tolerance_seconds
)
values (
  'c8600000-0000-4000-8000-000000000002',
  'c8100000-0000-4000-8000-000000000001',
  'c8500000-0000-4000-8000-000000000001',
  'Potência Contrato A',
  '2026-01-01 00:00:00+00',
  'power_telemetry',
  'device-contract-a',
  5,
  1,
  120
);

insert into public.generator_power_profiles (
  id, generator_id, nominal_power_w, valid_from, created_by
)
values (
  'c8700000-0000-4000-8000-000000000001',
  'c8500000-0000-4000-8000-000000000001',
  100,
  '2026-01-01 00:00:00+00',
  'c8200000-0000-4000-8000-000000000001'
);

insert into public.import_batches (
  id, client_id, location_id, cold_room_id, generator_id, controller_id,
  data_kind, file_name, file_sha256, status, total_rows, inserted_rows,
  period_start, period_end, created_by, confirmed_at
)
values
  (
    'c8800000-0000-4000-8000-000000000001',
    'c8100000-0000-4000-8000-000000000001',
    'c8300000-0000-4000-8000-000000000001',
    'c8400000-0000-4000-8000-000000000001',
    'c8500000-0000-4000-8000-000000000001',
    'c8600000-0000-4000-8000-000000000001',
    'state_events',
    'estado-contrato.xlsx',
    repeat('8', 64),
    'confirmed',
    10,
    10,
    '2026-09-01 10:00:00+00',
    '2026-09-04 10:30:00+00',
    'c8200000-0000-4000-8000-000000000001',
    '2026-09-04 11:00:00+00'
  ),
  (
    'c8800000-0000-4000-8000-000000000002',
    'c8100000-0000-4000-8000-000000000001',
    'c8300000-0000-4000-8000-000000000001',
    'c8400000-0000-4000-8000-000000000001',
    'c8500000-0000-4000-8000-000000000001',
    'c8600000-0000-4000-8000-000000000002',
    'power_readings',
    'potencia-contrato.xlsx',
    repeat('9', 64),
    'confirmed',
    3,
    3,
    '2026-09-01 10:00:10+00',
    '2026-09-02 10:00:10+00',
    'c8200000-0000-4000-8000-000000000001',
    '2026-09-04 11:00:00+00'
  );

insert into public.raw_events (
  import_batch_id, generator_id, controller_id, occurred_at, occurred_at_raw,
  operation, operation_raw, source_original, source_normalized,
  source_classification, fingerprint
)
select
  'c8800000-0000-4000-8000-000000000001',
  'c8500000-0000-4000-8000-000000000001',
  'c8600000-0000-4000-8000-000000000001',
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
    ('2026-09-01 10:00:00+00'::timestamptz, 'turn_on', '8101'),
    ('2026-09-01 10:30:00+00'::timestamptz, 'turn_off', '8102'),
    ('2026-09-01 12:00:00+00'::timestamptz, 'turn_on', '8103'),
    ('2026-09-01 12:30:00+00'::timestamptz, 'turn_off', '8104'),
    ('2026-09-02 10:00:00+00'::timestamptz, 'turn_on', '8105'),
    ('2026-09-02 10:30:00+00'::timestamptz, 'turn_off', '8106'),
    ('2026-09-03 10:00:00+00'::timestamptz, 'turn_on', '8107'),
    ('2026-09-03 10:30:00+00'::timestamptz, 'turn_off', '8108'),
    ('2026-09-04 10:00:00+00'::timestamptz, 'turn_on', '8109'),
    ('2026-09-04 10:30:00+00'::timestamptz, 'turn_off', '8110')
) as source(occurred_at, operation, fingerprint_seed);

insert into public.applications (
  generator_id, controller_id, start_event_id, end_event_id, public_date
)
select
  'c8500000-0000-4000-8000-000000000001',
  'c8600000-0000-4000-8000-000000000001',
  start_event.id,
  end_event.id,
  (period.start_at at time zone 'America/Fortaleza')::date
from (
  values
    ('2026-09-01 10:00:00+00'::timestamptz, '2026-09-01 10:30:00+00'::timestamptz),
    ('2026-09-01 12:00:00+00'::timestamptz, '2026-09-01 12:30:00+00'::timestamptz),
    ('2026-09-02 10:00:00+00'::timestamptz, '2026-09-02 10:30:00+00'::timestamptz),
    ('2026-09-03 10:00:00+00'::timestamptz, '2026-09-03 10:30:00+00'::timestamptz),
    ('2026-09-04 10:00:00+00'::timestamptz, '2026-09-04 10:30:00+00'::timestamptz)
) as period(start_at, end_at)
join public.raw_events as start_event
  on start_event.occurred_at = period.start_at
join public.raw_events as end_event
  on end_event.occurred_at = period.end_at;

insert into public.power_readings (
  import_batch_id, client_id, location_id, cold_room_id, generator_id,
  controller_id, occurred_at, occurred_at_raw, power_w, power_raw,
  device_name, device_id, device_id_normalized, event_type, event_name,
  event_detail, request_from, source_detail, fingerprint
)
select
  'c8800000-0000-4000-8000-000000000002',
  'c8100000-0000-4000-8000-000000000001',
  'c8300000-0000-4000-8000-000000000001',
  'c8400000-0000-4000-8000-000000000001',
  'c8500000-0000-4000-8000-000000000001',
  'c8600000-0000-4000-8000-000000000002',
  source.occurred_at,
  source.occurred_at::text,
  source.power_w,
  source.power_w::text || 'W',
  'Medidor Contrato',
  'device-contract-a',
  'device-contract-a',
  'Report',
  'Power',
  source.power_w::text || 'W',
  'Device',
  '',
  lpad(source.fingerprint_seed, 64, '0')
from (
  values
    ('2026-09-01 10:00:10+00'::timestamptz, 84.000::numeric, '8201'),
    ('2026-09-01 10:10:00+00'::timestamptz, 70.000::numeric, '8206'),
    ('2026-09-01 10:20:00+00'::timestamptz, 96.000::numeric, '8207'),
    ('2026-09-01 12:00:10+00'::timestamptz, 80.000::numeric, '8202'),
    ('2026-09-02 10:00:10+00'::timestamptz, 85.000::numeric, '8203')
) as source(occurred_at, power_w, fingerprint_seed);

insert into public.application_power_verifications (
  application_id, generator_id, controller_id, power_on_reading_id,
  status, technical_reason, source_updated_at, operational_power_status,
  power_profile_id, reference_power_reading_id, nominal_power_w_snapshot,
  minimum_acceptable_power_w_snapshot, observed_power_w_snapshot,
  operational_reason
)
select
  application.id,
  application.generator_id,
  'c8600000-0000-4000-8000-000000000002',
  reading.id,
  'missing_power_off',
  'off_transition_not_found_within_tolerance',
  reading.occurred_at,
  case when application.public_date = '2026-09-02' then 'within_expected' else 'below_expected' end,
  'c8700000-0000-4000-8000-000000000001',
  reading.id,
  100,
  85,
  reading.power_w,
  case when application.public_date = '2026-09-02'
    then 'reference_power_at_or_above_minimum'
    else 'reference_power_below_minimum'
  end
from public.applications as application
join public.raw_events as start_event on start_event.id = application.start_event_id
join public.power_readings as reading
  on reading.occurred_at = start_event.occurred_at + interval '10 seconds'
where application.public_date in ('2026-09-01', '2026-09-02');

insert into public.application_power_verifications (
  application_id, generator_id, controller_id, status, technical_reason,
  source_updated_at, operational_power_status, power_profile_id,
  nominal_power_w_snapshot, minimum_acceptable_power_w_snapshot,
  operational_reason
)
select
  application.id,
  application.generator_id,
  'c8600000-0000-4000-8000-000000000002',
  'missing_power_on',
  'on_transition_not_found_within_tolerance',
  '2026-09-03 10:30:00+00',
  'not_evaluable',
  'c8700000-0000-4000-8000-000000000001',
  100,
  85,
  'on_transition_not_found_within_tolerance'
from public.applications as application
where application.public_date = '2026-09-03';

insert into public.application_power_verifications (
  application_id, generator_id, status, technical_reason,
  source_updated_at, operational_power_status, operational_reason
)
select
  application.id,
  application.generator_id,
  'no_coverage',
  'power_coverage_not_available',
  '2026-09-04 10:30:00+00',
  'not_configured',
  'nominal_power_profile_not_configured'
from public.applications as application
where application.public_date = '2026-09-04';

insert into public.client_daily_status (
  client_id, location_id, cold_room_id, generator_id, status_date, status
)
values
  ('c8100000-0000-4000-8000-000000000001', 'c8300000-0000-4000-8000-000000000001', 'c8400000-0000-4000-8000-000000000001', 'c8500000-0000-4000-8000-000000000001', '2026-09-01', 'completed'),
  ('c8100000-0000-4000-8000-000000000001', 'c8300000-0000-4000-8000-000000000001', 'c8400000-0000-4000-8000-000000000001', 'c8500000-0000-4000-8000-000000000001', '2026-09-02', 'completed'),
  ('c8100000-0000-4000-8000-000000000001', 'c8300000-0000-4000-8000-000000000001', 'c8400000-0000-4000-8000-000000000001', 'c8500000-0000-4000-8000-000000000001', '2026-09-03', 'completed'),
  ('c8100000-0000-4000-8000-000000000001', 'c8300000-0000-4000-8000-000000000001', 'c8400000-0000-4000-8000-000000000001', 'c8500000-0000-4000-8000-000000000001', '2026-09-04', 'completed'),
  ('c8100000-0000-4000-8000-000000000001', 'c8300000-0000-4000-8000-000000000001', 'c8400000-0000-4000-8000-000000000001', 'c8500000-0000-4000-8000-000000000001', '2026-09-05', 'verification_required'),
  ('c8100000-0000-4000-8000-000000000001', 'c8300000-0000-4000-8000-000000000001', 'c8400000-0000-4000-8000-000000000001', 'c8500000-0000-4000-8000-000000000001', '2026-09-06', 'no_data'),
  ('c8100000-0000-4000-8000-000000000001', 'c8300000-0000-4000-8000-000000000001', 'c8400000-0000-4000-8000-000000000001', 'c8500000-0000-4000-8000-000000000001', '2026-09-07', 'awaiting_update'),
  ('c8100000-0000-4000-8000-000000000002', 'c8300000-0000-4000-8000-000000000002', 'c8400000-0000-4000-8000-000000000002', 'c8500000-0000-4000-8000-000000000002', '2026-09-01', 'completed');

do $$
declare
  output_columns text[];
  public_function regprocedure := 'public.list_client_application_status(date,date,uuid,uuid,uuid,integer)'::regprocedure;
begin
  select array_agg(argument.name order by argument.ordinality)
  into output_columns
  from pg_catalog.pg_proc as procedure
  join pg_catalog.pg_namespace as namespace on namespace.oid = procedure.pronamespace
  cross join lateral unnest(procedure.proargnames, procedure.proargmodes)
    with ordinality as argument(name, mode, ordinality)
  where namespace.nspname = 'public'
    and procedure.proname = 'list_client_application_status'
    and argument.mode = 't';

  if output_columns is distinct from array[
    'client_id', 'location_id', 'cold_room_id', 'generator_id',
    'status_date', 'application_status', 'attention_status'
  ]::text[] then
    raise exception 'contrato público contém colunas inesperadas: %', output_columns;
  end if;

  if has_function_privilege('anon', public_function, 'execute')
    or not has_function_privilege('authenticated', public_function, 'execute')
    or (select prosecdef from pg_catalog.pg_proc where oid = public_function)
    or not (select proconfig @> array['search_path=""'] from pg_catalog.pg_proc where oid = public_function)
    or has_table_privilege('anon', 'public.client_daily_status', 'select')
    or not has_table_privilege('authenticated', 'public.client_daily_status', 'select') then
    raise exception 'permissões do contrato novo ou da ponte antiga estão incorretas';
  end if;
end;
$$;

set local role anon;
do $$
begin
  begin
    perform public.list_client_application_status();
    raise exception 'anon consultou o contrato sanitizado';
  exception when insufficient_privilege then null;
  end;
end;
$$;
reset role;

set local role authenticated;
set local request.jwt.claim.sub = 'c8200000-0000-4000-8000-000000000002';

do $$
begin
  if exists (select power_evidence_status from public.client_daily_status) then
    raise exception 'cliente ainda acessa o contrato antigo';
  end if;
end;
$$;

do $$
begin
  if (select count(*) from public.list_client_application_status()) <> 7
    or exists (
      select 1 from public.list_client_application_status()
      where client_id <> 'c8100000-0000-4000-8000-000000000001'
    ) then
    raise exception 'cliente A acessou outra conta ou perdeu o próprio histórico';
  end if;

  if (select count(*) from public.list_client_application_status()
      where status_date = '2026-09-01' and attention_status = 'attention') <> 1
    or exists (
      select 1 from public.list_client_application_status()
      where status_date in ('2026-09-02', '2026-09-03', '2026-09-04')
        and attention_status <> 'none'
    ) then
    raise exception 'agregação ou mapeamento qualitativo incorreto';
  end if;

  if exists (
    select 1 from public.list_client_application_status()
    where (status_date <= '2026-09-04' and application_status <> 'registered')
      or (status_date = '2026-09-05' and application_status <> 'verification_required')
      or (status_date = '2026-09-06' and application_status <> 'no_data')
      or (status_date = '2026-09-07' and application_status <> 'awaiting_update')
  ) then
    raise exception 'estado público de aplicação incorreto';
  end if;

  if exists (
    select 1
    from public.list_client_application_status(
      p_generator_id => 'c8500000-0000-4000-8000-000000000002'
    )
  ) then
    raise exception 'filtro permitiu inferir dados do cliente B';
  end if;

  if (select count(*) from public.list_client_application_details()) <> 5
    or not exists (
      select 1
      from public.list_client_application_details()
      where status_date = '2026-09-01'
        and application_started_at = '07:00:00'::time
        and application_ended_at = '07:30:00'::time
        and max_measured_power_w = 96
        and attention_status = 'attention'
    ) then
    raise exception 'a agenda não retornou horário local e maior potência do intervalo';
  end if;
end;
$$;

set local request.jwt.claim.sub = 'c8200000-0000-4000-8000-000000000003';
do $$
begin
  if (select count(*) from public.list_client_application_status()) <> 1
    or not exists (
      select 1 from public.list_client_application_status()
      where client_id = 'c8100000-0000-4000-8000-000000000002'
        and application_status = 'registered'
        and attention_status = 'none'
    ) then
    raise exception 'cliente B não recebeu somente seu próprio estado';
  end if;
end;
$$;

set local request.jwt.claim.sub = 'c8200000-0000-4000-8000-000000000001';
do $$
begin
  if (select count(*) from public.list_client_application_status()) <> 8
    or (select count(distinct client_id) from public.list_client_application_status()) <> 2
    or (select count(*) from public.list_client_application_status(
      p_start_date => '2026-09-02',
      p_end_date => '2026-09-04',
      p_location_id => 'c8300000-0000-4000-8000-000000000001',
      p_cold_room_id => 'c8400000-0000-4000-8000-000000000001',
      p_generator_id => 'c8500000-0000-4000-8000-000000000001'
    )) <> 3 then
    raise exception 'Master ou filtros não receberam o escopo correto';
  end if;
end;
$$;
reset role;

select extensions.pass(
  '12.8 sanitized contract, daily attention, catalog and account isolation'
);
select * from extensions.finish();

rollback;
