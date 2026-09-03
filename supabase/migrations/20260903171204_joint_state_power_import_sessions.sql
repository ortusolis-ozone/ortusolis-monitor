-- Spec 11: one administrative session for a state-events workbook and a
-- power-readings workbook. The source batches remain independent and are
-- reused by hash/context while confirmation is atomic.

create table public.import_sessions (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id),
  location_id uuid not null,
  cold_room_id uuid not null,
  generator_id uuid not null,
  state_controller_id uuid not null,
  power_controller_id uuid not null,
  state_batch_id uuid references public.import_batches (id),
  power_batch_id uuid references public.import_batches (id),
  status text not null,
  coverage_status text not null,
  coverage_warning_acknowledged boolean not null default false,
  error_message text,
  failed_state_file_name text,
  failed_state_file_sha256 text,
  failed_power_file_name text,
  failed_power_file_sha256 text,
  state_period_start timestamptz,
  state_period_end timestamptz,
  power_period_start timestamptz,
  power_period_end timestamptz,
  intersection_start timestamptz,
  intersection_end timestamptz,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  confirmed_at timestamptz,
  constraint import_sessions_distinct_controllers_check check (
    state_controller_id <> power_controller_id
  ),
  constraint import_sessions_status_check check (
    status in ('confirmed', 'failed')
  ),
  constraint import_sessions_coverage_status_check check (
    coverage_status in ('full', 'partial', 'no_intersection', 'unknown')
  ),
  constraint import_sessions_state_period_check check (
    state_period_end is null
    or state_period_start is null
    or state_period_end >= state_period_start
  ),
  constraint import_sessions_power_period_check check (
    power_period_end is null
    or power_period_start is null
    or power_period_end >= power_period_start
  ),
  constraint import_sessions_intersection_check check (
    (
      intersection_start is null
      and intersection_end is null
    )
    or (
      intersection_start is not null
      and intersection_end is not null
      and intersection_end >= intersection_start
    )
  ),
  constraint import_sessions_status_shape_check check (
    (
      status = 'confirmed'
      and state_batch_id is not null
      and power_batch_id is not null
      and coverage_status in ('full', 'partial')
      and (
        coverage_status <> 'partial'
        or coverage_warning_acknowledged
      )
      and error_message is null
      and failed_state_file_name is null
      and failed_state_file_sha256 is null
      and failed_power_file_name is null
      and failed_power_file_sha256 is null
      and state_period_start is not null
      and state_period_end is not null
      and power_period_start is not null
      and power_period_end is not null
      and intersection_start is not null
      and intersection_end is not null
      and confirmed_at is not null
    )
    or (
      status = 'failed'
      and state_batch_id is null
      and power_batch_id is null
      and not coverage_warning_acknowledged
      and btrim(coalesce(error_message, '')) <> ''
      and btrim(coalesce(failed_state_file_name, '')) <> ''
      and coalesce(failed_state_file_sha256, '') ~ '^[0-9a-f]{64}$'
      and btrim(coalesce(failed_power_file_name, '')) <> ''
      and coalesce(failed_power_file_sha256, '') ~ '^[0-9a-f]{64}$'
      and confirmed_at is null
    )
  ),
  constraint import_sessions_batch_pair_key unique (
    state_batch_id,
    power_batch_id
  ),
  constraint import_sessions_cold_room_hierarchy_fkey foreign key (
    cold_room_id,
    client_id,
    location_id
  ) references public.cold_rooms (
    id,
    client_id,
    location_id
  ),
  constraint import_sessions_generator_client_fkey foreign key (
    generator_id,
    client_id
  ) references public.generators (
    id,
    client_id
  ),
  constraint import_sessions_state_controller_context_fkey foreign key (
    state_controller_id,
    client_id,
    generator_id
  ) references public.controllers (
    id,
    client_id,
    generator_id
  ),
  constraint import_sessions_power_controller_context_fkey foreign key (
    power_controller_id,
    client_id,
    generator_id
  ) references public.controllers (
    id,
    client_id,
    generator_id
  )
);

create index import_sessions_created_at_idx
on public.import_sessions (created_at desc);

create index import_sessions_generator_created_at_idx
on public.import_sessions (generator_id, created_at desc);

