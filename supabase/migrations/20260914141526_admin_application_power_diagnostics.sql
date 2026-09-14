-- Master-only diagnostic contracts. Decimal snapshots remain text across the API.
-- No client-facing contract or operational calculation changes in this migration.

create or replace function private.list_admin_application_power_diagnostics(p_generator_id uuid default null, p_application_id bigint default null, p_offset integer default 0)
returns table (
  application_id bigint, generator_id uuid, generator_identifier text,
  client_name text, location_name text, cold_room_name text,
  start_at timestamptz, end_at timestamptz,
  correlation_status text, correlation_reason text, operational_status text, operational_reason text,
  nominal_power_w text, minimum_power_w text, observed_power_w text,
  difference_w text, difference_percent text,
  reference_reading_id bigint, reference_reading_at timestamptz,
  power_controller_id uuid, power_controller_identifier text,
  power_batch_id uuid, power_file_name text,
  state_controller_id uuid, state_controller_identifier text,
  start_event_id bigint, end_event_id bigint,
  state_batch_id uuid, state_file_name text, end_batch_id uuid, end_file_name text,
  power_profile_id uuid, profile_valid_from timestamptz, profile_valid_until timestamptz,
  evaluated_at timestamptz, rule_version text
)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (select private.is_active_master()) then
    raise exception 'somente o Master pode consultar diagnósticos técnicos' using errcode = '42501';
  end if;
  if p_generator_id is null and p_application_id is null then
    raise exception 'informe o gerador ou a aplicação' using errcode = '22023';
  end if;
  if p_offset is null or p_offset < 0 then
    raise exception 'página inválida' using errcode = '22023';
  end if;
  return query
  select a.id, g.id, g.identifier, c.legal_name, l.name, room.name,
    first_event.occurred_at, last_event.occurred_at,
    coalesce(v.status, 'not_processed'), coalesce(v.technical_reason, 'not_processed'),
    coalesce(v.operational_power_status, 'not_processed'), coalesce(v.operational_reason, 'not_processed'),
    v.nominal_power_w_snapshot::text, v.minimum_acceptable_power_w_snapshot::text,
    v.observed_power_w_snapshot::text,
    abs(v.observed_power_w_snapshot - v.nominal_power_w_snapshot)::text,
    round(100 * (v.observed_power_w_snapshot - v.nominal_power_w_snapshot)
      / nullif(v.nominal_power_w_snapshot, 0), 3)::text,
    reading.id, reading.occurred_at, power_controller.id, power_controller.identifier,
    power_batch.id, power_batch.file_name, state_controller.id, state_controller.identifier,
    first_event.id, last_event.id, state_batch.id, state_batch.file_name, end_batch.id, end_batch.file_name,
    v.power_profile_id, profile.valid_from, profile.valid_until, v.updated_at, v.operational_rule_version
  from public.applications a
  join public.generators g on g.id = a.generator_id
  join public.clients c on c.id = g.client_id
  join public.raw_events first_event on first_event.id = a.start_event_id
  join public.raw_events last_event on last_event.id = a.end_event_id
  join public.import_batches state_batch on state_batch.id = first_event.import_batch_id
  join public.import_batches end_batch on end_batch.id = last_event.import_batch_id
  join public.locations l on l.id = state_batch.location_id
  join public.cold_rooms room on room.id = state_batch.cold_room_id
  join public.controllers state_controller on state_controller.id = a.controller_id
  left join public.application_power_verifications v on v.application_id = a.id
  left join public.power_readings reading on reading.id = v.reference_power_reading_id
  left join public.controllers power_controller on power_controller.id = coalesce(reading.controller_id, v.controller_id)
  left join public.import_batches power_batch on power_batch.id = reading.import_batch_id
  left join public.generator_power_profiles profile on profile.id = v.power_profile_id
  where (p_generator_id is null or a.generator_id = p_generator_id)
    and (p_application_id is null or a.id = p_application_id)
  order by a.id desc limit 50 offset p_offset;
end;
$$;
create or replace function public.list_admin_application_power_diagnostics(p_generator_id uuid default null, p_application_id bigint default null, p_offset integer default 0)
returns table (
  application_id bigint, generator_id uuid, generator_identifier text,
  client_name text, location_name text, cold_room_name text,
  start_at timestamptz, end_at timestamptz,
  correlation_status text, correlation_reason text, operational_status text, operational_reason text,
  nominal_power_w text, minimum_power_w text, observed_power_w text,
  difference_w text, difference_percent text,
  reference_reading_id bigint, reference_reading_at timestamptz,
  power_controller_id uuid, power_controller_identifier text,
  power_batch_id uuid, power_file_name text,
  state_controller_id uuid, state_controller_identifier text,
  start_event_id bigint, end_event_id bigint,
  state_batch_id uuid, state_file_name text, end_batch_id uuid, end_file_name text,
  power_profile_id uuid, profile_valid_from timestamptz, profile_valid_until timestamptz,
  evaluated_at timestamptz, rule_version text
)
language sql stable security invoker set search_path = '' as $$
  select * from private.list_admin_application_power_diagnostics(p_generator_id, p_application_id, p_offset);
