create or replace function private.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

revoke all on function private.touch_updated_at() from public, anon, authenticated;

create or replace function private.prevent_operational_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'cadastros operacionais não podem ser excluídos; inative o registro'
    using errcode = '23514',
      constraint = 'operational_records_cannot_be_deleted';
end;
$$;

revoke all on function private.prevent_operational_delete()
from public, anon, authenticated;

create or replace function private.audit_operational_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  row_data jsonb;
  old_data jsonb;
  audit_action text;
begin
  row_data = to_jsonb(new);
  old_data = case when tg_op = 'UPDATE' then to_jsonb(old) else null end;

  if tg_op = 'INSERT' then
    audit_action = 'created';
  elsif old_data ? 'is_active'
    and (old_data ->> 'is_active')::boolean
      is distinct from (row_data ->> 'is_active')::boolean then
    audit_action = case
      when (row_data ->> 'is_active')::boolean then 'activated'
      else 'deactivated'
    end;
  elsif tg_table_name = 'generator_assignments'
    and old_data ->> 'valid_until' is null
    and row_data ->> 'valid_until' is not null then
    audit_action = 'allocation_ended';
  else
    audit_action = 'updated';
  end if;

  insert into public.audit_logs (
    actor_id,
    action,
    entity_type,
    entity_id
  )
  values (
    (select auth.uid()),
    audit_action,
    tg_table_name,
    row_data ->> 'id'
  );

  return new;
end;
$$;

revoke all on function private.audit_operational_change()
from public, anon, authenticated;

create trigger clients_touch_updated_at
before update on public.clients
for each row execute function private.touch_updated_at();

create trigger profiles_touch_updated_at
before update on public.profiles
for each row execute function private.touch_updated_at();

create trigger locations_touch_updated_at
before update on public.locations
for each row execute function private.touch_updated_at();

create trigger cold_rooms_touch_updated_at
before update on public.cold_rooms
for each row execute function private.touch_updated_at();

create trigger generators_touch_updated_at
before update on public.generators
for each row execute function private.touch_updated_at();

create trigger controllers_touch_updated_at
before update on public.controllers
for each row execute function private.touch_updated_at();

create trigger clients_prevent_delete
before delete on public.clients
for each row execute function private.prevent_operational_delete();

create trigger profiles_prevent_delete
before delete on public.profiles
for each row execute function private.prevent_operational_delete();

create trigger locations_prevent_delete
before delete on public.locations
for each row execute function private.prevent_operational_delete();

create trigger cold_rooms_prevent_delete
before delete on public.cold_rooms
for each row execute function private.prevent_operational_delete();

create trigger generators_prevent_delete
before delete on public.generators
for each row execute function private.prevent_operational_delete();

create trigger generator_assignments_prevent_delete
before delete on public.generator_assignments
for each row execute function private.prevent_operational_delete();

create trigger controllers_prevent_delete
before delete on public.controllers
for each row execute function private.prevent_operational_delete();

create trigger clients_audit_operational_change
after insert or update on public.clients
for each row execute function private.audit_operational_change();

create trigger profiles_audit_operational_change
after insert or update on public.profiles
for each row execute function private.audit_operational_change();

create trigger locations_audit_operational_change
after insert or update on public.locations
for each row execute function private.audit_operational_change();

create trigger cold_rooms_audit_operational_change
after insert or update on public.cold_rooms
for each row execute function private.audit_operational_change();

create trigger generators_audit_operational_change
after insert or update on public.generators
for each row execute function private.audit_operational_change();

create trigger generator_assignments_audit_operational_change
after insert or update on public.generator_assignments
for each row execute function private.audit_operational_change();

create trigger controllers_audit_operational_change
after insert or update on public.controllers
for each row execute function private.audit_operational_change();

grant select on table
  public.generator_assignments,
  public.controllers
to authenticated;

grant insert, update on table
  public.clients,
  public.profiles,
  public.locations,
  public.cold_rooms,
  public.generators,
  public.generator_assignments,
  public.controllers
to authenticated;

grant usage, select on sequence public.generator_assignments_id_seq
to authenticated;

create policy generator_assignments_select_master
on public.generator_assignments
for select
to authenticated
using ((select private.is_active_master()));

create policy controllers_select_master
on public.controllers
for select
to authenticated
using ((select private.is_active_master()));