create index import_sessions_state_batch_idx
on public.import_sessions (state_batch_id)
where state_batch_id is not null;

create index import_sessions_power_batch_idx
on public.import_sessions (power_batch_id)
where power_batch_id is not null;

alter table public.import_sessions enable row level security;

revoke all on table public.import_sessions
from public, anon, authenticated;

grant select on table public.import_sessions to authenticated;
grant select, insert, update, delete on table public.import_sessions to service_role;

create policy import_sessions_select_master
on public.import_sessions
for select
to authenticated
using ((select private.is_active_master()));

create or replace function private.validate_import_session()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  state_batch public.import_batches%rowtype;
  power_batch public.import_batches%rowtype;
  state_role text;
  power_role text;
  calculated_coverage text;
  calculated_intersection_start timestamptz;
  calculated_intersection_end timestamptz;
begin
  select controller.role
  into state_role
  from public.controllers as controller
  where controller.id = new.state_controller_id
    and controller.client_id = new.client_id
    and controller.generator_id = new.generator_id;

  select controller.role
  into power_role
  from public.controllers as controller
  where controller.id = new.power_controller_id
    and controller.client_id = new.client_id
    and controller.generator_id = new.generator_id;

  if state_role is distinct from 'state'
    or power_role is distinct from 'power_telemetry' then
    raise exception 'a sessão exige exatamente um controlador de cada papel'
      using errcode = '23514', constraint = 'import_sessions_controller_roles';
  end if;

  if new.status = 'failed' then
    return new;
  end if;

  select * into state_batch
  from public.import_batches as batch
  where batch.id = new.state_batch_id;

  select * into power_batch
  from public.import_batches as batch
  where batch.id = new.power_batch_id;

  if state_batch.id is null
    or state_batch.status <> 'confirmed'
    or state_batch.data_kind <> 'state_events'
    or state_batch.client_id <> new.client_id
    or state_batch.location_id <> new.location_id
    or state_batch.cold_room_id <> new.cold_room_id
    or state_batch.generator_id <> new.generator_id
    or state_batch.controller_id <> new.state_controller_id then
    raise exception 'o lote de estado não é compatível com a sessão'
      using errcode = '23514', constraint = 'import_sessions_state_batch';
  end if;

  if power_batch.id is null
    or power_batch.status <> 'confirmed'
    or power_batch.data_kind <> 'power_readings'
    or power_batch.client_id <> new.client_id
    or power_batch.location_id <> new.location_id
    or power_batch.cold_room_id <> new.cold_room_id
    or power_batch.generator_id <> new.generator_id
    or power_batch.controller_id <> new.power_controller_id then
    raise exception 'o lote de potência não é compatível com a sessão'
      using errcode = '23514', constraint = 'import_sessions_power_batch';
  end if;

  if state_batch.period_start is null
    or state_batch.period_end is null
    or power_batch.period_start is null
    or power_batch.period_end is null then
    raise exception 'os lotes confirmados devem possuir períodos completos'
      using errcode = '23514', constraint = 'import_sessions_batch_periods';
  end if;

  if power_batch.period_end < state_batch.period_start
    or state_batch.period_end < power_batch.period_start then
    raise exception 'os arquivos não possuem interseção temporal'
      using errcode = '23514', constraint = 'import_sessions_no_intersection';
  end if;

  calculated_intersection_start := greatest(
    state_batch.period_start,
    power_batch.period_start
  );
  calculated_intersection_end := least(
    state_batch.period_end,
    power_batch.period_end
  );
  calculated_coverage := case
    when power_batch.period_start <= state_batch.period_start
      and power_batch.period_end >= state_batch.period_end
      then 'full'
    else 'partial'
  end;

  if new.state_period_start is distinct from state_batch.period_start
    or new.state_period_end is distinct from state_batch.period_end
    or new.power_period_start is distinct from power_batch.period_start
    or new.power_period_end is distinct from power_batch.period_end
    or new.intersection_start is distinct from calculated_intersection_start
    or new.intersection_end is distinct from calculated_intersection_end
    or new.coverage_status is distinct from calculated_coverage then
    raise exception 'o resumo temporal da sessão não corresponde aos lotes'
      using errcode = '23514', constraint = 'import_sessions_period_summary';
  end if;

  return new;
