-- Explicit source time zone; preserve all raw evidence and historical sessions.
alter table public.import_batches
  add column source_timezone text not null default '',
  add column normalization_version integer not null default 0
    check (normalization_version in (0, 1));

-- One-time metadata backfill; timestamps and immutable source values are untouched.
alter table public.import_batches disable trigger import_batches_prevent_session_mutation;
update public.import_batches b set source_timezone = l.time_zone
from public.locations l where b.location_id = l.id and b.data_kind = 'power_readings';
alter table public.import_batches enable trigger import_batches_prevent_session_mutation;
alter table public.import_batches drop constraint import_batches_context_key;
alter table public.import_batches add constraint import_batches_context_key unique
  (file_sha256, client_id, location_id, cold_room_id, generator_id, controller_id, source_timezone);
alter table public.import_batches add constraint import_batches_timezone_metadata_check check (
  normalization_version = 0 or (data_kind = 'power_readings' and source_timezone in ('UTC', 'America/Fortaleza'))
);
create index power_readings_raw_time_idx on public.power_readings(controller_id, occurred_at_raw, power_w);

create table private.power_reading_replacements (
  old_reading_id bigint primary key references public.power_readings(id),
  new_reading_id bigint not null references public.power_readings(id),
  correction_batch_id uuid not null references public.import_batches(id),
  actor_id uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  check (old_reading_id < new_reading_id)
);
alter table private.power_reading_replacements enable row level security;
revoke all on private.power_reading_replacements from public, anon, authenticated;

create view private.effective_power_readings as
select r.* from public.power_readings r
where not exists (select 1 from private.power_reading_replacements x where x.old_reading_id = r.id);
revoke all on private.effective_power_readings from public, anon, authenticated;

-- Coverage follows effective readings, including partially overlapping corrected files.
create view private.effective_power_batches as
select b.id, b.generator_id, b.controller_id, b.data_kind, b.status,
       min(r.occurred_at) as period_start, max(r.occurred_at) as period_end
from public.import_batches b join private.effective_power_readings r on r.import_batch_id = b.id
where b.data_kind = 'power_readings' and b.status = 'confirmed'
group by b.id;
revoke all on private.effective_power_batches from public, anon, authenticated;

create function private.replace_power_reading_interpretations(p_batch_id uuid, p_readings jsonb)
returns void language plpgsql security definer set search_path = '' as $$
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
    raise exception 'use o fuso da importação corrigida' using errcode = 'P1301';
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
$$;
revoke all on function private.replace_power_reading_interpretations(uuid,jsonb) from public, anon, authenticated;

-- Keep existing RPC signatures compatible; metadata travels with the validated rows.
do $$
declare fn regprocedure; definition text; original text;
begin
  for fn in select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in
      ('confirm_xlsx_import','record_failed_xlsx_import','confirm_power_xlsx_import','record_failed_power_xlsx_import')
  loop
    definition := pg_get_functiondef(fn);
    original := definition;
    definition := regexp_replace(definition, '(on conflict \([[:space:]]*file_sha256,[[:space:]]*client_id,[[:space:]]*location_id,[[:space:]]*cold_room_id,[[:space:]]*generator_id,[[:space:]]*controller_id)([[:space:]]*\))', '\1, source_timezone\2', 'g');
    if definition = original then raise exception 'batch conflict contract changed: %', fn; end if;
    execute definition;
  end loop;
  definition := pg_get_functiondef('public.confirm_power_xlsx_import(uuid,uuid,uuid,uuid,uuid,text,text,jsonb)'::regprocedure);
  definition := replace(definition, 'current_user_id uuid', 'source_zone text; rule_version integer; current_user_id uuid');
  definition := replace(definition, '  select count(*)::integer, min(reading.occurred_at)', $code$
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_generator_id::text, 0));
  source_zone := p_readings->0->>'source_timezone';
  rule_version := case when source_zone is null then 0 else 1 end;
  if source_zone is null then
    select time_zone into source_zone from public.locations where id = p_location_id;
  elsif source_zone not in ('UTC', 'America/Fortaleza') then
    raise exception 'fuso não suportado' using errcode = '23514';
  end if;
  if exists (select 1 from jsonb_array_elements(p_readings) j
    where (rule_version = 1 and (j->>'source_timezone' is distinct from source_zone
      or j->>'normalization_version' is distinct from '1'))
      or (rule_version = 0 and j ? 'source_timezone')) then
    raise exception 'metadados temporais inconsistentes' using errcode = '23514';
  end if;
  select count(*)::integer, min(reading.occurred_at)$code$);
  definition := replace(definition, E'    file_sha256,\n    status,', E'    file_sha256,\n    source_timezone,\n    normalization_version,\n    status,');
  definition := replace(definition, E'    p_file_sha256,\n    ''processing'',', E'    p_file_sha256,\n    source_zone,\n    rule_version,\n    ''processing'',');
  definition := replace(definition, 'where batch.file_sha256 = p_file_sha256', 'where batch.file_sha256 = p_file_sha256 and batch.source_timezone = source_zone');
  definition := replace(definition, $code$  if target_batch_status = 'confirmed' then$code$, $code$
  if exists (select 1 from private.power_reading_replacements x where x.old_reading_id in
    (select id from public.power_readings where import_batch_id = target_batch_id)) then
    raise exception 'este lote foi corrigido; use o fuso da correção' using errcode = 'P1301';
  end if;
  if target_batch_status = 'confirmed' then$code$);
  definition := replace(definition, '  update public.import_batches' || E'\n  set\n    status = ''confirmed'',',
    '  perform private.replace_power_reading_interpretations(target_batch_id, p_readings);' || E'\n  update public.import_batches\n  set\n    status = ''confirmed'',');
  -- Private body needs access to replacement records; public entry remains an invoker.
  definition := replace(definition, 'FUNCTION public.confirm_power_xlsx_import', 'FUNCTION private.confirm_power_xlsx_import');
  definition := replace(definition, 'SET search_path', 'SECURITY DEFINER SET search_path');
  execute definition;
end;
$$;
revoke all on function private.confirm_power_xlsx_import(uuid,uuid,uuid,uuid,uuid,text,text,jsonb) from public, anon;
grant execute on function private.confirm_power_xlsx_import(uuid,uuid,uuid,uuid,uuid,text,text,jsonb) to authenticated;
create or replace function public.confirm_power_xlsx_import(p_client_id uuid,p_location_id uuid,p_cold_room_id uuid,p_generator_id uuid,p_controller_id uuid,p_file_name text,p_file_sha256 text,p_readings jsonb)
returns jsonb language sql security invoker set search_path = '' as $$
  select private.confirm_power_xlsx_import(p_client_id,p_location_id,p_cold_room_id,p_generator_id,p_controller_id,p_file_name,p_file_sha256,p_readings);
$$;

do $$
declare fn regprocedure; definition text;
begin
  foreach fn in array array['private.power_transitions(uuid)'::regprocedure,
    'private.desired_power_verifications(uuid)'::regprocedure,
    'private.reprocess_power_telemetry_correlation(uuid)'::regprocedure] loop
    definition := pg_get_functiondef(fn);
    definition := replace(definition, 'public.power_readings', 'private.effective_power_readings');
    definition := replace(definition, 'public.import_batches', 'private.effective_power_batches');
    execute definition;
  end loop;
end;
$$;
