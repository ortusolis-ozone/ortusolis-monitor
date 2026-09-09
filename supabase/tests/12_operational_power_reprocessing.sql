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

do $$
declare
  application_before_boundary bigint;
  initial_inconsistency_id bigint;
  repeated_inconsistency_id bigint;
  verification_snapshot jsonb;
begin
  perform private.reprocess_power_telemetry(
    'e5000000-0000-4000-8000-000000000001'
  );

  if (
    select count(*) filter (
      where verification.operational_power_status = 'within_expected'
    )
    from public.application_power_verifications as verification
    where verification.generator_id
      = 'e5000000-0000-4000-8000-000000000001'
  ) <> 2 or (
    select count(*) filter (
      where verification.operational_power_status = 'below_expected'
    )
    from public.application_power_verifications as verification
    where verification.generator_id
      = 'e5000000-0000-4000-8000-000000000001'
  ) <> 1 or (
    select count(*) filter (
      where verification.operational_power_status = 'not_evaluable'
    )
    from public.application_power_verifications as verification
    where verification.generator_id
      = 'e5000000-0000-4000-8000-000000000001'
  ) <> 1 then
    raise exception 'o reprocessamento não persistiu os quatro resultados esperados';
  end if;

  if exists (
    select 1
    from public.application_power_verifications as verification
    where verification.generator_id
      = 'e5000000-0000-4000-8000-000000000001'
      and verification.operational_rule_version <> 'nominal-power-v1'
  ) then
    raise exception 'a versão da regra não foi persistida nas avaliações';
  end if;

  select inconsistency.id
  into strict initial_inconsistency_id
  from public.inconsistencies as inconsistency
  join public.applications as application
    on application.id = inconsistency.application_id
  join public.raw_events as start_event
    on start_event.id = application.start_event_id
  where inconsistency.type = 'power_below_expected'
    and start_event.occurred_at = '2026-01-10 10:00:00+00'
    and inconsistency.status = 'pending'
    and inconsistency.power_reading_id is not null
    and inconsistency.power_profile_id
      = 'e7000000-0000-4000-8000-000000000001';

  if (
    select daily_status.status
    from public.client_daily_status as daily_status
    where daily_status.generator_id
      = 'e5000000-0000-4000-8000-000000000001'
      and daily_status.status_date = '2026-01-10'
  ) <> 'completed' then
    raise exception 'a potência baixa alterou o estado principal do dia';
  end if;

  if not exists (
    select 1
    from private.operational_power_reprocessing_runs as run
    where run.generator_id = 'e5000000-0000-4000-8000-000000000001'
      and run.reason = 'power_telemetry_reprocess'
      and run.rule_version = 'nominal-power-v1'
      and run.within_expected_count = 2
      and run.below_expected_count = 1
      and run.not_evaluable_count = 1
      and run.not_configured_count = 0
    order by run.id desc
    limit 1
  ) then
    raise exception 'o resumo do reprocessamento não registrou versão e contagens';
  end if;

  select to_jsonb(verification)
  into strict verification_snapshot
  from public.application_power_verifications as verification
  join public.applications as application
    on application.id = verification.application_id
  join public.raw_events as start_event
    on start_event.id = application.start_event_id
  where start_event.occurred_at = '2026-01-10 10:00:00+00';

  perform private.reprocess_power_telemetry(
    'e5000000-0000-4000-8000-000000000001'
  );

  select inconsistency.id
  into strict repeated_inconsistency_id
  from public.inconsistencies as inconsistency
  where inconsistency.type = 'power_below_expected'
    and inconsistency.id = initial_inconsistency_id;

  if repeated_inconsistency_id <> initial_inconsistency_id
    or (
      select count(*)
      from public.inconsistencies as inconsistency
      where inconsistency.type = 'power_below_expected'
    ) <> 1 then
    raise exception 'o reprocessamento repetido duplicou a inconsistência';
  end if;

  if (
    select to_jsonb(verification)
    from public.application_power_verifications as verification
    join public.applications as application
      on application.id = verification.application_id
    join public.raw_events as start_event
      on start_event.id = application.start_event_id
    where start_event.occurred_at = '2026-01-10 10:00:00+00'
  ) is distinct from verification_snapshot then
    raise exception 'o reprocessamento idempotente alterou a avaliação';
  end if;

  select application.id
  into strict application_before_boundary
  from public.applications as application
  join public.raw_events as start_event
    on start_event.id = application.start_event_id
  where start_event.occurred_at = '2026-01-10 10:00:00+00';

  if application_before_boundary is null then
    raise exception 'a aplicação histórica não foi localizada';
  end if;
