begin;

insert into public.clients (id, legal_name, cnpj)
values ('81000000-0000-0000-0000-000000000001', 'Cliente Processamento', '19131243000197');

insert into auth.users (id)
values ('82000000-0000-0000-0000-000000000001');

insert into public.profiles (id, full_name, role)
values ('82000000-0000-0000-0000-000000000001', 'Master Processamento', 'master');

insert into public.locations (id, client_id, name, time_zone)
values (
  '83000000-0000-0000-0000-000000000001',
  '81000000-0000-0000-0000-000000000001',
  'Unidade Processamento',
  'America/Fortaleza'
);

insert into public.cold_rooms (id, client_id, location_id, name, category)
values (
  '84000000-0000-0000-0000-000000000001',
  '81000000-0000-0000-0000-000000000001',
  '83000000-0000-0000-0000-000000000001',
  'Câmara Processamento',
  'outros'
);

insert into public.generators (id, client_id, identifier)
select
  ('85000000-0000-0000-0000-' || lpad(number::text, 12, '0'))::uuid,
  '81000000-0000-0000-0000-000000000001',
  'Gerador ' || number
from generate_series(1, 12) as number;

insert into public.generator_assignments (
  generator_id,
  client_id,
  location_id,
  cold_room_id,
  valid_from
)
select
  generator.id,
  generator.client_id,
  '83000000-0000-0000-0000-000000000001',
  '84000000-0000-0000-0000-000000000001',
  ((current_date - 10) + time '00:00') at time zone 'America/Fortaleza'
from public.generators as generator
where generator.client_id = '81000000-0000-0000-0000-000000000001';

insert into public.controllers (
  id,
  client_id,
  generator_id,
  identifier,
  activated_at
)
select
  ('86000000-0000-0000-0000-' || lpad(number::text, 12, '0'))::uuid,
  '81000000-0000-0000-0000-000000000001',
  ('85000000-0000-0000-0000-' || lpad(number::text, 12, '0'))::uuid,
  'Controlador ' || number,
  ((current_date - 10) + time '00:00') at time zone 'America/Fortaleza'
from generate_series(1, 12) as number;

update public.controllers
set
  is_active = false,
  deactivated_at = ((current_date - 2) + time '10:30') at time zone 'America/Fortaleza'
where id = '86000000-0000-0000-0000-000000000006';

insert into public.controllers (
  id,
  client_id,
  generator_id,
  identifier,
  activated_at
)
values (
  '86000000-0000-0000-0001-000000000006',
  '81000000-0000-0000-0000-000000000001',
  '85000000-0000-0000-0000-000000000006',
  'Controlador 6 substituto',
  ((current_date - 2) + time '10:30') at time zone 'America/Fortaleza'
);

insert into public.source_mappings (normalized_source, classification, created_by)
values
  ('agenda', 'programmed', '82000000-0000-0000-0000-000000000001'),
  ('teste', 'test', '82000000-0000-0000-0000-000000000001');

insert into public.import_batches (
  id,
  client_id,
  location_id,
  cold_room_id,
  generator_id,
  controller_id,
  file_name,
  file_sha256,
  status,
  total_rows,
  inserted_rows,
  created_by
)
select
  ('87000000-0000-0000-0000-' || lpad(number::text, 12, '0'))::uuid,
  '81000000-0000-0000-0000-000000000001',
  '83000000-0000-0000-0000-000000000001',
  '84000000-0000-0000-0000-000000000001',
  ('85000000-0000-0000-0000-' || lpad(number::text, 12, '0'))::uuid,
  ('86000000-0000-0000-0000-' || lpad(number::text, 12, '0'))::uuid,
  'lote-' || number || '.xlsx',
  lpad(to_hex(number), 64, '0'),
  'processing',
  case
    when number in (1, 4, 5, 12) then 3
    when number in (3, 6, 11) then 2
    else 1
  end,
  case
    when number in (1, 4, 5, 12) then 3
    when number in (3, 6, 11) then 2
    else 1
  end,
  '82000000-0000-0000-0000-000000000001'
from generate_series(1, 12) as number;

