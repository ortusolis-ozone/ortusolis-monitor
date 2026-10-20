begin;
\ir helpers/temporal-fixtures.sql

select extensions.plan(1);
update private.history_retention_policy set activates_at=null;

insert into public.clients (id, legal_name, cnpj)
values
  ('c8100000-0000-4000-8000-000000000001', 'Cliente Contrato A', '04252011000110'),
  ('c8100000-0000-4000-8000-000000000002', 'Cliente Contrato B', '11444777000161');

insert into auth.users (id)
values
  ('c8200000-0000-4000-8000-000000000001'),
  ('c8200000-0000-4000-8000-000000000002'),
  ('c8200000-0000-4000-8000-000000000003');

insert into public.profiles (id, client_id, full_name, role)
values
  ('c8200000-0000-4000-8000-000000000001', null, 'Master Contrato', 'master'),
  ('c8200000-0000-4000-8000-000000000002', 'c8100000-0000-4000-8000-000000000001', 'Leitor Contrato A', 'viewer'),
  ('c8200000-0000-4000-8000-000000000003', 'c8100000-0000-4000-8000-000000000002', 'Leitor Contrato B', 'viewer');

insert into public.locations (id, client_id, name, time_zone)
values
  ('c8300000-0000-4000-8000-000000000001', 'c8100000-0000-4000-8000-000000000001', 'Unidade Contrato A', 'America/Fortaleza'),
  ('c8300000-0000-4000-8000-000000000002', 'c8100000-0000-4000-8000-000000000002', 'Unidade Contrato B', 'America/Fortaleza');

insert into public.cold_rooms (id, client_id, location_id, name, category)
values
  ('c8400000-0000-4000-8000-000000000001', 'c8100000-0000-4000-8000-000000000001', 'c8300000-0000-4000-8000-000000000001', 'Câmara Contrato A', 'outros'),
  ('c8400000-0000-4000-8000-000000000002', 'c8100000-0000-4000-8000-000000000002', 'c8300000-0000-4000-8000-000000000002', 'Câmara Contrato B', 'outros');

insert into public.generators (id, client_id, identifier)
values
  ('c8500000-0000-4000-8000-000000000001', 'c8100000-0000-4000-8000-000000000001', 'Gerador Contrato A'),
  ('c8500000-0000-4000-8000-000000000002', 'c8100000-0000-4000-8000-000000000002', 'Gerador Contrato B');

insert into public.controllers (
  id, client_id, generator_id, identifier, activated_at, role
)
values (
  'c8600000-0000-4000-8000-000000000001',
  'c8100000-0000-4000-8000-000000000001',
  'c8500000-0000-4000-8000-000000000001',
  'Estado Contrato A',
  '2026-01-01 00:00:00+00',
  'state'
);

insert into public.controllers (
  id, client_id, generator_id, identifier, activated_at, role,
  external_device_id, power_on_threshold_w, power_off_threshold_w,
  correlation_tolerance_seconds
)
values (
  'c8600000-0000-4000-8000-000000000002',
  'c8100000-0000-4000-8000-000000000001',
  'c8500000-0000-4000-8000-000000000001',
  'Potência Contrato A',
  '2026-01-01 00:00:00+00',
  'power_telemetry',
  'device-contract-a',
  5,
  1,
  120
);

insert into public.generator_power_profiles (
  id, generator_id, nominal_power_w, valid_from, created_by
)
values (
  'c8700000-0000-4000-8000-000000000001',
  'c8500000-0000-4000-8000-000000000001',
  100,
  '2026-01-01 00:00:00+00',
  'c8200000-0000-4000-8000-000000000001'
);

