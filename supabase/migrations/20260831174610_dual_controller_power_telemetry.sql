-- Spec 10: two independent controller roles and power telemetry.
-- This migration is intentionally additive. Legacy RPC signatures remain valid.

alter table public.generators
add column telemetry_status text not null default 'telemetry_pending';

alter table public.generators
add constraint generators_telemetry_status_check check (
  telemetry_status in ('telemetry_pending', 'ready')
);

alter table public.controllers
add column role text not null default 'state',
add column external_device_id text,
add column external_device_id_normalized text generated always as (
  lower(btrim(external_device_id))
) stored,
add column power_on_threshold_w numeric(12, 3),
add column power_off_threshold_w numeric(12, 3),
add column correlation_tolerance_seconds integer;

alter table public.controllers
add constraint controllers_role_check check (
  role in ('state', 'power_telemetry')
),
add constraint controllers_role_configuration_check check (
  (
    role = 'state'
    and external_device_id is null
    and power_on_threshold_w is null
    and power_off_threshold_w is null
    and correlation_tolerance_seconds is null
  )
  or (
    role = 'power_telemetry'
    and btrim(coalesce(external_device_id, '')) <> ''
    and power_on_threshold_w is not null
    and power_off_threshold_w is not null
    and power_off_threshold_w >= 0
    and power_off_threshold_w < power_on_threshold_w
    and correlation_tolerance_seconds between 0 and 86400
  )
);

alter table public.controllers
drop constraint controllers_no_overlap;

alter table public.controllers
add constraint controllers_role_no_overlap exclude using gist (
  generator_id with =,
  role with =,
  tstzrange(
    activated_at,
    coalesce(deactivated_at, 'infinity'::timestamptz),
    '[)'
  ) with &&
) deferrable initially immediate;

alter table public.controllers
add constraint controllers_external_device_no_overlap exclude using gist (
  external_device_id_normalized with =,
  tstzrange(
    activated_at,
    coalesce(deactivated_at, 'infinity'::timestamptz),
    '[)'
  ) with &&
) where (role = 'power_telemetry')
deferrable initially immediate;

create index controllers_generator_role_period_idx
on public.controllers (generator_id, role, activated_at, deactivated_at);

alter table public.import_batches
add column data_kind text not null default 'state_events';

alter table public.import_batches
add constraint import_batches_data_kind_check check (
  data_kind in ('state_events', 'power_readings')
);

create table public.power_readings (
  id bigint generated always as identity primary key,
  import_batch_id uuid not null,
  client_id uuid not null,
  location_id uuid not null,
  cold_room_id uuid not null,
  generator_id uuid not null,
  controller_id uuid not null,
  occurred_at timestamptz not null,
  occurred_at_raw text not null,
  power_w numeric(14, 3) not null,
  power_raw text not null,
  device_name text not null,
  device_id text not null,
  device_id_normalized text not null,
  event_type text not null,
  event_name text not null,
  event_detail text not null,
  request_from text not null default '',
  source_detail text not null default '',
  fingerprint text not null,
  created_at timestamptz not null default now(),
  constraint power_readings_power_check check (power_w >= 0),
  constraint power_readings_required_values_check check (
    btrim(occurred_at_raw) <> ''
    and btrim(power_raw) <> ''
    and btrim(device_name) <> ''
    and btrim(device_id) <> ''
    and btrim(device_id_normalized) <> ''
    and device_id_normalized = lower(btrim(device_id))
    and lower(btrim(event_type)) = 'report'
    and lower(btrim(event_name)) = 'power'
  ),
  constraint power_readings_fingerprint_format check (
    fingerprint ~ '^[0-9a-f]{64}$'
  ),
  constraint power_readings_fingerprint_key unique (fingerprint),
  constraint power_readings_id_generator_key unique (id, generator_id),
  constraint power_readings_id_context_key unique (
    id,
    generator_id,
    controller_id
  ),
  constraint power_readings_batch_context_fkey foreign key (
    import_batch_id,
    generator_id,
    controller_id
  ) references public.import_batches (
    id,
    generator_id,
    controller_id
  ),
  constraint power_readings_cold_room_context_fkey foreign key (
    cold_room_id,
    client_id,
    location_id
  ) references public.cold_rooms (
    id,
    client_id,
    location_id
  ),
  constraint power_readings_generator_context_fkey foreign key (
    generator_id,
    client_id
  ) references public.generators (
    id,
    client_id
  ),
  constraint power_readings_controller_context_fkey foreign key (
    controller_id,
    client_id,
    generator_id
  ) references public.controllers (
    id,
    client_id,
    generator_id
  )
);

create index power_readings_batch_idx
on public.power_readings (import_batch_id);

create index power_readings_generator_occurred_idx
on public.power_readings (generator_id, occurred_at, fingerprint);

create index power_readings_controller_occurred_idx
on public.power_readings (controller_id, occurred_at, fingerprint);

create table public.application_power_verifications (
  application_id bigint primary key references public.applications (id) on delete cascade,
  generator_id uuid not null references public.generators (id),
  controller_id uuid references public.controllers (id),
  power_on_reading_id bigint,
  power_off_reading_id bigint,
  status text not null,
  technical_reason text not null,
  source_updated_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint application_power_verifications_status_check check (
    status in (
      'verified',
      'missing_power_on',
      'missing_power_off',
      'missing_power_both',
      'no_coverage'
    )
  ),
  constraint application_power_verifications_reason_nonempty check (
    btrim(technical_reason) <> ''
  ),
  constraint application_power_verifications_on_context_fkey foreign key (
    power_on_reading_id,
    generator_id,
    controller_id
  ) references public.power_readings (
    id,
    generator_id,
    controller_id
  ),
  constraint application_power_verifications_off_context_fkey foreign key (
    power_off_reading_id,
    generator_id,
    controller_id
  ) references public.power_readings (
    id,
    generator_id,
    controller_id
  )
);

create index application_power_verifications_generator_status_idx
on public.application_power_verifications (generator_id, status);

create unique index application_power_verifications_on_reading_key
on public.application_power_verifications (power_on_reading_id)
where power_on_reading_id is not null;

create unique index application_power_verifications_off_reading_key
on public.application_power_verifications (power_off_reading_id)
where power_off_reading_id is not null;

drop index public.inconsistencies_derivation_key_idx;

alter table public.inconsistencies
alter column event_id drop not null;

alter table public.inconsistencies
add column application_id bigint references public.applications (id) on delete cascade,
add column power_reading_id bigint,
add constraint inconsistencies_power_reading_generator_fkey foreign key (
  power_reading_id,
  generator_id
) references public.power_readings (
  id,
  generator_id
) on delete cascade;

alter table public.inconsistencies
drop constraint inconsistencies_type_check,
drop constraint inconsistencies_distinct_events_check;

alter table public.inconsistencies
add constraint inconsistencies_type_check check (
  type in (
    'unmatched_turn_on',
    'unmatched_turn_off',
    'consecutive_turn_on',
    'controller_mismatch',
    'unknown_source',
    'invalid_sequence',
    'missing_power_on',
    'missing_power_off',
    'missing_power_both',
    'unexpected_power'
  )
),
add constraint inconsistencies_distinct_events_check check (
  related_event_id is null
  or event_id is null
  or related_event_id <> event_id
),
add constraint inconsistencies_source_check check (
  event_id is not null
  or application_id is not null
  or power_reading_id is not null
);

create unique index inconsistencies_state_derivation_key_idx
on public.inconsistencies (
  generator_id,
  event_id,
  related_event_id,
  type,
  public_date
)
nulls not distinct
where event_id is not null and type not like 'missing_power_%';

create unique index inconsistencies_application_power_key_idx
on public.inconsistencies (application_id, type)
where application_id is not null and type like 'missing_power_%';

