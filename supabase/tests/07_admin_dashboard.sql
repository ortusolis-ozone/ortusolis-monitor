begin;

select extensions.plan(1);

insert into public.clients (id, legal_name, cnpj, is_active)
values
  ('91000000-0000-4000-8000-000000000001', 'Cliente Admin A', '77777777777777', true),
  ('91000000-0000-4000-8000-000000000002', 'Cliente Admin B', '88888888888888', true);

insert into auth.users (id)
values
  ('92000000-0000-4000-8000-000000000001'),
  ('92000000-0000-4000-8000-000000000002');

insert into public.profiles (id, client_id, full_name, role, is_active)
values
  ('92000000-0000-4000-8000-000000000001', null, 'Master Admin', 'master', true),
  ('92000000-0000-4000-8000-000000000002', '91000000-0000-4000-8000-000000000001', 'Operador Admin', 'operator', true);

insert into public.locations (id, client_id, name, time_zone)
values
  ('93000000-0000-4000-8000-000000000001', '91000000-0000-4000-8000-000000000001', 'Unidade Admin A', 'America/Fortaleza'),
  ('93000000-0000-4000-8000-000000000002', '91000000-0000-4000-8000-000000000002', 'Unidade Admin B', 'America/Fortaleza');

insert into public.cold_rooms (id, client_id, location_id, name, category)
values
  ('94000000-0000-4000-8000-000000000001', '91000000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000001', 'Câmara Admin A', 'outros'),
  ('94000000-0000-4000-8000-000000000002', '91000000-0000-4000-8000-000000000002', '93000000-0000-4000-8000-000000000002', 'Câmara Admin B', 'outros');

insert into public.generators (id, client_id, identifier)
values
  ('95000000-0000-4000-8000-000000000001', '91000000-0000-4000-8000-000000000001', 'Gerador Admin A'),
  ('95000000-0000-4000-8000-000000000002', '91000000-0000-4000-8000-000000000002', 'Gerador Admin B');

insert into public.generator_assignments (
  generator_id,
  client_id,
  location_id,
  cold_room_id,
  valid_from
)
values (
  '95000000-0000-4000-8000-000000000001',
  '91000000-0000-4000-8000-000000000001',
  '93000000-0000-4000-8000-000000000001',
  '94000000-0000-4000-8000-000000000001',
  ((current_date - 7) + time '00:00') at time zone 'America/Fortaleza'
);

