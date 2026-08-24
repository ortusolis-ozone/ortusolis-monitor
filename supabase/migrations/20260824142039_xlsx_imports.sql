alter table public.raw_events
drop constraint raw_events_raw_values_nonempty;

alter table public.raw_events
add constraint raw_events_raw_values_nonempty check (
  btrim(occurred_at_raw) <> ''
  and btrim(operation_raw) <> ''
);

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'operational-imports',
  'operational-imports',
  false,
  5242880,
  array[
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/octet-stream'
  ]::text[]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy operational_imports_insert_master
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'operational-imports'
  and (select private.is_active_master())
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and lower(name) like '%.xlsx'
);

create policy operational_imports_select_master
on storage.objects
for select
to authenticated
using (
  bucket_id = 'operational-imports'
  and (select private.is_active_master())
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy operational_imports_delete_master
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'operational-imports'
  and (select private.is_active_master())
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

grant select on table
  public.source_mappings,
  public.import_batches,
  public.raw_events
to authenticated;

grant insert, update on table public.import_batches to authenticated;
grant insert on table public.raw_events to authenticated;
grant usage, select on sequence public.raw_events_id_seq to authenticated;

create policy source_mappings_select_master
on public.source_mappings
for select
to authenticated
using ((select private.is_active_master()));

create policy import_batches_select_master
on public.import_batches
for select
to authenticated
using ((select private.is_active_master()));

create policy import_batches_insert_master
on public.import_batches
for insert
to authenticated
with check (
  (select private.is_active_master())
  and created_by = (select auth.uid())
);

create policy import_batches_update_master
on public.import_batches
for update
to authenticated
using ((select private.is_active_master()))
with check ((select private.is_active_master()));

create policy raw_events_select_master
on public.raw_events
for select
to authenticated
using ((select private.is_active_master()));

create policy raw_events_insert_master
on public.raw_events
for insert
to authenticated
with check (
  (select private.is_active_master())
  and exists (
    select 1
    from public.import_batches as batch
    where batch.id = import_batch_id
      and batch.generator_id = generator_id
      and batch.controller_id = controller_id
  )
);

create or replace function private.audit_import_batch_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  audit_action text;
begin
  if new.status = 'confirmed'
    and (tg_op = 'INSERT' or old.status is distinct from new.status) then
    audit_action = 'import_confirmed';
  elsif new.status = 'failed'
    and (tg_op = 'INSERT' or old.status is distinct from new.status) then
    audit_action = 'import_failed';
  else
    return new;
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
    'import_batches',
    new.id::text
  );

  return new;
end;
$$;

revoke all on function private.audit_import_batch_change()
from public, anon, authenticated;

create trigger import_batches_audit_status
after insert or update of status on public.import_batches
for each row execute function private.audit_import_batch_change();

create or replace function public.existing_event_fingerprints(
  p_fingerprints text[]
)
returns table (fingerprint text)
language sql
stable
security invoker
set search_path = ''
as $$
  select event.fingerprint
  from public.raw_events as event
  where event.fingerprint = any(coalesce(p_fingerprints, array[]::text[]));
$$;