end;
$$;

set local role authenticated;
set local request.jwt.claim.sub = 'e2000000-0000-4000-8000-000000000001';

do $$
declare
  target_inconsistency_id bigint;
begin
  select inconsistency.id
  into strict target_inconsistency_id
  from public.inconsistencies as inconsistency
  where inconsistency.type = 'power_below_expected';

  if not public.review_inconsistency(
    target_inconsistency_id,
    'Equipamento conferido pelo Master'
  ) then
    raise exception 'o reconhecimento administrativo falhou';
  end if;
end;
$$;

reset role;

update public.generator_power_profiles
set nominal_power_w = 60.000
where id = 'e7000000-0000-4000-8000-000000000001';

do $$
begin
  if not exists (
    select 1
    from public.inconsistencies as inconsistency
    where inconsistency.type = 'power_below_expected'
      and inconsistency.status = 'resolved'
      and inconsistency.resolved_at is not null
      and inconsistency.review_note = 'Equipamento conferido pelo Master'
      and inconsistency.reviewed_by
        = 'e2000000-0000-4000-8000-000000000001'
      and inconsistency.reviewed_at is not null
  ) then
    raise exception 'a resolução apagou o reconhecimento administrativo';
  end if;

  if not exists (
    select 1
    from public.application_power_verifications as verification
    join public.applications as application
      on application.id = verification.application_id
    join public.raw_events as start_event
      on start_event.id = application.start_event_id
    where start_event.occurred_at = '2026-01-10 10:00:00+00'
      and verification.operational_power_status = 'within_expected'
      and verification.nominal_power_w_snapshot = 60
  ) then
    raise exception 'a correção do perfil não resolveu a avaliação baixa';
  end if;
end;
$$;

update public.generator_power_profiles
set nominal_power_w = 72.000
where id = 'e7000000-0000-4000-8000-000000000001';

do $$
begin
  if (
    select count(*)
    from public.inconsistencies as inconsistency
    where inconsistency.type = 'power_below_expected'
  ) <> 1 or not exists (
    select 1
    from public.inconsistencies as inconsistency
    where inconsistency.type = 'power_below_expected'
      and inconsistency.status = 'reviewed'
      and inconsistency.resolved_at is null
      and inconsistency.review_note = 'Equipamento conferido pelo Master'
      and inconsistency.reviewed_by
        = 'e2000000-0000-4000-8000-000000000001'
  ) then
    raise exception 'o retorno da condição baixa perdeu o histórico ou duplicou';
  end if;
end;
$$;

update public.generator_power_profiles
set valid_until = '2026-07-01 00:00:00+00'
where id = 'e7000000-0000-4000-8000-000000000001';

do $$
begin
  if not exists (
    select 1
    from public.application_power_verifications as verification
    join public.applications as application
      on application.id = verification.application_id
    join public.raw_events as start_event
      on start_event.id = application.start_event_id
    where start_event.occurred_at = '2026-01-10 10:00:00+00'
      and verification.power_profile_id
        = 'e7000000-0000-4000-8000-000000000001'
      and verification.nominal_power_w_snapshot = 72
      and verification.operational_power_status = 'below_expected'
  ) then
    raise exception 'a mudança de vigência reprocessou o histórico anterior';
  end if;

  if not exists (
    select 1
    from private.operational_power_reprocessing_runs as run
    where run.reason = 'power_profile_valid_until_changed'
      and run.affected_from = '2026-07-01 00:00:00+00'
      and run.affected_until is null
      and (
        run.within_expected_count
        + run.below_expected_count
        + run.not_evaluable_count
        + run.not_configured_count
      ) = 3
    order by run.id desc
    limit 1
  ) then
    raise exception 'a mudança de vigência não respeitou o intervalo afetado';
  end if;
end;
$$;

insert into public.generator_power_profiles (
  id,
  generator_id,
  nominal_power_w,
  valid_from,
  valid_until,
  created_by
)
values (
  'e7000000-0000-4000-8000-000000000002',
  'e5000000-0000-4000-8000-000000000001',
  100.000,
  '2026-07-01 00:00:00+00',
  null,
  'e2000000-0000-4000-8000-000000000001'
);