insert into public.controllers (
  id,
  client_id,
  generator_id,
  identifier,
  activated_at
)
values (
  '96000000-0000-4000-8000-000000000001',
  '91000000-0000-4000-8000-000000000001',
  '95000000-0000-4000-8000-000000000001',
  'Controlador Admin A',
  ((current_date - 7) + time '00:00') at time zone 'America/Fortaleza'
);

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
values (
  '97000000-0000-4000-8000-000000000001',
  '91000000-0000-4000-8000-000000000001',
  '93000000-0000-4000-8000-000000000001',
  '94000000-0000-4000-8000-000000000001',
  '95000000-0000-4000-8000-000000000001',
  '96000000-0000-4000-8000-000000000001',
  'admin-dashboard.xlsx',
  lpad(to_hex(701), 64, '0'),
  'processing',
  2,
  2,
  '92000000-0000-4000-8000-000000000001'
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
  (
    '97000000-0000-4000-8000-000000000001',
    '95000000-0000-4000-8000-000000000001',
    '96000000-0000-4000-8000-000000000001',
    ((current_date - 2) + time '10:00') at time zone 'America/Fortaleza',
    '10:00',
    'turn_on',
    'Ligar',
    'Manual',
    'manual',
    'unknown',
    lpad(to_hex(701), 64, '0')
  ),
  (
    '97000000-0000-4000-8000-000000000001',
    '95000000-0000-4000-8000-000000000001',
    '96000000-0000-4000-8000-000000000001',
    ((current_date - 2) + time '11:00') at time zone 'America/Fortaleza',
    '11:00',
    'turn_off',
    'Desligar',
    'Manual',
    'manual',
    'unknown',
    lpad(to_hex(702), 64, '0')
  );

update public.import_batches
set
  status = 'confirmed',
  confirmed_at = transaction_timestamp(),
  period_start = ((current_date - 2) + time '10:00') at time zone 'America/Fortaleza',
  period_end = ((current_date - 2) + time '11:00') at time zone 'America/Fortaleza'
where id = '97000000-0000-4000-8000-000000000001';

do $$
begin
  if not has_table_privilege('authenticated', 'public.inconsistencies', 'select')
    or not has_column_privilege('authenticated', 'public.inconsistencies', 'status', 'update')
    or not has_function_privilege(
      'authenticated',
      'public.review_inconsistency(bigint,text)',
      'execute'
    ) then
    raise exception 'as permissões administrativas mínimas não foram concedidas';
  end if;

  if has_table_privilege('authenticated', 'public.audit_logs', 'select')
    or has_table_privilege('authenticated', 'public.applications', 'select') then
    raise exception 'tabelas internas desnecessárias foram expostas';
  end if;
end
$$;

set local role authenticated;
set local request.jwt.claim.sub = '92000000-0000-4000-8000-000000000002';

do $$
begin
  if exists (select 1 from public.inconsistencies)
    or exists (select 1 from public.list_source_values())
    or exists (select 1 from public.list_admin_inconsistencies()) then
    raise exception 'um usuário de cliente acessou dados administrativos';
  end if;

  begin
    perform public.review_inconsistency(1, 'Tentativa indevida');
    raise exception 'um usuário de cliente revisou uma inconsistência';
  exception
    when insufficient_privilege then null;
  end;

  begin
    perform public.set_source_mapping('manual', 'programmed');
    raise exception 'um usuário de cliente alterou um mapeamento';
  exception
    when insufficient_privilege then null;
  end;
end
$$;

reset role;
set local role authenticated;
set local request.jwt.claim.sub = '92000000-0000-4000-8000-000000000001';

do $$
declare
  inconsistency_id bigint;
begin
  select id into inconsistency_id
  from public.inconsistencies
  where generator_id = '95000000-0000-4000-8000-000000000001'
    and type = 'unknown_source'
    and status = 'pending'
  order by id
  limit 1;

  if inconsistency_id is null then
    raise exception 'a massa de teste não gerou a pendência esperada';
  end if;

  if (
    select count(*)
    from public.inconsistencies
    where status = 'pending'
  ) <> (
    select count(*)
    from public.list_admin_inconsistencies(p_status => 'pending')
  ) then
    raise exception 'o indicador de pendências diverge da lista padrão';
  end if;

  if (
    select count(*)
    from public.list_admin_inconsistencies(
      p_status => 'pending',
      p_client_id => '91000000-0000-4000-8000-000000000001',
      p_location_id => '93000000-0000-4000-8000-000000000001',
      p_generator_id => '95000000-0000-4000-8000-000000000001',
      p_type => 'unknown_source',
      p_start_date => current_date - 2,
      p_end_date => current_date - 2
    )
  ) <> 2 then
    raise exception 'os filtros administrativos não retornaram as pendências esperadas';
  end if;

  if not exists (
    select 1
    from public.list_source_values() as source
    where source.normalized_source = 'manual'
      and source.event_count = 2
      and not source.is_active
  ) then
    raise exception 'a origem desconhecida não apareceu no mapeamento';
  end if;

  if not public.review_inconsistency(inconsistency_id, 'Conferido pelo Master.') then
    raise exception 'a revisão administrativa não alterou a pendência';
  end if;

  if not exists (
    select 1
    from public.inconsistencies
    where id = inconsistency_id
      and status = 'reviewed'
      and review_note = 'Conferido pelo Master.'
      and reviewed_by = '92000000-0000-4000-8000-000000000001'
      and reviewed_at is not null
  ) then
    raise exception 'autor, horário ou nota da revisão não foram registrados';
  end if;

  if not exists (
    select 1
    from public.client_daily_status
    where generator_id = '95000000-0000-4000-8000-000000000001'
      and status_date = current_date - 2
      and status = 'verification_required'
  ) then
    raise exception 'a pendência remanescente não preservou o estado de verificação';
  end if;

  if not public.reopen_inconsistency(inconsistency_id) then
    raise exception 'a revisão administrativa não foi reaberta';
  end if;

  if not exists (
    select 1
    from public.inconsistencies
    where id = inconsistency_id
      and status = 'pending'
      and review_note is null
      and reviewed_by is null
      and reviewed_at is null
  ) then
    raise exception 'a reabertura não limpou os dados da revisão';
  end if;
end
$$;

select public.set_source_mapping('manual', 'programmed');

reset role;

do $$
begin
  if (
    select count(*)
    from public.applications
    where generator_id = '95000000-0000-4000-8000-000000000001'
  ) <> 1
    or exists (
      select 1
      from public.inconsistencies
      where generator_id = '95000000-0000-4000-8000-000000000001'
        and status = 'pending'
    )
    or exists (
      select 1
      from public.raw_events
      where generator_id = '95000000-0000-4000-8000-000000000001'
        and source_classification <> 'programmed'
    ) then
    raise exception 'o mapeamento programado não reprocessou o gerador';
  end if;

  if not exists (
    select 1
    from public.client_daily_status
    where generator_id = '95000000-0000-4000-8000-000000000001'
      and status_date = current_date - 2
      and status = 'completed'
  ) then
    raise exception 'o reprocessamento do mapeamento não publicou Concluído';
  end if;
end
$$;

set local role authenticated;
set local request.jwt.claim.sub = '92000000-0000-4000-8000-000000000001';

select public.set_source_mapping('manual', 'unknown');

do $$
begin
  if not exists (
    select 1
    from public.source_mappings
    where normalized_source = 'manual'
      and not is_active
  )
    or not exists (
      select 1
      from public.inconsistencies
      where generator_id = '95000000-0000-4000-8000-000000000001'
        and type = 'unknown_source'
        and status = 'pending'
    )
    or not exists (
      select 1
      from public.client_daily_status
      where generator_id = '95000000-0000-4000-8000-000000000001'
        and status_date = current_date - 2
        and status = 'verification_required'
    ) then
    raise exception 'remover o mapeamento não restaurou a origem desconhecida';
  end if;
end
$$;

reset role;

do $$
begin
  if not exists (
    select 1
    from public.audit_logs
    where actor_id = '92000000-0000-4000-8000-000000000001'
      and action = 'inconsistency_reviewed'
      and entity_type = 'inconsistencies'
  )
    or not exists (
      select 1
      from public.audit_logs
      where actor_id = '92000000-0000-4000-8000-000000000001'
        and action = 'inconsistency_reopened'
        and entity_type = 'inconsistencies'
    )
    or not exists (
      select 1
      from public.audit_logs
      where actor_id = '92000000-0000-4000-8000-000000000001'
        and entity_type = 'source_mappings'
    ) then
    raise exception 'as ações administrativas importantes não foram auditadas';
  end if;
end
$$;

select extensions.pass('spec 07 admin dashboard tests passed');
select * from extensions.finish();

rollback;
