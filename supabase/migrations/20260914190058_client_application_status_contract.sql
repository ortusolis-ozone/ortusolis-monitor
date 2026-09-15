create or replace function private.list_client_application_status(
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
  application_status text,
  attention_status text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_is_master boolean := (select private.is_active_master());
  v_client_id uuid := (select private.current_client_id());
begin
  if not v_is_master and v_client_id is null then
    raise exception 'usuário não autorizado para consultar o portal'
      using errcode = '42501';
  end if;

  if p_start_date is not null
    and p_end_date is not null
    and p_start_date > p_end_date then
    raise exception 'período inválido' using errcode = '22023';
  end if;

  if p_offset is null or p_offset < 0 then
    raise exception 'página inválida' using errcode = '22023';
  end if;

  return query
  select
    daily_status.client_id,
    daily_status.location_id,
    daily_status.cold_room_id,
    daily_status.generator_id,
    daily_status.status_date,
    case daily_status.status
      when 'completed' then 'registered'
      else daily_status.status
    end as application_status,
    case
      when exists (
        select 1
        from public.applications as application
        join public.application_power_verifications as verification
          on verification.application_id = application.id
        where application.generator_id = daily_status.generator_id
          and application.public_date = daily_status.status_date
          and verification.operational_power_status = 'below_expected'
      ) then 'attention'
      else 'none'
    end as attention_status
  from public.client_daily_status as daily_status
  where (v_is_master or daily_status.client_id = v_client_id)
    and (p_start_date is null or daily_status.status_date >= p_start_date)
    and (p_end_date is null or daily_status.status_date <= p_end_date)
    and (p_location_id is null or daily_status.location_id = p_location_id)
    and (p_cold_room_id is null or daily_status.cold_room_id = p_cold_room_id)
    and (p_generator_id is null or daily_status.generator_id = p_generator_id)
  order by daily_status.status_date desc, daily_status.generator_id
  limit 1000
  offset p_offset;
end;
$$;

comment on function private.list_client_application_status(
  date,
  date,
  uuid,
  uuid,
  uuid,
  integer
) is
  'Implementação protegida do histórico público sanitizado por conta.';

create or replace function public.list_client_application_status(
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
  application_status text,
  attention_status text
)
language sql
stable
security invoker
set search_path = ''
as $$
  select *
  from private.list_client_application_status(
    p_start_date,
    p_end_date,
    p_location_id,
    p_cold_room_id,
    p_generator_id,
    p_offset
  );
$$;

comment on function public.list_client_application_status(
  date,
  date,
  uuid,
  uuid,
  uuid,
  integer
) is
  'Histórico público por gerador e dia; registered indica aplicação concluída e attention sinaliza ao menos uma redução operacional.';

revoke all on function private.list_client_application_status(
  date,
  date,
  uuid,
  uuid,
  uuid,
  integer
) from public, anon, authenticated;

grant execute on function private.list_client_application_status(
  date,
  date,
  uuid,
  uuid,
  uuid,
  integer
) to authenticated;

revoke all on function public.list_client_application_status(
  date,
  date,
  uuid,
  uuid,
  uuid,
  integer
) from public, anon, authenticated;

grant execute on function public.list_client_application_status(
  date,
  date,
  uuid,
  uuid,
  uuid,
  integer
) to authenticated;
