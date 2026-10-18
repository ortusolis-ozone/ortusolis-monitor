-- Adapt pre-Spec-15 fixtures explicitly to the current import contract.
-- This file is included only inside rolled-back test transactions.
alter table public.locations alter column telemetry_time_basis set default 'location';
create function pg_temp.temporal_rows(p_location_id uuid, p_rows jsonb, p_power boolean)
returns jsonb language plpgsql as $$
declare loc public.locations%rowtype; zone text; snapshot jsonb;
begin
  if jsonb_typeof(p_rows) is distinct from 'array' or jsonb_array_length(p_rows) = 0 then return p_rows; end if;
  select * into loc from public.locations where id = p_location_id;
  zone := case when p_power then coalesce(p_rows->0->>'source_timezone', loc.time_zone) else loc.time_zone end;
  snapshot := jsonb_build_object('locationId', loc.id, 'locationTimeZone', loc.time_zone,
    'timeZoneRevision', loc.time_zone_revision, 'telemetryRevision', loc.telemetry_revision,
    'telemetryTimeBasis', loc.telemetry_time_basis, 'sourceTimezone', zone,
    'origin', case when p_power then 'file_override' else 'state' end);
  return (select jsonb_agg(j || jsonb_build_object('temporal_context', snapshot)
    || case when p_power then jsonb_build_object('source_timezone', coalesce(j->>'source_timezone',zone), 'normalization_version',1) else '{}'::jsonb end)
    from jsonb_array_elements(p_rows) j);
end;
$$;
do $$
declare fn record; args text; params text;
begin
  for fn in select p.* from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in ('confirm_xlsx_import','confirm_power_xlsx_import','confirm_import_session','preview_import_session') loop
    args := pg_get_function_arguments(fn.oid);
    select string_agg(case name
      when 'p_events' then 'pg_temp.temporal_rows(p_location_id,p_events,false)'
      when 'p_readings' then 'pg_temp.temporal_rows(p_location_id,p_readings,true)'
      when 'p_state_events' then 'pg_temp.temporal_rows(p_location_id,p_state_events,false)'
      when 'p_power_readings' then 'pg_temp.temporal_rows(p_location_id,p_power_readings,true)'
      else name end, ',') into params from unnest(fn.proargnames) name;
    execute format('create function pg_temp.%I(%s) returns jsonb language sql as %L',fn.proname,args,
      format('select public.%I(%s)',fn.proname,params));
  end loop;
end;
$$;
