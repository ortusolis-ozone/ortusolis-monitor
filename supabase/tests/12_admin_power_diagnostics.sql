begin;

select extensions.plan(1);

insert into public.clients (id, legal_name, cnpj)
values (
  'e1000000-0000-4000-8000-000000000001',
  'Cliente Reprocessamento',
  '04252011000110'
);

insert into auth.users (id)
values ('e2000000-0000-4000-8000-000000000001');

insert into public.profiles (id, client_id, full_name, role)
values (
  'e2000000-0000-4000-8000-000000000001',
  null,
  'Master Reprocessamento',
  'master'
);

insert into public.locations (id, client_id, name, time_zone)
values (
  'e3000000-0000-4000-8000-000000000001',
  'e1000000-0000-4000-8000-000000000001',
  'Unidade Reprocessamento',
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
  'e4000000-0000-4000-8000-000000000001',
  'e1000000-0000-4000-8000-000000000001',
  'e3000000-0000-4000-8000-000000000001',
  'Câmara Reprocessamento',
  'outros'
);

insert into public.generators (id, client_id, identifier)
values (
  'e5000000-0000-4000-8000-000000000001',
  'e1000000-0000-4000-8000-000000000001',
  'Gerador Reprocessamento'
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
  'e6000000-0000-4000-8000-000000000001',
  'e1000000-0000-4000-8000-000000000001',
  'e5000000-0000-4000-8000-000000000001',
  'Estado Reprocessamento',
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
  'e6000000-0000-4000-8000-000000000002',
  'e1000000-0000-4000-8000-000000000001',
  'e5000000-0000-4000-8000-000000000001',
  'Potência Reprocessamento',
  '2025-01-01 00:00:00+00',
  'power_telemetry',
  'device-reprocessing',
  5,
  1,
  120
);

insert into public.source_mappings (
  normalized_source,
  classification,
  created_by
)
values (
  'agendamento',
  'programmed',
  'e2000000-0000-4000-8000-000000000001'
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
    'e8000000-0000-4000-8000-000000000001',
    'e1000000-0000-4000-8000-000000000001',
    'e3000000-0000-4000-8000-000000000001',
    'e4000000-0000-4000-8000-000000000001',
    'e5000000-0000-4000-8000-000000000001',
    'e6000000-0000-4000-8000-000000000001',
    'state_events',
    'estado-reprocessamento.xlsx',
    repeat('1', 64),
    'confirmed',
    8,
    8,
    '2026-01-10 10:00:00+00',
    '2026-07-12 10:30:00+00',
    'e2000000-0000-4000-8000-000000000001',
    '2026-07-12 11:00:00+00'
  ),
  (
    'e8000000-0000-4000-8000-000000000002',
    'e1000000-0000-4000-8000-000000000001',
    'e3000000-0000-4000-8000-000000000001',
    'e4000000-0000-4000-8000-000000000001',
    'e5000000-0000-4000-8000-000000000001',
    'e6000000-0000-4000-8000-000000000002',
    'power_readings',
    'potencia-reprocessamento.xlsx',
    repeat('2', 64),
    'confirmed',
    6,
    6,
    '2026-01-10 10:00:10+00',
    '2026-07-12 10:30:10+00',
    'e2000000-0000-4000-8000-000000000001',
    '2026-07-12 11:00:00+00'
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
  'e8000000-0000-4000-8000-000000000001',
  'e5000000-0000-4000-8000-000000000001',
  'e6000000-0000-4000-8000-000000000001',
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
    ('2026-01-10 10:00:00+00'::timestamptz, 'turn_on', '301'),
    ('2026-01-10 10:30:00+00'::timestamptz, 'turn_off', '302'),
    ('2026-07-10 10:00:00+00'::timestamptz, 'turn_on', '303'),
    ('2026-07-10 10:30:00+00'::timestamptz, 'turn_off', '304'),
    ('2026-07-11 10:00:00+00'::timestamptz, 'turn_on', '305'),
    ('2026-07-11 10:30:00+00'::timestamptz, 'turn_off', '306'),
    ('2026-07-12 10:00:00+00'::timestamptz, 'turn_on', '307'),
    ('2026-07-12 10:30:00+00'::timestamptz, 'turn_off', '308')
) as source(occurred_at, operation, fingerprint_seed);

insert into public.applications (
  generator_id,
  controller_id,
  start_event_id,
  end_event_id,
  public_date
)
select
  'e5000000-0000-4000-8000-000000000001',
  'e6000000-0000-4000-8000-000000000001',
  start_event.id,
  end_event.id,
  (period.start_at at time zone 'America/Fortaleza')::date