create unique index inconsistencies_unexpected_power_key_idx
on public.inconsistencies (power_reading_id, type)
where power_reading_id is not null and type = 'unexpected_power';

create index inconsistencies_application_id_idx
on public.inconsistencies (application_id)
where application_id is not null;

create index inconsistencies_power_reading_id_idx
on public.inconsistencies (power_reading_id)
where power_reading_id is not null;

alter table public.client_daily_status
add column power_evidence_status text not null default 'not_applicable';

alter table public.client_daily_status
add constraint client_daily_status_power_evidence_check check (
  power_evidence_status in (
    'confirmed',
    'requires_review',
    'partial',
    'unavailable',
    'not_applicable'
  )
);

alter table public.power_readings enable row level security;
alter table public.application_power_verifications enable row level security;

revoke all on table
  public.power_readings,
  public.application_power_verifications
from public, anon, authenticated;

grant select, insert, update, delete on table
  public.power_readings,
  public.application_power_verifications
to service_role;

revoke all on sequence public.power_readings_id_seq
from public, anon, authenticated;

grant usage, select on sequence public.power_readings_id_seq
to service_role;

grant select, insert on table public.power_readings to authenticated;
grant select on table public.application_power_verifications to authenticated;
grant usage, select on sequence public.power_readings_id_seq to authenticated;

create policy power_readings_select_master
on public.power_readings
for select
to authenticated
using ((select private.is_active_master()));

create policy power_readings_insert_master
on public.power_readings
for insert
to authenticated
with check (
  (select private.is_active_master())
  and exists (
    select 1
    from public.import_batches as batch
    join public.controllers as controller
      on controller.id = batch.controller_id
      and controller.generator_id = batch.generator_id
      and controller.client_id = batch.client_id
    where batch.id = power_readings.import_batch_id
      and batch.client_id = power_readings.client_id
      and batch.location_id = power_readings.location_id
      and batch.cold_room_id = power_readings.cold_room_id
      and batch.generator_id = power_readings.generator_id
      and batch.controller_id = power_readings.controller_id
      and batch.data_kind = 'power_readings'
      and controller.role = 'power_telemetry'
  )
);

create policy application_power_verifications_select_master
on public.application_power_verifications
for select
to authenticated
using ((select private.is_active_master()));

create or replace function private.refresh_generator_telemetry_status(
  p_generator_id uuid
)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.generators as generator
  set telemetry_status = case
    when exists (
      select 1
      from public.controllers as controller
      where controller.generator_id = p_generator_id
        and controller.role = 'state'
        and controller.is_active
        and controller.deactivated_at is null
    ) and exists (
      select 1
      from public.controllers as controller
      where controller.generator_id = p_generator_id
        and controller.role = 'power_telemetry'
        and controller.is_active
        and controller.deactivated_at is null
    ) then 'ready'
    else 'telemetry_pending'
  end
  where generator.id = p_generator_id;
$$;

revoke all on function private.refresh_generator_telemetry_status(uuid)
from public, anon, authenticated;

create or replace function private.sync_generator_telemetry_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.refresh_generator_telemetry_status(
    coalesce(new.generator_id, old.generator_id)
  );

  if tg_op = 'UPDATE' and new.generator_id is distinct from old.generator_id then
    perform private.refresh_generator_telemetry_status(old.generator_id);
  end if;

  return coalesce(new, old);
end;
$$;

revoke all on function private.sync_generator_telemetry_status()
from public, anon, authenticated;

create trigger controllers_sync_generator_telemetry_status
after insert or update or delete on public.controllers
for each row execute function private.sync_generator_telemetry_status();

create or replace function private.validate_import_batch_data_kind()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  selected_role text;
begin
  select controller.role
  into selected_role
  from public.controllers as controller
  where controller.id = new.controller_id
    and controller.generator_id = new.generator_id
    and controller.client_id = new.client_id;

  if not found
    or (new.data_kind = 'state_events' and selected_role <> 'state')
    or (new.data_kind = 'power_readings' and selected_role <> 'power_telemetry') then
    raise exception 'o formato do lote é incompatível com o papel do controlador'
      using errcode = '23514',
        constraint = 'import_batches_controller_role';
  end if;

  if tg_op = 'UPDATE' and new.data_kind is distinct from old.data_kind then
    raise exception 'o tipo de dados do lote é imutável'
      using errcode = '23514',
        constraint = 'import_batches_data_kind_immutable';
  end if;

  return new;
end;
$$;

revoke all on function private.validate_import_batch_data_kind()
from public, anon, authenticated;

create trigger import_batches_validate_data_kind
before insert or update of data_kind, controller_id, generator_id, client_id
on public.import_batches
for each row execute function private.validate_import_batch_data_kind();