end;
$$;

revoke all on function private.validate_import_session()
from public, anon, authenticated;

create trigger import_sessions_validate
before insert on public.import_sessions
for each row execute function private.validate_import_session();

create or replace function private.prevent_import_session_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception 'sessões de importação são imutáveis'
    using errcode = '55000';
end;
$$;

revoke all on function private.prevent_import_session_mutation()
from public, anon, authenticated;

create trigger import_sessions_prevent_mutation
before update or delete on public.import_sessions
for each row execute function private.prevent_import_session_mutation();

create or replace function private.prevent_session_batch_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.import_sessions as session
    where session.state_batch_id = old.id
      or session.power_batch_id = old.id
  ) then
    if tg_op = 'DELETE' or to_jsonb(new) is distinct from to_jsonb(old) then
      raise exception 'lotes associados a uma sessão são imutáveis'
        using errcode = '55000';
    end if;
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

revoke all on function private.prevent_session_batch_mutation()
from public, anon, authenticated;

create trigger import_batches_prevent_session_mutation
before update or delete on public.import_batches
for each row execute function private.prevent_session_batch_mutation();

create or replace function private.audit_import_session()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.audit_logs (
    actor_id,
    action,
    entity_type,
    entity_id
  )
  values (
    (select auth.uid()),
    case
      when new.status = 'confirmed' then 'import_session_confirmed'
      else 'import_session_failed'
    end,
    'import_sessions',
    new.id::text
  );

  return new;
end;
$$;

revoke all on function private.audit_import_session()
from public, anon, authenticated;

create trigger import_sessions_audit
after insert on public.import_sessions
for each row execute function private.audit_import_session();