insert into public.import_batches (
  id,
  client_id,
  location_id,
  cold_room_id,
  generator_id,
  controller_id,
  file_name,
  file_sha256,
  status,
  total_rows,
  inserted_rows,
  created_by
)
values
  (
    '87000000-0000-0000-0001-000000000006',
    '81000000-0000-0000-0000-000000000001',
    '83000000-0000-0000-0000-000000000001',
    '84000000-0000-0000-0000-000000000001',
    '85000000-0000-0000-0000-000000000006',
    '86000000-0000-0000-0001-000000000006',
    'lote-6-substituto.xlsx',
    lpad(to_hex(106), 64, '0'),
    'processing',
    1,
    1,
    '82000000-0000-0000-0000-000000000001'
  ),
  (
    '87000000-0000-0000-0001-000000000007',
    '81000000-0000-0000-0000-000000000001',
    '83000000-0000-0000-0000-000000000001',
    '84000000-0000-0000-0000-000000000001',
    '85000000-0000-0000-0000-000000000007',
    '86000000-0000-0000-0000-000000000007',
    'lote-7-desligar.xlsx',
    lpad(to_hex(107), 64, '0'),
    'processing',
    1,
    1,
    '82000000-0000-0000-0000-000000000001'
  ),
  (
    '87000000-0000-0000-0001-000000000008',
    '81000000-0000-0000-0000-000000000001',
    '83000000-0000-0000-0000-000000000001',
    '84000000-0000-0000-0000-000000000001',
    '85000000-0000-0000-0000-000000000008',
    '86000000-0000-0000-0000-000000000008',
    'lote-8-ligar.xlsx',
    lpad(to_hex(108), 64, '0'),
    'processing',
    1,
    1,
    '82000000-0000-0000-0000-000000000001'
  );

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
values
  ('87000000-0000-0000-0000-000000000001', '85000000-0000-0000-0000-000000000001', '86000000-0000-0000-0000-000000000001', ((current_date - 2) + time '10:00') at time zone 'America/Fortaleza', '10:00', 'turn_on', 'Ligar', 'Agenda', 'agenda', 'programmed', lpad(to_hex(1), 64, '0')),
  ('87000000-0000-0000-0000-000000000001', '85000000-0000-0000-0000-000000000001', '86000000-0000-0000-0000-000000000001', ((current_date - 2) + time '10:30') at time zone 'America/Fortaleza', '10:30', 'turn_off', 'Desligar', 'Teste', 'teste', 'test', lpad(to_hex(2), 64, '0')),
  ('87000000-0000-0000-0000-000000000001', '85000000-0000-0000-0000-000000000001', '86000000-0000-0000-0000-000000000001', ((current_date - 2) + time '11:00') at time zone 'America/Fortaleza', '11:00', 'turn_off', 'Desligar', 'Agenda', 'agenda', 'programmed', lpad(to_hex(3), 64, '0')),
  ('87000000-0000-0000-0000-000000000002', '85000000-0000-0000-0000-000000000002', '86000000-0000-0000-0000-000000000002', ((current_date - 2) + time '10:00') at time zone 'America/Fortaleza', '10:00', 'turn_on', 'Ligar', 'Agenda', 'agenda', 'programmed', lpad(to_hex(4), 64, '0')),
  ('87000000-0000-0000-0000-000000000003', '85000000-0000-0000-0000-000000000003', '86000000-0000-0000-0000-000000000003', ((current_date - 2) + time '10:00') at time zone 'America/Fortaleza', '10:00', 'turn_off', 'Desligar', 'Agenda', 'agenda', 'programmed', lpad(to_hex(5), 64, '0')),
  ('87000000-0000-0000-0000-000000000003', '85000000-0000-0000-0000-000000000003', '86000000-0000-0000-0000-000000000003', ((current_date - 2) + time '11:00') at time zone 'America/Fortaleza', '11:00', 'turn_on', 'Ligar', 'Agenda', 'agenda', 'programmed', lpad(to_hex(6), 64, '0')),
  ('87000000-0000-0000-0000-000000000004', '85000000-0000-0000-0000-000000000004', '86000000-0000-0000-0000-000000000004', ((current_date - 2) + time '10:00') at time zone 'America/Fortaleza', '10:00', 'turn_on', 'Ligar', 'Agenda', 'agenda', 'programmed', lpad(to_hex(7), 64, '0')),
  ('87000000-0000-0000-0000-000000000004', '85000000-0000-0000-0000-000000000004', '86000000-0000-0000-0000-000000000004', ((current_date - 2) + time '11:00') at time zone 'America/Fortaleza', '11:00', 'turn_on', 'Ligar', 'Agenda', 'agenda', 'programmed', lpad(to_hex(8), 64, '0')),
  ('87000000-0000-0000-0000-000000000004', '85000000-0000-0000-0000-000000000004', '86000000-0000-0000-0000-000000000004', ((current_date - 2) + time '12:00') at time zone 'America/Fortaleza', '12:00', 'turn_off', 'Desligar', 'Agenda', 'agenda', 'programmed', lpad(to_hex(9), 64, '0')),
  ('87000000-0000-0000-0000-000000000005', '85000000-0000-0000-0000-000000000005', '86000000-0000-0000-0000-000000000005', ((current_date - 2) + time '10:00') at time zone 'America/Fortaleza', '10:00', 'turn_on', 'Ligar', 'Manual', 'manual', 'unknown', lpad(to_hex(10), 64, '0')),
  ('87000000-0000-0000-0000-000000000005', '85000000-0000-0000-0000-000000000005', '86000000-0000-0000-0000-000000000005', ((current_date - 2) + time '11:00') at time zone 'America/Fortaleza', '11:00', 'turn_off', 'Desligar', 'Manual', 'manual', 'unknown', lpad(to_hex(11), 64, '0')),
  ('87000000-0000-0000-0000-000000000005', '85000000-0000-0000-0000-000000000005', '86000000-0000-0000-0000-000000000005', ((current_date - 2) + time '11:30') at time zone 'America/Fortaleza', '11:30', 'turn_on', 'Ligar', 'Teste', 'teste', 'test', lpad(to_hex(12), 64, '0')),
  ('87000000-0000-0000-0000-000000000006', '85000000-0000-0000-0000-000000000006', '86000000-0000-0000-0000-000000000006', ((current_date - 2) + time '10:00') at time zone 'America/Fortaleza', '10:00', 'turn_on', 'Ligar', 'Agenda', 'agenda', 'programmed', lpad(to_hex(13), 64, '0')),
  ('87000000-0000-0000-0001-000000000006', '85000000-0000-0000-0000-000000000006', '86000000-0000-0000-0001-000000000006', ((current_date - 2) + time '11:00') at time zone 'America/Fortaleza', '11:00', 'turn_off', 'Desligar', 'Agenda', 'agenda', 'programmed', lpad(to_hex(14), 64, '0')),
  ('87000000-0000-0000-0000-000000000007', '85000000-0000-0000-0000-000000000007', '86000000-0000-0000-0000-000000000007', ((current_date - 2) + time '10:00') at time zone 'America/Fortaleza', '10:00', 'turn_on', 'Ligar', 'Agenda', 'agenda', 'programmed', lpad(to_hex(15), 64, '0')),
  ('87000000-0000-0000-0001-000000000007', '85000000-0000-0000-0000-000000000007', '86000000-0000-0000-0000-000000000007', ((current_date - 2) + time '11:00') at time zone 'America/Fortaleza', '11:00', 'turn_off', 'Desligar', 'Agenda', 'agenda', 'programmed', lpad(to_hex(16), 64, '0')),
  ('87000000-0000-0000-0000-000000000008', '85000000-0000-0000-0000-000000000008', '86000000-0000-0000-0000-000000000008', ((current_date - 2) + time '11:00') at time zone 'America/Fortaleza', '11:00', 'turn_off', 'Desligar', 'Agenda', 'agenda', 'programmed', lpad(to_hex(18), 64, '0')),
  ('87000000-0000-0000-0001-000000000008', '85000000-0000-0000-0000-000000000008', '86000000-0000-0000-0000-000000000008', ((current_date - 2) + time '10:00') at time zone 'America/Fortaleza', '10:00', 'turn_on', 'Ligar', 'Agenda', 'agenda', 'programmed', lpad(to_hex(17), 64, '0')),
  ('87000000-0000-0000-0000-000000000009', '85000000-0000-0000-0000-000000000009', '86000000-0000-0000-0000-000000000009', ((current_date - 2) + time '10:00') at time zone 'America/Fortaleza', '10:00', 'turn_off', 'Desligar', 'Agenda', 'agenda', 'programmed', lpad(to_hex(19), 64, '0')),
  ('87000000-0000-0000-0000-000000000010', '85000000-0000-0000-0000-000000000010', '86000000-0000-0000-0000-000000000010', ((current_date - 2) + time '10:00') at time zone 'America/Fortaleza', '10:00', 'turn_off', 'Desligar', 'Agenda', 'agenda', 'programmed', lpad(to_hex(20), 64, '0')),
  ('87000000-0000-0000-0000-000000000011', '85000000-0000-0000-0000-000000000011', '86000000-0000-0000-0000-000000000011', ((current_date - 2) + time '10:00') at time zone 'America/Fortaleza', '10:00', 'turn_off', 'Desligar', 'Agenda', 'agenda', 'programmed', lpad(to_hex(22), 64, '0')),
  ('87000000-0000-0000-0000-000000000011', '85000000-0000-0000-0000-000000000011', '86000000-0000-0000-0000-000000000011', ((current_date - 2) + time '10:00') at time zone 'America/Fortaleza', '10:00', 'turn_on', 'Ligar', 'Agenda', 'agenda', 'programmed', lpad(to_hex(21), 64, '0')),
  ('87000000-0000-0000-0000-000000000012', '85000000-0000-0000-0000-000000000012', '86000000-0000-0000-0000-000000000012', ((current_date - 2) + time '10:00') at time zone 'America/Fortaleza', '10:00', 'turn_on', 'Ligar', 'Agenda', 'agenda', 'programmed', lpad(to_hex(23), 64, '0')),
  ('87000000-0000-0000-0000-000000000012', '85000000-0000-0000-0000-000000000012', '86000000-0000-0000-0000-000000000012', ((current_date - 2) + time '11:00') at time zone 'America/Fortaleza', '11:00', 'turn_off', 'Desligar', 'Agenda', 'agenda', 'programmed', lpad(to_hex(24), 64, '0')),
  ('87000000-0000-0000-0000-000000000012', '85000000-0000-0000-0000-000000000012', '86000000-0000-0000-0000-000000000012', current_date + time '10:00' at time zone 'America/Fortaleza', '10:00', 'turn_on', 'Ligar', 'Agenda', 'agenda', 'programmed', lpad(to_hex(25), 64, '0'));

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
values (
  '87000000-0000-0000-0000-000000000001',
  '85000000-0000-0000-0000-000000000001',
  '86000000-0000-0000-0000-000000000001',
  ((current_date - 2) + time '10:00') at time zone 'America/Fortaleza',
  '10:00',
  'turn_on',
  'Ligar',
  'Agenda',
  'agenda',
  'programmed',
  lpad(to_hex(1), 64, '0')
)
on conflict (fingerprint) do nothing;

