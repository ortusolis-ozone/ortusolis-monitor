-- Spec 16. Publication starts the notice period explicitly; migration alone
-- never starts the destructive policy before the PDF is available.
create table private.history_retention_policy (
  singleton boolean primary key default true check (singleton),
  activates_at timestamptz
);
insert into private.history_retention_policy(singleton) values (true);
alter table private.history_retention_policy enable row level security;
revoke all on private.history_retention_policy from public, anon, authenticated, service_role;

create function private.start_history_retention_notice() returns timestamptz
language sql security definer set search_path = '' as $$
  update private.history_retention_policy
  set activates_at = coalesce(activates_at, transaction_timestamp() + interval '35 days')
  returning activates_at;
$$;
revoke all on function private.start_history_retention_notice() from public, anon, authenticated, service_role;

create function private.history_retention_active() returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(transaction_timestamp() >= activates_at, false)
  from private.history_retention_policy where singleton;
$$;
create function private.history_date_allowed(p_date date, p_location_id uuid, p_days integer)
returns boolean language sql stable security definer set search_path = '' as $$
  select not private.history_retention_active() or exists (
    select 1 from public.locations l where l.id = p_location_id
      and p_date between (transaction_timestamp() at time zone l.time_zone)::date - (p_days - 1)
                     and (transaction_timestamp() at time zone l.time_zone)::date
  );
