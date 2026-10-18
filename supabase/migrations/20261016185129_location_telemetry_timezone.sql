-- Spec 15: location telemetry defaults and immutable per-import provenance.
-- Existing locations intentionally retain a null preference.
alter table "public"."import_batches" drop constraint "import_batches_timezone_metadata_check";

alter table "public"."import_sessions" drop constraint "import_sessions_batch_pair_key";

drop index if exists "public"."import_sessions_batch_pair_key";

alter table "public"."import_batches" add column "temporal_context" jsonb;

alter table "public"."import_sessions" add column "temporal_context" jsonb;

alter table "public"."locations" add column "telemetry_revision" integer not null default 0;

alter table "public"."locations" add column "telemetry_time_basis" text;

alter table "public"."locations" add column "time_zone_revision" integer not null default 0;

CREATE UNIQUE INDEX import_sessions_batch_pair_key ON public.import_sessions USING btree (state_batch_id, power_batch_id, temporal_context);

alter table "public"."locations" add constraint "locations_telemetry_time_basis_check" CHECK ((telemetry_time_basis = ANY (ARRAY['utc'::text, 'location'::text]))) not valid;

alter table "public"."locations" validate constraint "locations_telemetry_time_basis_check";



alter table "public"."import_sessions" add constraint "import_sessions_batch_pair_key" UNIQUE using index "import_sessions_batch_pair_key";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION private.audit_location_temporal_configuration()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if (tg_op = 'INSERT' and new.telemetry_time_basis is not null)
    or (tg_op = 'UPDATE' and (new.telemetry_revision <> old.telemetry_revision)) then
    insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
    values ((select auth.uid()), 'location_telemetry_configured', 'locations', new.id,
      jsonb_build_object('previous_basis', case when tg_op = 'UPDATE' then old.telemetry_time_basis end,
        'basis', new.telemetry_time_basis, 'previous_timezone', case when tg_op = 'UPDATE' then old.time_zone end,
        'timezone', new.time_zone, 'revision', new.telemetry_revision));
  end if;
  return null;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.confirm_import_session(p_client_id uuid, p_location_id uuid, p_cold_room_id uuid, p_generator_id uuid, p_state_controller_id uuid, p_state_file_name text, p_state_file_sha256 text, p_state_events jsonb, p_power_controller_id uuid, p_power_file_name text, p_power_file_sha256 text, p_power_readings jsonb, p_coverage_warning_acknowledged boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  operational_summary jsonb;
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

  perform private.validate_import_temporal_context(p_location_id, p_state_events, false);
  perform private.validate_import_temporal_context(p_location_id, p_power_readings, true);
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

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_generator_id::text, 0));
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
    temporal_context,
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
    p_power_readings->0->'temporal_context',
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
  on conflict (state_batch_id, power_batch_id, temporal_context) do nothing
  returning id into target_session_id;

  if target_session_id is null then
    reused_session := true;

    select * into target_session
    from public.import_sessions as session
    where session.state_batch_id = state_batch.id
      and session.power_batch_id = power_batch.id and session.temporal_context = p_power_readings->0->'temporal_context';
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

  operational_summary := private.import_operational_summary(p_generator_id, array[state_batch.id, power_batch.id]);
  perform private.require_import_nominal_profiles(operational_summary);

  return jsonb_build_object(
    'operational_summary', operational_summary,
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
$function$
;

CREATE OR REPLACE FUNCTION private.corrected_timezone_hint(p_generator_id uuid)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select 'Fuso(s) registrado(s) nas correções: ' || coalesce(string_agg(distinct b.source_timezone, ', '), 'consulte o histórico') || '.'
  from private.power_reading_replacements x
  join public.import_batches b on b.id=x.correction_batch_id where b.generator_id=p_generator_id;
$function$
;

CREATE OR REPLACE FUNCTION private.is_supported_timezone(p_zone text)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select coalesce((p_zone = 'UTC' or p_zone ~ '^[A-Za-z_]+/[A-Za-z0-9_+/-]+$')
    and exists (select 1 from pg_catalog.pg_timezone_names where name = p_zone), false);
$function$
;

CREATE OR REPLACE FUNCTION private.location_temporal_revision()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if not private.is_supported_timezone(new.time_zone) then
    raise exception 'informe um fuso IANA suportado' using errcode = '23514';
  end if;
  if tg_op = 'INSERT' then
    new.telemetry_revision := 0;
    new.time_zone_revision := 0;
  else
    new.time_zone_revision := old.time_zone_revision + case when new.time_zone is distinct from old.time_zone then 1 else 0 end;
    new.telemetry_revision := old.telemetry_revision + case when new.time_zone is distinct from old.time_zone
      or new.telemetry_time_basis is distinct from old.telemetry_time_basis then 1 else 0 end;
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.require_new_location_time_basis()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if exists(select 1 from public.locations where id = new.id and telemetry_time_basis is null) then
    raise exception 'novos locais exigem a referência temporal da telemetria' using errcode = '23514';
  end if;
  return null;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.validate_import_temporal_context(p_location_id uuid, p_rows jsonb, p_power boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare loc public.locations%rowtype; snapshot jsonb; zone text; origin text;
begin
  if not (select private.is_active_master()) then raise insufficient_privilege; end if;
  select * into loc from public.locations where id = p_location_id and is_active for share;
  snapshot := p_rows->0->'temporal_context';
  if loc.id is null or snapshot is null or jsonb_typeof(snapshot) <> 'object' then
    raise exception 'atualize a tela e valide a configuração temporal' using errcode = 'P1501';
  end if;
  origin := snapshot->>'origin';
  zone := case when not p_power then loc.time_zone
    when origin = 'location_default' then case loc.telemetry_time_basis when 'utc' then 'UTC' when 'location' then loc.time_zone end
    when origin = 'file_override' then snapshot->>'sourceTimezone' end;
  if snapshot->>'locationId' is distinct from loc.id::text
    or snapshot->>'locationTimeZone' is distinct from loc.time_zone
    or snapshot->>'timeZoneRevision' is distinct from loc.time_zone_revision::text
    or (not p_power and origin is distinct from 'state')
    or (p_power and (loc.telemetry_time_basis is null
      or snapshot->>'telemetryTimeBasis' is distinct from loc.telemetry_time_basis
      or snapshot->>'telemetryRevision' is distinct from loc.telemetry_revision::text))
    or not private.is_supported_timezone(zone)
    or snapshot->>'sourceTimezone' is distinct from zone
    or (p_power and zone not in ('UTC', 'America/Fortaleza', loc.time_zone))
    or exists(select 1 from jsonb_array_elements(p_rows) j where j->'temporal_context' is distinct from snapshot
      or (p_power and (j->>'source_timezone' is distinct from zone or j->>'normalization_version' is distinct from '1'))) then
    raise exception 'a configuração temporal mudou; valide novamente' using errcode = 'P1501';
  end if;
  return snapshot;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.register_complete_client_structure_with_telemetry(p_client_legal_name text, p_client_cnpj text, p_location_name text, p_location_description text, p_location_time_zone text, p_cold_room_name text, p_cold_room_category text, p_generator_identifier text, p_generator_valid_from date, p_state_controller_identifier text, p_state_controller_activated_on date, p_power_controller_identifier text, p_power_controller_device_id text, p_power_controller_activated_on date, p_nominal_power_w text, p_telemetry_time_basis text, p_power_on_threshold_w numeric DEFAULT 5, p_power_off_threshold_w numeric DEFAULT 1, p_correlation_tolerance_seconds integer DEFAULT 120)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare result jsonb;
begin
  if not (select private.is_active_master()) then raise insufficient_privilege; end if;
  if p_telemetry_time_basis is null or p_telemetry_time_basis not in ('utc','location') then
    raise exception 'selecione a referência temporal da telemetria' using errcode = '23514';
  end if;
  result := public.register_complete_client_structure_with_power_profile(
    p_client_legal_name,p_client_cnpj,p_location_name,p_location_description,p_location_time_zone,
    p_cold_room_name,p_cold_room_category,p_generator_identifier,p_generator_valid_from,
    p_state_controller_identifier,p_state_controller_activated_on,p_power_controller_identifier,p_power_controller_device_id,p_power_controller_activated_on,
    p_nominal_power_w,p_power_on_threshold_w,p_power_off_threshold_w,p_correlation_tolerance_seconds);
  update public.locations set telemetry_time_basis = p_telemetry_time_basis where id = (result->>'location_id')::uuid;
  return result;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.confirm_power_xlsx_import(p_client_id uuid, p_location_id uuid, p_cold_room_id uuid, p_generator_id uuid, p_controller_id uuid, p_file_name text, p_file_sha256 text, p_readings jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  source_zone text; rule_version integer; current_user_id uuid := (select auth.uid());
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

  perform private.validate_import_temporal_context(p_location_id, p_readings, true);
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


  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_generator_id::text, 0));
  source_zone := p_readings->0->>'source_timezone';
  rule_version := case when source_zone is null then 0 else 1 end;
  if source_zone is null then
    select time_zone into source_zone from public.locations where id = p_location_id;
  elsif not private.is_supported_timezone(source_zone) then
    raise exception 'fuso não suportado' using errcode = '23514';
  end if;
  if exists (select 1 from jsonb_array_elements(p_readings) j
    where (rule_version = 1 and (j->>'source_timezone' is distinct from source_zone
      or j->>'normalization_version' is distinct from '1'))
      or (rule_version = 0 and j ? 'source_timezone')) then
    raise exception 'metadados temporais inconsistentes' using errcode = '23514';
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
    temporal_context,
    file_name,
    file_sha256,
    source_timezone,
    normalization_version,
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
    p_readings->0->'temporal_context',
    btrim(p_file_name),
    p_file_sha256,
    source_zone,
    rule_version,
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
    controller_id, source_timezone
  ) do nothing
  returning id, status into target_batch_id, target_batch_status;

  if target_batch_id is null then
    select batch.id, batch.status
    into target_batch_id, target_batch_status
    from public.import_batches as batch
    where batch.file_sha256 = p_file_sha256 and batch.source_timezone = source_zone
      and batch.client_id = p_client_id
      and batch.location_id = p_location_id
      and batch.cold_room_id = p_cold_room_id
      and batch.generator_id = p_generator_id
      and batch.controller_id = p_controller_id
      and batch.data_kind = 'power_readings'
    for update;
  end if;


  if exists (select 1 from private.power_reading_replacements x where x.old_reading_id in
    (select id from public.power_readings where import_batch_id = target_batch_id)) then
    raise exception 'este lote foi corrigido; use o fuso da correção' using errcode = 'P1301', hint = private.corrected_timezone_hint(p_generator_id);
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

  perform private.replace_power_reading_interpretations(target_batch_id, p_readings);
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
$function$
;

