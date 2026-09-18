-- Master-only counterpart of the client agenda. The selected client is
-- mandatory so administrative navigation never produces a mixed-client feed.

create function private.list_admin_client_application_details(
  p_client_id uuid,
  p_start_date date default null,
  p_end_date date default null,
  p_location_id uuid default null,
  p_cold_room_id uuid default null,
  p_generator_id uuid default null,
  p_offset integer default 0
)
returns table (
  client_id uuid,
  location_id uuid,
  cold_room_id uuid,
  generator_id uuid,
  status_date date,
  application_started_at time,
  application_ended_at time,
  max_measured_power_w numeric,
  attention_status text
)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (select private.is_active_master()) then
    raise exception 'somente o Master pode consultar a agenda administrativa' using errcode = '42501';
  end if;
  if p_client_id is null then
    raise exception 'informe o cliente' using errcode = '22023';
  end if;
  if p_start_date is not null and p_end_date is not null and p_start_date > p_end_date then
    raise exception 'período inválido' using errcode = '22023';
  end if;
  if p_offset is null or p_offset < 0 then
    raise exception 'página inválida' using errcode = '22023';
  end if;

  return query
  select daily_status.client_id, daily_status.location_id, daily_status.cold_room_id,
    application.generator_id, application.public_date,
    (start_event.occurred_at at time zone location.time_zone)::time,
    (end_event.occurred_at at time zone location.time_zone)::time,
    max(reading.power_w),
    case when exists (
      select 1 from public.application_power_verifications as verification
      where verification.application_id = application.id
        and verification.operational_power_status = 'below_expected'
    ) then 'attention' else 'none' end
  from public.applications as application
  join public.client_daily_status as daily_status on daily_status.generator_id = application.generator_id
    and daily_status.status_date = application.public_date and daily_status.status = 'completed'
  join public.raw_events as start_event on start_event.id = application.start_event_id and start_event.generator_id = application.generator_id
  join public.raw_events as end_event on end_event.id = application.end_event_id and end_event.generator_id = application.generator_id
  join public.locations as location on location.id = daily_status.location_id and location.client_id = daily_status.client_id
  left join private.effective_power_readings as reading on reading.generator_id = application.generator_id
    and reading.occurred_at >= start_event.occurred_at and reading.occurred_at <= end_event.occurred_at
  where daily_status.client_id = p_client_id
    and (p_start_date is null or application.public_date >= p_start_date)
    and (p_end_date is null or application.public_date <= p_end_date)
    and (p_location_id is null or daily_status.location_id = p_location_id)
    and (p_cold_room_id is null or daily_status.cold_room_id = p_cold_room_id)
    and (p_generator_id is null or application.generator_id = p_generator_id)
  group by daily_status.client_id, daily_status.location_id, daily_status.cold_room_id,
    application.id, application.generator_id, application.public_date,
    start_event.occurred_at, end_event.occurred_at, location.time_zone
  order by application.public_date desc, start_event.occurred_at desc, application.id desc
  limit 1000 offset p_offset;
end;
$$;

create function public.list_admin_client_application_details(
  p_client_id uuid,
  p_start_date date default null,
  p_end_date date default null,
  p_location_id uuid default null,
  p_cold_room_id uuid default null,
  p_generator_id uuid default null,
  p_offset integer default 0
)
returns table (
  client_id uuid, location_id uuid, cold_room_id uuid, generator_id uuid,
  status_date date, application_started_at time, application_ended_at time,
  max_measured_power_w numeric, attention_status text
)
language sql stable security invoker set search_path = '' as $$
  select * from private.list_admin_client_application_details(
    p_client_id, p_start_date, p_end_date, p_location_id, p_cold_room_id, p_generator_id, p_offset
  );
$$;

revoke all on function private.list_admin_client_application_details(uuid,date,date,uuid,uuid,uuid,integer) from public, anon, authenticated;
grant execute on function private.list_admin_client_application_details(uuid,date,date,uuid,uuid,uuid,integer) to authenticated;
revoke all on function public.list_admin_client_application_details(uuid,date,date,uuid,uuid,uuid,integer) from public, anon, authenticated;
grant execute on function public.list_admin_client_application_details(uuid,date,date,uuid,uuid,uuid,integer) to authenticated;