$$;
create function private.history_instant_allowed(p_at timestamptz, p_location_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select not private.history_retention_active() or exists (
    select 1 from public.locations l where l.id = p_location_id
      and p_at >= (((transaction_timestamp() at time zone l.time_zone)::date - 89)::timestamp at time zone l.time_zone)
      and p_at < (((transaction_timestamp() at time zone l.time_zone)::date + 1)::timestamp at time zone l.time_zone)
  );
$$;
create function private.history_generator_date_allowed(p_date date, p_generator_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select not private.history_retention_active() or exists (
    select 1 from public.generator_assignments a
    join public.cold_rooms r on r.id = a.cold_room_id
    join public.locations l on l.id = r.location_id
    where a.generator_id = p_generator_id
      and p_date >= (a.valid_from at time zone l.time_zone)::date
      and (a.valid_until is null or p_date <= (a.valid_until at time zone l.time_zone)::date)
      and private.history_date_allowed(p_date, l.id, 90)
  );
$$;
revoke all on function private.history_retention_active(),
  private.history_date_allowed(date,uuid,integer), private.history_instant_allowed(timestamptz,uuid),
  private.history_generator_date_allowed(date,uuid) from public, anon;
grant execute on function private.history_retention_active(),
  private.history_date_allowed(date,uuid,integer), private.history_instant_allowed(timestamptz,uuid),
  private.history_generator_date_allowed(date,uuid) to authenticated;

create function private.get_history_retention_windows()
returns table(location_id uuid, today date, client_start_date date, operational_start_date date, activates_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_active_master() and private.current_client_id() is null then
    raise insufficient_privilege;
  end if;
  return query select l.id, (transaction_timestamp() at time zone l.time_zone)::date,
    case when private.history_retention_active() then (transaction_timestamp() at time zone l.time_zone)::date - 34 end,
    case when private.history_retention_active() then (transaction_timestamp() at time zone l.time_zone)::date - 89 end,
    p.activates_at
  from public.locations l cross join private.history_retention_policy p
  where private.is_active_master() or l.client_id = private.current_client_id();
end;
$$;
create function public.get_history_retention_windows()
returns table(location_id uuid, today date, client_start_date date, operational_start_date date, activates_at timestamptz)
language sql stable security invoker set search_path = '' as $$
  select * from private.get_history_retention_windows();
$$;
revoke all on function private.get_history_retention_windows(), public.get_history_retention_windows() from public, anon;
grant execute on function private.get_history_retention_windows(), public.get_history_retention_windows() to authenticated;

-- These private views also protect SECURITY DEFINER readers, which bypass RLS.
create view private.retained_raw_events as select e.* from public.raw_events e
join public.import_batches b on b.id = e.import_batch_id
where private.history_instant_allowed(e.occurred_at,b.location_id);
create view private.retained_power_readings as select r.* from public.power_readings r
where private.history_instant_allowed(r.occurred_at,r.location_id);
create view private.retained_applications as select a.* from public.applications a
where private.history_generator_date_allowed(a.public_date,a.generator_id);
create view private.retained_inconsistencies as select i.* from public.inconsistencies i
where private.history_generator_date_allowed(i.public_date,i.generator_id);
create view private.retained_client_daily_status as select d.* from public.client_daily_status d
where private.history_date_allowed(d.status_date,d.location_id,
  case when private.is_active_master() then 90 else 35 end);
revoke all on private.retained_raw_events, private.retained_power_readings,
  private.retained_applications, private.retained_inconsistencies, private.retained_client_daily_status
  from public, anon, authenticated, service_role;

create policy history_window on public.client_daily_status as restrictive for select to authenticated
using (private.history_date_allowed(status_date,location_id,case when private.is_active_master() then 90 else 35 end));
create policy history_window on public.raw_events as restrictive for select to authenticated
using (exists (select 1 from public.import_batches b where b.id=import_batch_id
  and private.history_instant_allowed(occurred_at,b.location_id)));
create policy history_window on public.power_readings as restrictive for select to authenticated
using (private.history_instant_allowed(occurred_at,location_id));
create policy history_window on public.applications as restrictive for select to authenticated
using (private.history_generator_date_allowed(public_date,generator_id));
create policy history_window on public.inconsistencies as restrictive for select to authenticated
using (private.history_generator_date_allowed(public_date,generator_id));
create function private.history_application_allowed(p_id bigint) returns boolean
language sql stable security definer set search_path='' as $$
 select not private.history_retention_active() or exists(select 1 from public.applications a
   where a.id=p_id and private.history_generator_date_allowed(a.public_date,a.generator_id));
$$;
revoke all on function private.history_application_allowed(bigint) from public,anon;
grant execute on function private.history_application_allowed(bigint) to authenticated;
create policy history_window on public.application_power_verifications as restrictive for select to authenticated
using (private.history_application_allowed(application_id));
create policy history_window on public.import_batches as restrictive for select to authenticated
using (private.history_instant_allowed(coalesce(period_end,created_at),location_id));
create policy history_window on public.import_sessions as restrictive for select to authenticated
using (private.history_instant_allowed(coalesce(greatest(state_period_end,power_period_end),created_at),location_id));

-- Extend canonical readers without duplicating their domain logic. All changed
-- definitions are resolved inside this migration; contracts fail closed.
do $$
declare f record; definition text; tab text;
begin
  for f in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('private','public') and p.prosecdef and p.proname like 'list_%'
  loop
    definition := pg_get_functiondef(f.oid);
    foreach tab in array array['raw_events','power_readings','applications','inconsistencies','client_daily_status'] loop
      definition := regexp_replace(definition, '(from|join) public\.' || tab || '\M',
        '\1 private.retained_' || tab, 'gi');
    end loop;
    execute definition;
  end loop;
end;
$$;

-- Filtering runs before counts, coverage and file reuse, also for legacy RPCs.
create function private.retained_import_rows(p_rows jsonb,p_location_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare result jsonb; expected integer;
begin
  if not private.is_active_master() then raise insufficient_privilege; end if;
  if jsonb_typeof(p_rows) is distinct from 'array' then raise invalid_parameter_value; end if;
  select coalesce(jsonb_agg(j order by ord),'[]'::jsonb) into result
  from jsonb_array_elements(p_rows) with ordinality as x(j,ord)
  where private.history_instant_allowed((j->>'occurred_at')::timestamptz,p_location_id);
  expected := (p_rows->0->>'retention_expected_count')::integer;
  if expected is not null and expected <> jsonb_array_length(result) then
    raise exception 'O período disponível mudou. Valide os arquivos novamente.' using errcode='P1601';
  end if;
  if jsonb_array_length(result)=0 then
    raise exception 'Todos os registros estão fora do período de retenção de 90 dias.' using errcode='P1602';
  end if;
  return result;
end;
$$;
revoke all on function private.retained_import_rows(jsonb,uuid) from public, anon;
grant execute on function private.retained_import_rows(jsonb,uuid) to authenticated;
do $$
declare f record; definition text; insertion text;
begin
  for f in select p.oid,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where (n.nspname='public' and p.proname='confirm_xlsx_import') or
          (n.nspname='private' and p.proname in ('confirm_power_xlsx_import','confirm_import_session'))
  loop
    definition := pg_get_functiondef(f.oid);
    insertion := case f.proname
      when 'confirm_xlsx_import' then 'p_events := private.retained_import_rows(p_events,p_location_id);'
      when 'confirm_power_xlsx_import' then 'p_readings := private.retained_import_rows(p_readings,p_location_id);'
      else 'p_state_events := private.retained_import_rows(p_state_events,p_location_id); p_power_readings := private.retained_import_rows(p_power_readings,p_location_id);' end;
    if strpos(definition,E'begin\n')=0 then raise exception 'import contract changed: %',f.proname; end if;
    execute overlay(definition placing E'begin\n  ' || insertion || E'\n' from strpos(definition,E'begin\n') for 6);
  end loop;
end;
$$;

-- Direct inserts cannot resurrect expired evidence. Lock with the canonical
-- importer before checking the cutoff so cleanup cannot race these writes.
create function private.guard_retained_evidence() returns trigger
language plpgsql security definer set search_path = '' as $$
declare loc uuid;
begin
  perform pg_advisory_xact_lock(hashtextextended(new.generator_id::text,0));
  select location_id into loc from public.import_batches where id=new.import_batch_id;
  if not private.history_instant_allowed(new.occurred_at,loc) then
    raise exception 'Registro fora do período de retenção.' using errcode='P1602';
  end if;
  return new;
end;
$$;
revoke all on function private.guard_retained_evidence() from public, anon, authenticated;
create trigger retention_evidence before insert on public.raw_events for each row execute function private.guard_retained_evidence();
create trigger retention_evidence before insert on public.power_readings for each row execute function private.guard_retained_evidence();

-- Reprocessing uses retained evidence even if a scheduled cleanup was delayed.
do $$
declare definition text;
begin
  definition := pg_get_functiondef('private.reprocess_generator(uuid)'::regprocedure);
  if strpos(definition,'from public.raw_events as event')=0 then raise exception 'state reprocessor contract changed'; end if;
  definition := replace(definition,'from public.raw_events as event','from private.retained_raw_events as event');
  execute definition;
end;
$$;
create or replace view private.effective_power_readings as
select r.* from public.power_readings r
where not exists(select 1 from private.power_reading_replacements x where x.old_reading_id=r.id)
and private.history_instant_allowed(r.occurred_at,r.location_id);
create function private.guard_retained_daily_status() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if not private.history_date_allowed(new.status_date,new.location_id,90) then return null; end if;
  return new;
end;
$$;
revoke all on function private.guard_retained_daily_status() from public,anon,authenticated;
create trigger retention_daily_status before insert or update on public.client_daily_status
for each row execute function private.guard_retained_daily_status();

-- A private, transaction-scoped marker cannot be forged with a custom GUC.
create table private.retention_maintenance_transactions (transaction_id bigint primary key);
alter table private.retention_maintenance_transactions enable row level security;
revoke all on private.retention_maintenance_transactions from public,anon,authenticated,service_role;
create function private.in_retention_maintenance() returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.retention_maintenance_transactions where transaction_id=txid_current());
$$;
revoke all on function private.in_retention_maintenance() from public,anon,authenticated,service_role;
do $$
declare definition text;
begin
 definition:=pg_get_functiondef('private.prevent_import_session_mutation()'::regprocedure);
 execute replace(definition,E'begin\n',E'begin\n  if private.in_retention_maintenance() then return case when tg_op=''DELETE'' then old else new end; end if;\n');
 definition:=pg_get_functiondef('private.prevent_session_batch_mutation()'::regprocedure);
 execute replace(definition,E'begin\n',E'begin\n  if private.in_retention_maintenance() then return case when tg_op=''DELETE'' then old else new end; end if;\n');
end;
$$;

-- Keep only the fact that evidence expired, never the expired measurement.
alter table public.applications add column retention_evidence_removed boolean not null default false;
create function private.guard_retention_power_result() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.applications a where a.id=new.application_id and a.retention_evidence_removed) then
   if tg_table_name='inconsistencies' then
     if new.type like 'missing_power_%' or new.type='power_below_expected' then return null; end if;
   else
     new.status:='no_coverage'; new.technical_reason:='evidence_expired_by_retention';
     new.power_on_reading_id:=null; new.power_off_reading_id:=null;
     new.reference_power_reading_id:=null; new.observed_power_w_snapshot:=null;
     new.operational_power_status:=case when new.power_profile_id is null then 'not_configured' else 'not_evaluable' end;
     new.operational_reason:='evidence_expired_by_retention';
   end if;
 end if;
 return new;
end;
$$;
revoke all on function private.guard_retention_power_result() from public,anon,authenticated;
create trigger retention_power_result before insert or update on public.application_power_verifications
for each row execute function private.guard_retention_power_result();
create trigger retention_power_result before insert or update on public.inconsistencies
for each row execute function private.guard_retention_power_result();

-- Preserve the reason before correlation replaces references to expired readings.
create function private.mark_expired_power_evidence(p_generator_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform pg_advisory_xact_lock(hashtextextended(p_generator_id::text,0));
 update public.applications a set retention_evidence_removed=true
 where a.generator_id=p_generator_id and not a.retention_evidence_removed and exists (
   select 1 from public.application_power_verifications v join public.power_readings r
   on r.id in (v.power_on_reading_id,v.power_off_reading_id,v.reference_power_reading_id)
   where v.application_id=a.id and not private.history_instant_allowed(r.occurred_at,r.location_id)
 );
end;
$$;
revoke all on function private.mark_expired_power_evidence(uuid) from public,anon,authenticated,service_role;
do $$
declare definition text;
begin
 definition:=pg_get_functiondef('private.reprocess_power_telemetry(uuid)'::regprocedure);
 execute replace(definition,E'begin\n',E'begin\n  perform private.mark_expired_power_evidence(p_generator_id);\n');
end;
$$;

create function private.history_date_expired(p_date date,p_location_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select private.history_retention_active() and exists(select 1 from public.locations l where l.id=p_location_id
 and p_date<(transaction_timestamp() at time zone l.time_zone)::date-89);
$$;
create function private.history_instant_expired(p_at timestamptz,p_location_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select private.history_retention_active() and exists(select 1 from public.locations l where l.id=p_location_id
 and p_at<(((transaction_timestamp() at time zone l.time_zone)::date-89)::timestamp at time zone l.time_zone));
$$;
create function private.history_generator_date_expired(p_date date,p_generator_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select private.history_retention_active() and exists(select 1 from public.generator_assignments a
 join public.locations l on l.id=a.location_id where a.generator_id=p_generator_id
 and p_date>=(a.valid_from at time zone l.time_zone)::date
 and (a.valid_until is null or p_date<=(a.valid_until at time zone l.time_zone)::date)
 and private.history_date_expired(p_date,l.id));
$$;
revoke all on function private.history_date_expired(date,uuid), private.history_instant_expired(timestamptz,uuid),
private.history_generator_date_expired(date,uuid) from public,anon,authenticated,service_role;

create function private.history_retention_counts()
returns table(table_name text, expired_rows bigint)
language sql stable security definer set search_path='' as $$
 select 'raw_events',count(*) from public.raw_events e join public.import_batches b on b.id=e.import_batch_id
 where private.history_instant_expired(e.occurred_at,b.location_id)
 union all select 'power_readings',count(*) from public.power_readings r where private.history_instant_expired(r.occurred_at,r.location_id)
 union all select 'applications',count(*) from public.applications a where private.history_generator_date_expired(a.public_date,a.generator_id)
 union all select 'inconsistencies',count(*) from public.inconsistencies i where private.history_generator_date_expired(i.public_date,i.generator_id)
 union all select 'client_daily_status',count(*) from public.client_daily_status d where private.history_date_expired(d.status_date,d.location_id)
 union all select 'application_power_verifications',count(*) from public.application_power_verifications v
 join public.applications a on a.id=v.application_id where private.history_generator_date_expired(a.public_date,a.generator_id)
 union all select 'power_reading_replacements',count(*) from private.power_reading_replacements x
 where exists(select 1 from public.power_readings r where r.id in (x.old_reading_id,x.new_reading_id)
   and private.history_instant_expired(r.occurred_at,r.location_id))
 union all select 'import_sessions',count(*) from public.import_sessions s
 where private.history_instant_expired(coalesce(greatest(s.state_period_end,s.power_period_end),s.created_at),s.location_id)
 and not exists(select 1 from public.raw_events e where e.import_batch_id=s.state_batch_id and not private.history_instant_expired(e.occurred_at,s.location_id))
 and not exists(select 1 from public.power_readings r where r.import_batch_id=s.power_batch_id and not private.history_instant_expired(r.occurred_at,r.location_id))
 union all select 'import_batches',count(*) from public.import_batches b
 where private.history_instant_expired(coalesce(b.period_end,b.created_at),b.location_id)
 and not exists(select 1 from public.raw_events e where e.import_batch_id=b.id and not private.history_instant_expired(e.occurred_at,b.location_id))
 and not exists(select 1 from public.power_readings r where r.import_batch_id=b.id and not private.history_instant_expired(r.occurred_at,r.location_id))
 union all select 'operational_power_reprocessing_runs',count(*) from private.operational_power_reprocessing_runs r
 where private.history_retention_active() and (r.affected_from is null or r.processed_at<transaction_timestamp()-interval '90 days'
 or exists(select 1 from public.generator_assignments a where a.generator_id=r.generator_id and private.history_instant_expired(r.affected_from,a.location_id)));
$$;
revoke all on function private.history_retention_counts() from public,anon,authenticated,service_role;

create function private.purge_generator_history(p_generator_id uuid,p_limit integer default 5000)
returns jsonb language plpgsql security definer set search_path='' as $$
declare events bigint[]; readings bigint[]; n integer; counts jsonb:='{}';
begin
 if not private.history_retention_active() then return counts; end if;
 if p_limit is null or p_limit<1 or p_limit>5000 then raise invalid_parameter_value; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_generator_id::text,0));
 insert into private.retention_maintenance_transactions values(txid_current()) on conflict do nothing;
 select array_agg(id) into events from (
   select e.id from public.raw_events e join public.import_batches b on b.id=e.import_batch_id
   where e.generator_id=p_generator_id and private.history_instant_expired(e.occurred_at,b.location_id)
   order by e.occurred_at,e.id limit p_limit
 ) x;
 select array_agg(id) into readings from (
   select r.id from public.power_readings r where r.generator_id=p_generator_id
     and private.history_instant_expired(r.occurred_at,r.location_id)
   order by r.occurred_at,r.id limit p_limit
 ) x;
 -- Replacement links are removed only alongside the obsolete interpretations.
 -- If the new interpretation expires first, remove its superseded predecessor
 -- too, so deleting the link can never reactivate an obsolete reading.
 with recursive obsolete(id) as (
   select unnest(readings) union
   select x.old_reading_id from private.power_reading_replacements x join obsolete o on o.id=x.new_reading_id
 ) select array_agg(id) into readings from obsolete;
 update public.applications a set retention_evidence_removed=true
 where a.generator_id=p_generator_id and exists (
   select 1 from public.application_power_verifications v where v.application_id=a.id
   and (v.power_on_reading_id=any(readings) or v.power_off_reading_id=any(readings) or v.reference_power_reading_id=any(readings))
 );
 update public.application_power_verifications v set
   power_on_reading_id=null,power_off_reading_id=null,reference_power_reading_id=null,
   observed_power_w_snapshot=null,status='no_coverage',technical_reason='evidence_expired_by_retention',
   operational_power_status=case when v.power_profile_id is null then 'not_configured' else 'not_evaluable' end,
   operational_reason='evidence_expired_by_retention'
 where v.generator_id=p_generator_id and exists(select 1 from public.applications a where a.id=v.application_id and a.retention_evidence_removed);
 delete from public.inconsistencies i where i.generator_id=p_generator_id and (
   i.id in (select old.id from public.inconsistencies old where old.generator_id=p_generator_id
     and private.history_generator_date_expired(old.public_date,old.generator_id) order by old.id limit p_limit)
   or i.event_id=any(events) or i.related_event_id=any(events) or i.power_reading_id=any(readings)
   or ((i.type like 'missing_power_%' or i.type='power_below_expected') and exists(
     select 1 from public.applications a where a.id=i.application_id and a.retention_evidence_removed))
 );
 get diagnostics n=row_count; counts:=counts||jsonb_build_object('inconsistencies',n);
 delete from public.applications a where a.generator_id=p_generator_id and (
   a.id in (select old.id from public.applications old where old.generator_id=p_generator_id
     and private.history_generator_date_expired(old.public_date,old.generator_id) order by old.id limit p_limit)
   or a.start_event_id=any(events) or a.end_event_id=any(events));
 get diagnostics n=row_count; counts:=counts||jsonb_build_object('applications',n);
 delete from private.power_reading_replacements where old_reading_id=any(readings) or new_reading_id=any(readings);
 get diagnostics n=row_count; counts:=counts||jsonb_build_object('power_reading_replacements',n);
 delete from public.raw_events where id=any(events);
 get diagnostics n=row_count; counts:=counts||jsonb_build_object('raw_events',n);
 delete from public.power_readings where id=any(readings);
 get diagnostics n=row_count; counts:=counts||jsonb_build_object('power_readings',n);
 delete from public.client_daily_status d where (d.generator_id,d.status_date) in (
   select old.generator_id,old.status_date from public.client_daily_status old where old.generator_id=p_generator_id
   and private.history_date_expired(old.status_date,old.location_id) order by old.status_date limit p_limit);
 get diagnostics n=row_count; counts:=counts||jsonb_build_object('client_daily_status',n);
 -- Keep a shared session until both sources have expired.
 delete from public.import_sessions s where s.generator_id=p_generator_id
   and not exists(select 1 from public.raw_events e where e.import_batch_id=s.state_batch_id)
   and not exists(select 1 from public.power_readings r where r.import_batch_id=s.power_batch_id)
   and private.history_instant_expired(coalesce(greatest(s.state_period_end,s.power_period_end),s.created_at),s.location_id);
 get diagnostics n=row_count; counts:=counts||jsonb_build_object('import_sessions',n);
 delete from public.import_batches b where b.generator_id=p_generator_id
   and not exists(select 1 from public.raw_events e where e.import_batch_id=b.id)
   and not exists(select 1 from public.power_readings r where r.import_batch_id=b.id)
   and not exists(select 1 from public.import_sessions s where s.state_batch_id=b.id or s.power_batch_id=b.id)
   and not exists(select 1 from private.power_reading_replacements x where x.correction_batch_id=b.id)
   and private.history_instant_expired(coalesce(b.period_end,b.created_at),b.location_id);
 get diagnostics n=row_count; counts:=counts||jsonb_build_object('import_batches',n);
 -- A run summarizes its entire input. Drop summaries affected by removed
 -- evidence instead of retaining old operational counts under a recent run date.
 delete from private.operational_power_reprocessing_runs r where r.id in (
   select old.id from private.operational_power_reprocessing_runs old where old.generator_id=p_generator_id
   and (events is not null or readings is not null or old.processed_at<transaction_timestamp()-interval '90 days'
     or old.affected_from is null
     or exists(select 1 from public.generator_assignments a where a.generator_id=p_generator_id
       and private.history_instant_expired(old.affected_from,a.location_id)))
   order by old.id limit p_limit);
 get diagnostics n=row_count; counts:=counts||jsonb_build_object('reprocessing_runs',n);
 delete from private.retention_maintenance_transactions where transaction_id=txid_current();
 return counts;
end;
$$;
revoke all on function private.purge_generator_history(uuid,integer) from public,anon,authenticated,service_role;

-- Commits each bounded pass, releasing the generator lock between batches.
create procedure private.purge_history() language plpgsql as $$
declare g record; counts jsonb; total bigint;
begin
 -- A procedure with a SET clause cannot COMMIT. Set the local path explicitly
 -- after each transaction boundary instead. Only postgres may CALL this job.
 perform pg_catalog.set_config('search_path','',true);
 if not private.history_retention_active() then return; end if;
 for g in select id from public.generators order by id loop
   loop
     counts:=private.purge_generator_history(g.id);
     select coalesce(sum(value::bigint),0) into total from jsonb_each_text(counts);
     if total>0 then
       insert into public.audit_logs(action,entity_type,entity_id,metadata)
       values('history_retention_purge','generators',g.id::text,counts);
     end if;
     commit;
     perform pg_catalog.set_config('search_path','',true);
     exit when total=0;
   end loop;
 end loop;
 -- Administrative audit survives; operational payloads do not survive their rows.
 update public.audit_logs l set metadata='{}'
 where l.entity_type in ('raw_events','power_readings','applications','inconsistencies','import_batches','import_sessions')
 and l.metadata<>'{}'::jsonb and (l.occurred_at<now()-interval '90 days' or not exists (
   select 1 from public.raw_events r where l.entity_type='raw_events' and r.id::text=l.entity_id
   union all select 1 from public.power_readings r where l.entity_type='power_readings' and r.id::text=l.entity_id
   union all select 1 from public.applications r where l.entity_type='applications' and r.id::text=l.entity_id
   union all select 1 from public.inconsistencies r where l.entity_type='inconsistencies' and r.id::text=l.entity_id
   union all select 1 from public.import_batches r where l.entity_type='import_batches' and r.id::text=l.entity_id
   union all select 1 from public.import_sessions r where l.entity_type='import_sessions' and r.id::text=l.entity_id
 ));
 commit;
end;
$$;
revoke all on procedure private.purge_history() from public,anon,authenticated,service_role;
create extension if not exists pg_cron;
select cron.schedule('history-retention-daily','15 6 * * *','call private.purge_history()');

-- Storage objects must be deleted through its API, never with SQL DELETE.
-- Vault secrets are configured at release; no credentials enter migrations.
create extension if not exists http with schema extensions;
create function private.purge_abandoned_import_uploads() returns integer
language plpgsql security definer set search_path='' as $$
declare paths jsonb; base_url text; api_key text; response extensions.http_response; removed integer:=0;
begin
 select decrypted_secret into base_url from vault.decrypted_secrets where name='retention_storage_url';
 select decrypted_secret into api_key from vault.decrypted_secrets where name='retention_storage_service_key';
 loop
   select jsonb_agg(name) into paths from (
     select name from storage.objects where bucket_id='operational-imports'
       and created_at<now()-interval '24 hours' order by name limit 100
   ) x;
   exit when paths is null;
   if base_url is null or api_key is null then
     raise exception 'Configure os segredos Vault retention_storage_url e retention_storage_service_key.';
   end if;
   select * into response from extensions.http((
     'DELETE',rtrim(base_url,'/')||'/storage/v1/object/operational-imports',
     array[extensions.http_header('Authorization','Bearer '||api_key),extensions.http_header('apikey',api_key)],
     'application/json',jsonb_build_object('prefixes',paths)::text
   )::extensions.http_request);
   if response.status<200 or response.status>=300 then
     raise exception 'Falha na limpeza Storage (HTTP %).',response.status;
   end if;
   if exists(select 1 from storage.objects where bucket_id='operational-imports' and name in (select jsonb_array_elements_text(paths))) then
     raise exception 'Storage não confirmou a remoção dos arquivos temporários.';
   end if;
   removed:=removed+jsonb_array_length(paths);
 end loop;
 return removed;
end;
$$;
revoke all on function private.purge_abandoned_import_uploads() from public,anon,authenticated,service_role;
select cron.schedule('abandoned-import-uploads-daily','45 6 * * *','select private.purge_abandoned_import_uploads()');
