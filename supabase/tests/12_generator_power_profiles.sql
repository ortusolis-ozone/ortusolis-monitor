begin;

select extensions.plan(1);

insert into public.clients (id, legal_name, cnpj)
values
  ('c1000000-0000-4000-8000-000000000001', 'Cliente Perfil A', '04252011000110'),
  ('c1000000-0000-4000-8000-000000000002', 'Cliente Perfil B', '11444777000161');

insert into auth.users (id)
values
  ('c2000000-0000-4000-8000-000000000001'),
  ('c2000000-0000-4000-8000-000000000002'),
  ('c2000000-0000-4000-8000-000000000003');

insert into public.profiles (id, client_id, full_name, role)
values
  ('c2000000-0000-4000-8000-000000000001', null, 'Master Perfil', 'master'),
  ('c2000000-0000-4000-8000-000000000002', 'c1000000-0000-4000-8000-000000000001', 'Cliente Perfil A', 'viewer'),
  ('c2000000-0000-4000-8000-000000000003', 'c1000000-0000-4000-8000-000000000002', 'Cliente Perfil B', 'viewer');

insert into public.generators (id, client_id, identifier)
values
  ('c3000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000001', 'Gerador Perfil A'),
  ('c3000000-0000-4000-8000-000000000002', 'c1000000-0000-4000-8000-000000000002', 'Gerador Perfil B');

do $$
begin
  if exists (select 1 from public.generator_power_profiles) then
    raise exception 'a migration inferiu potência para geradores legados';
  end if;

  if not (
    select relation.relrowsecurity
    from pg_catalog.pg_class as relation
    where relation.oid = 'public.generator_power_profiles'::regclass
  ) then
    raise exception 'generator_power_profiles foi criada sem RLS';
  end if;

  if has_table_privilege('anon', 'public.generator_power_profiles', 'select')
    or has_table_privilege('anon', 'public.generator_power_profiles', 'insert')
    or has_table_privilege('anon', 'public.generator_power_profiles', 'update')
    or has_table_privilege('anon', 'public.generator_power_profiles', 'delete') then
    raise exception 'anon recebeu acesso aos perfis nominais';
  end if;

  if not has_table_privilege(
    'service_role',
    'public.generator_power_profiles',
    'select,insert,update,delete'
  ) then
    raise exception 'service_role não recebeu os privilégios explícitos';
  end if;

  if not has_table_privilege(
    'authenticated',
    'public.generator_power_profiles',
    'select'
  ) or has_table_privilege(
    'authenticated',
    'public.generator_power_profiles',
    'delete'
  ) then
    raise exception 'os privilégios de tabela de authenticated estão incorretos';
  end if;

  if not has_column_privilege(
    'authenticated',
    'public.generator_power_profiles',
    'nominal_power_w',
    'insert'
  ) or has_column_privilege(
    'authenticated',
    'public.generator_power_profiles',
    'nominal_power_w',
    'update'
  ) or not has_column_privilege(
    'authenticated',
    'public.generator_power_profiles',
    'valid_until',
    'update'
  ) or has_column_privilege(
    'authenticated',
    'public.generator_power_profiles',
    'reduction_limit_percent',
    'insert'
  ) then
    raise exception 'os privilégios de coluna não preservam o histórico';
  end if;
end;
$$;

do $$
begin
  begin
    insert into public.generator_power_profiles (
      generator_id,
      nominal_power_w,
      reduction_limit_percent,
      valid_from,
      created_by
    )
    values (
      'c3000000-0000-4000-8000-000000000002',
      72,
      10,
      '2026-01-01 00:00:00+00',
      'c2000000-0000-4000-8000-000000000001'
    );
    raise exception 'a constraint aceitou outro percentual de redução';
  exception when check_violation then null;
  end;

  begin
    insert into public.generator_power_profiles (
      generator_id,
      nominal_power_w,
      minimum_acceptable_power_w,
      valid_from,
      created_by
    )
    values (
      'c3000000-0000-4000-8000-000000000002',
      72,
      1,
      '2026-01-01 00:00:00+00',
      'c2000000-0000-4000-8000-000000000001'
    );
    raise exception 'a coluna gerada aceitou um mínimo externo';
  exception when generated_always then null;
  end;

  begin
    insert into public.generator_power_profiles (
      generator_id,
      nominal_power_w,
      valid_from,
      created_by
    )
    values (
      'c3000000-0000-4000-8000-000000000002',
      null,
      '2026-01-01 00:00:00+00',
      'c2000000-0000-4000-8000-000000000001'
    );
    raise exception 'potência nula foi aceita';
  exception when not_null_violation then null;
  end;

  begin
    insert into public.generator_power_profiles (
      generator_id,
      nominal_power_w,
      valid_from,
      created_by
    )
    values (
      'c3000000-0000-4000-8000-000000000002',
      72,
      '2026-01-01 00:00:00+00',
      'c2000000-0000-4000-8000-000000000099'
    );
    raise exception 'um autor inexistente foi aceito';
  exception when foreign_key_violation then null;
  end;
end;
$$;