do $$
begin
  if (
    select count(*)
    from public.raw_events
    where generator_id = '85000000-0000-0000-0000-000000000001'
  ) <> 3 then
    raise exception 'um evento duplicado não foi ignorado';
  end if;
end
$$;

update public.import_batches
set
  status = 'confirmed',
  confirmed_at = transaction_timestamp()
where generator_id not in (
  '85000000-0000-0000-0000-000000000007',
  '85000000-0000-0000-0000-000000000008'
);

do $$
begin
  if (
    select count(*)
    from public.applications
    where generator_id = '85000000-0000-0000-0000-000000000001'
  ) <> 1
    or exists (
      select 1
      from public.inconsistencies
      where generator_id = '85000000-0000-0000-0000-000000000001'
        and status = 'pending'
    ) then
    raise exception 'o par completo com teste intercalado não foi processado';
  end if;

  if not exists (
    select 1
    from public.inconsistencies
    where generator_id = '85000000-0000-0000-0000-000000000002'
      and type = 'unmatched_turn_on'
      and status = 'pending'
  ) then
    raise exception 'o Ligar incompleto não gerou inconsistência';
  end if;

  if (
    select array_agg(type order by type)
    from public.inconsistencies
    where generator_id = '85000000-0000-0000-0000-000000000003'
      and status = 'pending'
  ) is distinct from array['unmatched_turn_off', 'unmatched_turn_on']::text[] then
    raise exception 'a sequência invertida não gerou as duas inconsistências';
  end if;

  if not exists (
    select 1
    from public.inconsistencies
    where generator_id = '85000000-0000-0000-0000-000000000004'
      and type = 'consecutive_turn_on'
      and status = 'pending'
  ) or (
    select count(*)
    from public.applications
    where generator_id = '85000000-0000-0000-0000-000000000004'
  ) <> 1 then
    raise exception 'os Ligar consecutivos não foram reconciliados com o evento mais recente';
  end if;

  if not exists (
    select 1
    from public.inconsistencies
    where generator_id = '85000000-0000-0000-0000-000000000005'
      and type = 'unknown_source'
      and status = 'pending'
  ) then
    raise exception 'a origem desconhecida não gerou inconsistência';
  end if;

  if not exists (
    select 1
    from public.inconsistencies
    where generator_id = '85000000-0000-0000-0000-000000000006'
      and type = 'controller_mismatch'
      and status = 'pending'
  ) or exists (
    select 1
    from public.applications
    where generator_id = '85000000-0000-0000-0000-000000000006'
  ) then
    raise exception 'eventos de controladores diferentes formaram uma aplicação';
  end if;

  if not exists (
    select 1
    from public.applications
    where generator_id = '85000000-0000-0000-0000-000000000011'
  ) then
    raise exception 'o desempate estável por fingerprint não foi aplicado';
  end if;