do $$
begin
  if not exists (
    select 1
    from public.application_power_verifications as verification
    join public.applications as application
      on application.id = verification.application_id
    join public.raw_events as start_event
      on start_event.id = application.start_event_id
    where start_event.occurred_at = '2026-07-10 10:00:00+00'
      and verification.operational_power_status = 'below_expected'
      and verification.power_profile_id
        = 'e7000000-0000-4000-8000-000000000002'
      and verification.nominal_power_w_snapshot = 100
      and verification.minimum_acceptable_power_w_snapshot = 85
      and verification.observed_power_w_snapshot = 70
  ) then
    raise exception 'o novo perfil não reprocessou o período futuro';
  end if;

  if (
    select count(*)
    from public.inconsistencies as inconsistency
    where inconsistency.type = 'power_below_expected'
  ) <> 2 or (
    select count(*)
    from public.inconsistencies as inconsistency
    where inconsistency.type = 'power_below_expected'
      and inconsistency.status <> 'resolved'
  ) <> 2 then
    raise exception 'o histórico por aplicação, leitura e perfil ficou inconsistente';
  end if;
end;
$$;

do $$
declare
  target_application_id bigint;
begin
  select application.id
  into strict target_application_id
  from public.applications as application
  join public.raw_events as start_event
    on start_event.id = application.start_event_id
  where start_event.occurred_at = '2026-07-10 10:00:00+00';

  update public.application_power_verifications
  set
    power_on_reading_id = null,
    status = 'missing_power_on',
    technical_reason = 'stale_state_for_atomicity_test',
    operational_power_status = 'not_evaluable',
    reference_power_reading_id = null,
    observed_power_w_snapshot = null,
    operational_reason = 'stale_operational_state_for_atomicity_test'
  where application_id = target_application_id;
end;
$$;

create or replace function private.fail_spec12_3_operational_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'spec12_3_forced_operational_failure';
end;
$$;

create trigger spec12_3_force_operational_failure
before update of operational_power_status
on public.application_power_verifications
for each row execute function private.fail_spec12_3_operational_update();

do $$
declare
  failure_seen boolean := false;
  runs_before bigint;
  target_application_id bigint;
begin
  select application.id
  into strict target_application_id
  from public.applications as application
  join public.raw_events as start_event
    on start_event.id = application.start_event_id
  where start_event.occurred_at = '2026-07-10 10:00:00+00';

  select count(*)
  into runs_before
  from private.operational_power_reprocessing_runs;

  begin
    perform private.reprocess_power_telemetry(
      'e5000000-0000-4000-8000-000000000001'
    );
  exception when others then
    if sqlerrm = 'spec12_3_forced_operational_failure' then
      failure_seen = true;
    else
      raise;
    end if;
  end;

  if not failure_seen then
    raise exception 'a falha operacional simulada não interrompeu o processamento';
  end if;

  if not exists (
    select 1
    from public.application_power_verifications as verification
    where verification.application_id = target_application_id
      and verification.status = 'missing_power_on'
      and verification.power_on_reading_id is null
      and verification.operational_power_status = 'not_evaluable'
      and verification.reference_power_reading_id is null
  ) then
    raise exception 'a correlação foi parcialmente publicada após a falha';
  end if;

  if (
    select count(*)
    from private.operational_power_reprocessing_runs
  ) <> runs_before then
    raise exception 'uma execução com rollback deixou resumo parcial';
  end if;
end;
$$;

drop trigger spec12_3_force_operational_failure
on public.application_power_verifications;
drop function private.fail_spec12_3_operational_update();

select private.reprocess_power_telemetry(
  'e5000000-0000-4000-8000-000000000001'
);

do $$
declare
  previous_run_id bigint;