from (
  values
    (
      '2026-01-10 10:00:00+00'::timestamptz,
      '2026-01-10 10:30:00+00'::timestamptz
    ),
    (
      '2026-07-10 10:00:00+00'::timestamptz,
      '2026-07-10 10:30:00+00'::timestamptz
    ),
    (
      '2026-07-11 10:00:00+00'::timestamptz,
      '2026-07-11 10:30:00+00'::timestamptz
    ),
    (
      '2026-07-12 10:00:00+00'::timestamptz,
      '2026-07-12 10:30:00+00'::timestamptz
    )
) as period(start_at, end_at)
join public.raw_events as start_event
  on start_event.generator_id = 'e5000000-0000-4000-8000-000000000001'
  and start_event.occurred_at = period.start_at
join public.raw_events as end_event
  on end_event.generator_id = 'e5000000-0000-4000-8000-000000000001'
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
  'e8000000-0000-4000-8000-000000000002',
  'e1000000-0000-4000-8000-000000000001',
  'e3000000-0000-4000-8000-000000000001',
  'e4000000-0000-4000-8000-000000000001',
  'e5000000-0000-4000-8000-000000000001',
  'e6000000-0000-4000-8000-000000000002',
  source.occurred_at,
  source.occurred_at::text,
  source.power_w,
  source.power_w::text || 'W',
  'Medidor Reprocessamento',
  'device-reprocessing',
  'device-reprocessing',
  'Report',
  'Power',
  source.power_w::text || 'W',
  'Device',
  '',
  lpad(source.fingerprint_seed, 64, '0')
from (
  values
    ('2026-01-10 10:00:10+00'::timestamptz, 61.199::numeric, '401'),
    ('2026-01-10 10:30:10+00'::timestamptz, 0.000::numeric, '402'),
    ('2026-07-10 10:00:10+00'::timestamptz, 70.000::numeric, '403'),
    ('2026-07-10 10:30:10+00'::timestamptz, 0.000::numeric, '404'),
    ('2026-07-11 10:00:10+00'::timestamptz, 90.000::numeric, '405'),
    ('2026-07-11 10:30:10+00'::timestamptz, 0.000::numeric, '406')
) as source(occurred_at, power_w, fingerprint_seed);

insert into public.client_daily_status (
  client_id,
  location_id,
  cold_room_id,
  generator_id,
  status_date,
  status
)
select
  'e1000000-0000-4000-8000-000000000001',
  'e3000000-0000-4000-8000-000000000001',
  'e4000000-0000-4000-8000-000000000001',
  'e5000000-0000-4000-8000-000000000001',
  status_date,
  'completed'
from unnest(array[
  '2026-01-10'::date,
  '2026-07-10'::date,
  '2026-07-11'::date,
  '2026-07-12'::date
]) as status_date;

insert into public.generator_power_profiles (
  id,
  generator_id,
  nominal_power_w,
  valid_from,
  valid_until,
  created_by
)
values (
  'e7000000-0000-4000-8000-000000000001',
  'e5000000-0000-4000-8000-000000000001',
  72.000,
  '2026-01-01 00:00:00+00',
  null,
  'e2000000-0000-4000-8000-000000000001'
);