end
$$;

insert into public.source_mappings (normalized_source, classification, created_by)
values ('manual', 'programmed', '82000000-0000-0000-0000-000000000001');

do $$
begin
  if (
    select count(*)
    from public.applications
    where generator_id = '85000000-0000-0000-0000-000000000005'
  ) <> 1
    or exists (
      select 1
      from public.inconsistencies
      where generator_id = '85000000-0000-0000-0000-000000000005'
        and status = 'pending'
    )
    or exists (
      select 1
      from public.raw_events
      where generator_id = '85000000-0000-0000-0000-000000000005'
        and source_normalized = 'manual'
        and source_classification <> 'programmed'
    ) then
    raise exception 'a alteração do mapeamento não reprocessou o gerador';
  end if;
end
$$;

update public.inconsistencies
set
  status = 'reviewed',
  review_note = 'Registro conferido.',
  reviewed_by = '82000000-0000-0000-0000-000000000001',
  reviewed_at = transaction_timestamp()
where generator_id = '85000000-0000-0000-0000-000000000010'
  and status = 'pending';

do $$
begin
  if not exists (
    select 1
    from public.client_daily_status
    where generator_id = '85000000-0000-0000-0000-000000000010'
      and status_date = current_date - 2
      and status = 'no_data'
  ) then
    raise exception 'a revisão não removeu a precedência da inconsistência';
  end if;

  if not exists (
    select 1
    from public.client_daily_status
    where generator_id = '85000000-0000-0000-0000-000000000001'
      and status_date = current_date - 2
      and status = 'completed'
  ) or not exists (
    select 1
    from public.client_daily_status
    where generator_id = '85000000-0000-0000-0000-000000000001'
      and status_date = current_date
      and status = 'awaiting_update'
  ) then
    raise exception 'os estados Concluído/Aguardando atualização estão incorretos';
  end if;

  if not exists (
    select 1
    from public.client_daily_status
    where generator_id = '85000000-0000-0000-0000-000000000004'
      and status_date = current_date - 2
      and status = 'verification_required'
  ) then
    raise exception 'a inconsistência pendente não teve precedência sobre a aplicação';
  end if;

  if not exists (
    select 1
    from public.client_daily_status
    where generator_id = '85000000-0000-0000-0000-000000000012'
      and status_date = current_date - 1
      and status = 'no_data'
  ) then
    raise exception 'uma data importada sem aplicação não foi publicada como Sem dados';
  end if;
