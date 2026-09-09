-- Enforce the invariant at transaction end, after the registration RPC has
-- created the generator, allocation, controllers and nominal profile.
-- Existing generators are intentionally not backfilled or revalidated.
create function private.require_new_generator_power_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (select 1 from public.generators where id = new.id)
    and not exists (select 1 from public.generator_power_profiles where generator_id = new.id) then
    raise exception 'novos geradores exigem potência nominal positiva'
      using errcode = '23514', constraint = 'new_generator_requires_power_profile';
  end if;
  return null;
end;
$$;
revoke all on function private.require_new_generator_power_profile() from public, anon, authenticated;

create constraint trigger new_generator_requires_power_profile
after insert on public.generators
deferrable initially deferred
for each row execute function private.require_new_generator_power_profile();

create function public.register_complete_client_structure_with_power_profile(
  p_client_legal_name text,
  p_client_cnpj text,
  p_location_name text,
  p_location_description text,
  p_location_time_zone text,
  p_cold_room_name text,
  p_cold_room_category text,
  p_generator_identifier text,
  p_generator_valid_from date,
  p_state_controller_identifier text,
  p_state_controller_activated_on date,
  p_power_controller_identifier text,
  p_power_controller_device_id text,
  p_power_controller_activated_on date,
  p_nominal_power_w text,
  p_power_on_threshold_w numeric default 5,
  p_power_off_threshold_w numeric default 1,
  p_correlation_tolerance_seconds integer default 120
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  structure jsonb;
  nominal numeric;
  generator_id_value uuid;
  profile_start timestamptz;
begin
  if not (select private.is_active_master()) then
    raise exception 'somente o Master pode cadastrar a estrutura' using errcode = '42501';
  end if;
  nominal := private.parse_nominal_power(p_nominal_power_w);
  if p_generator_valid_from is null or not isfinite(p_generator_valid_from) then
    raise exception 'informe uma data inicial válida' using errcode = '22023';
  end if;
  structure := public.register_complete_client_structure_v2(
    p_client_legal_name, p_client_cnpj, p_location_name, p_location_description,
    p_location_time_zone, p_cold_room_name, p_cold_room_category,
    p_generator_identifier, p_generator_valid_from,
    p_state_controller_identifier, p_state_controller_activated_on,
    p_power_controller_identifier, p_power_controller_device_id, p_power_controller_activated_on,
    p_power_on_threshold_w, p_power_off_threshold_w, p_correlation_tolerance_seconds
  );
  generator_id_value := (structure ->> 'generator_id')::uuid;
  select valid_from into strict profile_start from public.generator_assignments
  where generator_id = generator_id_value and valid_until is null;
  insert into public.generator_power_profiles (generator_id, nominal_power_w, valid_from, created_by)
  values (generator_id_value, nominal, profile_start, (select auth.uid()));
  return structure;
end;
$$;

revoke all on function public.register_complete_client_structure_with_power_profile(
  text, text, text, text, text, text, text, text, date, text, date, text, text, date, text, numeric, numeric, integer
) from public, anon, authenticated;
grant execute on function public.register_complete_client_structure_with_power_profile(
  text, text, text, text, text, text, text, text, date, text, date, text, text, date, text, numeric, numeric, integer
) to authenticated;

comment on trigger new_generator_requires_power_profile on public.generators is
  'Impede INSERT direto e cadastros legados sem perfil ao concluir a transação. RPCs antigas permanecem apenas como composição interna dos cadastros nominais.';