insert into public.generator_assignments(generator_id,client_id,location_id,cold_room_id,valid_from)
values('c8500000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000001',
'c8300000-0000-4000-8000-000000000001','c8400000-0000-4000-8000-000000000001','2020-01-01');
insert into public.source_mappings(normalized_source,classification,created_by) values('retention','programmed','c8200000-0000-4000-8000-000000000001');
insert into public.import_batches(id,client_id,location_id,cold_room_id,generator_id,controller_id,
data_kind,file_name,file_sha256,status,total_rows,inserted_rows,period_start,period_end,created_by,confirmed_at)
select 'c8800000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000001',
'c8300000-0000-4000-8000-000000000001','c8400000-0000-4000-8000-000000000001',
'c8500000-0000-4000-8000-000000000001','c8600000-0000-4000-8000-000000000001',
'state_events','mixed.xlsx',repeat('1',64),'confirmed',10,10,now()-interval '90 days',now(),
'c8200000-0000-4000-8000-000000000001',now();
insert into public.raw_events(import_batch_id,generator_id,controller_id,occurred_at,occurred_at_raw,
operation,operation_raw,source_original,source_normalized,source_classification,fingerprint)
select 'c8800000-0000-4000-8000-000000000001','c8500000-0000-4000-8000-000000000001',
'c8600000-0000-4000-8000-000000000001',
(((now() at time zone 'America/Fortaleza')::date-age)::timestamp
 + case when age=90 and step=1 then interval '1 day 30 minutes'
        when age=89 then interval '1 hour'+step*interval '30 seconds'
        else step*interval '30 seconds' end) at time zone 'America/Fortaleza',
'raw',case step when 0 then 'turn_on' else 'turn_off' end,'raw','retention','retention','programmed',
lpad((age*2+step+1)::text,64,'0')
from unnest(array[0,34,35,89,90]) age cross join generate_series(0,1) step;
select private.reprocess_all_generator_data('c8500000-0000-4000-8000-000000000001');

-- Transition does not start on migration; an explicit publication starts 35 days.
do $$
declare activation timestamptz;
begin
 if private.history_retention_active() then raise exception 'migration started retention'; end if;
 activation:=private.start_history_retention_notice();
 if activation<>transaction_timestamp()+interval '35 days' or private.start_history_retention_notice()<>activation then
   raise exception 'notice not idempotent or not 35 days'; end if;
 if private.purge_generator_history('c8500000-0000-4000-8000-000000000001')<>'{}'::jsonb then raise exception 'notice deleted data'; end if;
end;
$$;
-- Cross-cutoff power evidence: the application is retained but this reading is not.
insert into public.import_batches(id,client_id,location_id,cold_room_id,generator_id,controller_id,
data_kind,file_name,file_sha256,status,total_rows,inserted_rows,period_start,period_end,created_by,confirmed_at)
select 'c8800000-0000-4000-8000-000000000002','c8100000-0000-4000-8000-000000000001',
'c8300000-0000-4000-8000-000000000001','c8400000-0000-4000-8000-000000000001',
'c8500000-0000-4000-8000-000000000001','c8600000-0000-4000-8000-000000000002',
'power_readings','expired-power.xlsx',repeat('2',64),'confirmed',1,1,now()-interval '90 days',now()-interval '90 days',
'c8200000-0000-4000-8000-000000000001',now();
insert into public.power_readings(import_batch_id,client_id,location_id,cold_room_id,generator_id,controller_id,
occurred_at,occurred_at_raw,power_w,power_raw,device_name,device_id,device_id_normalized,event_type,event_name,event_detail,request_from,source_detail,fingerprint)
select 'c8800000-0000-4000-8000-000000000002','c8100000-0000-4000-8000-000000000001',
'c8300000-0000-4000-8000-000000000001','c8400000-0000-4000-8000-000000000001',
'c8500000-0000-4000-8000-000000000001','c8600000-0000-4000-8000-000000000002',
(((now() at time zone 'America/Fortaleza')::date-89)::timestamp at time zone 'America/Fortaleza')-interval '1 second',
'raw',75,'75','power','device-contract-a','device-contract-a','report','power','detail','request','source',repeat('3',64);
update public.application_power_verifications v set controller_id='c8600000-0000-4000-8000-000000000002',
power_on_reading_id=(select id from public.power_readings where fingerprint=repeat('3',64)),
reference_power_reading_id=(select id from public.power_readings where fingerprint=repeat('3',64)),
observed_power_w_snapshot=75,operational_power_status='below_expected',operational_reason='reference_power_below_minimum'
from public.applications a where a.id=v.application_id and a.generator_id='c8500000-0000-4000-8000-000000000001'
and a.public_date=(now() at time zone 'America/Fortaleza')::date-89;
update private.history_retention_policy set activates_at=now()-interval '1 second';