end
$$;

update public.import_batches
set
  status = 'confirmed',
  confirmed_at = transaction_timestamp()
where id = '87000000-0000-0000-0000-000000000007';

do $$
begin
  if not exists (
    select 1
    from public.inconsistencies
    where generator_id = '85000000-0000-0000-0000-000000000007'
      and type = 'unmatched_turn_on'
      and status = 'pending'
  ) then
    raise exception 'o Ligar de uma importação anterior não permaneceu aberto';
  end if;
end
$$;

update public.import_batches
set
  status = 'confirmed',
  confirmed_at = transaction_timestamp()
where id = '87000000-0000-0000-0001-000000000007';

update public.import_batches
set
  status = 'confirmed',
  confirmed_at = transaction_timestamp()
where id = '87000000-0000-0000-0000-000000000008';

update public.import_batches
set
  status = 'confirmed',
  confirmed_at = transaction_timestamp()
where id = '87000000-0000-0000-0001-000000000008';

do $$
begin
  if (
    select count(*)
    from public.applications
    where generator_id in (
      '85000000-0000-0000-0000-000000000007',
      '85000000-0000-0000-0000-000000000008'
    )
  ) <> 2
    or exists (
      select 1
      from public.inconsistencies
      where generator_id in (
        '85000000-0000-0000-0000-000000000007',
        '85000000-0000-0000-0000-000000000008'
      )
        and status = 'pending'
    ) then
    raise exception 'ordens de importação diferentes produziram resultados finais diferentes';
  end if;

  if not exists (
    select 1
    from public.inconsistencies
    where generator_id = '85000000-0000-0000-0000-000000000007'
      and type = 'unmatched_turn_on'
      and status = 'resolved'
  ) then
    raise exception 'a inconsistência aberta não foi resolvida pelo evento posterior';
  end if;
