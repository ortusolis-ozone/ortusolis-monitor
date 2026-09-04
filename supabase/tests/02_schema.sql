begin;

select extensions.plan(1);

do $$
declare
  client_a uuid := gen_random_uuid();
  client_b uuid := gen_random_uuid();
  user_a uuid := gen_random_uuid();
  location_a uuid := gen_random_uuid();
  cold_room_a uuid := gen_random_uuid();
  generator_a uuid := gen_random_uuid();
  controller_a uuid := gen_random_uuid();
  batch_a uuid := gen_random_uuid();
begin
  insert into public.clients (id, legal_name, cnpj)
  values
    (client_a, 'Cliente A', '11111111111111'),
    (client_b, 'Cliente B', '22222222222222');

  insert into auth.users (id) values (user_a);

  insert into public.profiles (id, client_id, full_name, role)
  values (user_a, client_a, 'Operador A', 'operator');

  insert into public.locations (id, client_id, name)
  values (location_a, client_a, 'Unidade A');

  insert into public.cold_rooms (
    id,
    client_id,
    location_id,
    name,
    category
  )
  values (cold_room_a, client_a, location_a, 'Câmara A', 'bovinos');

  insert into public.generators (id, client_id, identifier)
  values (generator_a, client_a, 'Gerador A');

  insert into public.generator_assignments (
    generator_id,
    client_id,
    location_id,
    cold_room_id,
    valid_from
  )
  values (
    generator_a,
    client_a,
    location_a,
    cold_room_a,
    '2026-01-01 00:00:00+00'
  );

  insert into public.controllers (
    id,
    client_id,
    generator_id,
    identifier,
    activated_at
  )
  values (
    controller_a,
    client_a,
    generator_a,
    'Controlador A',
    '2026-01-01 00:00:00+00'
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
    created_by,
    confirmed_at
  )
  values (
    batch_a,
    client_a,
    location_a,
    cold_room_a,
    generator_a,
    controller_a,
    'eventos.xlsx',
    repeat('a', 64),
    'confirmed',
    1,
    1,
    user_a,
    now()
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
  values (
    batch_a,
    generator_a,
    controller_a,
    '2026-01-02 10:00:00+00',
    '02/01/2026 07:00:00',
    'turn_on',
    'Ligou',
    'Programação',
    'programação',
    'programmed',
    repeat('b', 64)
  );

  begin
    insert into public.cold_rooms (
      client_id,
      location_id,
      name,
      category
    )
    values (client_b, location_a, 'Vínculo inválido', 'outros');

    raise exception 'a hierarquia aceitou vínculo entre clientes';
  exception
    when foreign_key_violation then null;
  end;

  begin
    insert into public.generator_assignments (
      generator_id,
      client_id,
      location_id,
      cold_room_id,
      valid_from
    )
    values (
      generator_a,
      client_a,
      location_a,
      cold_room_a,
      '2026-02-01 00:00:00+00'
    );

    raise exception 'o gerador aceitou alocações sobrepostas';
  exception
    when exclusion_violation then null;
  end;

  begin
    insert into public.controllers (
      client_id,
      generator_id,
      identifier,
      activated_at
    )
    values (
      client_a,
      generator_a,
      'Controlador sobreposto',
      '2026-02-01 00:00:00+00'
    );

    raise exception 'o gerador aceitou períodos de controladores sobrepostos';
  exception
    when exclusion_violation then null;
  end;

  begin
    insert into public.controllers (
      client_id,
      generator_id,
      identifier,
      activated_at,
      is_active
    )
    values (
      client_a,
      generator_a,
      'Controlador inativo sem encerramento',
      '2025-01-01 00:00:00+00',
      false
    );

    raise exception 'um controlador inativo foi aceito sem desativação';
  exception
    when check_violation then null;
  end;

  begin
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
      batch_a,
      generator_a,
      controller_a,
      '2026-01-02 11:00:00+00',
      '02/01/2026 08:00:00',
      'turn_off',
      'Desligou',
      'Programação',
      'programação',
      'programmed',
      repeat('b', 64)
    );

    raise exception 'o fingerprint duplicado foi aceito';
  exception
    when unique_violation then null;
  end;
end
$$;

do $$
declare
  expected_tables constant text[] := array[
    'application_power_verifications',
    'applications',
    'audit_logs',
    'client_daily_status',
    'clients',
    'cold_rooms',
    'controllers',
    'generator_assignments',
    'generator_power_profiles',
    'generators',
    'import_batches',
    'import_sessions',
    'inconsistencies',
    'locations',
    'power_readings',
    'profiles',
    'raw_events',
    'source_mappings'
  ];
  actual_tables text[];
  public_status_columns text[];
begin
  select array_agg(tablename order by tablename)
  into actual_tables
  from pg_catalog.pg_tables
  where schemaname = 'public';

  if actual_tables is distinct from expected_tables then
    raise exception 'conjunto inesperado de tabelas públicas: %', actual_tables;
  end if;

  if exists (
    select 1
    from pg_catalog.pg_class as relation
    join pg_catalog.pg_namespace as namespace
      on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relkind = 'r'
      and not relation.relrowsecurity
  ) then
    raise exception 'há tabela pública sem RLS habilitada';
  end if;

  if has_table_privilege('anon', 'public.clients', 'select') then
    raise exception 'anon recebeu acesso aos dados protegidos';
  end if;

  if not has_table_privilege('service_role', 'public.clients', 'select,insert,update,delete') then
    raise exception 'service_role não recebeu as permissões operacionais';
  end if;

  select array_agg(column_name::text order by ordinal_position)
  into public_status_columns
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'client_daily_status';

  if public_status_columns is distinct from array[
    'client_id',
    'location_id',
    'cold_room_id',
    'generator_id',
    'status_date',
    'status',
    'updated_at',
    'power_evidence_status'
  ] then
    raise exception 'client_daily_status expõe colunas inesperadas: %', public_status_columns;
  end if;
end
$$;

select extensions.pass('spec 02 schema tests passed');
select * from extensions.finish();

rollback;