do $$
begin
 if not private.history_date_allowed((now() at time zone 'America/Fortaleza')::date-34,'c8300000-0000-4000-8000-000000000001',35)
 or private.history_date_allowed((now() at time zone 'America/Fortaleza')::date-35,'c8300000-0000-4000-8000-000000000001',35) then raise exception '35-day boundary'; end if;
 if not private.history_date_allowed((now() at time zone 'America/Fortaleza')::date-89,'c8300000-0000-4000-8000-000000000001',90)
 or private.history_date_allowed((now() at time zone 'America/Fortaleza')::date-90,'c8300000-0000-4000-8000-000000000001',90) then raise exception '90-day boundary'; end if;
end;
$$;
-- A second unit can already be on the following date; midnight is local.
update public.locations set time_zone='Pacific/Kiritimati' where id='c8300000-0000-4000-8000-000000000002';
do $$
declare cutoff timestamptz;
begin
 cutoff:=(((now() at time zone 'Pacific/Kiritimati')::date-89)::timestamp at time zone 'Pacific/Kiritimati');
 if not private.history_instant_allowed(cutoff,'c8300000-0000-4000-8000-000000000002')
 or private.history_instant_allowed(cutoff-interval '1 microsecond','c8300000-0000-4000-8000-000000000002') then
   raise exception 'local midnight boundary'; end if;
end;
$$;
set local role authenticated;
set local request.jwt.claim.sub='c8200000-0000-4000-8000-000000000002';
do $$
begin
 if (select count(*) from public.list_client_application_details())<>2 then raise exception 'client RPC bypass'; end if;
 if exists(select 1 from public.client_daily_status where status_date<(now() at time zone 'America/Fortaleza')::date-34) then raise exception 'direct RLS bypass'; end if;
 if exists(select 1 from public.list_client_application_status() where status_date<(now() at time zone 'America/Fortaleza')::date-34) then raise exception 'legacy RPC bypass'; end if;
 if has_function_privilege('authenticated','private.purge_generator_history(uuid,integer)','execute') then raise exception 'client can purge'; end if;
 if (select count(*) from public.get_history_retention_windows())<>1 then raise exception 'window tenant leak'; end if;
end;
$$;
set local request.jwt.claim.sub='c8200000-0000-4000-8000-000000000003';
do $$ begin
 if exists(select 1 from public.list_client_application_details()) then raise exception 'cross-tenant leak'; end if;