create or replace function public.register_controller_v2(
  p_generator_id uuid,
  p_role text,
  p_identifier text,
  p_activated_on date,
  p_external_device_id text default null,
  p_power_on_threshold_w numeric default null,
  p_power_off_threshold_w numeric default null,
  p_correlation_tolerance_seconds integer default null
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
  if p_role not in ('state', 'power_telemetry') then
    raise exception 'papel de controlador inválido'
      using errcode = '23514', constraint = 'register_controller_v2_role';
  end if;

  if btrim(coalesce(p_identifier, '')) = '' or p_activated_on is null then
    raise exception 'identificação e data de ativação são obrigatórias'
      using errcode = '23514', constraint = 'register_controller_v2_required_fields';
  end if;

  if p_role = 'state' and (
    p_external_device_id is not null
    or p_power_on_threshold_w is not null
    or p_power_off_threshold_w is not null
    or p_correlation_tolerance_seconds is not null
  ) then
    raise exception 'controlador de estado não recebe configuração de potência'
      using errcode = '23514', constraint = 'register_controller_v2_state_config';
  end if;

  if p_role = 'power_telemetry' and (
    btrim(coalesce(p_external_device_id, '')) = ''
    or p_power_on_threshold_w is null
    or p_power_off_threshold_w is null
    or p_power_off_threshold_w < 0
    or p_power_off_threshold_w >= p_power_on_threshold_w
    or p_correlation_tolerance_seconds not between 0 and 86400
  ) then
    raise exception 'informe Device ID, limites válidos e tolerância da telemetria'
      using errcode = '23514', constraint = 'register_controller_v2_power_config';
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
      using errcode = '23514', constraint = 'register_controller_v2_active_generator';
  end if;

  if exists (
    select 1
    from public.controllers as controller
    where controller.generator_id = p_generator_id
      and controller.role = p_role
      and controller.deactivated_at is null
  ) then
    raise exception 'substitua o controlador ativo deste papel em vez de criar outro'
      using errcode = '23514', constraint = 'register_controller_v2_existing_active';
  end if;

  activated_at_value = p_activated_on::timestamp at time zone location_time_zone;

  insert into public.controllers (
    client_id,
    generator_id,
    role,
    identifier,
    external_device_id,
    power_on_threshold_w,
    power_off_threshold_w,
    correlation_tolerance_seconds,
    activated_at
  )
  values (
    generator_client_id,
    p_generator_id,
    p_role,
    btrim(p_identifier),
    case when p_role = 'power_telemetry' then btrim(p_external_device_id) end,
    p_power_on_threshold_w,
    p_power_off_threshold_w,
    p_correlation_tolerance_seconds,
    activated_at_value
  )
  returning id into new_controller_id;

  return new_controller_id;
end;
$$;

create or replace function public.replace_controller_v2(
  p_generator_id uuid,
  p_role text,
  p_identifier text,
  p_activated_on date,
  p_external_device_id text default null,
  p_power_on_threshold_w numeric default null,
  p_power_off_threshold_w numeric default null,
  p_correlation_tolerance_seconds integer default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  current_controller_id uuid;
  current_activated_at timestamptz;
  location_time_zone text;
  activated_at_value timestamptz;
  new_controller_id uuid;
begin
  select controller.id, controller.activated_at, location.time_zone
  into current_controller_id, current_activated_at, location_time_zone
  from public.controllers as controller
  join public.generator_assignments as assignment
    on assignment.generator_id = controller.generator_id
    and assignment.valid_until is null
  join public.locations as location on location.id = assignment.location_id
  where controller.generator_id = p_generator_id
    and controller.role = p_role
    and controller.deactivated_at is null
  for update of controller;

  if not found then
    raise exception 'o gerador não possui controlador ativo deste papel'
      using errcode = '23514', constraint = 'replace_controller_v2_current_controller';
  end if;

  activated_at_value = p_activated_on::timestamp at time zone location_time_zone;

  if activated_at_value <= current_activated_at then
    raise exception 'a ativação do novo controlador deve ser posterior à atual'
      using errcode = '23514', constraint = 'replace_controller_v2_period';
  end if;

  update public.controllers
  set deactivated_at = activated_at_value, is_active = false
  where id = current_controller_id;

  new_controller_id := public.register_controller_v2(
    p_generator_id,
    p_role,
    p_identifier,
    p_activated_on,
    p_external_device_id,
    p_power_on_threshold_w,
    p_power_off_threshold_w,
    p_correlation_tolerance_seconds
  );

  return new_controller_id;
end;
$$;

create or replace function public.register_generator_v2(
  p_client_id uuid,
  p_location_id uuid,
  p_cold_room_id uuid,
  p_identifier text,
  p_valid_from date,
  p_state_controller_identifier text,
  p_state_controller_activated_on date,
  p_power_controller_identifier text,
  p_power_controller_device_id text,
  p_power_controller_activated_on date,
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
begin
  if p_state_controller_activated_on < p_valid_from
    or p_power_controller_activated_on < p_valid_from then
    raise exception 'controladores não podem iniciar antes da alocação do gerador'
      using errcode = '23514', constraint = 'register_generator_v2_controller_period';
  end if;

  new_generator_id := public.register_generator(
    p_client_id,
    p_location_id,
    p_cold_room_id,
    p_identifier,
    p_valid_from
  );

  perform public.register_controller_v2(
    new_generator_id,
    'state',
    p_state_controller_identifier,
    p_state_controller_activated_on
  );

  perform public.register_controller_v2(
    new_generator_id,
    'power_telemetry',
    p_power_controller_identifier,
    p_power_controller_activated_on,
    p_power_controller_device_id,
    p_power_on_threshold_w,
    p_power_off_threshold_w,
    p_correlation_tolerance_seconds
  );

  return new_generator_id;
end;
$$;

create or replace function public.register_complete_client_structure_v2(
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
  generator_id_value uuid;
  power_controller_id uuid;
begin
  structure := public.register_complete_client_structure(
    p_client_legal_name,
    p_client_cnpj,
    p_location_name,
    p_location_description,
    p_location_time_zone,
    p_cold_room_name,
    p_cold_room_category,
    p_generator_identifier,
    p_generator_valid_from,
    p_state_controller_identifier,
    p_state_controller_activated_on
  );

  generator_id_value := (structure ->> 'generator_id')::uuid;
  power_controller_id := public.register_controller_v2(
    generator_id_value,
    'power_telemetry',
    p_power_controller_identifier,
    p_power_controller_activated_on,
    p_power_controller_device_id,
    p_power_on_threshold_w,
    p_power_off_threshold_w,
    p_correlation_tolerance_seconds
  );

  return structure
    || jsonb_build_object(
      'state_controller_id', structure -> 'controller_id',
      'power_controller_id', power_controller_id
    );
end;
$$;

revoke all on function public.register_controller_v2(
  uuid, text, text, date, text, numeric, numeric, integer
) from public, anon;
revoke all on function public.replace_controller_v2(
  uuid, text, text, date, text, numeric, numeric, integer
) from public, anon;
revoke all on function public.register_generator_v2(
  uuid, uuid, uuid, text, date, text, date, text, text, date, numeric, numeric, integer
) from public, anon;
revoke all on function public.register_complete_client_structure_v2(
  text, text, text, text, text, text, text, text, date, text, date,
  text, text, date, numeric, numeric, integer
) from public, anon;

grant execute on function public.register_controller_v2(
  uuid, text, text, date, text, numeric, numeric, integer
) to authenticated;
grant execute on function public.replace_controller_v2(
  uuid, text, text, date, text, numeric, numeric, integer
) to authenticated;
grant execute on function public.register_generator_v2(
  uuid, uuid, uuid, text, date, text, date, text, text, date, numeric, numeric, integer
) to authenticated;
grant execute on function public.register_complete_client_structure_v2(
  text, text, text, text, text, text, text, text, date, text, date,
  text, text, date, numeric, numeric, integer
) to authenticated;

create or replace function public.existing_power_fingerprints(
  p_fingerprints text[]
)
returns table (fingerprint text)
language sql
stable
security invoker
set search_path = ''
as $$
  select reading.fingerprint
  from public.power_readings as reading
  where reading.fingerprint = any(coalesce(p_fingerprints, array[]::text[]));
$$;

create or replace function public.confirm_power_xlsx_import(
  p_client_id uuid,
  p_location_id uuid,
  p_cold_room_id uuid,
  p_generator_id uuid,
  p_controller_id uuid,
  p_file_name text,
  p_file_sha256 text,
  p_readings jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
  controller_activated_at timestamptz;
  controller_deactivated_at timestamptz;
  controller_device_id text;
  reading_count integer;
  inserted_count integer;
  first_reading_at timestamptz;
  last_reading_at timestamptz;
  target_batch_id uuid;
  target_batch_status text;
  stored_batch public.import_batches%rowtype;
begin
  if not (select private.is_active_master()) then
    raise exception 'somente o Master pode confirmar importações de potência'
      using errcode = '42501';
  end if;

  if btrim(coalesce(p_file_name, '')) = ''
    or coalesce(p_file_sha256, '') !~ '^[0-9a-f]{64}$' then
    raise exception 'arquivo ou hash inválido'
      using errcode = '23514', constraint = 'confirm_power_xlsx_import_file';
  end if;

  if jsonb_typeof(p_readings) is distinct from 'array' then
    raise exception 'a lista de leituras é inválida'
      using errcode = '23514', constraint = 'confirm_power_xlsx_import_readings';
  end if;

  select
    controller.activated_at,
    controller.deactivated_at,
    controller.external_device_id_normalized
  into
    controller_activated_at,
    controller_deactivated_at,
    controller_device_id
  from public.clients as client
  join public.locations as location
    on location.client_id = client.id
    and location.id = p_location_id
  join public.cold_rooms as cold_room
    on cold_room.client_id = client.id
    and cold_room.location_id = location.id
    and cold_room.id = p_cold_room_id
  join public.generator_assignments as assignment
    on assignment.client_id = client.id
    and assignment.location_id = location.id
    and assignment.cold_room_id = cold_room.id
    and assignment.generator_id = p_generator_id
    and assignment.valid_until is null
  join public.generators as generator
    on generator.client_id = client.id
    and generator.id = assignment.generator_id
  join public.controllers as controller
    on controller.client_id = client.id
    and controller.generator_id = generator.id
    and controller.id = p_controller_id
    and controller.role = 'power_telemetry'
  where client.id = p_client_id
    and client.is_active
    and location.is_active
    and cold_room.is_active
    and generator.is_active
    and controller.is_active;

  if not found then
    raise exception 'a hierarquia e o controlador de potência devem estar ativos e coerentes'
      using errcode = '23514', constraint = 'confirm_power_xlsx_import_hierarchy';
  end if;

  select count(*)::integer, min(reading.occurred_at), max(reading.occurred_at)
  into reading_count, first_reading_at, last_reading_at
  from jsonb_to_recordset(p_readings) as reading (
    occurred_at timestamptz,
    occurred_at_raw text,
    power_w numeric,
    power_raw text,
    device_name text,
    device_id text,
    device_id_normalized text,
    event_type text,
    event_name text,
    event_detail text,
    request_from text,
    source_detail text,
    fingerprint text
  );

  if reading_count < 1 or reading_count > 25000 then
    raise exception 'o arquivo deve conter entre 1 e 25.000 leituras'
      using errcode = '23514', constraint = 'confirm_power_xlsx_import_reading_count';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_readings) as reading (
      occurred_at timestamptz,
      occurred_at_raw text,
      power_w numeric,
      power_raw text,
      device_name text,
      device_id text,
      device_id_normalized text,
      event_type text,
      event_name text,
      event_detail text,
      request_from text,
      source_detail text,
      fingerprint text
    )
    where reading.occurred_at is null
      or btrim(coalesce(reading.occurred_at_raw, '')) = ''
      or reading.power_w is null
      or reading.power_w < 0
      or btrim(coalesce(reading.power_raw, '')) = ''
      or btrim(coalesce(reading.device_name, '')) = ''
      or lower(btrim(coalesce(reading.device_id, ''))) <> controller_device_id
      or reading.device_id_normalized <> controller_device_id
      or lower(btrim(coalesce(reading.event_type, ''))) <> 'report'
      or lower(btrim(coalesce(reading.event_name, ''))) <> 'power'
      or reading.fingerprint !~ '^[0-9a-f]{64}$'
      or reading.occurred_at < controller_activated_at
      or (
        controller_deactivated_at is not null
        and reading.occurred_at >= controller_deactivated_at
      )
  ) then
    raise exception 'uma ou mais leituras são inválidas, de outro dispositivo ou fora da vigência'
      using errcode = '23514', constraint = 'confirm_power_xlsx_import_values';
  end if;

  if (
    select count(distinct reading.device_id_normalized)
    from jsonb_to_recordset(p_readings) as reading (device_id_normalized text)
  ) <> 1 then
    raise exception 'o arquivo deve conter um único dispositivo'
      using errcode = '23514', constraint = 'confirm_power_xlsx_import_single_device';
  end if;

  insert into public.import_batches (
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
    period_start,
    period_end,
    created_by
  )
  values (
    p_client_id,
    p_location_id,
    p_cold_room_id,
    p_generator_id,
    p_controller_id,
    'power_readings',
    btrim(p_file_name),
    p_file_sha256,
    'processing',
    reading_count,
    first_reading_at,
    last_reading_at,
    current_user_id
  )
  on conflict (
    file_sha256,
    client_id,
    location_id,
    cold_room_id,
    generator_id,
    controller_id
  ) do nothing
  returning id, status into target_batch_id, target_batch_status;

  if target_batch_id is null then
    select batch.id, batch.status
    into target_batch_id, target_batch_status
    from public.import_batches as batch
    where batch.file_sha256 = p_file_sha256
      and batch.client_id = p_client_id
      and batch.location_id = p_location_id
      and batch.cold_room_id = p_cold_room_id
      and batch.generator_id = p_generator_id
      and batch.controller_id = p_controller_id
      and batch.data_kind = 'power_readings'
    for update;
  end if;

  if target_batch_status = 'confirmed' then
    select * into stored_batch
    from public.import_batches as batch
    where batch.id = target_batch_id;

    return jsonb_build_object(
      'batch_id', stored_batch.id,
      'status', stored_batch.status,
      'total_rows', stored_batch.total_rows,
      'inserted_rows', stored_batch.inserted_rows,
      'duplicate_rows', stored_batch.duplicate_rows,
      'unknown_source_rows', 0,
      'period_start', stored_batch.period_start,
      'period_end', stored_batch.period_end,
      'already_confirmed', true
    );
  end if;

  update public.import_batches
  set
    file_name = btrim(p_file_name),
    status = 'processing',
    total_rows = reading_count,
    inserted_rows = 0,
    duplicate_rows = 0,
    unknown_source_rows = 0,
    period_start = first_reading_at,
    period_end = last_reading_at,
    error_message = null,
    confirmed_at = null
  where id = target_batch_id;

  with inserted_readings as (
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
      target_batch_id,
      p_client_id,
      p_location_id,
      p_cold_room_id,
      p_generator_id,
      p_controller_id,
      reading.occurred_at,
      reading.occurred_at_raw,
      reading.power_w,
      reading.power_raw,
      reading.device_name,
      reading.device_id,
      reading.device_id_normalized,
      reading.event_type,
      reading.event_name,
      reading.event_detail,
      coalesce(reading.request_from, ''),
      coalesce(reading.source_detail, ''),
      reading.fingerprint
    from jsonb_to_recordset(p_readings) as reading (
      occurred_at timestamptz,
      occurred_at_raw text,
      power_w numeric,
      power_raw text,
      device_name text,
      device_id text,
      device_id_normalized text,
      event_type text,
      event_name text,
      event_detail text,
      request_from text,
      source_detail text,
      fingerprint text
    )
    on conflict (fingerprint) do nothing
    returning 1
  )
  select count(*)::integer into inserted_count from inserted_readings;

  update public.import_batches
  set
    status = 'confirmed',
    inserted_rows = inserted_count,
    duplicate_rows = reading_count - inserted_count,
    confirmed_at = now()
  where id = target_batch_id
  returning * into stored_batch;

  return jsonb_build_object(
    'batch_id', stored_batch.id,
    'status', stored_batch.status,
    'total_rows', stored_batch.total_rows,
    'inserted_rows', stored_batch.inserted_rows,
    'duplicate_rows', stored_batch.duplicate_rows,
    'unknown_source_rows', 0,
    'period_start', stored_batch.period_start,
    'period_end', stored_batch.period_end,
    'already_confirmed', false
  );
end;
$$;

create or replace function public.record_failed_power_xlsx_import(
  p_client_id uuid,
  p_location_id uuid,
  p_cold_room_id uuid,
  p_generator_id uuid,
  p_controller_id uuid,
  p_file_name text,
  p_file_sha256 text,
  p_error_message text
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  failed_batch_id uuid;
begin
  if not (select private.is_active_master()) then
    raise exception 'somente o Master pode registrar falhas de importação'
      using errcode = '42501';
  end if;

  insert into public.import_batches (
    client_id,
    location_id,
    cold_room_id,
    generator_id,
    controller_id,
    data_kind,
    file_name,
    file_sha256,
    status,
    error_message,
    created_by
  )
  values (
    p_client_id,
    p_location_id,
    p_cold_room_id,
    p_generator_id,
    p_controller_id,
    'power_readings',
    btrim(p_file_name),
    p_file_sha256,
    'failed',
    left(btrim(coalesce(p_error_message, 'Falha de persistência.')), 500),
    (select auth.uid())
  )
  on conflict (
    file_sha256,
    client_id,
    location_id,
    cold_room_id,
    generator_id,
    controller_id
  ) do update
  set
    status = 'failed',
    error_message = excluded.error_message,
    confirmed_at = null
  where import_batches.status <> 'confirmed'
  returning id into failed_batch_id;

  return failed_batch_id;
end;
$$;

revoke all on function public.existing_power_fingerprints(text[])
from public, anon;
revoke all on function public.confirm_power_xlsx_import(
  uuid, uuid, uuid, uuid, uuid, text, text, jsonb
) from public, anon;
revoke all on function public.record_failed_power_xlsx_import(
  uuid, uuid, uuid, uuid, uuid, text, text, text
) from public, anon;

grant execute on function public.existing_power_fingerprints(text[])
to authenticated;
grant execute on function public.confirm_power_xlsx_import(
  uuid, uuid, uuid, uuid, uuid, text, text, jsonb
) to authenticated;
grant execute on function public.record_failed_power_xlsx_import(
  uuid, uuid, uuid, uuid, uuid, text, text, text
) to authenticated;

create or replace function private.power_transitions(p_generator_id uuid)
returns table (
  reading_id bigint,
  controller_id uuid,
  occurred_at timestamptz,
  transition text
)
language sql
stable
security definer
set search_path = ''
as $$
  with ordered as (
    select
      reading.id,
      reading.controller_id,
      reading.occurred_at,
      reading.fingerprint,
      case
        when reading.power_w >= controller.power_on_threshold_w then 'on'
        when reading.power_w <= controller.power_off_threshold_w then 'off'
      end as observed_state
    from public.power_readings as reading
    join public.import_batches as batch
      on batch.id = reading.import_batch_id
      and batch.status = 'confirmed'
      and batch.data_kind = 'power_readings'
    join public.controllers as controller
      on controller.id = reading.controller_id
      and controller.generator_id = reading.generator_id
      and controller.role = 'power_telemetry'
      and reading.occurred_at >= controller.activated_at
      and (
        controller.deactivated_at is null
        or reading.occurred_at < controller.deactivated_at
      )
    where reading.generator_id = p_generator_id
  ),
  grouped as (
    select
      ordered.*,
      count(observed_state) over (
        partition by controller_id
        order by occurred_at, fingerprint
        rows between unbounded preceding and current row
      ) as state_group
    from ordered
  ),
  stable as (
    select
      grouped.*,
      max(observed_state) over (
        partition by controller_id, state_group
      ) as stable_state
    from grouped
  ),
  lagged as (
    select
      stable.*,
      lag(stable_state) over (
        partition by controller_id
        order by occurred_at, fingerprint
      ) as previous_state
    from stable
  )
  select
    lagged.id,
    lagged.controller_id,
    lagged.occurred_at,
    lagged.stable_state
  from lagged
  where (
    lagged.stable_state = 'on'
    and lagged.previous_state is distinct from 'on'
  ) or (
    lagged.stable_state = 'off'
    and lagged.previous_state = 'on'
  );
$$;

revoke all on function private.power_transitions(uuid)
from public, anon, authenticated;

create or replace function private.desired_power_verifications(
  p_generator_id uuid
)
returns table (
  application_id bigint,
  generator_id uuid,
  public_date date,
  start_event_id bigint,
  controller_id uuid,
  power_on_reading_id bigint,
  power_off_reading_id bigint,
  status text,
  technical_reason text,
  source_updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with transitions as materialized (
    select * from private.power_transitions(p_generator_id)
  ),
  application_context as (
    select
      application.id as application_id,
      application.generator_id,
      application.public_date,
      start_event.id as start_event_id,
      start_event.occurred_at as start_at,
      end_event.occurred_at as end_at,
      power_controller.id as controller_id,
      power_controller.correlation_tolerance_seconds as tolerance_seconds,
      coverage.source_updated_at as coverage_updated_at,
      coverage.has_coverage
    from public.applications as application
    join public.raw_events as start_event on start_event.id = application.start_event_id
    join public.raw_events as end_event on end_event.id = application.end_event_id
    left join lateral (
      select controller.*
      from public.controllers as controller
      where controller.generator_id = application.generator_id
        and controller.role = 'power_telemetry'
        and controller.activated_at <= start_event.occurred_at
        and (
          controller.deactivated_at is null
          or controller.deactivated_at > end_event.occurred_at
        )
      order by controller.activated_at desc, controller.id
      limit 1
    ) as power_controller on true
    left join lateral (
      select
        true as has_coverage,
        max(batch.period_end) as source_updated_at
      from public.import_batches as batch
      where batch.generator_id = application.generator_id
        and batch.controller_id = power_controller.id
        and batch.data_kind = 'power_readings'
        and batch.status = 'confirmed'
        and batch.period_start <= start_event.occurred_at
          + make_interval(secs => power_controller.correlation_tolerance_seconds)
        and batch.period_end >= end_event.occurred_at
          - make_interval(secs => power_controller.correlation_tolerance_seconds)
      having count(*) > 0
    ) as coverage on true
    where application.generator_id = p_generator_id
  ),
  on_candidate_winners as (
    select
      context.application_id,
      transition.reading_id,
      transition.occurred_at,
      row_number() over (
        partition by transition.reading_id
        order by
          abs(extract(epoch from transition.occurred_at - context.start_at)),
          context.application_id
      ) as transition_rank
    from application_context as context
    join transitions as transition
      on transition.controller_id = context.controller_id
      and transition.transition = 'on'
      and transition.occurred_at between
        context.start_at - make_interval(secs => context.tolerance_seconds)
        and context.start_at + make_interval(secs => context.tolerance_seconds)
    where context.has_coverage
  ),
  on_choices as (
    select
      winner.*,
      row_number() over (
        partition by winner.application_id
        order by
          abs(extract(epoch from winner.occurred_at - context.start_at)),
          winner.reading_id
      ) as application_rank
    from on_candidate_winners as winner
    join application_context as context
      on context.application_id = winner.application_id
    where winner.transition_rank = 1
  ),
  off_candidate_winners as (
    select
      context.application_id,
      transition.reading_id,
      transition.occurred_at,
      row_number() over (
        partition by transition.reading_id
        order by
          abs(extract(epoch from transition.occurred_at - context.end_at)),
          context.application_id
      ) as transition_rank
    from application_context as context
    join transitions as transition
      on transition.controller_id = context.controller_id
      and transition.transition = 'off'
      and transition.occurred_at between
        context.end_at - make_interval(secs => context.tolerance_seconds)
        and context.end_at + make_interval(secs => context.tolerance_seconds)
    where context.has_coverage
  ),
  off_choices as (
    select
      winner.*,
      row_number() over (
        partition by winner.application_id
        order by
          abs(extract(epoch from winner.occurred_at - context.end_at)),
          winner.reading_id
      ) as application_rank
    from off_candidate_winners as winner
    join application_context as context
      on context.application_id = winner.application_id
    where winner.transition_rank = 1
  )
  select
    context.application_id,
    context.generator_id,
    context.public_date,
    context.start_event_id,
    context.controller_id,
    case
      when on_choice.occurred_at < off_choice.occurred_at
        then on_choice.reading_id
      when off_choice.reading_id is null then on_choice.reading_id
    end,
    case
      when on_choice.occurred_at < off_choice.occurred_at
        then off_choice.reading_id
      when on_choice.reading_id is null then off_choice.reading_id
    end,
    case
      when context.controller_id is null or not coalesce(context.has_coverage, false)
        then 'no_coverage'
      when on_choice.occurred_at < off_choice.occurred_at then 'verified'
      when on_choice.reading_id is null and off_choice.reading_id is null
        then 'missing_power_both'
      when on_choice.reading_id is null then 'missing_power_on'
      when off_choice.reading_id is null then 'missing_power_off'
      else 'missing_power_both'
    end,
    case
      when context.controller_id is null then 'no_power_controller_for_application_period'
      when not coalesce(context.has_coverage, false) then 'application_outside_confirmed_power_coverage'
      when on_choice.occurred_at < off_choice.occurred_at then 'power_transitions_correlated'
      when on_choice.reading_id is null and off_choice.reading_id is null
        then 'on_and_off_transitions_not_found_within_tolerance'
      when on_choice.reading_id is null then 'on_transition_not_found_within_tolerance'
      when off_choice.reading_id is null then 'off_transition_not_found_within_tolerance'
      else 'transition_order_is_not_valid'
    end,
    greatest(
      context.end_at,
      context.coverage_updated_at,
      on_choice.occurred_at,
      off_choice.occurred_at
    )
  from application_context as context
  left join on_choices as on_choice
    on on_choice.application_id = context.application_id
    and on_choice.application_rank = 1
  left join off_choices as off_choice
    on off_choice.application_id = context.application_id
    and off_choice.application_rank = 1;
$$;

revoke all on function private.desired_power_verifications(uuid)
from public, anon, authenticated;

create or replace function private.unexpected_power_readings(
  p_generator_id uuid
)
returns table (
  power_reading_id bigint,
  generator_id uuid,
  public_date date
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    transition.reading_id,
    reading.generator_id,
    (reading.occurred_at at time zone location.time_zone)::date
  from private.power_transitions(p_generator_id) as transition
  join public.power_readings as reading on reading.id = transition.reading_id
  join public.import_batches as batch on batch.id = reading.import_batch_id
  join public.locations as location
    on location.id = batch.location_id
    and location.client_id = batch.client_id
  where transition.transition = 'on'
    and not exists (
      select 1
      from public.application_power_verifications as verification
      where verification.generator_id = p_generator_id
        and verification.power_on_reading_id = transition.reading_id
    );
$$;

revoke all on function private.unexpected_power_readings(uuid)
from public, anon, authenticated;

create or replace function private.reprocess_power_telemetry(p_generator_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.generators as generator
    where generator.id = p_generator_id
  ) then
    raise exception 'gerador não encontrado' using errcode = 'P0002';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_generator_id::text, 0)
  );

  /* Derivation moved to private.desired_power_verifications for concurrency
     safety and static database linting.
  drop table if exists pg_temp.spec10_desired_verifications;

  create temporary table spec10_desired_verifications
  on commit drop
  as
  with transitions as materialized (
    select * from private.power_transitions(p_generator_id)
  ),
  application_context as (
    select
      application.id as application_id,
      application.generator_id,
      application.public_date,
      start_event.id as start_event_id,
      start_event.occurred_at as start_at,
      end_event.occurred_at as end_at,
      power_controller.id as controller_id,
      power_controller.correlation_tolerance_seconds as tolerance_seconds,
      coverage.source_updated_at as coverage_updated_at,
      coverage.has_coverage
    from public.applications as application
    join public.raw_events as start_event on start_event.id = application.start_event_id
    join public.raw_events as end_event on end_event.id = application.end_event_id
    left join lateral (
      select controller.*
      from public.controllers as controller
      where controller.generator_id = application.generator_id
        and controller.role = 'power_telemetry'
        and controller.activated_at <= start_event.occurred_at
        and (
          controller.deactivated_at is null
          or controller.deactivated_at > end_event.occurred_at
        )
      order by controller.activated_at desc, controller.id
      limit 1
    ) as power_controller on true
    left join lateral (
      select
        true as has_coverage,
        max(batch.period_end) as source_updated_at
      from public.import_batches as batch
      where batch.generator_id = application.generator_id
        and batch.controller_id = power_controller.id
        and batch.data_kind = 'power_readings'
        and batch.status = 'confirmed'
        and batch.period_start <= start_event.occurred_at
          + make_interval(secs => power_controller.correlation_tolerance_seconds)
        and batch.period_end >= end_event.occurred_at
          - make_interval(secs => power_controller.correlation_tolerance_seconds)
      having count(*) > 0
    ) as coverage on true
    where application.generator_id = p_generator_id
  ),
  on_candidate_winners as (
    select
      context.application_id,
      transition.reading_id,
      transition.occurred_at,
      row_number() over (
        partition by transition.reading_id
        order by
          abs(extract(epoch from transition.occurred_at - context.start_at)),
          context.application_id
      ) as transition_rank
    from application_context as context
    join transitions as transition
      on transition.controller_id = context.controller_id
      and transition.transition = 'on'
      and transition.occurred_at between
        context.start_at - make_interval(secs => context.tolerance_seconds)
        and context.start_at + make_interval(secs => context.tolerance_seconds)
    where context.has_coverage
  ),
  on_choices as (
    select
      winner.*,
      row_number() over (
        partition by winner.application_id
        order by
          abs(extract(epoch from winner.occurred_at - context.start_at)),
          winner.reading_id
      ) as application_rank
    from on_candidate_winners as winner
    join application_context as context
      on context.application_id = winner.application_id
    where winner.transition_rank = 1
  ),
  off_candidate_winners as (
    select
      context.application_id,
      transition.reading_id,
      transition.occurred_at,
      row_number() over (
        partition by transition.reading_id
        order by
          abs(extract(epoch from transition.occurred_at - context.end_at)),
          context.application_id
      ) as transition_rank
    from application_context as context
    join transitions as transition
      on transition.controller_id = context.controller_id
      and transition.transition = 'off'
      and transition.occurred_at between
        context.end_at - make_interval(secs => context.tolerance_seconds)
        and context.end_at + make_interval(secs => context.tolerance_seconds)
    where context.has_coverage
  ),
  off_choices as (
    select
      winner.*,
      row_number() over (
        partition by winner.application_id
        order by
          abs(extract(epoch from winner.occurred_at - context.end_at)),
          winner.reading_id
      ) as application_rank
    from off_candidate_winners as winner
    join application_context as context
      on context.application_id = winner.application_id
    where winner.transition_rank = 1
  )
  select
    context.application_id,
    context.generator_id,
    context.public_date,
    context.start_event_id,
    context.controller_id,
    case
      when on_choice.occurred_at < off_choice.occurred_at
        then on_choice.reading_id
      when off_choice.reading_id is null then on_choice.reading_id
    end as power_on_reading_id,
    case
      when on_choice.occurred_at < off_choice.occurred_at
        then off_choice.reading_id
      when on_choice.reading_id is null then off_choice.reading_id
    end as power_off_reading_id,
    case
      when context.controller_id is null or not coalesce(context.has_coverage, false)
        then 'no_coverage'
      when on_choice.occurred_at < off_choice.occurred_at then 'verified'
      when on_choice.reading_id is null and off_choice.reading_id is null
        then 'missing_power_both'
      when on_choice.reading_id is null then 'missing_power_on'
      when off_choice.reading_id is null then 'missing_power_off'
      else 'missing_power_both'
    end as status,
    case
      when context.controller_id is null then 'no_power_controller_for_application_period'
      when not coalesce(context.has_coverage, false) then 'application_outside_confirmed_power_coverage'
      when on_choice.occurred_at < off_choice.occurred_at then 'power_transitions_correlated'
      when on_choice.reading_id is null and off_choice.reading_id is null
        then 'on_and_off_transitions_not_found_within_tolerance'
      when on_choice.reading_id is null then 'on_transition_not_found_within_tolerance'
      when off_choice.reading_id is null then 'off_transition_not_found_within_tolerance'
      else 'transition_order_is_not_valid'
    end as technical_reason,
    greatest(
      context.end_at,
      context.coverage_updated_at,
      on_choice.occurred_at,
      off_choice.occurred_at
    ) as source_updated_at
  from application_context as context
  left join on_choices as on_choice
    on on_choice.application_id = context.application_id
    and on_choice.application_rank = 1
  left join off_choices as off_choice
    on off_choice.application_id = context.application_id
    and off_choice.application_rank = 1;
  */

  delete from public.application_power_verifications as verification
  where verification.generator_id = p_generator_id
    and not exists (
      select 1
      from private.desired_power_verifications(p_generator_id) as desired
      where desired.application_id = verification.application_id
    );

  insert into public.application_power_verifications (
    application_id,
    generator_id,
    controller_id,
    power_on_reading_id,
    power_off_reading_id,
    status,
    technical_reason,
    source_updated_at,
    updated_at
  )
  select
    desired.application_id,
    desired.generator_id,
    desired.controller_id,
    desired.power_on_reading_id,
    desired.power_off_reading_id,
    desired.status,
    desired.technical_reason,
    desired.source_updated_at,
    desired.source_updated_at
  from private.desired_power_verifications(p_generator_id) as desired
  on conflict (application_id) do update
  set
    generator_id = excluded.generator_id,
    controller_id = excluded.controller_id,
    power_on_reading_id = excluded.power_on_reading_id,
    power_off_reading_id = excluded.power_off_reading_id,
    status = excluded.status,
    technical_reason = excluded.technical_reason,
    source_updated_at = excluded.source_updated_at,
    updated_at = excluded.source_updated_at
  where (
    application_power_verifications.generator_id,
    application_power_verifications.controller_id,
    application_power_verifications.power_on_reading_id,
    application_power_verifications.power_off_reading_id,
    application_power_verifications.status,
    application_power_verifications.technical_reason,
    application_power_verifications.source_updated_at
  ) is distinct from (
    excluded.generator_id,
    excluded.controller_id,
    excluded.power_on_reading_id,
    excluded.power_off_reading_id,
    excluded.status,
    excluded.technical_reason,
    excluded.source_updated_at
  );

  update public.inconsistencies as inconsistency
  set status = 'resolved', resolved_at = transaction_timestamp()
  where inconsistency.generator_id = p_generator_id
    and inconsistency.status = 'pending'
    and inconsistency.type like 'missing_power_%'
    and not exists (
      select 1
      from private.desired_power_verifications(p_generator_id) as desired
      where desired.application_id = inconsistency.application_id
        and desired.status = inconsistency.type
    );

  update public.inconsistencies as inconsistency
  set status = 'pending', resolved_at = null
  where inconsistency.generator_id = p_generator_id
    and inconsistency.status = 'resolved'
    and inconsistency.type like 'missing_power_%'
    and exists (
      select 1
      from private.desired_power_verifications(p_generator_id) as desired
      where desired.application_id = inconsistency.application_id
        and desired.status = inconsistency.type
    );

  insert into public.inconsistencies (
    generator_id,
    event_id,
    application_id,
    type,
    public_date
  )
  select
    p_generator_id,
    desired.start_event_id,
    desired.application_id,
    desired.status,
    desired.public_date
  from private.desired_power_verifications(p_generator_id) as desired
  where desired.status in (
    'missing_power_on',
    'missing_power_off',
    'missing_power_both'
  )
  on conflict (application_id, type)
  where application_id is not null and type like 'missing_power_%'
  do nothing;

  /* Derivation moved to private.unexpected_power_readings.
  drop table if exists pg_temp.spec10_unexpected_power;

  create temporary table spec10_unexpected_power
  on commit drop
  as
  select
    transition.reading_id as power_reading_id,
    reading.generator_id,
    (reading.occurred_at at time zone location.time_zone)::date as public_date
  from private.power_transitions(p_generator_id) as transition
  join public.power_readings as reading on reading.id = transition.reading_id
  join public.import_batches as batch on batch.id = reading.import_batch_id
  join public.locations as location
    on location.id = batch.location_id
    and location.client_id = batch.client_id
  where transition.transition = 'on'
    and not exists (
      select 1
      from public.application_power_verifications as verification
      where verification.generator_id = p_generator_id
        and verification.power_on_reading_id = transition.reading_id
    );
  */

  update public.inconsistencies as inconsistency
  set status = 'resolved', resolved_at = transaction_timestamp()
  where inconsistency.generator_id = p_generator_id
    and inconsistency.status = 'pending'
    and inconsistency.type = 'unexpected_power'
    and not exists (
      select 1
      from private.unexpected_power_readings(p_generator_id) as desired
      where desired.power_reading_id = inconsistency.power_reading_id
    );

  update public.inconsistencies as inconsistency
  set status = 'pending', resolved_at = null
  where inconsistency.generator_id = p_generator_id
    and inconsistency.status = 'resolved'
    and inconsistency.type = 'unexpected_power'
    and exists (
      select 1
      from private.unexpected_power_readings(p_generator_id) as desired
      where desired.power_reading_id = inconsistency.power_reading_id
    );

  insert into public.inconsistencies (
    generator_id,
    power_reading_id,
    type,
    public_date
  )
  select
    desired.generator_id,
    desired.power_reading_id,
    'unexpected_power',
    desired.public_date
  from private.unexpected_power_readings(p_generator_id) as desired
  on conflict (power_reading_id, type)
  where power_reading_id is not null and type = 'unexpected_power'
  do nothing;

  update public.client_daily_status as daily_status
  set
    power_evidence_status = case
      when exists (
        select 1
        from public.inconsistencies as inconsistency
        where inconsistency.generator_id = p_generator_id
          and inconsistency.public_date = daily_status.status_date
          and inconsistency.type = 'unexpected_power'
          and inconsistency.status <> 'resolved'
      ) then 'requires_review'
      when not exists (
        select 1
        from public.applications as application
        where application.generator_id = p_generator_id
          and application.public_date = daily_status.status_date
      ) then 'not_applicable'
      when exists (
        select 1
        from public.application_power_verifications as verification
        join public.applications as application
          on application.id = verification.application_id
        where verification.generator_id = p_generator_id
          and application.public_date = daily_status.status_date
          and verification.status like 'missing_power_%'
      ) then 'requires_review'
      when not exists (
        select 1
        from public.application_power_verifications as verification
        join public.applications as application
          on application.id = verification.application_id
        where verification.generator_id = p_generator_id
          and application.public_date = daily_status.status_date
          and verification.status <> 'verified'
      ) then 'confirmed'
      when exists (
        select 1
        from public.application_power_verifications as verification
        join public.applications as application
          on application.id = verification.application_id
        where verification.generator_id = p_generator_id
          and application.public_date = daily_status.status_date
          and verification.status = 'verified'
      ) then 'partial'
      else 'unavailable'
    end,
    status = case
      when exists (
        select 1
        from public.inconsistencies as inconsistency
        where inconsistency.generator_id = p_generator_id
          and inconsistency.public_date = daily_status.status_date
          and inconsistency.status = 'pending'
      ) then 'verification_required'
      else daily_status.status
    end,
    updated_at = greatest(
      daily_status.updated_at,
      coalesce((
        select max(verification.source_updated_at)
        from public.application_power_verifications as verification
        join public.applications as application
          on application.id = verification.application_id
        where verification.generator_id = p_generator_id
          and application.public_date = daily_status.status_date
      ), daily_status.updated_at),
      coalesce((
        select max(reading.occurred_at)
        from public.inconsistencies as inconsistency
        join public.power_readings as reading
          on reading.id = inconsistency.power_reading_id
        where inconsistency.generator_id = p_generator_id
          and inconsistency.public_date = daily_status.status_date
          and inconsistency.type = 'unexpected_power'
          and inconsistency.status <> 'resolved'
      ), daily_status.updated_at)
    )
  where daily_status.generator_id = p_generator_id;
end;
$$;

revoke all on function private.reprocess_power_telemetry(uuid)
from public, anon, authenticated;

create or replace function private.reprocess_all_generator_data(p_generator_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.reprocess_generator(p_generator_id);
  perform private.reprocess_power_telemetry(p_generator_id);
end;
$$;

revoke all on function private.reprocess_all_generator_data(uuid)
from public, anon, authenticated;

create or replace function public.reprocess_generator_telemetry(
  p_generator_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not (select private.is_active_master()) then
    raise exception 'somente o Master pode reprocessar a telemetria'
      using errcode = '42501';
  end if;

  perform private.reprocess_all_generator_data(p_generator_id);
end;
$$;

revoke all on function public.reprocess_generator_telemetry(uuid)
from public, anon;
grant execute on function public.reprocess_generator_telemetry(uuid)
to authenticated;

create or replace function private.reprocess_confirmed_import()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'confirmed'
    and (tg_op = 'INSERT' or old.status is distinct from new.status) then
    perform private.reprocess_all_generator_data(new.generator_id);
  end if;

  return new;
end;
$$;

create or replace function private.reprocess_reviewed_inconsistency()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (
    old.status = 'pending' and new.status = 'reviewed'
  ) or (
    old.status = 'reviewed' and new.status = 'pending'
  ) then
    perform private.reprocess_all_generator_data(new.generator_id);
  end if;

  return new;
end;
$$;

create or replace function private.reprocess_source_mapping_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  affected_generator_id uuid;
begin
  for affected_generator_id in
    select distinct event.generator_id
    from public.raw_events as event
    join public.import_batches as batch
      on batch.id = event.import_batch_id
      and batch.status = 'confirmed'
    where event.source_normalized = coalesce(new.normalized_source, old.normalized_source)
      or (
        tg_op = 'UPDATE'
        and new.normalized_source is distinct from old.normalized_source
        and event.source_normalized = old.normalized_source
      )
  loop
    perform private.reprocess_all_generator_data(affected_generator_id);
  end loop;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

create or replace function private.reprocess_controller_power_configuration()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.role = 'power_telemetry' and (
    tg_op = 'INSERT'
    or (
      new.power_on_threshold_w,
      new.power_off_threshold_w,
      new.correlation_tolerance_seconds,
      new.activated_at,
      new.deactivated_at
    ) is distinct from (
      old.power_on_threshold_w,
      old.power_off_threshold_w,
      old.correlation_tolerance_seconds,
      old.activated_at,
      old.deactivated_at
    )
  ) then
    perform private.reprocess_all_generator_data(new.generator_id);
  end if;

  return new;
end;
$$;

revoke all on function private.reprocess_controller_power_configuration()
from public, anon, authenticated;

create trigger controllers_reprocess_power_configuration
after insert or update
on public.controllers
for each row execute function private.reprocess_controller_power_configuration();

create or replace function public.list_admin_inconsistencies_v2(
  p_status text default 'pending',
  p_client_id uuid default null,
  p_location_id uuid default null,
  p_generator_id uuid default null,
  p_type text default null,
  p_start_date date default null,
  p_end_date date default null
)
returns table (
  id bigint,
  type text,
  status text,
  public_date date,
  review_note text,
  reviewed_by uuid,
  reviewed_by_name text,
  reviewed_at timestamptz,
  created_at timestamptz,
  generator_id uuid,
  generator_identifier text,
  client_id uuid,
  client_name text,
  location_id uuid,
  location_name text,
  event_id bigint,
  event_occurred_at timestamptz,
  event_operation text,
  event_source_original text,
  event_source_normalized text,
  event_source_classification text,
  event_controller_identifier text,
  related_event_id bigint,
  related_event_occurred_at timestamptz,
  related_event_operation text,
  related_event_source_original text,
  related_event_source_classification text,
  related_event_controller_identifier text,
  power_reading_id bigint,
  power_occurred_at timestamptz,
  power_w numeric,
  power_device_name text,
  power_device_id text,
  power_controller_identifier text,
  verification_status text,
  verification_reason text,
  correlated_power_on_at timestamptz,
  correlated_power_on_w numeric,
  correlated_power_off_at timestamptz,
  correlated_power_off_w numeric
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    inconsistency.id,
    inconsistency.type,
    inconsistency.status,
    inconsistency.public_date,
    inconsistency.review_note,
    inconsistency.reviewed_by,
    reviewer.full_name,
    inconsistency.reviewed_at,
    inconsistency.created_at,
    generator.id,
    generator.identifier,
    client.id,
    client.legal_name,
    location.id,
    location.name,
    event.id,
    event.occurred_at,
    event.operation,
    event.source_original,
    event.source_normalized,
    event.source_classification,
    event_controller.identifier,
    related_event.id,
    related_event.occurred_at,
    related_event.operation,
    related_event.source_original,
    related_event.source_classification,
    related_controller.identifier,
    power_reading.id,
    power_reading.occurred_at,
    power_reading.power_w,
    power_reading.device_name,
    power_reading.device_id,
    power_controller.identifier,
    verification.status,
    verification.technical_reason,
    correlated_on.occurred_at,
    correlated_on.power_w,
    correlated_off.occurred_at,
    correlated_off.power_w
  from public.inconsistencies as inconsistency
  join public.generators as generator
    on generator.id = inconsistency.generator_id
  join public.clients as client on client.id = generator.client_id
  left join public.raw_events as event
    on event.id = inconsistency.event_id
    and event.generator_id = inconsistency.generator_id
  left join public.import_batches as event_batch
    on event_batch.id = event.import_batch_id
  left join public.controllers as event_controller
    on event_controller.id = event.controller_id
  left join public.raw_events as related_event
    on related_event.id = inconsistency.related_event_id
    and related_event.generator_id = inconsistency.generator_id
  left join public.controllers as related_controller
    on related_controller.id = related_event.controller_id
  left join public.power_readings as power_reading
    on power_reading.id = inconsistency.power_reading_id
    and power_reading.generator_id = inconsistency.generator_id
  left join public.import_batches as power_batch
    on power_batch.id = power_reading.import_batch_id
  left join public.controllers as power_controller
    on power_controller.id = power_reading.controller_id
  left join public.application_power_verifications as verification
    on verification.application_id = inconsistency.application_id
  left join public.power_readings as correlated_on
    on correlated_on.id = verification.power_on_reading_id
  left join public.power_readings as correlated_off
    on correlated_off.id = verification.power_off_reading_id
  join public.locations as location
    on location.id = coalesce(event_batch.location_id, power_batch.location_id)
    and location.client_id = client.id
  left join public.profiles as reviewer on reviewer.id = inconsistency.reviewed_by
  where (p_status is null or p_status = 'all' or inconsistency.status = p_status)
    and (p_client_id is null or client.id = p_client_id)
    and (p_location_id is null or location.id = p_location_id)
    and (p_generator_id is null or generator.id = p_generator_id)
    and (p_type is null or inconsistency.type = p_type)
    and (p_start_date is null or inconsistency.public_date >= p_start_date)
    and (p_end_date is null or inconsistency.public_date <= p_end_date)
  order by
    case inconsistency.status
      when 'pending' then 0
      when 'reviewed' then 1
      else 2
    end,
    coalesce(event.occurred_at, power_reading.occurred_at) desc,
    inconsistency.id desc
  limit 500;
$$;

revoke all on function public.list_admin_inconsistencies_v2(
  text, uuid, uuid, uuid, text, date, date
) from public, anon;

grant execute on function public.list_admin_inconsistencies_v2(
  text, uuid, uuid, uuid, text, date, date
) to authenticated;

do $$
declare
  existing_generator_id uuid;
begin
  for existing_generator_id in
    select generator.id from public.generators as generator
  loop
    perform private.refresh_generator_telemetry_status(existing_generator_id);

    if exists (
      select 1
      from public.raw_events as event
      join public.import_batches as batch
        on batch.id = event.import_batch_id
        and batch.status = 'confirmed'
      where event.generator_id = existing_generator_id
    ) then
      perform private.reprocess_all_generator_data(existing_generator_id);
    end if;
  end loop;
end;
$$;
