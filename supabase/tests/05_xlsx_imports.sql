begin;

select extensions.plan(1);

insert into public.clients (id, legal_name, cnpj)
values
  ('71000000-0000-0000-0000-000000000001', 'Cliente Importação A', '04252011000110'),
  ('71000000-0000-0000-0000-000000000002', 'Cliente Importação B', '11444777000161');

insert into auth.users (id)
values
  ('72000000-0000-0000-0000-000000000001'),
  ('72000000-0000-0000-0000-000000000002');

insert into public.profiles (id, client_id, full_name, role)
values
  ('72000000-0000-0000-0000-000000000001', null, 'Master Importação', 'master'),
  ('72000000-0000-0000-0000-000000000002', '71000000-0000-0000-0000-000000000001', 'Cliente Importação', 'operator');

insert into public.locations (id, client_id, name, time_zone)
values
  ('73000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000001', 'Unidade Importação A', 'America/Fortaleza'),
  ('73000000-0000-0000-0000-000000000002', '71000000-0000-0000-0000-000000000002', 'Unidade Importação B', 'America/Fortaleza');

insert into public.cold_rooms (id, client_id, location_id, name, category)
values
  ('74000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000001', '73000000-0000-0000-0000-000000000001', 'Câmara Importação A', 'bovinos'),
  ('74000000-0000-0000-0000-000000000002', '71000000-0000-0000-0000-000000000002', '73000000-0000-0000-0000-000000000002', 'Câmara Importação B', 'aves');

insert into public.generators (id, client_id, identifier)
values ('75000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000001', 'Gerador Importação');

insert into public.generator_assignments (
  generator_id,
  client_id,
  location_id,
  cold_room_id,
  valid_from
)
values (
  '75000000-0000-0000-0000-000000000001',
  '71000000-0000-0000-0000-000000000001',
  '73000000-0000-0000-0000-000000000001',
  '74000000-0000-0000-0000-000000000001',
  '2026-01-01 03:00:00+00'
);

insert into public.controllers (
  id,
  client_id,
  generator_id,
  identifier,
  activated_at
)
values (
  '76000000-0000-0000-0000-000000000001',
  '71000000-0000-0000-0000-000000000001',
  '75000000-0000-0000-0000-000000000001',
  'Controlador Importação',
  '2026-01-01 03:00:00+00'
);

insert into public.source_mappings (
  normalized_source,
  classification,
  created_by
)
values
  ('agendamento', 'programmed', '72000000-0000-0000-0000-000000000001'),
  ('teste manual', 'test', '72000000-0000-0000-0000-000000000001');

do $$
begin
  if not exists (
    select 1
    from storage.buckets
    where id = 'operational-imports'
      and not public
      and file_size_limit = 5242880
      and allowed_mime_types @> array[
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      ]::text[]
  ) then
    raise exception 'o bucket privado de importação não foi configurado corretamente';
  end if;

  if (
    select count(*)
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname in (
        'operational_imports_insert_master',
        'operational_imports_select_master',
        'operational_imports_delete_master'
      )
  ) <> 3 then
    raise exception 'as políticas do transporte temporário não foram criadas';
  end if;
end
$$;

set local role authenticated;
set local request.jwt.claim.sub = '72000000-0000-0000-0000-000000000001';

insert into storage.objects (bucket_id, name, owner_id)
values (
  'operational-imports',
  '72000000-0000-0000-0000-000000000001/arquivo-teste.xlsx',
  '72000000-0000-0000-0000-000000000001'
);