$$;
revoke all on function private.list_admin_application_power_diagnostics(uuid,bigint,integer) from public, anon, authenticated;
grant execute on function private.list_admin_application_power_diagnostics(uuid,bigint,integer) to authenticated;
revoke all on function public.list_admin_application_power_diagnostics(uuid,bigint,integer) from public, anon, authenticated;
grant execute on function public.list_admin_application_power_diagnostics(uuid,bigint,integer) to authenticated;

create or replace function private.list_admin_application_power_inconsistencies(p_application_id bigint)
returns table (
  id bigint, type text, status text, review_note text, reviewed_by_name text,
  reviewed_at timestamptz, resolved_at timestamptz, created_at timestamptz,
  power_reading_id bigint, power_profile_id uuid
)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (select private.is_active_master()) then
    raise exception 'somente o Master pode consultar diagnósticos técnicos' using errcode = '42501';
  end if;
  return query
  select i.id, i.type, i.status, i.review_note, reviewer.full_name,
    i.reviewed_at, i.resolved_at, i.created_at, i.power_reading_id, i.power_profile_id
  from public.inconsistencies i
  left join public.profiles reviewer on reviewer.id = i.reviewed_by
  where i.application_id = p_application_id
  order by i.created_at desc, i.id desc;
end;
$$;
create or replace function public.list_admin_application_power_inconsistencies(p_application_id bigint)
returns table (
  id bigint, type text, status text, review_note text, reviewed_by_name text,
  reviewed_at timestamptz, resolved_at timestamptz, created_at timestamptz,
  power_reading_id bigint, power_profile_id uuid
)
language sql stable security invoker set search_path = '' as $$
  select * from private.list_admin_application_power_inconsistencies(p_application_id);
$$;
revoke all on function private.list_admin_application_power_inconsistencies(bigint) from public, anon, authenticated;
grant execute on function private.list_admin_application_power_inconsistencies(bigint) to authenticated;
revoke all on function public.list_admin_application_power_inconsistencies(bigint) from public, anon, authenticated;
grant execute on function public.list_admin_application_power_inconsistencies(bigint) to authenticated;

create or replace function private.list_admin_application_power_runs(p_application_id bigint, p_offset integer default 0)
returns table (
  id bigint, affected_from timestamptz, affected_until timestamptz, reason text,
  rule_version text, processed_at timestamptz,
  within_expected_count bigint, below_expected_count bigint,
  not_evaluable_count bigint, not_configured_count bigint
)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (select private.is_active_master()) then
    raise exception 'somente o Master pode consultar diagnósticos técnicos' using errcode = '42501';
  end if;
  if p_offset is null or p_offset < 0 then
    raise exception 'página inválida' using errcode = '22023';
  end if;
  return query
  select r.id, r.affected_from, r.affected_until, r.reason, r.rule_version, r.processed_at,
    r.within_expected_count, r.below_expected_count, r.not_evaluable_count, r.not_configured_count
  from private.operational_power_reprocessing_runs r
  join public.applications a on a.generator_id = r.generator_id and a.id = p_application_id
  join public.raw_events e on e.id = a.start_event_id
  where (r.affected_from is null or e.occurred_at >= r.affected_from)
    and (r.affected_until is null or e.occurred_at < r.affected_until)
  order by r.processed_at desc, r.id desc limit 20 offset p_offset;
end;
$$;
create or replace function public.list_admin_application_power_runs(p_application_id bigint, p_offset integer default 0)
returns table (
  id bigint, affected_from timestamptz, affected_until timestamptz, reason text,
  rule_version text, processed_at timestamptz,
  within_expected_count bigint, below_expected_count bigint,
  not_evaluable_count bigint, not_configured_count bigint
)
language sql stable security invoker set search_path = '' as $$
  select * from private.list_admin_application_power_runs(p_application_id, p_offset);
$$;
revoke all on function private.list_admin_application_power_runs(bigint,integer) from public, anon, authenticated;
grant execute on function private.list_admin_application_power_runs(bigint,integer) to authenticated;
revoke all on function public.list_admin_application_power_runs(bigint,integer) from public, anon, authenticated;
grant execute on function public.list_admin_application_power_runs(bigint,integer) to authenticated;
