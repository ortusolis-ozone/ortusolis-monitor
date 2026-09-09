begin;
select extensions.plan(1);

insert into public.clients (id, legal_name, cnpj) values
  ('f1000000-0000-4000-8000-000000000001', 'Cliente Contratos Nominais', '04252011000110');
insert into auth.users (id) values
  ('f2000000-0000-4000-8000-000000000001'),
  ('f2000000-0000-4000-8000-000000000002'),
  ('f2000000-0000-4000-8000-000000000003');
insert into public.profiles (id, client_id, full_name, role, is_active) values
  ('f2000000-0000-4000-8000-000000000001', null, 'Master Contratos', 'master', true),
  ('f2000000-0000-4000-8000-000000000002', 'f1000000-0000-4000-8000-000000000001', 'Cliente Contratos', 'viewer', true),
  ('f2000000-0000-4000-8000-000000000003', null, 'Master Inativo', 'master', false);
insert into public.locations (id, client_id, name, time_zone) values
  ('f3000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'Local Contratos', 'America/Fortaleza');
insert into public.cold_rooms (id, client_id, location_id, name, category) values
  ('f4000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'f3000000-0000-4000-8000-000000000001', 'Câmara Contratos', 'flv');

-- Late failure: audit and reprocessing triggers execute before this one.
create function pg_temp.fail_nominal_contract() returns trigger language plpgsql as $$
begin
  raise exception 'forced_nominal_contract_failure';
end;
$$;
create trigger zzz_fail_nominal_contract after insert on public.generator_power_profiles
for each row when (new.nominal_power_w = 999)
execute function pg_temp.fail_nominal_contract();

create function pg_temp.nominal_snapshot() returns jsonb
language sql security definer set search_path = '' as $$
  select jsonb_build_object(
    'generators', (select count(*) from public.generators),
    'assignments', (select count(*) from public.generator_assignments),
    'controllers', (select count(*) from public.controllers),
    'profiles', (select jsonb_agg(to_jsonb(p) order by id) from public.generator_power_profiles p),
    'audit', (select count(*) from public.audit_logs),
    'runs', (select count(*) from private.operational_power_reprocessing_runs)
  );
$$;

set local role authenticated;
set local request.jwt.claim.sub = 'f2000000-0000-4000-8000-000000000001';
do $$
declare
  generator uuid;
  legacy uuid;
  first_profile uuid;
  next_profile uuid;
  value text;
  snapshot jsonb;
begin
  generator := public.register_generator_with_power_profile(
    'f4000000-0000-4000-8000-000000000001', 'Gerador nominal', '2026-01-01',
    '72,000', 'Estado nominal', 'Potência nominal', 'nominal-device'
  );
  select id into strict first_profile from public.generator_power_profiles where generator_id = generator;
  if not exists (select 1 from public.generator_power_profiles
    where id = first_profile and nominal_power_w = 72 and minimum_acceptable_power_w = 61.2
      and valid_from = '2026-01-01 03:00:00+00'
      and created_by = 'f2000000-0000-4000-8000-000000000001')
    or (select count(*) from public.controllers where generator_id = generator) <> 2 then
    raise exception 'cadastro não criou configuração exata, dois controladores ou autoria confiável';
  end if;

  snapshot := pg_temp.nominal_snapshot();
  foreach value in array array[null, '', ' ', 'NaN', 'Infinity', '-Infinity', 'abc', '0', '-1', '72.0001', '1e2', '1.2.3'] loop
    begin
      perform public.register_generator_with_power_profile(
        'f4000000-0000-4000-8000-000000000001', 'Inválido', '2026-01-01',
        value, 'Estado inválido', 'Potência inválida', 'invalid-device'
      );
      raise exception 'potência inválida aceita: %', value;
    exception when invalid_parameter_value then null;
    end;
  end loop;
  if snapshot is distinct from pg_temp.nominal_snapshot() then
    raise exception 'validação nominal publicou cadastro parcial';
  end if;

  -- Neither caller-supplied author nor calculated minimum is in the RPC contract.
  begin
    execute $sql$select public.register_generator_with_power_profile(
      p_cold_room_id => 'f4000000-0000-4000-8000-000000000001',
      p_identifier => 'Adulterado', p_valid_from => '2026-01-01', p_nominal_power_w => '72',
      p_state_controller_identifier => 'Estado adulterado', p_power_controller_identifier => 'Potência adulterada',
      p_power_controller_device_id => 'tampered-device', p_minimum_acceptable_power_w => 1,
      p_created_by => 'f2000000-0000-4000-8000-000000000002')$sql$;
    raise exception 'contrato aceitou mínimo ou autor adulterado';
  exception when undefined_function then null;
  end;

  next_profile := public.version_generator_power_profile(generator, '100', '2026-07-01 03:00:00+00', first_profile);
  if not exists (select 1 from public.generator_power_profiles where id = first_profile
      and nominal_power_w = 72 and valid_until = '2026-07-01 03:00:00+00')
    or not exists (select 1 from public.generator_power_profiles where id = next_profile
      and nominal_power_w = 100 and minimum_acceptable_power_w = 85 and valid_until is null) then
    raise exception 'nova vigência sobrescreveu valores históricos';
  end if;
  if (select power_profile_id from public.list_admin_generator_power_configuration('2026-07-01 02:59:59+00', false, generator)) <> first_profile
    or (select power_profile_id from public.list_admin_generator_power_configuration('2026-07-01 03:00:00+00', false, generator)) <> next_profile
    or (select count(*) from public.list_admin_generator_power_history(generator)) <> 2 then
    raise exception 'consulta de histórico ou fronteira semiaberta incorreta';
  end if;

  snapshot := pg_temp.nominal_snapshot();
  begin
    perform public.version_generator_power_profile(generator, '120', '2026-08-01', first_profile);
    raise exception 'edição com versão desatualizada foi aceita';
  exception when serialization_failure then null;
  end;
  begin
    perform public.version_generator_power_profile(generator, '120', '2026-07-01 03:00:00+00', next_profile);
    raise exception 'edição com início igual foi aceita';
  exception when exclusion_violation then null;
  end;
  begin
    perform public.version_generator_power_profile(generator, '999', '2026-08-01', next_profile);
    raise exception 'falha tardia não interrompeu versionamento';
  exception when raise_exception then
    if sqlerrm <> 'forced_nominal_contract_failure' then raise; end if;
  end;
  begin
    perform public.register_generator_with_power_profile(
      'f4000000-0000-4000-8000-000000000001', 'Falha atômica', '2026-01-01',
      '999', 'Estado falha', 'Potência falha', 'failure-device'
    );
    raise exception 'falha tardia não interrompeu cadastro';
  exception when raise_exception then
    if sqlerrm <> 'forced_nominal_contract_failure' then raise; end if;
  end;
  if snapshot is distinct from pg_temp.nominal_snapshot() then
    raise exception 'falha ou conflito publicou resultado parcial, auditoria ou reprocessamento';
  end if;

  -- The old registration remains usable until task 12.5 switches the UI.
  legacy := public.register_generator_v2(
    'f1000000-0000-4000-8000-000000000001', 'f3000000-0000-4000-8000-000000000001',
    'f4000000-0000-4000-8000-000000000001', 'Gerador legado', '2026-01-01',
    'Estado legado', '2026-01-01', 'Potência legado', 'legacy-device', '2026-01-01'
  );
  if not exists (select 1 from public.list_admin_generator_power_configuration('2026-07-01', true)
    where generator_id = legacy and power_profile_id is null and configuration_status = 'not_configured') then
    raise exception 'gerador legado não foi listado como pendente';
  end if;
  perform public.version_generator_power_profile(legacy, '9007199254740993.001', '2026-01-01', null);
  if not exists (select 1 from public.list_admin_generator_power_history(legacy)
    where nominal_power_w = '9007199254740993.001') then
    raise exception 'o contrato perdeu precisão decimal';
  end if;
  if exists (select 1 from public.list_admin_generator_power_configuration('2026-07-01', true) where generator_id = legacy) then
    raise exception 'legado configurado permaneceu pendente';
  end if;
end;
$$;

-- Actual execution is denied for clients, inactive Masters and absent identity.
do $$
declare
  subject text;
begin
  foreach subject in array array['f2000000-0000-4000-8000-000000000002', 'f2000000-0000-4000-8000-000000000003', ''] loop
    perform set_config('request.jwt.claim.sub', subject, true);
    begin
      perform public.register_generator_with_power_profile('f4000000-0000-4000-8000-000000000001', 'Proibido', '2026-01-01', '72', 'Estado proibido', 'Potência proibida', 'forbidden-device');
      raise exception 'cadastro sem Master foi aceito';
    exception when insufficient_privilege then null;
    end;
    begin
      perform public.version_generator_power_profile('f5000000-0000-4000-8000-000000000001', '72', '2026-01-01', null);
      raise exception 'versionamento sem Master foi aceito';
    exception when insufficient_privilege then null;
    end;
    begin
      perform public.list_admin_generator_power_configuration();
      raise exception 'consulta sem Master foi aceita';
    exception when insufficient_privilege then null;
    end;
    begin
      perform public.list_admin_generator_power_history('f5000000-0000-4000-8000-000000000001');
      raise exception 'histórico sem Master foi aceito';
    exception when insufficient_privilege then null;
    end;
  end loop;
end;
$$;
reset role;

do $$
declare
  fn regprocedure;
begin
  foreach fn in array array[
    'public.register_generator_with_power_profile(uuid,text,date,text,text,text,text,numeric,numeric,integer)'::regprocedure,
    'public.version_generator_power_profile(uuid,text,timestamptz,uuid)'::regprocedure,
    'public.list_admin_generator_power_configuration(timestamptz,boolean,uuid)'::regprocedure,
    'public.list_admin_generator_power_history(uuid)'::regprocedure
  ] loop
    if has_function_privilege('anon', fn, 'execute')
      or not has_function_privilege('authenticated', fn, 'execute')
      or (select prosecdef from pg_proc where oid = fn)
      or not (select proconfig @> array['search_path=""'] from pg_proc where oid = fn) then
      raise exception 'permissões ou search_path incorretos: %', fn;
    end if;
  end loop;
end;
$$;

select extensions.pass('spec 12.4 nominal power administrative contracts passed');
select * from extensions.finish();
rollback;