create or replace function public.confirm_xlsx_import(
  p_client_id uuid,
  p_location_id uuid,
  p_cold_room_id uuid,
  p_generator_id uuid,
  p_controller_id uuid,
  p_file_name text,
  p_file_sha256 text,
  p_events jsonb
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
  event_count integer;
  inserted_count integer;
  unknown_count integer;
  first_event_at timestamptz;
  last_event_at timestamptz;
  target_batch_id uuid;
  target_batch_status text;
  stored_batch public.import_batches%rowtype;
begin
  if not (select private.is_active_master()) then
    raise exception 'somente o Master pode confirmar importações'
      using errcode = '42501';
  end if;

  if btrim(coalesce(p_file_name, '')) = ''
    or coalesce(p_file_sha256, '') !~ '^[0-9a-f]{64}$' then
    raise exception 'arquivo ou hash inválido'
      using errcode = '23514', constraint = 'confirm_xlsx_import_file';
  end if;

  if jsonb_typeof(p_events) is distinct from 'array' then
    raise exception 'a lista de eventos é inválida'
      using errcode = '23514', constraint = 'confirm_xlsx_import_events';
  end if;

  select controller.activated_at, controller.deactivated_at
  into controller_activated_at, controller_deactivated_at
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
  where client.id = p_client_id
    and client.is_active
    and location.is_active
    and cold_room.is_active
    and generator.is_active
    and controller.is_active;

  if not found then
    raise exception 'a hierarquia selecionada deve estar ativa e coerente'
      using errcode = '23514', constraint = 'confirm_xlsx_import_hierarchy';
  end if;

  select
    count(*)::integer,
    count(*) filter (
      where event.source_classification = 'unknown'
    )::integer,
    min(event.occurred_at),
    max(event.occurred_at)
  into event_count, unknown_count, first_event_at, last_event_at
  from jsonb_to_recordset(p_events) as event (
    occurred_at timestamptz,
    occurred_at_raw text,
    operation text,
    operation_raw text,
    source_original text,
    source_normalized text,
    source_classification text,
    fingerprint text
  );

  if event_count < 1 or event_count > 25000 then
    raise exception 'o arquivo deve conter entre 1 e 25.000 eventos'
      using errcode = '23514', constraint = 'confirm_xlsx_import_event_count';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_events) as event (
      occurred_at timestamptz,
      occurred_at_raw text,
      operation text,
      operation_raw text,
      source_original text,
      source_normalized text,
      source_classification text,
      fingerprint text
    )
    where event.occurred_at is null
      or btrim(coalesce(event.occurred_at_raw, '')) = ''
      or event.operation not in ('turn_on', 'turn_off')
      or btrim(coalesce(event.operation_raw, '')) = ''
      or event.source_original is null
      or event.source_normalized is null
      or event.source_classification not in ('programmed', 'test', 'unknown')
      or event.fingerprint !~ '^[0-9a-f]{64}$'
      or event.occurred_at < controller_activated_at
      or (
        controller_deactivated_at is not null
        and event.occurred_at >= controller_deactivated_at
      )
  ) then
    raise exception 'um ou mais eventos são inválidos ou estão fora da vigência do controlador'
      using errcode = '23514', constraint = 'confirm_xlsx_import_event_values';
  end if;

  insert into public.import_batches (
    client_id,
    location_id,
    cold_room_id,
    generator_id,
    controller_id,
    file_name,
    file_sha256,
    status,
    total_rows,
    unknown_source_rows,
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
    btrim(p_file_name),
    p_file_sha256,
    'processing',
    event_count,
    unknown_count,
    first_event_at,
    last_event_at,
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
      'unknown_source_rows', stored_batch.unknown_source_rows,
      'period_start', stored_batch.period_start,
      'period_end', stored_batch.period_end,
      'already_confirmed', true
    );
  end if;

  update public.import_batches
  set
    file_name = btrim(p_file_name),
    status = 'processing',
    total_rows = event_count,
    inserted_rows = 0,
    duplicate_rows = 0,
    unknown_source_rows = unknown_count,
    period_start = first_event_at,
    period_end = last_event_at,
    error_message = null,
    confirmed_at = null
  where id = target_batch_id;

  with inserted_events as (
    insert into public.raw_events (
      import_batch_id,
      generator_id,
      controller_id,
      occurred_at,
      occurred_at_raw,
      operation,
      operation_raw,
      source_original,
      source_normalized,
      source_classification,
      fingerprint
    )
    select
      target_batch_id,
      p_generator_id,
      p_controller_id,
      event.occurred_at,
      event.occurred_at_raw,
      event.operation,
      event.operation_raw,
      event.source_original,
      event.source_normalized,
      event.source_classification,
      event.fingerprint
    from jsonb_to_recordset(p_events) as event (
      occurred_at timestamptz,
      occurred_at_raw text,
      operation text,
      operation_raw text,
      source_original text,
      source_normalized text,
      source_classification text,
      fingerprint text
    )
    on conflict (fingerprint) do nothing
    returning 1
  )
  select count(*)::integer into inserted_count from inserted_events;

  update public.import_batches
  set
    status = 'confirmed',
    inserted_rows = inserted_count,
    duplicate_rows = event_count - inserted_count,
    confirmed_at = now()
  where id = target_batch_id
  returning * into stored_batch;

  return jsonb_build_object(
    'batch_id', stored_batch.id,
    'status', stored_batch.status,
    'total_rows', stored_batch.total_rows,
    'inserted_rows', stored_batch.inserted_rows,
    'duplicate_rows', stored_batch.duplicate_rows,
    'unknown_source_rows', stored_batch.unknown_source_rows,
    'period_start', stored_batch.period_start,
    'period_end', stored_batch.period_end,
    'already_confirmed', false
  );
end;
$$;

create or replace function public.record_failed_xlsx_import(
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

revoke all on function public.existing_event_fingerprints(text[])
from public, anon;
revoke all on function public.confirm_xlsx_import(
  uuid, uuid, uuid, uuid, uuid, text, text, jsonb
) from public, anon;
revoke all on function public.record_failed_xlsx_import(
  uuid, uuid, uuid, uuid, uuid, text, text, text
) from public, anon;

grant execute on function public.existing_event_fingerprints(text[])
to authenticated;
grant execute on function public.confirm_xlsx_import(
  uuid, uuid, uuid, uuid, uuid, text, text, jsonb
) to authenticated;
grant execute on function public.record_failed_xlsx_import(
  uuid, uuid, uuid, uuid, uuid, text, text, text
) to authenticated;