create policy clients_insert_master
on public.clients
for insert
to authenticated
with check ((select private.is_active_master()));

create policy clients_update_master
on public.clients
for update
to authenticated
using ((select private.is_active_master()))
with check ((select private.is_active_master()));

create policy profiles_insert_master
on public.profiles
for insert
to authenticated
with check ((select private.is_active_master()));

create policy profiles_update_master
on public.profiles
for update
to authenticated
using ((select private.is_active_master()))
with check ((select private.is_active_master()));

create policy locations_insert_master
on public.locations
for insert
to authenticated
with check ((select private.is_active_master()));

create policy locations_update_master
on public.locations
for update
to authenticated
using ((select private.is_active_master()))
with check ((select private.is_active_master()));

create policy cold_rooms_insert_master
on public.cold_rooms
for insert
to authenticated
with check ((select private.is_active_master()));

create policy cold_rooms_update_master
on public.cold_rooms
for update
to authenticated
using ((select private.is_active_master()))
with check ((select private.is_active_master()));

create policy generators_insert_master
on public.generators
for insert
to authenticated
with check ((select private.is_active_master()));

create policy generators_update_master
on public.generators
for update
to authenticated
using ((select private.is_active_master()))
with check ((select private.is_active_master()));

create policy generator_assignments_insert_master
on public.generator_assignments
for insert
to authenticated
with check ((select private.is_active_master()));

create policy generator_assignments_update_master
on public.generator_assignments
for update
to authenticated
using ((select private.is_active_master()))
with check ((select private.is_active_master()));

create policy controllers_insert_master
on public.controllers
for insert
to authenticated
with check ((select private.is_active_master()));

create policy controllers_update_master
on public.controllers
for update
to authenticated
using ((select private.is_active_master()))
with check ((select private.is_active_master()));

