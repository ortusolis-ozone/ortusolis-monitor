drop index if exists public.raw_events_generator_occurred_at_idx;

create index raw_events_generator_occurred_at_idx
on public.raw_events (generator_id, occurred_at, fingerprint);

create index raw_events_source_normalized_generator_idx
on public.raw_events (source_normalized, generator_id);

create unique index inconsistencies_derivation_key_idx
on public.inconsistencies (
  generator_id,
  event_id,
  related_event_id,
  type,
  public_date
)
nulls not distinct;

create or replace function private.reprocess_generator(p_generator_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  event_record record;
  open_event_id bigint;
  open_controller_id uuid;
  open_public_date date;
  desired_application_controller_ids uuid[] := array[]::uuid[];
  desired_application_start_event_ids bigint[] := array[]::bigint[];
  desired_application_end_event_ids bigint[] := array[]::bigint[];
  desired_application_public_dates date[] := array[]::date[];
  desired_inconsistency_event_ids bigint[] := array[]::bigint[];
  desired_inconsistency_related_event_ids bigint[] := array[]::bigint[];
  desired_inconsistency_types text[] := array[]::text[];
  desired_inconsistency_public_dates date[] := array[]::date[];
  first_public_date date;
  last_public_date date;
  last_status_date date;
  last_event_at timestamptz;
  latest_client_id uuid;
  latest_location_id uuid;
  latest_cold_room_id uuid;
  latest_time_zone text;
begin
  if not exists (
    select 1
    from public.generators as generator
    where generator.id = p_generator_id
  ) then
    raise exception 'gerador não encontrado'
      using errcode = 'P0002';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_generator_id::text, 0)
  );

  update public.raw_events as event
  set source_classification = coalesce(
    (
      select mapping.classification
      from public.source_mappings as mapping
      where mapping.normalized_source = event.source_normalized
        and mapping.is_active
    ),
    'unknown'
  )
  where event.generator_id = p_generator_id
    and exists (
      select 1
      from public.import_batches as batch
      where batch.id = event.import_batch_id
        and batch.status = 'confirmed'
    )
    and event.source_classification is distinct from coalesce(
      (
        select mapping.classification
        from public.source_mappings as mapping
        where mapping.normalized_source = event.source_normalized
          and mapping.is_active
      ),
      'unknown'
    );

  for event_record in
    select
      event.id,
      event.controller_id,
      event.operation,
      event.source_classification,
      (event.occurred_at at time zone location.time_zone)::date as public_date
    from public.raw_events as event
    join public.import_batches as batch
      on batch.id = event.import_batch_id
      and batch.status = 'confirmed'
    join public.locations as location
      on location.id = batch.location_id
      and location.client_id = batch.client_id
    where event.generator_id = p_generator_id
    order by event.occurred_at, event.fingerprint
  loop
    if event_record.source_classification = 'test' then
      continue;
    end if;

    if event_record.source_classification = 'unknown' then
      desired_inconsistency_event_ids := array_append(
        desired_inconsistency_event_ids,
        event_record.id
      );
      desired_inconsistency_related_event_ids := desired_inconsistency_related_event_ids
        || array[null::bigint];
      desired_inconsistency_types := array_append(
        desired_inconsistency_types,
        'unknown_source'
      );
      desired_inconsistency_public_dates := array_append(
        desired_inconsistency_public_dates,
        event_record.public_date
      );
      continue;
    end if;

    if event_record.operation = 'turn_on' then
      if open_event_id is not null then
        desired_inconsistency_event_ids := array_append(
          desired_inconsistency_event_ids,
          open_event_id
        );
        desired_inconsistency_related_event_ids := array_append(
          desired_inconsistency_related_event_ids,
          event_record.id
        );
        desired_inconsistency_types := array_append(
          desired_inconsistency_types,
          'consecutive_turn_on'
        );
        desired_inconsistency_public_dates := array_append(
          desired_inconsistency_public_dates,
          open_public_date
        );
      end if;

      open_event_id := event_record.id;
      open_controller_id := event_record.controller_id;
      open_public_date := event_record.public_date;
      continue;
    end if;

    if open_event_id is null then
      desired_inconsistency_event_ids := array_append(
        desired_inconsistency_event_ids,
        event_record.id
      );
      desired_inconsistency_related_event_ids := desired_inconsistency_related_event_ids
        || array[null::bigint];
      desired_inconsistency_types := array_append(
        desired_inconsistency_types,
        'unmatched_turn_off'
      );
      desired_inconsistency_public_dates := array_append(
        desired_inconsistency_public_dates,
        event_record.public_date
      );
    elsif open_controller_id <> event_record.controller_id then
      desired_inconsistency_event_ids := array_append(
        desired_inconsistency_event_ids,
        open_event_id
      );
      desired_inconsistency_related_event_ids := array_append(
        desired_inconsistency_related_event_ids,
        event_record.id
      );
      desired_inconsistency_types := array_append(
        desired_inconsistency_types,
        'controller_mismatch'
      );
      desired_inconsistency_public_dates := array_append(
        desired_inconsistency_public_dates,
        open_public_date
      );

      open_event_id := null;
      open_controller_id := null;
      open_public_date := null;
    else
      desired_application_controller_ids := array_append(
        desired_application_controller_ids,
        open_controller_id
      );
      desired_application_start_event_ids := array_append(
        desired_application_start_event_ids,
        open_event_id
      );
      desired_application_end_event_ids := array_append(
        desired_application_end_event_ids,
        event_record.id
      );
      desired_application_public_dates := array_append(
        desired_application_public_dates,
        open_public_date
      );

      open_event_id := null;
      open_controller_id := null;
      open_public_date := null;
    end if;
  end loop;

  if open_event_id is not null then
    desired_inconsistency_event_ids := array_append(
      desired_inconsistency_event_ids,
      open_event_id
    );
    desired_inconsistency_related_event_ids := desired_inconsistency_related_event_ids
      || array[null::bigint];
    desired_inconsistency_types := array_append(
      desired_inconsistency_types,
      'unmatched_turn_on'
    );
    desired_inconsistency_public_dates := array_append(
      desired_inconsistency_public_dates,
      open_public_date
    );
  end if;

  delete from public.applications as application
  where application.generator_id = p_generator_id
    and not exists (
      select 1
      from unnest(
        desired_application_controller_ids,
        desired_application_start_event_ids,
        desired_application_end_event_ids,
        desired_application_public_dates
      ) as desired (
        controller_id,
        start_event_id,
        end_event_id,
        public_date
      )
      where desired.start_event_id = application.start_event_id
        and desired.end_event_id = application.end_event_id
        and desired.controller_id = application.controller_id
        and desired.public_date = application.public_date
    );

  insert into public.applications (
    generator_id,
    controller_id,
    start_event_id,
    end_event_id,
    public_date
  )
  select
    p_generator_id,
    desired.controller_id,
    desired.start_event_id,
    desired.end_event_id,
    desired.public_date
  from unnest(
    desired_application_controller_ids,
    desired_application_start_event_ids,
    desired_application_end_event_ids,
    desired_application_public_dates
  ) as desired (
    controller_id,
    start_event_id,
    end_event_id,
    public_date
  )
  where not exists (
    select 1
    from public.applications as application
    where application.generator_id = p_generator_id
      and application.start_event_id = desired.start_event_id
      and application.end_event_id = desired.end_event_id
      and application.controller_id = desired.controller_id
      and application.public_date = desired.public_date
  );

  update public.inconsistencies as inconsistency
  set
    status = 'resolved',
    resolved_at = transaction_timestamp()
  where inconsistency.generator_id = p_generator_id
    and inconsistency.status = 'pending'
    and not exists (
      select 1
      from unnest(
        desired_inconsistency_event_ids,
        desired_inconsistency_related_event_ids,
        desired_inconsistency_types,
        desired_inconsistency_public_dates
      ) as desired (
        event_id,
        related_event_id,
        type,
        public_date
      )
      where desired.event_id = inconsistency.event_id
        and desired.type = inconsistency.type
        and desired.related_event_id is not distinct from inconsistency.related_event_id
        and desired.public_date = inconsistency.public_date
    );

  update public.inconsistencies as inconsistency
  set
    status = 'pending',
    resolved_at = null
  where inconsistency.generator_id = p_generator_id
    and inconsistency.status = 'resolved'
    and exists (
      select 1
      from unnest(
        desired_inconsistency_event_ids,
        desired_inconsistency_related_event_ids,
        desired_inconsistency_types,
        desired_inconsistency_public_dates
      ) as desired (
        event_id,
        related_event_id,
        type,
        public_date
      )
      where desired.event_id = inconsistency.event_id
        and desired.type = inconsistency.type
        and desired.related_event_id is not distinct from inconsistency.related_event_id
        and desired.public_date = inconsistency.public_date
    );

  insert into public.inconsistencies (
    generator_id,
    event_id,
    related_event_id,
    type,
    public_date
  )
  select
    p_generator_id,
    desired.event_id,
    desired.related_event_id,
    desired.type,
    desired.public_date
  from unnest(
    desired_inconsistency_event_ids,
    desired_inconsistency_related_event_ids,
    desired_inconsistency_types,
    desired_inconsistency_public_dates
  ) as desired (
    event_id,
    related_event_id,
    type,
    public_date
  )
  where not exists (
    select 1
    from public.inconsistencies as inconsistency
    where inconsistency.generator_id = p_generator_id
      and inconsistency.event_id = desired.event_id
      and inconsistency.type = desired.type
      and inconsistency.related_event_id is not distinct from desired.related_event_id
      and inconsistency.public_date = desired.public_date
  );

  select
    min((event.occurred_at at time zone location.time_zone)::date),
    max((event.occurred_at at time zone location.time_zone)::date),
    max(event.occurred_at)
  into first_public_date, last_public_date, last_event_at
  from public.raw_events as event
  join public.import_batches as batch
    on batch.id = event.import_batch_id
    and batch.status = 'confirmed'
  join public.locations as location
    on location.id = batch.location_id
    and location.client_id = batch.client_id
  where event.generator_id = p_generator_id;

  select
    batch.client_id,
    batch.location_id,
    batch.cold_room_id,
    location.time_zone
  into
    latest_client_id,
    latest_location_id,
    latest_cold_room_id,
    latest_time_zone
  from public.raw_events as event
  join public.import_batches as batch
    on batch.id = event.import_batch_id
    and batch.status = 'confirmed'
  join public.locations as location
    on location.id = batch.location_id
    and location.client_id = batch.client_id
  where event.generator_id = p_generator_id
  order by event.occurred_at desc, event.fingerprint desc
  limit 1;

  if first_public_date is null then
    delete from public.client_daily_status as daily_status
    where daily_status.generator_id = p_generator_id;
    return;
  end if;

  last_status_date := greatest(
    last_public_date,
    (transaction_timestamp() at time zone latest_time_zone)::date
  );

  delete from public.client_daily_status as daily_status
  where daily_status.generator_id = p_generator_id
    and (
      daily_status.status_date < first_public_date
      or daily_status.status_date > last_status_date
    );

  with event_context as (
    select
      event.generator_id,
      event.occurred_at,
      event.fingerprint,
      (event.occurred_at at time zone location.time_zone)::date as public_date,
      batch.client_id,
      batch.location_id,
      batch.cold_room_id,
      location.time_zone
    from public.raw_events as event
    join public.import_batches as batch
      on batch.id = event.import_batch_id
      and batch.status = 'confirmed'
    join public.locations as location
      on location.id = batch.location_id
      and location.client_id = batch.client_id
    where event.generator_id = p_generator_id
  ),
  daily_event_context as (
    select distinct on (context.public_date)
      context.public_date,
      context.client_id,
      context.location_id,
      context.cold_room_id
    from event_context as context
    order by context.public_date, context.occurred_at desc, context.fingerprint desc
  ),
  calendar as (
    select generated_date::date as status_date
    from generate_series(
      first_public_date,
      last_status_date,
      interval '1 day'
    ) as generated_date
  ),
  dated_context as (
    select
      calendar.status_date,
      coalesce(day_context.client_id, assignment.client_id, latest_client_id) as client_id,
      coalesce(day_context.location_id, assignment.location_id, latest_location_id) as location_id,
      coalesce(day_context.cold_room_id, assignment.cold_room_id, latest_cold_room_id) as cold_room_id
    from calendar
    left join daily_event_context as day_context
      on day_context.public_date = calendar.status_date
    left join lateral (
      select
        candidate.client_id,
        candidate.location_id,
        candidate.cold_room_id
      from public.generator_assignments as candidate
      join public.locations as assignment_location
        on assignment_location.id = candidate.location_id
        and assignment_location.client_id = candidate.client_id
      where candidate.generator_id = p_generator_id
        and candidate.valid_from < (
          (calendar.status_date + 1)::timestamp
          at time zone assignment_location.time_zone
        )
        and (
          candidate.valid_until is null
          or candidate.valid_until > (
            calendar.status_date::timestamp
            at time zone assignment_location.time_zone
          )
        )
      order by candidate.valid_from desc
      limit 1
    ) as assignment on true
  )
  insert into public.client_daily_status (
    client_id,
    location_id,
    cold_room_id,
    generator_id,
    status_date,
    status,
    updated_at
  )
  select
    context.client_id,
    context.location_id,
    context.cold_room_id,
    p_generator_id,
    context.status_date,
    case
      when exists (
        select 1
        from public.inconsistencies as inconsistency
        where inconsistency.generator_id = p_generator_id
          and inconsistency.public_date = context.status_date
          and inconsistency.status = 'pending'
      ) then 'verification_required'
      when exists (
        select 1
        from public.applications as application
        where application.generator_id = p_generator_id
          and application.public_date = context.status_date
      ) then 'completed'
      when context.status_date <= last_public_date then 'no_data'
      else 'awaiting_update'
    end,
    last_event_at
  from dated_context as context
  on conflict (generator_id, status_date) do update
  set
    client_id = excluded.client_id,
    location_id = excluded.location_id,
    cold_room_id = excluded.cold_room_id,
    status = excluded.status,
    updated_at = excluded.updated_at;