end
$$;

create temporary table processing_snapshot as
select jsonb_build_object(
  'applications', (
    select jsonb_agg(to_jsonb(application) order by application.id)
    from public.applications as application
    where application.generator_id = '85000000-0000-0000-0000-000000000007'
  ),
  'inconsistencies', (
    select jsonb_agg(to_jsonb(inconsistency) order by inconsistency.id)
    from public.inconsistencies as inconsistency
    where inconsistency.generator_id = '85000000-0000-0000-0000-000000000007'
  ),
  'daily_status', (
    select jsonb_agg(to_jsonb(daily_status) order by daily_status.status_date)
    from public.client_daily_status as daily_status
    where daily_status.generator_id = '85000000-0000-0000-0000-000000000007'
  )
) as value;

select private.reprocess_generator('85000000-0000-0000-0000-000000000007');

do $$
declare
  current_snapshot jsonb;
begin
  if has_function_privilege(
    'authenticated',
    'private.reprocess_generator(uuid)',
    'execute'
  ) then
    raise exception 'o reprocessamento técnico foi exposto ao cliente autenticado';
  end if;

  select jsonb_build_object(
    'applications', (
      select jsonb_agg(to_jsonb(application) order by application.id)
      from public.applications as application
      where application.generator_id = '85000000-0000-0000-0000-000000000007'
    ),
    'inconsistencies', (
      select jsonb_agg(to_jsonb(inconsistency) order by inconsistency.id)
      from public.inconsistencies as inconsistency
      where inconsistency.generator_id = '85000000-0000-0000-0000-000000000007'
    ),
    'daily_status', (
      select jsonb_agg(to_jsonb(daily_status) order by daily_status.status_date)
      from public.client_daily_status as daily_status
      where daily_status.generator_id = '85000000-0000-0000-0000-000000000007'
    )
  ) into current_snapshot;

  if current_snapshot is distinct from (select value from processing_snapshot) then
    raise exception 'reprocessar sem novos eventos não foi idempotente';
  end if;

  if (
    select array_agg(column_name::text order by ordinal_position)
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'client_daily_status'
  ) is distinct from array[
    'client_id',
    'location_id',
    'cold_room_id',
    'generator_id',
    'status_date',
    'status',
    'updated_at'
  ]::text[] then
    raise exception 'a publicação diária expõe dados técnicos';
  end if;

  if exists (
    select 1
    from public.client_daily_status as daily_status
    join public.raw_events as event
      on event.generator_id = daily_status.generator_id
    where daily_status.generator_id = '85000000-0000-0000-0000-000000000001'
      and daily_status.updated_at <> (
        select max(confirmed_event.occurred_at)
        from public.raw_events as confirmed_event
        join public.import_batches as batch
          on batch.id = confirmed_event.import_batch_id
          and batch.status = 'confirmed'
        where confirmed_event.generator_id = daily_status.generator_id
      )
  ) then
    raise exception 'a última atualização não corresponde ao maior evento confirmado';
  end if;
end
$$;

rollback;

select 'spec 06 processing and daily states tests passed' as result;