-- Individual imports still reprocess immediately. The joint RPC sets a
-- transaction-local flag while it confirms the two batches and performs the
-- single complete rebuild itself after both are available.
create or replace function private.reprocess_confirmed_import()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'confirmed'
    and (tg_op = 'INSERT' or old.status is distinct from new.status)
    and coalesce(
      current_setting('app.defer_import_reprocess', true),
      'off'
    ) <> 'on' then
    perform private.reprocess_all_generator_data(new.generator_id);
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

  return jsonb_build_object(
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

create or replace function public.record_failed_import_session(
  p_client_id uuid,
  p_location_id uuid,
  p_cold_room_id uuid,
  p_generator_id uuid,
  p_state_controller_id uuid,
  p_state_file_name text,
  p_state_file_sha256 text,
  p_state_period_start timestamptz,
  p_state_period_end timestamptz,
  p_power_controller_id uuid,
  p_power_file_name text,
  p_power_file_sha256 text,
  p_power_period_start timestamptz,
  p_power_period_end timestamptz,
  p_error_message text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  failed_session_id uuid;
  failed_coverage text := 'unknown';
  overlap_start timestamptz;
  overlap_end timestamptz;
begin
  if not (select private.is_active_master()) then
    raise exception 'somente o Master pode registrar falhas de sessão'
      using errcode = '42501';
  end if;

  if btrim(coalesce(p_state_file_name, '')) = ''
    or coalesce(p_state_file_sha256, '') !~ '^[0-9a-f]{64}$'
    or btrim(coalesce(p_power_file_name, '')) = ''
    or coalesce(p_power_file_sha256, '') !~ '^[0-9a-f]{64}$' then
    raise exception 'os arquivos ou hashes da tentativa são inválidos'
      using errcode = '23514', constraint = 'record_failed_import_session_files';
  end if;

  if not exists (
    select 1
    from public.clients as client
    join public.locations as location
      on location.id = p_location_id
      and location.client_id = client.id
    join public.cold_rooms as cold_room
      on cold_room.id = p_cold_room_id
      and cold_room.client_id = client.id
      and cold_room.location_id = location.id
    join public.generator_assignments as assignment
      on assignment.client_id = client.id
      and assignment.location_id = location.id
      and assignment.cold_room_id = cold_room.id
      and assignment.generator_id = p_generator_id
      and assignment.valid_until is null
    join public.generators as generator
      on generator.id = assignment.generator_id
      and generator.client_id = client.id
    join public.controllers as state_controller
      on state_controller.id = p_state_controller_id
      and state_controller.client_id = client.id
      and state_controller.generator_id = generator.id
      and state_controller.role = 'state'
    join public.controllers as power_controller
      on power_controller.id = p_power_controller_id
      and power_controller.client_id = client.id
      and power_controller.generator_id = generator.id
      and power_controller.role = 'power_telemetry'
    where client.id = p_client_id
      and client.is_active
      and location.is_active
      and cold_room.is_active
      and generator.is_active
  ) then
    raise exception 'a hierarquia da tentativa deve estar ativa e coerente'
      using errcode = '23514', constraint = 'record_failed_import_session_hierarchy';
  end if;

  if p_state_period_start is not null
    and p_state_period_end is not null
    and p_power_period_start is not null
    and p_power_period_end is not null then
    if p_power_period_end < p_state_period_start
      or p_state_period_end < p_power_period_start then
      failed_coverage := 'no_intersection';
    else
      overlap_start := greatest(p_state_period_start, p_power_period_start);
      overlap_end := least(p_state_period_end, p_power_period_end);
      failed_coverage := case
        when p_power_period_start <= p_state_period_start
          and p_power_period_end >= p_state_period_end
          then 'full'
        else 'partial'
      end;
    end if;
  end if;

  insert into public.import_sessions (
    client_id,
    location_id,
    cold_room_id,
    generator_id,
    state_controller_id,
    power_controller_id,
    status,
    coverage_status,
    error_message,
    failed_state_file_name,
    failed_state_file_sha256,
    failed_power_file_name,
    failed_power_file_sha256,
    state_period_start,
    state_period_end,
    power_period_start,
    power_period_end,
    intersection_start,
    intersection_end,
    created_by
  )
  values (
    p_client_id,
    p_location_id,
    p_cold_room_id,
    p_generator_id,
    p_state_controller_id,
    p_power_controller_id,
    'failed',
    failed_coverage,
    left(btrim(coalesce(p_error_message, 'Falha de persistência.')), 500),
    btrim(p_state_file_name),
    p_state_file_sha256,
    btrim(p_power_file_name),
    p_power_file_sha256,
    p_state_period_start,
    p_state_period_end,
    p_power_period_start,
    p_power_period_end,
    overlap_start,
    overlap_end,
    (select auth.uid())
  )
  returning id into failed_session_id;

  return failed_session_id;
end;
$$;

revoke all on function public.confirm_import_session(
  uuid, uuid, uuid, uuid, uuid, text, text, jsonb,
  uuid, text, text, jsonb, boolean
) from public, anon;

revoke all on function public.record_failed_import_session(
  uuid, uuid, uuid, uuid, uuid, text, text, timestamptz, timestamptz,
  uuid, text, text, timestamptz, timestamptz, text
) from public, anon;

grant execute on function public.confirm_import_session(
  uuid, uuid, uuid, uuid, uuid, text, text, jsonb,
  uuid, text, text, jsonb, boolean
) to authenticated;

grant execute on function public.record_failed_import_session(
  uuid, uuid, uuid, uuid, uuid, text, text, timestamptz, timestamptz,
  uuid, text, text, timestamptz, timestamptz, text
) to authenticated;

create view public.latest_confirmed_import_batches
with (security_invoker = true)
as
select distinct on (
  batch.client_id,
  batch.location_id,
  batch.cold_room_id,
  batch.generator_id,
  batch.controller_id
)
  batch.id,
  batch.client_id,
  batch.location_id,
  batch.cold_room_id,
  batch.generator_id,
  batch.controller_id,
  batch.data_kind,
  batch.file_name,
  batch.confirmed_at,
  batch.period_start,
  batch.period_end,
  batch.total_rows,
  batch.created_by
from public.import_batches as batch
where batch.status = 'confirmed'
order by
  batch.client_id,
  batch.location_id,
  batch.cold_room_id,
  batch.generator_id,
  batch.controller_id,
  batch.confirmed_at desc nulls last,
  batch.created_at desc,
  batch.id;

revoke all on table public.latest_confirmed_import_batches
from public, anon, authenticated;

grant select on table public.latest_confirmed_import_batches
to authenticated, service_role;
