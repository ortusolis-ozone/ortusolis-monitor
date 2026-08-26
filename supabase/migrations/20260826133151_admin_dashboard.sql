grant select on table public.inconsistencies to authenticated;

grant update (
  status,
  review_note,
  reviewed_by,
  reviewed_at,
  resolved_at
) on table public.inconsistencies to authenticated;

grant insert (
  normalized_source,
  classification,
  is_active,
  created_by
) on table public.source_mappings to authenticated;

grant update (
  classification,
  is_active,
  updated_at
) on table public.source_mappings to authenticated;

grant usage, select on sequence public.source_mappings_id_seq to authenticated;

create policy inconsistencies_select_master
on public.inconsistencies
for select
to authenticated
using ((select private.is_active_master()));

create policy inconsistencies_update_master
on public.inconsistencies
for update
to authenticated
using ((select private.is_active_master()))
with check ((select private.is_active_master()));

create policy source_mappings_insert_master
on public.source_mappings
for insert
to authenticated
with check (
  (select private.is_active_master())
  and created_by = (select auth.uid())
);

create policy source_mappings_update_master
on public.source_mappings
for update
to authenticated
using ((select private.is_active_master()))
with check ((select private.is_active_master()));

create index inconsistencies_status_generator_date_idx
on public.inconsistencies (status, generator_id, public_date desc);

create index raw_events_source_seen_idx
on public.raw_events (source_normalized, occurred_at desc)
include (source_original, source_classification);

create trigger source_mappings_touch_updated_at
before update on public.source_mappings
for each row execute function private.touch_updated_at();

create trigger source_mappings_audit_admin_change
after insert or update on public.source_mappings
for each row execute function private.audit_operational_change();

create or replace function private.audit_inconsistency_review_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  audit_action text;
begin
  if old.status = 'pending' and new.status = 'reviewed' then
    audit_action = 'inconsistency_reviewed';
  elsif old.status = 'reviewed' and new.status = 'pending' then
    audit_action = 'inconsistency_reopened';
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
    'inconsistencies',
    new.id::text
  );

  return new;
end;
$$;

revoke all on function private.audit_inconsistency_review_change()
from public, anon, authenticated;

create trigger inconsistencies_audit_review_change
after update of status on public.inconsistencies
for each row execute function private.audit_inconsistency_review_change();

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
    perform private.reprocess_generator(new.generator_id);
  end if;

  return new;
end;
$$;

revoke all on function private.reprocess_reviewed_inconsistency()
from public, anon, authenticated;

create or replace function public.review_inconsistency(
  p_inconsistency_id bigint,
  p_review_note text default null
)
returns boolean
language plpgsql
security invoker
set search_path = ''
as $$
declare
  affected_rows integer;
  normalized_note text;
begin
  if not (select private.is_active_master()) then
    raise exception 'apenas usuários Master ativos podem revisar inconsistências'
      using errcode = '42501';
  end if;

  normalized_note = nullif(btrim(coalesce(p_review_note, '')), '');

  if length(coalesce(normalized_note, '')) > 2000 then
    raise exception 'a nota interna deve ter no máximo 2.000 caracteres'
      using errcode = '22001';
  end if;

  update public.inconsistencies
  set
    status = 'reviewed',
    review_note = normalized_note,
    reviewed_by = (select auth.uid()),
    reviewed_at = transaction_timestamp(),
    resolved_at = null
  where id = p_inconsistency_id
    and status = 'pending';

  get diagnostics affected_rows = row_count;
  return affected_rows = 1;
end;
$$;

create or replace function public.reopen_inconsistency(
  p_inconsistency_id bigint
)
returns boolean
language plpgsql
security invoker
set search_path = ''
as $$
declare
  affected_rows integer;
begin
  if not (select private.is_active_master()) then
    raise exception 'apenas usuários Master ativos podem reabrir inconsistências'
      using errcode = '42501';
  end if;

  update public.inconsistencies
  set
    status = 'pending',
    review_note = null,
    reviewed_by = null,
    reviewed_at = null,
    resolved_at = null
  where id = p_inconsistency_id
    and status = 'reviewed';

  get diagnostics affected_rows = row_count;
  return affected_rows = 1;
end;
$$;

create or replace function public.set_source_mapping(
  p_normalized_source text,
  p_classification text
)
returns bigint
language plpgsql
security invoker
set search_path = ''
as $$
declare
  normalized_value text;
  stored_mapping_id bigint;
