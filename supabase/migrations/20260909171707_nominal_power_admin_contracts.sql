-- Text at the RPC boundary preserves exact decimals beyond JavaScript's range.
create function private.parse_nominal_power(p_value text)
returns numeric
language plpgsql
immutable
security invoker
set search_path = ''
as $$
declare
  normalized text := replace(btrim(coalesce(p_value, '')), ',', '.');
begin
  if normalized !~ '^[0-9]+([.][0-9]{1,3})?$' then
    raise exception 'informe potência nominal positiva com até três casas decimais'
      using errcode = '22023';
  end if;
  if normalized::numeric <= 0 then
    raise exception 'informe potência nominal positiva com até três casas decimais'
      using errcode = '22023';
  end if;
  return normalized::numeric;
end;
$$;

revoke all on function private.parse_nominal_power(text) from public, anon, authenticated;
grant execute on function private.parse_nominal_power(text) to authenticated;

create function public.register_generator_with_power_profile(
  p_cold_room_id uuid,
  p_identifier text,
  p_valid_from date,
  p_nominal_power_w text,
  p_state_controller_identifier text,
  p_power_controller_identifier text,
  p_power_controller_device_id text,
  p_power_on_threshold_w numeric default 5,
  p_power_off_threshold_w numeric default 1,
  p_correlation_tolerance_seconds integer default 120
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  new_generator_id uuid;
  room_client_id uuid;
  room_location_id uuid;
  profile_start timestamptz;
  nominal numeric;
begin
  if not (select private.is_active_master()) then
    raise exception 'somente o Master pode configurar potência nominal' using errcode = '42501';
  end if;
  nominal := private.parse_nominal_power(p_nominal_power_w);
  if p_valid_from is null or not isfinite(p_valid_from) then
    raise exception 'informe uma data inicial válida' using errcode = '22023';
  end if;

  select room.client_id, room.location_id
  into room_client_id, room_location_id
  from public.cold_rooms as room where room.id = p_cold_room_id;
  if not found then
    raise exception 'selecione uma câmara válida' using errcode = '23503';
  end if;

  new_generator_id := public.register_generator_v2(
    room_client_id, room_location_id, p_cold_room_id, p_identifier, p_valid_from,
    p_state_controller_identifier, p_valid_from,
    p_power_controller_identifier, p_power_controller_device_id, p_valid_from,
    p_power_on_threshold_w, p_power_off_threshold_w, p_correlation_tolerance_seconds
  );

  select assignment.valid_from into strict profile_start
  from public.generator_assignments as assignment
  where assignment.generator_id = new_generator_id and assignment.valid_until is null;

  insert into public.generator_power_profiles (
    generator_id, nominal_power_w, valid_from, created_by
  ) values (new_generator_id, nominal, profile_start, (select auth.uid()));
  return new_generator_id;
end;
$$;

create function public.version_generator_power_profile(
  p_generator_id uuid,
  p_nominal_power_w text,
  p_valid_from timestamptz,
  p_expected_profile_id uuid default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  current_profile public.generator_power_profiles%rowtype;
  new_profile_id uuid;
  nominal numeric;
begin
  if not (select private.is_active_master()) then
    raise exception 'somente o Master pode configurar potência nominal' using errcode = '42501';
  end if;
  nominal := private.parse_nominal_power(p_nominal_power_w);
  if p_valid_from is null or not isfinite(p_valid_from) then
    raise exception 'informe uma vigência válida' using errcode = '22023';
  end if;

  -- Same transaction lock as telemetry: a profile change and its recalculation
  -- must complete before another version can be based on this history.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_generator_id::text, 0));
  perform 1 from public.generators as generator
  join public.clients as client on client.id = generator.client_id
  where generator.id = p_generator_id and generator.is_active and client.is_active
  for update of generator;
  if not found then
    raise exception 'gerador ativo não encontrado' using errcode = 'P0002';
  end if;

  select * into current_profile from public.generator_power_profiles
  where generator_id = p_generator_id and valid_until is null
  for update;
  if current_profile.id is distinct from p_expected_profile_id then
    raise exception 'o perfil mudou; atualize o histórico antes de salvar' using errcode = '40001';
  end if;
  if current_profile.id is not null and p_valid_from <= current_profile.valid_from then
    raise exception 'a nova vigência deve ser posterior à anterior' using errcode = '23P01';
  end if;

  update public.generator_power_profiles set valid_until = p_valid_from
  where id = current_profile.id;
  insert into public.generator_power_profiles (
    generator_id, nominal_power_w, valid_from, created_by
  ) values (p_generator_id, nominal, p_valid_from, (select auth.uid()))
  returning id into new_profile_id;
  return new_profile_id;