begin
  select max(run.id)
  into strict previous_run_id
  from private.operational_power_reprocessing_runs as run
  where run.generator_id = 'e5000000-0000-4000-8000-000000000001';

  update public.controllers
  set correlation_tolerance_seconds = 121
  where id = 'e6000000-0000-4000-8000-000000000002';

  if not exists (
    select 1
    from private.operational_power_reprocessing_runs as run
    where run.generator_id = 'e5000000-0000-4000-8000-000000000001'
      and run.id > previous_run_id
      and run.reason = 'power_telemetry_reprocess'
  ) then
    raise exception 'a mudança de tolerância não reprocessou a avaliação';
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from public.application_power_verifications as verification
    join public.applications as application
      on application.id = verification.application_id
    join public.raw_events as start_event
      on start_event.id = application.start_event_id
    where start_event.occurred_at = '2026-07-10 10:00:00+00'
      and verification.status = 'verified'
      and verification.power_on_reading_id is not null
      and verification.operational_power_status = 'below_expected'
      and verification.reference_power_reading_id
        = verification.power_on_reading_id
  ) then
    raise exception 'o reprocessamento não se recuperou após o rollback';
  end if;

  if has_function_privilege(
    'anon',
    'private.reprocess_operational_power(uuid,timestamptz,timestamptz,text)',
    'execute'
  ) or has_function_privilege(
    'authenticated',
    'private.reprocess_operational_power(uuid,timestamptz,timestamptz,text)',
    'execute'
  ) then
    raise exception 'o reprocessador técnico foi exposto pela Data API';
  end if;

  if has_table_privilege(
    'anon',
    'private.operational_power_reprocessing_runs',
    'select'
  ) or has_table_privilege(
    'authenticated',
    'private.operational_power_reprocessing_runs',
    'select'
  ) then
    raise exception 'o histórico técnico foi exposto a usuários finais';
  end if;

  if exists (
    select 1
    from information_schema.columns as column_record
    where column_record.table_schema = 'private'
      and column_record.table_name = 'operational_power_reprocessing_runs'
      and (
        column_record.column_name like '%raw%'
        or column_record.column_name like '%file%'
        or column_record.column_name like '%content%'
        or column_record.column_name like '%payload%'
      )
  ) then
    raise exception 'o histórico técnico armazena conteúdo bruto';
  end if;
end;
$$;

-- Exercise the production reconstruction path and configuration triggers,
-- including loss and recovery of the reading used by a reviewed alert.
do $$
declare
  reviewed_snapshot jsonb;
begin
  select to_jsonb(inconsistency) into strict reviewed_snapshot
  from public.inconsistencies as inconsistency
  where type = 'power_below_expected' and status = 'reviewed';

  perform private.reprocess_all_generator_data(
    'e5000000-0000-4000-8000-000000000001'
  );

  if not exists (
    select 1 from public.inconsistencies as inconsistency
    where to_jsonb(inconsistency) = reviewed_snapshot
  ) then
    raise exception 'a reconstrução completa alterou o alerta reconhecido';
  end if;

  update public.controllers set power_on_threshold_w = 95
  where id = 'e6000000-0000-4000-8000-000000000002';

  if exists (
    select 1 from public.application_power_verifications
    where generator_id = 'e5000000-0000-4000-8000-000000000001'
      and operational_power_status <> 'not_evaluable'
  ) or exists (
    select 1 from public.inconsistencies
    where type = 'power_below_expected' and status <> 'resolved'
  ) then
    raise exception 'a mudança de limite não resolveu alertas sem leitura válida';
  end if;

  update public.controllers set power_on_threshold_w = 5
  where id = 'e6000000-0000-4000-8000-000000000002';

  if not exists (
    select 1 from public.inconsistencies as inconsistency
    where to_jsonb(inconsistency) = reviewed_snapshot
  ) or (
    select count(*) from public.inconsistencies
    where type = 'power_below_expected'
  ) <> 2 then
    raise exception 'a recuperação da leitura perdeu histórico ou duplicou alertas';
  end if;

  update public.controllers
  set deactivated_at = '2026-07-01 00:00:00+00', is_active = false
  where id = 'e6000000-0000-4000-8000-000000000002';

  if (
    select count(*) from public.inconsistencies
    where type = 'power_below_expected' and status <> 'resolved'
  ) <> 1 or not exists (
    select 1 from public.inconsistencies as inconsistency
    where to_jsonb(inconsistency) = reviewed_snapshot
  ) then
    raise exception 'a vigência do controlador não preservou somente o alerta histórico';
  end if;

  update public.controllers set deactivated_at = null, is_active = true
  where id = 'e6000000-0000-4000-8000-000000000002';
end;
$$;

select extensions.pass(
  'spec 12.3 operational power reprocessing tests passed'
);
select * from extensions.finish();

rollback;