do $$
declare
  first_events jsonb := jsonb_build_array(
    jsonb_build_object(
      'occurred_at', '2026-08-24T13:00:00.000Z',
      'occurred_at_raw', '24/08/2026 10:00:00',
      'operation', 'turn_on',
      'operation_raw', 'Ligar',
      'source_original', 'Agendamento',
      'source_normalized', 'agendamento',
      'source_classification', 'programmed',
      'fingerprint', repeat('a', 64)
    ),
    jsonb_build_object(
      'occurred_at', '2026-08-24T14:00:00.000Z',
      'occurred_at_raw', '24/08/2026 11:00:00',
      'operation', 'turn_off',
      'operation_raw', 'Desligar',
      'source_original', 'Aplicativo',
      'source_normalized', 'aplicativo',
      'source_classification', 'unknown',
      'fingerprint', repeat('b', 64)
    ),
    jsonb_build_object(
      'occurred_at', '2026-08-24T15:00:00.000Z',
      'occurred_at_raw', '24/08/2026 12:00:00',
      'operation', 'turn_on',
      'operation_raw', 'Ligar',
      'source_original', 'Teste manual',
      'source_normalized', 'teste manual',
      'source_classification', 'test',
      'fingerprint', repeat('c', 64)
    )
  );
  overlap_events jsonb := jsonb_build_array(
    jsonb_build_object(
      'occurred_at', '2026-08-24T13:00:00.000Z',
      'occurred_at_raw', '24/08/2026 10:00:00',
      'operation', 'turn_on',
      'operation_raw', 'Ligar',
      'source_original', 'Agendamento',
      'source_normalized', 'agendamento',
      'source_classification', 'programmed',
      'fingerprint', repeat('a', 64)
    ),
    jsonb_build_object(
      'occurred_at', '2026-08-24T16:00:00.000Z',
      'occurred_at_raw', '24/08/2026 13:00:00',
      'operation', 'turn_off',
      'operation_raw', 'Desligar',
      'source_original', '',
      'source_normalized', '',
      'source_classification', 'unknown',
      'fingerprint', repeat('d', 64)
    )
  );
  result jsonb;
  batch_count_before integer;
begin
  result := public.confirm_xlsx_import(
    '71000000-0000-0000-0000-000000000001',
    '73000000-0000-0000-0000-000000000001',
    '74000000-0000-0000-0000-000000000001',
    '75000000-0000-0000-0000-000000000001',
    '76000000-0000-0000-0000-000000000001',
    'primeiro.xlsx',
    repeat('1', 64),
    first_events
  );

  if result ->> 'status' <> 'confirmed'
    or (result ->> 'inserted_rows')::integer <> 3
    or (result ->> 'duplicate_rows')::integer <> 0
    or (result ->> 'unknown_source_rows')::integer <> 1
    or (result ->> 'already_confirmed')::boolean then
    raise exception 'a primeira importação não foi confirmada corretamente: %', result;
  end if;

  if (
    select count(*)
    from public.existing_event_fingerprints(
      array[repeat('a', 64), repeat('b', 64), repeat('c', 64)]
    )
  ) <> 3 then
    raise exception 'a consulta de fingerprints existentes não retornou os eventos';
  end if;

  result := public.confirm_xlsx_import(
    '71000000-0000-0000-0000-000000000001',
    '73000000-0000-0000-0000-000000000001',
    '74000000-0000-0000-0000-000000000001',
    '75000000-0000-0000-0000-000000000001',
    '76000000-0000-0000-0000-000000000001',
    'primeiro.xlsx',
    repeat('1', 64),
    first_events
  );

  if not (result ->> 'already_confirmed')::boolean
    or (result ->> 'inserted_rows')::integer <> 3
    or (select count(*) from public.raw_events) <> 3 then
    raise exception 'a reapresentação do mesmo arquivo criou duplicatas: %', result;
  end if;

  result := public.confirm_xlsx_import(
    '71000000-0000-0000-0000-000000000001',
    '73000000-0000-0000-0000-000000000001',
    '74000000-0000-0000-0000-000000000001',
    '75000000-0000-0000-0000-000000000001',
    '76000000-0000-0000-0000-000000000001',
    'sobreposto.xlsx',
    repeat('2', 64),
    overlap_events
  );

  if (result ->> 'inserted_rows')::integer <> 1
    or (result ->> 'duplicate_rows')::integer <> 1
    or (select count(*) from public.raw_events) <> 4 then
    raise exception 'o arquivo parcialmente sobreposto não foi deduplicado: %', result;
  end if;

  select count(*) into batch_count_before from public.import_batches;

  begin
    perform public.confirm_xlsx_import(
      '71000000-0000-0000-0000-000000000001',
      '73000000-0000-0000-0000-000000000001',
      '74000000-0000-0000-0000-000000000001',
      '75000000-0000-0000-0000-000000000001',
      '76000000-0000-0000-0000-000000000001',
      'fora-vigencia.xlsx',
      repeat('3', 64),
      jsonb_build_array(
        jsonb_build_object(
          'occurred_at', '2025-12-01T12:00:00.000Z',
          'occurred_at_raw', '01/12/2025 09:00:00',
          'operation', 'turn_on',
          'operation_raw', 'Ligar',
          'source_original', 'Agendamento',
          'source_normalized', 'agendamento',
          'source_classification', 'programmed',
          'fingerprint', repeat('e', 64)
        )
      )
    );

    raise exception 'um evento fora da vigência foi aceito';
  exception
    when check_violation then null;
  end;

  if (select count(*) from public.import_batches) <> batch_count_before
    or (select count(*) from public.raw_events) <> 4 then
    raise exception 'um arquivo inválido alterou os registros operacionais';
  end if;

  begin
    perform public.confirm_xlsx_import(
      '71000000-0000-0000-0000-000000000001',
      '73000000-0000-0000-0000-000000000002',
      '74000000-0000-0000-0000-000000000002',
      '75000000-0000-0000-0000-000000000001',
      '76000000-0000-0000-0000-000000000001',
      'hierarquia-invalida.xlsx',
      repeat('4', 64),
      first_events
    );

    raise exception 'uma hierarquia inconsistente foi aceita';
  exception
    when check_violation then null;
  end;

  perform public.record_failed_xlsx_import(
    '71000000-0000-0000-0000-000000000001',
    '73000000-0000-0000-0000-000000000001',
    '74000000-0000-0000-0000-000000000001',
    '75000000-0000-0000-0000-000000000001',
    '76000000-0000-0000-0000-000000000001',
    'falhou.xlsx',
    repeat('5', 64),
    'Falha controlada para teste'
  );

  if not exists (
    select 1
    from public.import_batches
    where file_sha256 = repeat('5', 64)
      and status = 'failed'
      and error_message = 'Falha controlada para teste'
  ) then
    raise exception 'a falha administrativa não foi registrada';
  end if;