create or replace function public.register_generator(
  p_client_id uuid,
  p_location_id uuid,
  p_cold_room_id uuid,
  p_identifier text,
  p_valid_from date
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  new_generator_id uuid;
  location_time_zone text;
  assignment_start timestamptz;
begin
  if btrim(coalesce(p_identifier, '')) = '' or p_valid_from is null then
    raise exception 'identificação e data inicial são obrigatórias'
      using errcode = '23514', constraint = 'register_generator_required_fields';
  end if;

  select location.time_zone
  into location_time_zone
  from public.cold_rooms as cold_room
  join public.locations as location
    on location.id = cold_room.location_id
    and location.client_id = cold_room.client_id
  join public.clients as client on client.id = cold_room.client_id
  where cold_room.id = p_cold_room_id
    and cold_room.location_id = p_location_id
    and cold_room.client_id = p_client_id
    and client.is_active
    and location.is_active
    and cold_room.is_active;

  if not found then
    raise exception 'selecione uma câmara ativa e coerente com o cliente'
      using errcode = '23514', constraint = 'register_generator_active_hierarchy';
  end if;

  assignment_start = p_valid_from::timestamp at time zone location_time_zone;

  insert into public.generators (client_id, identifier)
  values (p_client_id, btrim(p_identifier))
  returning id into new_generator_id;

  insert into public.generator_assignments (
    generator_id,
    client_id,
    location_id,
    cold_room_id,
    valid_from
  )
  values (
    new_generator_id,
    p_client_id,
    p_location_id,
    p_cold_room_id,
    assignment_start
  );

  return new_generator_id;
end;
$$;

create or replace function public.reassign_generator(
  p_generator_id uuid,
  p_location_id uuid,
  p_cold_room_id uuid,
  p_effective_on date
)
returns bigint
language plpgsql
security invoker
set search_path = ''
as $$
declare
  generator_client_id uuid;
  current_assignment_id bigint;
  current_cold_room_id uuid;
  current_valid_from timestamptz;
  location_time_zone text;
  effective_at timestamptz;
  new_assignment_id bigint;
begin
  if p_effective_on is null then
    raise exception 'a data efetiva é obrigatória'
      using errcode = '23514', constraint = 'reassign_generator_effective_date';
  end if;

  select generator.client_id
  into generator_client_id
  from public.generators as generator
  join public.clients as client on client.id = generator.client_id
  where generator.id = p_generator_id
    and generator.is_active
    and client.is_active
  for update of generator;

  if not found then
    raise exception 'gerador ativo não encontrado'
      using errcode = '23514', constraint = 'reassign_generator_active_generator';
  end if;

  select assignment.id, assignment.cold_room_id, assignment.valid_from
  into current_assignment_id, current_cold_room_id, current_valid_from
  from public.generator_assignments as assignment
  where assignment.generator_id = p_generator_id
    and assignment.valid_until is null
  for update;

  if not found then
    raise exception 'o gerador não possui alocação ativa'
      using errcode = '23514', constraint = 'reassign_generator_current_assignment';
  end if;

  if current_cold_room_id = p_cold_room_id then
    raise exception 'selecione uma câmara diferente da alocação atual'
      using errcode = '23514', constraint = 'reassign_generator_different_room';
  end if;

  select location.time_zone
  into location_time_zone
  from public.cold_rooms as cold_room
  join public.locations as location
    on location.id = cold_room.location_id
    and location.client_id = cold_room.client_id
  where cold_room.id = p_cold_room_id
    and cold_room.location_id = p_location_id
    and cold_room.client_id = generator_client_id
    and cold_room.is_active
    and location.is_active;

  if not found then
    raise exception 'a câmara de destino deve estar ativa e pertencer ao mesmo cliente'
      using errcode = '23514', constraint = 'reassign_generator_active_hierarchy';
  end if;

  effective_at = p_effective_on::timestamp at time zone location_time_zone;

  if effective_at <= current_valid_from then
    raise exception 'a data efetiva deve ser posterior ao início da alocação atual'
      using errcode = '23514', constraint = 'reassign_generator_period';
  end if;

  update public.generator_assignments
  set valid_until = effective_at
  where id = current_assignment_id;

  insert into public.generator_assignments (
    generator_id,
    client_id,
    location_id,
    cold_room_id,
    valid_from
  )
  values (
    p_generator_id,
    generator_client_id,
    p_location_id,
    p_cold_room_id,
    effective_at
  )
  returning id into new_assignment_id;

  return new_assignment_id;
end;
$$;

create or replace function public.register_controller(
  p_generator_id uuid,
  p_identifier text,
  p_activated_on date
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  generator_client_id uuid;
  location_time_zone text;
  activated_at_value timestamptz;
  new_controller_id uuid;
begin
  if btrim(coalesce(p_identifier, '')) = '' or p_activated_on is null then
    raise exception 'identificação e data de ativação são obrigatórias'
      using errcode = '23514', constraint = 'register_controller_required_fields';
  end if;

  select generator.client_id, location.time_zone
  into generator_client_id, location_time_zone
  from public.generators as generator
  join public.clients as client on client.id = generator.client_id
  join public.generator_assignments as assignment
    on assignment.generator_id = generator.id
    and assignment.valid_until is null
  join public.locations as location on location.id = assignment.location_id
  join public.cold_rooms as cold_room on cold_room.id = assignment.cold_room_id
  where generator.id = p_generator_id
    and generator.is_active
    and client.is_active
    and location.is_active
    and cold_room.is_active
  for update of generator;

  if not found then
    raise exception 'o gerador precisa estar ativo e alocado em uma câmara ativa'
      using errcode = '23514', constraint = 'register_controller_active_generator';
  end if;

  if exists (
    select 1
    from public.controllers as controller
    where controller.generator_id = p_generator_id
      and controller.deactivated_at is null
  ) then
    raise exception 'substitua o controlador ativo em vez de criar outro'
      using errcode = '23514', constraint = 'register_controller_existing_active';
  end if;

  activated_at_value = p_activated_on::timestamp at time zone location_time_zone;

  insert into public.controllers (
    client_id,
    generator_id,
    identifier,
    activated_at
  )
  values (
    generator_client_id,
    p_generator_id,
    btrim(p_identifier),
    activated_at_value
  )
  returning id into new_controller_id;

  return new_controller_id;
end;
$$;

create or replace function public.replace_controller(
  p_generator_id uuid,
  p_identifier text,
  p_activated_on date
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  generator_client_id uuid;
  location_time_zone text;
  current_controller_id uuid;
  current_activated_at timestamptz;
  activated_at_value timestamptz;
  new_controller_id uuid;
begin
  if btrim(coalesce(p_identifier, '')) = '' or p_activated_on is null then
    raise exception 'identificação e data de ativação são obrigatórias'
      using errcode = '23514', constraint = 'replace_controller_required_fields';
  end if;

  select generator.client_id, location.time_zone
  into generator_client_id, location_time_zone
  from public.generators as generator
  join public.clients as client on client.id = generator.client_id
  join public.generator_assignments as assignment
    on assignment.generator_id = generator.id
    and assignment.valid_until is null
  join public.locations as location on location.id = assignment.location_id
  join public.cold_rooms as cold_room on cold_room.id = assignment.cold_room_id
  where generator.id = p_generator_id
    and generator.is_active
    and client.is_active
    and location.is_active
    and cold_room.is_active
  for update of generator;

  if not found then
    raise exception 'o gerador precisa estar ativo e alocado em uma câmara ativa'
      using errcode = '23514', constraint = 'replace_controller_active_generator';
  end if;

  select controller.id, controller.activated_at
  into current_controller_id, current_activated_at
  from public.controllers as controller
  where controller.generator_id = p_generator_id
    and controller.deactivated_at is null
  for update;

  if not found then
    raise exception 'o gerador não possui controlador ativo para substituir'
      using errcode = '23514', constraint = 'replace_controller_current_controller';
  end if;

  activated_at_value = p_activated_on::timestamp at time zone location_time_zone;

  if activated_at_value <= current_activated_at then
    raise exception 'a ativação do novo controlador deve ser posterior à atual'
      using errcode = '23514', constraint = 'replace_controller_period';
  end if;

  update public.controllers
  set
    deactivated_at = activated_at_value,
    is_active = false
  where id = current_controller_id;

  insert into public.controllers (
    client_id,
    generator_id,
    identifier,
    activated_at
  )
  values (
    generator_client_id,
    p_generator_id,
    btrim(p_identifier),
    activated_at_value
  )
  returning id into new_controller_id;

  return new_controller_id;
end;
$$;

create or replace function public.deactivate_controller(
  p_controller_id uuid,
  p_deactivated_on date
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  current_activated_at timestamptz;
  location_time_zone text;
  deactivated_at_value timestamptz;
begin
  if p_deactivated_on is null then
    raise exception 'a data de desativação é obrigatória'
      using errcode = '23514', constraint = 'deactivate_controller_required_date';
  end if;

  select controller.activated_at, location.time_zone
  into current_activated_at, location_time_zone
  from public.controllers as controller
  join public.generator_assignments as assignment
    on assignment.generator_id = controller.generator_id
    and assignment.valid_until is null
  join public.locations as location on location.id = assignment.location_id
  where controller.id = p_controller_id
    and controller.deactivated_at is null
  for update of controller;

  if not found then
    raise exception 'controlador ativo não encontrado'
      using errcode = '23514', constraint = 'deactivate_controller_active';
  end if;

  deactivated_at_value = p_deactivated_on::timestamp at time zone location_time_zone;

  if deactivated_at_value <= current_activated_at then
    raise exception 'a desativação deve ser posterior à ativação'
      using errcode = '23514', constraint = 'deactivate_controller_period';
  end if;

  update public.controllers
  set
    deactivated_at = deactivated_at_value,
    is_active = false
  where id = p_controller_id;
end;
$$;

create or replace function public.reactivate_controller(p_controller_id uuid)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  update public.controllers
  set
    deactivated_at = null,
    is_active = true
  where id = p_controller_id
    and not is_active;

  if not found then
    raise exception 'controlador inativo não encontrado'
      using errcode = '23514', constraint = 'reactivate_controller_inactive';
  end if;
end;
$$;

revoke all on function public.register_generator(uuid, uuid, uuid, text, date)
from public, anon;
revoke all on function public.reassign_generator(uuid, uuid, uuid, date)
from public, anon;
revoke all on function public.register_controller(uuid, text, date)
from public, anon;
revoke all on function public.replace_controller(uuid, text, date)
from public, anon;
revoke all on function public.deactivate_controller(uuid, date)
from public, anon;
revoke all on function public.reactivate_controller(uuid)
from public, anon;

grant execute on function public.register_generator(uuid, uuid, uuid, text, date)
to authenticated;
grant execute on function public.reassign_generator(uuid, uuid, uuid, date)
to authenticated;
grant execute on function public.register_controller(uuid, text, date)
to authenticated;
grant execute on function public.replace_controller(uuid, text, date)
to authenticated;
grant execute on function public.deactivate_controller(uuid, date)
to authenticated;
grant execute on function public.reactivate_controller(uuid)
to authenticated;