end;
$$;

comment on function public.version_generator_power_profile(uuid, text, timestamptz, uuid) is
  'Versiona o último perfil aberto; expected_profile_id nulo configura um legado sem perfil aberto. Conflitos exigem releitura do histórico.';

create function public.list_admin_generator_power_configuration(
  p_at timestamptz default now(),
  p_only_pending boolean default false,
  p_generator_id uuid default null
)
returns table (
  generator_id uuid, identifier text, client_id uuid, is_active boolean,
  configuration_status text, power_profile_id uuid,
  nominal_power_w text, minimum_acceptable_power_w text,
  valid_from timestamptz, valid_until timestamptz
)
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  if not (select private.is_active_master()) then
    raise exception 'somente o Master pode consultar potência nominal' using errcode = '42501';
  end if;
  if p_at is null or not isfinite(p_at) then
    raise exception 'informe uma data de consulta válida' using errcode = '22023';
  end if;
  return query
  select g.id, g.identifier, g.client_id, g.is_active,
    case when p.id is null then 'not_configured' else 'configured' end,
    p.id, p.nominal_power_w::text, p.minimum_acceptable_power_w::text,
    p.valid_from, p.valid_until
  from public.generators as g
  left join public.generator_power_profiles as p on p.generator_id = g.id
    and p.valid_from <= p_at and (p.valid_until is null or p_at < p.valid_until)
  where (p_generator_id is null or g.id = p_generator_id)
    and (not p_only_pending or p.id is null)
  order by g.identifier, g.id;
end;
$$;

create function public.list_admin_generator_power_history(p_generator_id uuid)
returns table (
  id uuid, generator_id uuid, nominal_power_w text, minimum_acceptable_power_w text,
  reduction_limit_percent text, valid_from timestamptz, valid_until timestamptz,
  created_by uuid, created_at timestamptz
)
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  if not (select private.is_active_master()) then
    raise exception 'somente o Master pode consultar potência nominal' using errcode = '42501';
  end if;
  return query
  select p.id, p.generator_id, p.nominal_power_w::text,
    p.minimum_acceptable_power_w::text, p.reduction_limit_percent::text,
    p.valid_from, p.valid_until, p.created_by, p.created_at
  from public.generator_power_profiles as p
  where p.generator_id = p_generator_id order by p.valid_from desc, p.id;
end;
$$;

revoke all on function public.register_generator_with_power_profile(uuid, text, date, text, text, text, text, numeric, numeric, integer) from public, anon, authenticated;
revoke all on function public.version_generator_power_profile(uuid, text, timestamptz, uuid) from public, anon, authenticated;
revoke all on function public.list_admin_generator_power_configuration(timestamptz, boolean, uuid) from public, anon, authenticated;
revoke all on function public.list_admin_generator_power_history(uuid) from public, anon, authenticated;
grant execute on function public.register_generator_with_power_profile(uuid, text, date, text, text, text, text, numeric, numeric, integer) to authenticated;
grant execute on function public.version_generator_power_profile(uuid, text, timestamptz, uuid) to authenticated;
grant execute on function public.list_admin_generator_power_configuration(timestamptz, boolean, uuid) to authenticated;
grant execute on function public.list_admin_generator_power_history(uuid) to authenticated;
