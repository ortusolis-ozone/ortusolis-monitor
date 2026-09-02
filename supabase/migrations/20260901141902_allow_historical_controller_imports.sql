-- Historical controllers remain valid import targets for records inside their
-- own half-open validity interval [activated_at, deactivated_at). The current
-- operational hierarchy must still be active and coherent.

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
    and controller.role = 'state'
  where client.id = p_client_id
    and client.is_active
    and location.is_active
    and cold_room.is_active
    and generator.is_active;

  if not found then
    raise exception 'a hierarquia deve estar ativa e coerente, e o controlador de estado deve pertencer ao gerador'
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
    and generator.is_active;

  if not found then
    raise exception 'a hierarquia deve estar ativa e coerente, e o controlador de potência deve pertencer ao gerador'
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
