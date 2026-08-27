create or replace function public.register_complete_client_structure(
  p_client_legal_name text,
  p_client_cnpj text,
  p_location_name text,
  p_location_description text,
  p_location_time_zone text,
  p_cold_room_name text,
  p_cold_room_category text,
  p_generator_identifier text,
  p_generator_valid_from date,
  p_controller_identifier text,
  p_controller_activated_on date
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  new_client_id uuid;
  new_location_id uuid;
  new_cold_room_id uuid;
  new_generator_id uuid;
  new_controller_id uuid;
begin
  if p_controller_activated_on < p_generator_valid_from then
    raise exception 'a ativação do controlador não pode ser anterior ao início da alocação do gerador'
      using errcode = '23514',
        constraint = 'register_complete_client_structure_controller_period';
  end if;

  insert into public.clients (legal_name, cnpj)
  values (btrim(p_client_legal_name), btrim(p_client_cnpj))
  returning id into new_client_id;

  insert into public.locations (
    client_id,
    name,
    description,
    time_zone
  )
  values (
    new_client_id,
    btrim(p_location_name),
    nullif(btrim(p_location_description), ''),
    btrim(p_location_time_zone)
  )
  returning id into new_location_id;

  insert into public.cold_rooms (
    client_id,
    location_id,
    name,
    category
  )
  values (
    new_client_id,
    new_location_id,
    btrim(p_cold_room_name),
    p_cold_room_category
  )
  returning id into new_cold_room_id;

  new_generator_id := public.register_generator(
    new_client_id,
    new_location_id,
    new_cold_room_id,
    p_generator_identifier,
    p_generator_valid_from
  );

  new_controller_id := public.register_controller(
    new_generator_id,
    p_controller_identifier,
    p_controller_activated_on
  );

  return jsonb_build_object(
    'client_id', new_client_id,
    'location_id', new_location_id,
    'cold_room_id', new_cold_room_id,
    'generator_id', new_generator_id,
    'controller_id', new_controller_id
  );
end;
$$;

revoke all on function public.register_complete_client_structure(
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  date,
  text,
  date
) from public, anon;

grant execute on function public.register_complete_client_structure(
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  date,
  text,
  date
) to authenticated;