end;
$$;

revoke all on function private.reprocess_generator(uuid)
from public, anon, authenticated;

create or replace function private.reprocess_confirmed_import()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'confirmed'
    and (tg_op = 'INSERT' or old.status is distinct from new.status) then
    perform private.reprocess_generator(new.generator_id);
  end if;

  return new;
end;
$$;

revoke all on function private.reprocess_confirmed_import()
from public, anon, authenticated;

create trigger import_batches_reprocess_confirmed
after insert or update of status on public.import_batches
for each row execute function private.reprocess_confirmed_import();

create or replace function private.reprocess_reviewed_inconsistency()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.status = 'pending' and new.status = 'reviewed' then
    perform private.reprocess_generator(new.generator_id);
  end if;

  return new;
end;
$$;

revoke all on function private.reprocess_reviewed_inconsistency()
from public, anon, authenticated;

create trigger inconsistencies_reprocess_review
after update of status on public.inconsistencies
for each row execute function private.reprocess_reviewed_inconsistency();

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
    perform private.reprocess_generator(affected_generator_id);
  end loop;

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

revoke all on function private.reprocess_source_mapping_change()
from public, anon, authenticated;

create trigger source_mappings_reprocess_change
after insert or update or delete on public.source_mappings
for each row execute function private.reprocess_source_mapping_change();

do $$
declare
  existing_generator_id uuid;
begin
  for existing_generator_id in
    select distinct event.generator_id
    from public.raw_events as event
    join public.import_batches as batch
      on batch.id = event.import_batch_id
      and batch.status = 'confirmed'
  loop
    perform private.reprocess_generator(existing_generator_id);
  end loop;
end;
$$;