end; $$;
set local request.jwt.claim.sub='c8200000-0000-4000-8000-000000000001';
do $$
declare rows jsonb; result jsonb;
begin
 if (select count(*) from public.list_client_application_details())<>4 then raise exception 'master window'; end if;
 rows:=jsonb_build_array(jsonb_build_object('occurred_at',now()-interval '91 days'),jsonb_build_object('occurred_at',now()));
 if jsonb_array_length(private.retained_import_rows(rows,'c8300000-0000-4000-8000-000000000001'))<>1 then raise exception 'mixed rows'; end if;
 begin
   perform private.retained_import_rows(jsonb_build_array(jsonb_build_object('occurred_at',now()-interval '91 days')),'c8300000-0000-4000-8000-000000000001');
   raise exception 'expired accepted';
 exception when sqlstate 'P1602' then null; end;
 begin
   perform private.retained_import_rows(jsonb_build_array(jsonb_build_object('occurred_at',now(),'retention_expected_count',2)),'c8300000-0000-4000-8000-000000000001');
   raise exception 'stale preview accepted';
 exception when sqlstate 'P1601' then null; end;
 -- Actual legacy confirmation must also discard the expired row.
 rows:=(select jsonb_agg(jsonb_build_object('occurred_at',at,'occurred_at_raw','raw','operation',op,'operation_raw',op,
 'source_original','retention','source_normalized','retention','source_classification','programmed','fingerprint',fp))
 from (values(now()-interval '91 days','turn_on',repeat('4',64)),
 (now()-interval '3 minutes','turn_on',repeat('5',64)),(now()-interval '2 minutes','turn_off',repeat('6',64))) r(at,op,fp));
 result:=pg_temp.confirm_xlsx_import('c8100000-0000-4000-8000-000000000001','c8300000-0000-4000-8000-000000000001',
 'c8400000-0000-4000-8000-000000000001','c8500000-0000-4000-8000-000000000001','c8600000-0000-4000-8000-000000000001',
 'late.xlsx',repeat('7',64),rows);
 if (result->>'inserted_rows')::int<>2 then raise exception 'legacy confirmation retained expired evidence: %',result; end if;
end;
$$;
reset role;
-- Retention cleanup remains independent of caller JWT and auth.uid().
select set_config('request.jwt.claim.sub','',true);
do $$
declare counts jsonb;
begin
 if not exists(select 1 from public.applications where generator_id='c8500000-0000-4000-8000-000000000001' and retention_evidence_removed) then raise exception 'reprocessing lost the evidence-expiration reason'; end if;
 counts:=private.purge_generator_history('c8500000-0000-4000-8000-000000000001',1);
 if (counts->>'raw_events')::int<>1 then raise exception 'batch size ignored: %',counts; end if;
 perform private.purge_generator_history('c8500000-0000-4000-8000-000000000001');
 if exists(select 1 from public.raw_events e join public.import_batches b on b.id=e.import_batch_id
   where e.generator_id='c8500000-0000-4000-8000-000000000001' and not private.history_instant_allowed(e.occurred_at,b.location_id)) then raise exception 'expired evidence remains'; end if;
 if not exists(select 1 from public.raw_events where fingerprint=lpad('182',64,'0')) then raise exception 'recent end of crossing application removed'; end if;
 if exists(select 1 from public.applications where generator_id='c8500000-0000-4000-8000-000000000001' and public_date=(now() at time zone 'America/Fortaleza')::date-90) then raise exception 'crossing application retained past public date'; end if;
 if not exists(select 1 from public.import_batches where id='c8800000-0000-4000-8000-000000000001') then raise exception 'mixed batch deleted'; end if;
 if exists(select 1 from public.power_readings where fingerprint=repeat('3',64)) then raise exception 'expired power remains'; end if;
 if not exists(select 1 from public.generator_assignments where generator_id='c8500000-0000-4000-8000-000000000001') then raise exception 'assignment deleted'; end if;
 counts:=private.purge_generator_history('c8500000-0000-4000-8000-000000000001');
 if exists(select 1 from jsonb_each_text(counts) where value::bigint<>0) then raise exception 'purge not idempotent: %',counts; end if;
 perform private.reprocess_all_generator_data('c8500000-0000-4000-8000-000000000001');
 if exists(select 1 from public.client_daily_status d where d.generator_id='c8500000-0000-4000-8000-000000000001'
 and not private.history_date_allowed(d.status_date,d.location_id,90)) then raise exception 'expired days rebuilt'; end if;
 if exists(select 1 from public.application_power_verifications v join public.applications a on a.id=v.application_id
 where a.retention_evidence_removed and (v.reference_power_reading_id is not null or v.operational_power_status='below_expected')) then raise exception 'expired power caused false evaluation'; end if;
end;
$$;
select extensions.pass('retention windows, isolation, import filtering, bounded purge and reprocessing');
select * from extensions.finish();
rollback;