begin
  if not (select private.is_active_master()) then
    raise exception 'apenas usuários Master ativos podem alterar mapeamentos'
      using errcode = '42501';
  end if;

  normalized_value = lower(btrim(coalesce(p_normalized_source, '')));

  if normalized_value = '' then
    raise exception 'a origem é obrigatória'
      using errcode = '23514';
  end if;

  if p_classification not in ('programmed', 'test', 'unknown') then
    raise exception 'a classificação informada é inválida'
      using errcode = '23514';
  end if;

  if p_classification = 'unknown' then
    update public.source_mappings
    set
      is_active = false,
      updated_at = transaction_timestamp()
    where normalized_source = normalized_value
      and is_active
    returning id into stored_mapping_id;

    return stored_mapping_id;
  end if;

  insert into public.source_mappings (
    normalized_source,
    classification,
    is_active,
    created_by
  )
  values (
    normalized_value,
    p_classification,
    true,
    (select auth.uid())
  )
  on conflict (normalized_source) do update
  set
    classification = excluded.classification,
    is_active = true,
    updated_at = transaction_timestamp()
  returning id into stored_mapping_id;

  return stored_mapping_id;
end;
$$;

create or replace function public.list_source_values()
returns table (
  normalized_source text,
  example_source text,
  event_count bigint,
  last_seen_at timestamptz,
  classification text,
  is_active boolean
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    event.source_normalized,
    max(event.source_original) as example_source,
    count(*) as event_count,
    max(event.occurred_at) as last_seen_at,
    mapping.classification,
    coalesce(mapping.is_active, false) as is_active
  from public.raw_events as event
  join public.import_batches as batch
    on batch.id = event.import_batch_id
    and batch.status = 'confirmed'
  left join public.source_mappings as mapping
    on mapping.normalized_source = event.source_normalized
  group by
    event.source_normalized,
    mapping.classification,
    mapping.is_active
  order by max(event.occurred_at) desc, event.source_normalized;
$$;

create or replace function public.list_admin_inconsistencies(
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
  related_event_controller_identifier text
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
    reviewer.full_name as reviewed_by_name,
    inconsistency.reviewed_at,
    inconsistency.created_at,
    generator.id as generator_id,
    generator.identifier as generator_identifier,
    client.id as client_id,
    client.legal_name as client_name,
    location.id as location_id,
    location.name as location_name,
    event.id as event_id,
    event.occurred_at as event_occurred_at,
    event.operation as event_operation,
    event.source_original as event_source_original,
    event.source_normalized as event_source_normalized,
    event.source_classification as event_source_classification,
    event_controller.identifier as event_controller_identifier,
    related_event.id as related_event_id,
    related_event.occurred_at as related_event_occurred_at,
    related_event.operation as related_event_operation,
    related_event.source_original as related_event_source_original,
    related_event.source_classification as related_event_source_classification,
    related_controller.identifier as related_event_controller_identifier
  from public.inconsistencies as inconsistency
  join public.raw_events as event
    on event.id = inconsistency.event_id
    and event.generator_id = inconsistency.generator_id
  join public.import_batches as batch
    on batch.id = event.import_batch_id
  join public.generators as generator
    on generator.id = inconsistency.generator_id
  join public.clients as client
    on client.id = generator.client_id
  join public.locations as location
    on location.id = batch.location_id
    and location.client_id = batch.client_id
  join public.controllers as event_controller
    on event_controller.id = event.controller_id
  left join public.raw_events as related_event
    on related_event.id = inconsistency.related_event_id
    and related_event.generator_id = inconsistency.generator_id
  left join public.controllers as related_controller
    on related_controller.id = related_event.controller_id
  left join public.profiles as reviewer
    on reviewer.id = inconsistency.reviewed_by
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
    event.occurred_at desc,
    inconsistency.id desc
  limit 500;
$$;

revoke all on function public.review_inconsistency(bigint, text)
from public, anon;
revoke all on function public.reopen_inconsistency(bigint)
from public, anon;
revoke all on function public.set_source_mapping(text, text)
from public, anon;
revoke all on function public.list_source_values()
from public, anon;
revoke all on function public.list_admin_inconsistencies(
  text,
  uuid,
  uuid,
  uuid,
  text,
  date,
  date
) from public, anon;

grant execute on function public.review_inconsistency(bigint, text)
to authenticated;
grant execute on function public.reopen_inconsistency(bigint)
to authenticated;
grant execute on function public.set_source_mapping(text, text)
to authenticated;
grant execute on function public.list_source_values()
to authenticated;
grant execute on function public.list_admin_inconsistencies(
  text,
  uuid,
  uuid,
  uuid,
  text,
  date,
  date
) to authenticated;