set local role authenticated;
set local request.jwt.claim.sub = 'c2000000-0000-4000-8000-000000000002';

do $$
begin
  if exists (select 1 from public.generator_power_profiles) then
    raise exception 'o cliente consultou perfis nominais';
  end if;

  begin
    insert into public.generator_power_profiles (
      generator_id,
      nominal_power_w,
      valid_from,
      created_by
    )
    values (
      'c3000000-0000-4000-8000-000000000001',
      72,
      '2026-01-01 00:00:00+00',
      'c2000000-0000-4000-8000-000000000002'
    );
    raise exception 'o cliente criou um perfil nominal';
  exception when insufficient_privilege then null;
  end;
end;
$$;

reset role;
set local role authenticated;
set local request.jwt.claim.sub = 'c2000000-0000-4000-8000-000000000001';

insert into public.generator_power_profiles (
  generator_id,
  nominal_power_w,
  valid_from,
  created_by
)
values (
  'c3000000-0000-4000-8000-000000000001',
  72.000,
  '2026-01-01 00:00:00+00',
  'c2000000-0000-4000-8000-000000000001'
);

do $$
declare
  profile_record public.generator_power_profiles%rowtype;
begin
  select *
  into strict profile_record
  from public.generator_power_profiles
  where generator_id = 'c3000000-0000-4000-8000-000000000001';

  if profile_record.minimum_acceptable_power_w <> 61.2
    or profile_record.reduction_limit_percent <> 15.000 then
    raise exception 'o cálculo canônico de 85%% está incorreto';
  end if;

  if profile_record.created_by <> 'c2000000-0000-4000-8000-000000000001'
    or profile_record.created_at is null then
    raise exception 'a autoria básica do perfil não foi registrada';
  end if;

  begin
    insert into public.generator_power_profiles (
      generator_id,
      nominal_power_w,
      valid_from,
      created_by
    )
    values (
      'c3000000-0000-4000-8000-000000000001',
      80,
      '2026-02-01 00:00:00+00',
      'c2000000-0000-4000-8000-000000000001'
    );
    raise exception 'foi aceita sobreposição de perfis';
  exception when exclusion_violation or unique_violation then null;
  end;

  update public.generator_power_profiles
  set valid_until = '2026-06-01 00:00:00+00'
  where id = profile_record.id;

  insert into public.generator_power_profiles (
    generator_id,
    nominal_power_w,
    valid_from,
    created_by
  )
  values (
    'c3000000-0000-4000-8000-000000000001',
    80.125,
    '2026-06-01 00:00:00+00',
    'c2000000-0000-4000-8000-000000000001'
  );

  begin
    insert into public.generator_power_profiles (
      generator_id,
      nominal_power_w,
      valid_from,
      valid_until,
      created_by
    )
    values (
      'c3000000-0000-4000-8000-000000000001',
      90,
      '2026-07-01 00:00:00+00',
      '2026-08-01 00:00:00+00',
      'c2000000-0000-4000-8000-000000000001'
    );
    raise exception 'foi aceita sobreposição finita de perfis';
  exception when exclusion_violation then null;
  end;

  if (
    select count(*)
    from public.generator_power_profiles
    where generator_id = 'c3000000-0000-4000-8000-000000000001'
  ) <> 2 then
    raise exception 'a fronteira semiaberta não aceitou perfis adjacentes';
  end if;

  if (
    select count(*)
    from public.generator_power_profiles
    where generator_id = 'c3000000-0000-4000-8000-000000000001'
      and valid_until is null
  ) <> 1 then
    raise exception 'o gerador não possui exatamente um perfil vigente';
  end if;

  begin
    insert into public.generator_power_profiles (
      generator_id,
      nominal_power_w,
      valid_from,
      created_by
    )
    values (
      'c3000000-0000-4000-8000-000000000002',
      0,
      '2026-01-01 00:00:00+00',
      'c2000000-0000-4000-8000-000000000001'
    );
    raise exception 'potência zero foi aceita';
  exception when check_violation then null;
  end;

  begin
    insert into public.generator_power_profiles (
      generator_id,
      nominal_power_w,
      valid_from,
      created_by
    )
    values (
      'c3000000-0000-4000-8000-000000000002',
      -1,
      '2026-01-01 00:00:00+00',
      'c2000000-0000-4000-8000-000000000001'
    );
    raise exception 'potência negativa foi aceita';
  exception when check_violation then null;
  end;

  begin
    insert into public.generator_power_profiles (
      generator_id,
      nominal_power_w,
      valid_from,
      created_by
    )
    values (
      'c3000000-0000-4000-8000-000000000002',
      'NaN'::numeric,
      '2026-01-01 00:00:00+00',
      'c2000000-0000-4000-8000-000000000001'
    );
    raise exception 'NaN foi aceita como potência';
  exception when check_violation then null;
  end;

  begin
    insert into public.generator_power_profiles (
      generator_id,
      nominal_power_w,
      valid_from,
      created_by
    )
    values (
      'c3000000-0000-4000-8000-000000000002',
      'Infinity'::numeric,
      '2026-01-01 00:00:00+00',
      'c2000000-0000-4000-8000-000000000001'
    );
    raise exception 'infinito foi aceito como potência';
  exception when check_violation then null;
  end;

  begin
    insert into public.generator_power_profiles (
      generator_id,
      nominal_power_w,
      valid_from,
      created_by
    )
    values (
      'c3000000-0000-4000-8000-000000000002',
      72.0001,
      '2026-01-01 00:00:00+00',
      'c2000000-0000-4000-8000-000000000001'
    );
    raise exception 'mais de três casas decimais foram aceitas';
  exception when check_violation then null;
  end;

  begin
    insert into public.generator_power_profiles (
      generator_id,
      nominal_power_w,
      valid_from,
      valid_until,
      created_by
    )
    values (
      'c3000000-0000-4000-8000-000000000002',
      72,
      '2026-02-01 00:00:00+00',
      '2026-02-01 00:00:00+00',
      'c2000000-0000-4000-8000-000000000001'
    );
    raise exception 'vigência vazia foi aceita';
  exception when check_violation then null;
  end;

  begin
    insert into public.generator_power_profiles (
      generator_id,
      nominal_power_w,
      reduction_limit_percent,
      valid_from,
      created_by
    )
    values (
      'c3000000-0000-4000-8000-000000000002',
      72,
      10,
      '2026-01-01 00:00:00+00',
      'c2000000-0000-4000-8000-000000000001'
    );
    raise exception 'outro percentual de redução foi aceito';
  exception when insufficient_privilege or check_violation then null;
  end;

  begin
    insert into public.generator_power_profiles (
      generator_id,
      nominal_power_w,
      minimum_acceptable_power_w,
      valid_from,
      created_by
    )
    values (
      'c3000000-0000-4000-8000-000000000002',
      72,
      1,
      '2026-01-01 00:00:00+00',
      'c2000000-0000-4000-8000-000000000001'
    );
    raise exception 'um mínimo informado externamente foi aceito';
  exception when insufficient_privilege or generated_always then null;
  end;

  begin
    insert into public.generator_power_profiles (
      generator_id,
      nominal_power_w,
      valid_from,
      created_by
    )
    values (
      'c3000000-0000-4000-8000-000000000002',
      72,
      '2026-01-01 00:00:00+00',
      'c2000000-0000-4000-8000-000000000002'
    );
    raise exception 'o Master atribuiu autoria a outro usuário';
  exception when insufficient_privilege then null;
  end;

  begin
    update public.generator_power_profiles
    set nominal_power_w = 99
    where id = profile_record.id;
    raise exception 'o histórico nominal foi editado no lugar';
  exception when insufficient_privilege then null;
  end;

  begin
    delete from public.generator_power_profiles
    where id = profile_record.id;
    raise exception 'um perfil histórico foi excluído';
  exception when insufficient_privilege or check_violation then null;
  end;

  insert into public.generator_power_profiles (
    generator_id,
    nominal_power_w,
    valid_from,
    created_by
  )
  values (
    'c3000000-0000-4000-8000-000000000002',
    123456789012345678901234567890.123,
    '2026-01-01 00:00:00+00',
    'c2000000-0000-4000-8000-000000000001'
  );

  if not exists (
    select 1
    from public.generator_power_profiles as profile
    where profile.generator_id = 'c3000000-0000-4000-8000-000000000002'
      and profile.minimum_acceptable_power_w
        = profile.nominal_power_w * 0.85
  ) then
    raise exception 'um valor válido sem teto arbitrário não foi preservado';
  end if;