update public.generator_power_profiles set valid_until = '2026-07-11T10:00:00Z';
insert into public.generator_power_profiles(generator_id, nominal_power_w, valid_from, created_by)
values('e5000000-0000-4000-8000-000000000001', 72, '2026-07-12T00:00:00Z', 'e2000000-0000-4000-8000-000000000001');
select private.reprocess_power_telemetry('e5000000-0000-4000-8000-000000000001');
set local role authenticated;
set local request.jwt.claim.sub = 'e2000000-0000-4000-8000-000000000001';
do $$
declare d record; before_review jsonb; after_review jsonb; issue_id bigint; run_count bigint;
begin
  if (select count(distinct operational_status) from public.list_admin_application_power_diagnostics('e5000000-0000-4000-8000-000000000001')) <> 4 then
    raise exception 'diagnostic does not expose four distinct states';
  end if;
  select * into strict d from public.list_admin_application_power_diagnostics('e5000000-0000-4000-8000-000000000001') where operational_status = 'below_expected';
  if d.correlation_status <> 'verified' or d.nominal_power_w::numeric <> 72
    or d.minimum_power_w::numeric <> 61.2 or d.observed_power_w::numeric <> 61.199
    or d.difference_w::numeric <> 10.801 or d.difference_percent::numeric <> -15.001
    or d.reference_reading_id is null or d.reference_reading_at <> '2026-01-10T10:00:10Z'
    or d.power_controller_identifier <> 'Potência Reprocessamento'
    or d.power_batch_id <> 'e8000000-0000-4000-8000-000000000002'
    or d.power_file_name is null or d.state_file_name is null or d.end_file_name is null
    or d.power_profile_id <> 'e7000000-0000-4000-8000-000000000001'
    or d.profile_valid_from <> '2026-01-01T00:00:00Z'
    or d.rule_version <> 'nominal-power-v1' then
    raise exception 'incomplete or incorrect diagnosis: %', to_jsonb(d);
  end if;
  select to_jsonb(x) into before_review from public.list_admin_application_power_diagnostics(null,d.application_id) x;
  select id into strict issue_id from public.list_admin_application_power_inconsistencies(d.application_id) where type = 'power_below_expected';
  if not public.review_inconsistency(issue_id, 'Conferir equipamento e coleta') then
    raise exception 'review failed';
  end if;
  select to_jsonb(x) into after_review from public.list_admin_application_power_diagnostics(null,d.application_id) x;
  if after_review is distinct from before_review then raise exception 'review changed operational diagnosis'; end if;
  if not exists(select 1 from public.list_admin_application_power_inconsistencies(d.application_id) where status = 'reviewed' and review_note = 'Conferir equipamento e coleta' and reviewed_by_name is not null) then
    raise exception 'review history missing';
  end if;
  if not public.reopen_inconsistency(issue_id) then raise exception 'reopen failed'; end if;
  select to_jsonb(x) into after_review from public.list_admin_application_power_diagnostics(null,d.application_id) x;
  if after_review is distinct from before_review then raise exception 'reopen changed operational diagnosis'; end if;
  perform public.review_inconsistency(issue_id, 'Acompanhamento preservado');
  select count(*) into run_count from public.list_admin_application_power_runs(d.application_id);
  if run_count = 0 or exists(select 1 from public.list_admin_application_power_runs(d.application_id) where affected_from > d.start_at or affected_until <= d.start_at) then
    raise exception 'reprocessing history missing or unrelated';
  end if;
  if exists(select 1 from public.list_admin_application_power_diagnostics('e5000000-0000-4000-8000-000000000001', null, 50)) then raise exception 'pagination ignored'; end if;
  if exists(select 1 from public.list_admin_application_power_diagnostics(null, -1)) then raise exception 'nonexistent application returned data'; end if;
  if exists(select 1 from public.list_admin_application_power_diagnostics('e5000000-0000-4000-8000-000000000001') where (operational_status = 'not_evaluable' and observed_power_w is not null) or (operational_status in ('not_configured','not_evaluable') and (difference_w is not null or difference_percent is not null))) then raise exception 'missing reference fabricated values'; end if;
end;
$$;
reset role;
-- Resolution retains the administrative note and is visible through diagnostics.
update public.generator_power_profiles set nominal_power_w = 60 where id = 'e7000000-0000-4000-8000-000000000001';
set local role authenticated;
do $$
declare d record;
begin
  select * into strict d from public.list_admin_application_power_diagnostics('e5000000-0000-4000-8000-000000000001') where start_at = '2026-01-10T10:00:00Z';
  if d.operational_status <> 'within_expected' or not exists(select 1 from public.list_admin_application_power_inconsistencies(d.application_id) where status = 'resolved' and review_note = 'Acompanhamento preservado' and resolved_at is not null) then raise exception 'resolved history lost'; end if;
end;
$$;
reset role;
insert into auth.users(id) values('e2000000-0000-4000-8000-000000000002');
insert into public.profiles(id,client_id,full_name,role) values('e2000000-0000-4000-8000-000000000002','e1000000-0000-4000-8000-000000000001','Cliente Diagnóstico','viewer');
set local role authenticated;
set local request.jwt.claim.sub = 'e2000000-0000-4000-8000-000000000002';
do $$
begin
  begin
    perform public.list_admin_application_power_diagnostics('e5000000-0000-4000-8000-000000000001');
    raise exception 'viewer read technical values';
  exception when insufficient_privilege then null; end;
  begin
    perform public.list_admin_application_power_inconsistencies(1);
    raise exception 'viewer read review history';
  exception when insufficient_privilege then null; end;
  begin
    perform public.list_admin_application_power_runs(1);
    raise exception 'viewer read reprocessing history';
  exception when insufficient_privilege then null; end;
end;
$$;
reset role;
do $$
begin
  if has_function_privilege('anon','public.list_admin_application_power_diagnostics(uuid,bigint,integer)','execute')
    or has_function_privilege('anon','public.list_admin_application_power_inconsistencies(bigint)','execute')
    or has_function_privilege('anon','public.list_admin_application_power_runs(bigint,integer)','execute')
    or has_table_privilege('authenticated','private.operational_power_reprocessing_runs','select') then raise exception 'technical privilege leak'; end if;
end;
$$;
select extensions.pass('12.7 Master diagnosis, exact snapshots, four states, review independence, history and access control');
select * from extensions.finish();
rollback;
