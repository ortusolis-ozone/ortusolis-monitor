-- The Master application list needs the same diagnostic data without a prior
-- generator selection. Authorization remains enforced inside this function.

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
    round(100 * (v.observed_power_w_snapshot - v.nominal_power_w_snapshot) / nullif(v.nominal_power_w_snapshot, 0), 3)::text,
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