end;
$$;

reset role;

do $$
declare
  first_profile_id uuid;
begin
  select profile.id
  into strict first_profile_id
  from public.generator_power_profiles as profile
  where profile.generator_id = 'c3000000-0000-4000-8000-000000000001'
    and profile.valid_from = '2026-01-01 00:00:00+00';

  if not exists (
    select 1
    from public.audit_logs as audit
    where audit.actor_id = 'c2000000-0000-4000-8000-000000000001'
      and audit.entity_type = 'generator_power_profiles'
      and audit.entity_id = first_profile_id::text
      and audit.action = 'created'
  ) or not exists (
    select 1
    from public.audit_logs as audit
    where audit.actor_id = 'c2000000-0000-4000-8000-000000000001'
      and audit.entity_type = 'generator_power_profiles'
      and audit.entity_id = first_profile_id::text
      and audit.action = 'updated'
  ) then
    raise exception 'a criação ou o encerramento do perfil não foi auditado';
  end if;

  begin
    delete from public.generator_power_profiles
    where id = first_profile_id;
    raise exception 'o gatilho permitiu excluir um perfil histórico';
  exception when check_violation then null;
  end;
end;
$$;

set local role authenticated;
set local request.jwt.claim.sub = 'c2000000-0000-4000-8000-000000000003';

do $$
begin
  if exists (select 1 from public.generator_power_profiles) then
    raise exception 'outro cliente consultou perfis nominais';
  end if;
end;
$$;

reset role;

select extensions.pass('spec 12.1 generator power profile tests passed');
select * from extensions.finish();

rollback;