CREATE OR REPLACE FUNCTION private.replace_power_reading_interpretations(p_batch_id uuid, p_readings jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare affected integer;
begin
  if not (select private.is_active_master()) then raise insufficient_privilege; end if;
  if not exists (select 1 from public.import_batches where id = p_batch_id and status = 'processing') then
    raise exception 'a correção exige um lote em processamento' using errcode = '23514';
  end if;
  -- An obsolete interpretation must never reactivate when an old file is repeated.
  if exists (select 1 from jsonb_array_elements(p_readings) j
    join public.power_readings r on r.fingerprint = j->>'fingerprint'
    join private.power_reading_replacements x on x.old_reading_id = r.id) then
    raise exception 'use o fuso da importação corrigida' using errcode = 'P1301', hint = private.corrected_timezone_hint((select generator_id from public.import_batches where id=p_batch_id));
  end if;
  insert into private.power_reading_replacements(old_reading_id, new_reading_id, correction_batch_id, actor_id)
  select old.id, min(new.id), p_batch_id, (select auth.uid())
  from public.power_readings new
  join public.power_readings old on old.controller_id = new.controller_id
    and old.generator_id = new.generator_id and old.id < new.id
    and old.occurred_at_raw = new.occurred_at_raw and old.power_w = new.power_w
    and old.device_id_normalized = new.device_id_normalized
    and old.event_type = new.event_type and old.event_name = new.event_name
  join public.import_batches previous on previous.id = old.import_batch_id
  join public.import_batches current_batch on current_batch.id = new.import_batch_id
  where new.import_batch_id = p_batch_id
    and previous.status = 'confirmed'
    and (previous.source_timezone <> current_batch.source_timezone or previous.normalization_version <> current_batch.normalization_version)
  group by old.id
  on conflict (old_reading_id) do nothing;
  get diagnostics affected = row_count;
  if affected > 0 then
    insert into public.audit_logs(actor_id, action, entity_type, entity_id)
    values ((select auth.uid()), 'power_timezone_corrected', 'import_batches', p_batch_id);
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.confirm_import_session(p_client_id uuid, p_location_id uuid, p_cold_room_id uuid, p_generator_id uuid, p_state_controller_id uuid, p_state_file_name text, p_state_file_sha256 text, p_state_events jsonb, p_power_controller_id uuid, p_power_file_name text, p_power_file_sha256 text, p_power_readings jsonb, p_coverage_warning_acknowledged boolean)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$
  select private.confirm_import_session(p_client_id,p_location_id,p_cold_room_id,p_generator_id,
    p_state_controller_id,p_state_file_name,p_state_file_sha256,p_state_events,
    p_power_controller_id,p_power_file_name,p_power_file_sha256,p_power_readings,p_coverage_warning_acknowledged);
$function$
;

CREATE OR REPLACE FUNCTION public.confirm_xlsx_import(p_client_id uuid, p_location_id uuid, p_cold_room_id uuid, p_generator_id uuid, p_controller_id uuid, p_file_name text, p_file_sha256 text, p_events jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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

  perform private.validate_import_temporal_context(p_location_id, p_events, false);
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
      or event.source_classification not in ('programmed', 'manual', 'test', 'unknown')
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
    temporal_context,
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
    p_events->0->'temporal_context',
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
    controller_id, source_timezone
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
$function$
;

CREATE TRIGGER locations_temporal_audit AFTER INSERT OR UPDATE ON public.locations FOR EACH ROW EXECUTE FUNCTION private.audit_location_temporal_configuration();

CREATE TRIGGER locations_temporal_revision BEFORE INSERT OR UPDATE ON public.locations FOR EACH ROW EXECUTE FUNCTION private.location_temporal_revision();

CREATE CONSTRAINT TRIGGER new_location_requires_time_basis AFTER INSERT ON public.locations DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION private.require_new_location_time_basis();



alter table "public"."import_batches" add constraint "import_batches_timezone_metadata_check" CHECK (((normalization_version = 0) OR ((data_kind = 'power_readings'::text) AND private.is_supported_timezone(source_timezone)))) not valid;

alter table "public"."import_batches" validate constraint "import_batches_timezone_metadata_check";

-- Explicit privileges are required: schema diff does not preserve function ACLs.
revoke all on function private.audit_location_temporal_configuration(),
  private.location_temporal_revision(), private.require_new_location_time_basis(),
  private.corrected_timezone_hint(uuid), private.is_supported_timezone(text),
  private.validate_import_temporal_context(uuid,jsonb,boolean),
  private.confirm_import_session(uuid,uuid,uuid,uuid,uuid,text,text,jsonb,uuid,text,text,jsonb,boolean)
  from public, anon, authenticated;
grant execute on function private.is_supported_timezone(text),
  private.validate_import_temporal_context(uuid,jsonb,boolean),
  private.confirm_import_session(uuid,uuid,uuid,uuid,uuid,text,text,jsonb,uuid,text,text,jsonb,boolean)
  to authenticated;
revoke all on function public.register_complete_client_structure_with_telemetry(text,text,text,text,text,text,text,text,date,text,date,text,text,date,text,text,numeric,numeric,integer)
  from public, anon, authenticated;
grant execute on function public.register_complete_client_structure_with_telemetry(text,text,text,text,text,text,text,text,date,text,date,text,text,date,text,text,numeric,numeric,integer)
  to authenticated;
