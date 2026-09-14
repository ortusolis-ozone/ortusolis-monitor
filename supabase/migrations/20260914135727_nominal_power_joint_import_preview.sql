-- Summarize only applications touched by the supplied batches, including
-- boundary pairs and power readings within the configured correlation tolerance.
create or replace function private.import_operational_summary(p_generator_id uuid, p_batch_ids uuid[])
returns jsonb language sql stable security definer set search_path = '' as $$
  with affected as materialized (
    select v.* from public.application_power_verifications v
    join public.applications a on a.id = v.application_id
    join public.raw_events first_event on first_event.id = a.start_event_id
    join public.raw_events last_event on last_event.id = a.end_event_id
    where v.generator_id = p_generator_id and exists (
      select 1 from public.import_batches b
      join public.controllers c on c.id = b.controller_id
      where b.id = any(p_batch_ids) and b.generator_id = p_generator_id
      and (
        (b.data_kind = 'state_events' and b.controller_id = a.controller_id
          and first_event.occurred_at <= b.period_end and last_event.occurred_at >= b.period_start)
        or (b.data_kind = 'power_readings'
          and first_event.occurred_at <= b.period_end + make_interval(secs => c.correlation_tolerance_seconds)
          and last_event.occurred_at >= b.period_start - make_interval(secs => c.correlation_tolerance_seconds))
      )
    )
  ), groups as (
    select operational_power_status as status, operational_reason as reason, count(*) as count
    from affected group by 1, 2
  ), profiles as (
    select distinct p.id, p.valid_from, p.valid_until,
      p.nominal_power_w::text as nominal_power_w,
      p.minimum_acceptable_power_w::text as minimum_acceptable_power_w
    from affected a join public.generator_power_profiles p on p.id = a.power_profile_id
  )
  select jsonb_build_object(
    'within_expected', (select count(*) from affected where operational_power_status = 'within_expected'),
    'below_expected', (select count(*) from affected where operational_power_status = 'below_expected'),
    'not_evaluable', (select count(*) from affected where operational_power_status = 'not_evaluable'),
    'not_configured', (select count(*) from affected where operational_power_status = 'not_configured'),
    'groups', coalesce((select jsonb_agg(to_jsonb(g) order by status, reason) from groups g), '[]'::jsonb),
    'profiles', coalesce((select jsonb_agg(to_jsonb(p) order by valid_from, id) from profiles p), '[]'::jsonb)
  );
$$;
revoke all on function private.import_operational_summary(uuid, uuid[]) from public, anon, authenticated;

create or replace function private.require_import_nominal_profiles(p_summary jsonb)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if (p_summary ->> 'not_configured')::bigint > 0 then
    raise exception 'Complete a potência nominal do gerador para todo o período das aplicações e valide novamente.'
      using errcode = 'P1206';
  end if;
end;
$$;
revoke all on function private.require_import_nominal_profiles(jsonb) from public, anon, authenticated;

-- Legacy individual confirmations retain their contracts but cannot publish
-- applications without a nominal profile. Existing history remains untouched.
create or replace function private.reprocess_confirmed_import()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'confirmed'
    and (tg_op = 'INSERT' or old.status is distinct from new.status)
    and coalesce(current_setting('app.defer_import_reprocess', true), 'off') <> 'on' then
    perform private.reprocess_all_generator_data(new.generator_id);
    perform private.require_import_nominal_profiles(
      private.import_operational_summary(new.generator_id, array[new.id]));
  end if;
  return new;
end;
$$;