end
$$;

reset role;

do $$
begin
  if (
    select count(*)
    from public.audit_logs
    where actor_id = '72000000-0000-0000-0000-000000000001'
      and entity_type = 'import_batches'
      and action = 'import_confirmed'
  ) <> 2 then
    raise exception 'as confirmações idempotentes não foram auditadas corretamente';
  end if;

  if not exists (
    select 1
    from public.audit_logs
    where actor_id = '72000000-0000-0000-0000-000000000001'
      and entity_type = 'import_batches'
      and action = 'import_failed'
  ) then
    raise exception 'a falha de importação não foi auditada';
  end if;
end
$$;

set local role authenticated;
set local request.jwt.claim.sub = '72000000-0000-0000-0000-000000000002';

do $$
begin
  if exists (select 1 from public.import_batches)
    or exists (select 1 from public.raw_events)
    or exists (select 1 from public.source_mappings) then
    raise exception 'um usuário de cliente consultou dados técnicos da importação';
  end if;

  begin
    perform public.confirm_xlsx_import(
      '71000000-0000-0000-0000-000000000001',
      '73000000-0000-0000-0000-000000000001',
      '74000000-0000-0000-0000-000000000001',
      '75000000-0000-0000-0000-000000000001',
      '76000000-0000-0000-0000-000000000001',
      'indevido.xlsx',
      repeat('6', 64),
      '[]'::jsonb
    );

    raise exception 'um usuário de cliente confirmou uma importação';
  exception
    when insufficient_privilege then null;
  end;

  begin
    insert into storage.objects (bucket_id, name, owner_id)
    values (
      'operational-imports',
      '72000000-0000-0000-0000-000000000002/indevido.xlsx',
      '72000000-0000-0000-0000-000000000002'
    );

    raise exception 'um usuário de cliente enviou arquivo para o bucket operacional';
  exception
    when insufficient_privilege then null;
  end;
end
$$;

reset role;
select extensions.pass('spec 05 XLSX import tests passed');
select * from extensions.finish();

rollback;