create or replace function public.confirm_import_session(
  p_client_id uuid,
  p_location_id uuid,
  p_cold_room_id uuid,
  p_generator_id uuid,
  p_state_controller_id uuid,
  p_state_file_name text,
  p_state_file_sha256 text,
  p_state_events jsonb,
  p_power_controller_id uuid,
  p_power_file_name text,
  p_power_file_sha256 text,
  p_power_readings jsonb,
  p_coverage_warning_acknowledged boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  operational_summary jsonb;
  state_result jsonb;
  power_result jsonb;
  state_batch public.import_batches%rowtype;
  power_batch public.import_batches%rowtype;
  target_session public.import_sessions%rowtype;
  target_session_id uuid;
  state_start timestamptz;
  state_end timestamptz;
  power_start timestamptz;
  power_end timestamptz;
  overlap_start timestamptz;
  overlap_end timestamptz;
  calculated_coverage text;
  reused_session boolean := false;
begin
  if not (select private.is_active_master()) then
    raise exception 'somente o Master pode confirmar sessões de importação'
      using errcode = '42501';
  end if;

  if p_state_controller_id = p_power_controller_id then
    raise exception 'a sessão exige dois controladores de papéis diferentes'
      using errcode = '23514', constraint = 'confirm_import_session_controllers';
  end if;

  if jsonb_typeof(p_state_events) is distinct from 'array'
    or jsonb_typeof(p_power_readings) is distinct from 'array' then
    raise exception 'as duas listas da sessão devem ser válidas'
      using errcode = '23514', constraint = 'confirm_import_session_payloads';
  end if;

  select min(event.occurred_at), max(event.occurred_at)
  into state_start, state_end
  from jsonb_to_recordset(p_state_events) as event (
    occurred_at timestamptz
  );

  select min(reading.occurred_at), max(reading.occurred_at)
  into power_start, power_end
  from jsonb_to_recordset(p_power_readings) as reading (
    occurred_at timestamptz
  );

  if state_start is null or state_end is null
    or power_start is null or power_end is null then
    raise exception 'os dois arquivos devem conter períodos válidos'
      using errcode = '23514', constraint = 'confirm_import_session_periods';
  end if;

  if power_end < state_start or state_end < power_start then
    raise exception 'os arquivos não possuem interseção temporal'
      using errcode = '23514', constraint = 'confirm_import_session_no_intersection';
  end if;

  overlap_start := greatest(state_start, power_start);
  overlap_end := least(state_end, power_end);
  calculated_coverage := case
    when power_start <= state_start and power_end >= state_end then 'full'
    else 'partial'
  end;

  if calculated_coverage = 'partial'
    and not coalesce(p_coverage_warning_acknowledged, false) then
    raise exception 'a cobertura de potência é parcial e exige ciência explícita'
      using errcode = '23514', constraint = 'confirm_import_session_warning';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_generator_id::text, 0));
  perform set_config('app.defer_import_reprocess', 'on', true);

  state_result := public.confirm_xlsx_import(
    p_client_id,
    p_location_id,
    p_cold_room_id,
    p_generator_id,
    p_state_controller_id,
    p_state_file_name,
    p_state_file_sha256,
    p_state_events
  );

  power_result := public.confirm_power_xlsx_import(
    p_client_id,
    p_location_id,
    p_cold_room_id,
    p_generator_id,
    p_power_controller_id,
    p_power_file_name,
    p_power_file_sha256,
    p_power_readings
  );

  select * into state_batch
  from public.import_batches as batch
  where batch.id = (state_result ->> 'batch_id')::uuid;

  select * into power_batch
  from public.import_batches as batch
  where batch.id = (power_result ->> 'batch_id')::uuid;

  if state_batch.id is null or power_batch.id is null then
    raise exception 'os lotes confirmados não foram encontrados'
      using errcode = '23514', constraint = 'confirm_import_session_batches';
  end if;

  perform set_config('app.defer_import_reprocess', 'off', true);

  insert into public.import_sessions (
    client_id,
    location_id,
    cold_room_id,
    generator_id,
    state_controller_id,
    power_controller_id,
    state_batch_id,
    power_batch_id,
    status,
    coverage_status,
    coverage_warning_acknowledged,
    state_period_start,
    state_period_end,
    power_period_start,
    power_period_end,
    intersection_start,
    intersection_end,
    created_by,
    confirmed_at
  )
  values (
    p_client_id,
    p_location_id,
    p_cold_room_id,
    p_generator_id,
    p_state_controller_id,
    p_power_controller_id,
    state_batch.id,
    power_batch.id,
    'confirmed',
    calculated_coverage,
    calculated_coverage = 'partial',
    state_batch.period_start,
    state_batch.period_end,
    power_batch.period_start,
    power_batch.period_end,
    overlap_start,
    overlap_end,
    (select auth.uid()),
    now()
  )
  on conflict (state_batch_id, power_batch_id) do nothing
  returning id into target_session_id;

  if target_session_id is null then
    reused_session := true;

    select * into target_session
    from public.import_sessions as session
    where session.state_batch_id = state_batch.id
      and session.power_batch_id = power_batch.id;
  else
    select * into target_session
    from public.import_sessions as session
    where session.id = target_session_id;
  end if;

  if target_session.id is null then
    raise exception 'a sessão confirmada não foi encontrada'
      using errcode = '23514', constraint = 'confirm_import_session_result';
  end if;

  perform private.reprocess_all_generator_data(p_generator_id);

  operational_summary := private.import_operational_summary(p_generator_id, array[state_batch.id, power_batch.id]);
  perform private.require_import_nominal_profiles(operational_summary);

  return jsonb_build_object(
    'operational_summary', operational_summary,
    'session_id', target_session.id,
    'status', target_session.status,
    'coverage_status', target_session.coverage_status,
    'coverage_warning_acknowledged', target_session.coverage_warning_acknowledged,
    'state_period_start', target_session.state_period_start,
    'state_period_end', target_session.state_period_end,
    'power_period_start', target_session.power_period_start,
    'power_period_end', target_session.power_period_end,
    'intersection_start', target_session.intersection_start,
    'intersection_end', target_session.intersection_end,
    'already_confirmed', reused_session,
    'state_batch', state_result,
    'power_batch', power_result
  );
end;
$$;

create or replace function public.preview_import_session(
  p_client_id uuid,
  p_location_id uuid,
  p_cold_room_id uuid,
  p_generator_id uuid,
  p_state_controller_id uuid,
  p_state_file_name text,
  p_state_file_sha256 text,
  p_state_events jsonb,
  p_power_controller_id uuid,
  p_power_file_name text,
  p_power_file_sha256 text,
  p_power_readings jsonb
)
returns jsonb language plpgsql security invoker set search_path = '' as $$
declare result jsonb;
begin
  -- Only this deliberate exception is swallowed. All writes from the canonical
  -- confirmation (including audit and derived data) are rolled back together.
  begin
    result := public.confirm_import_session(
      p_client_id, p_location_id, p_cold_room_id, p_generator_id,
      p_state_controller_id, p_state_file_name, p_state_file_sha256, p_state_events,
      p_power_controller_id, p_power_file_name, p_power_file_sha256, p_power_readings,
      true
    );
    raise exception 'preview rollback' using errcode = 'P1207';
  exception when sqlstate 'P1207' then null;
  end;
  return result -> 'operational_summary';
end;
$$;
revoke all on function public.preview_import_session(uuid,uuid,uuid,uuid,uuid,text,text,jsonb,uuid,text,text,jsonb) from public, anon;
grant execute on function public.preview_import_session(uuid,uuid,uuid,uuid,uuid,text,text,jsonb,uuid,text,text,jsonb) to authenticated;
