begin;
select extensions.plan(1);

insert into auth.users (id) values ('f9000000-0000-4000-8000-000000000001');
insert into public.profiles (id, full_name, role)
values ('f9000000-0000-4000-8000-000000000001', 'Master Potência Obrigatória', 'master');
insert into public.clients (id, legal_name, cnpj)
values ('f9000000-0000-4000-8000-000000000002', 'Cliente legado 12.5', '04252011000110');

-- Simulate a generator that existed before the migration.
alter table public.generators disable trigger new_generator_requires_power_profile;
insert into public.generators (id, client_id, identifier)
values ('f9000000-0000-4000-8000-000000000003', 'f9000000-0000-4000-8000-000000000002', 'Legado sem nominal');
alter table public.generators enable trigger new_generator_requires_power_profile;

set local role authenticated;
set local request.jwt.claim.sub = 'f9000000-0000-4000-8000-000000000001';
do $$
declare
  structure jsonb;
  total_before bigint;
begin
  select count(*) into total_before from public.clients;
  begin
    perform public.register_complete_client_structure_with_power_profile(
      'Estrutura inválida', '11444777000161', 'Unidade', '', 'America/Fortaleza',
      'Câmara', 'flv', 'Gerador', '2026-01-01', 'Estado', '2026-01-01',
      'Potência', 'required-power-device', '2026-01-01', '0'
    );
    raise exception 'cadastro completo aceitou potência zero';
  exception when invalid_parameter_value then null;
  end;
  if (select count(*) from public.clients) <> total_before then
    raise exception 'falha de validação criou cliente parcial';
  end if;

  structure := public.register_complete_client_structure_with_power_profile(
    'Estrutura nominal 12.5', '11444777000161', 'Unidade', '', 'America/Fortaleza',
    'Câmara', 'flv', 'Gerador completo', '2026-01-01', 'Estado completo', '2026-01-01',
    'Potência completa', 'required-power-device', '2026-01-01', '72'
  );
  set constraints public.new_generator_requires_power_profile immediate;
  if not exists (select 1 from public.generator_power_profiles
    where generator_id = (structure ->> 'generator_id')::uuid and nominal_power_w = 72
      and minimum_acceptable_power_w = 61.2 and valid_from = '2026-01-01 03:00:00+00') then
    raise exception 'estrutura completa não criou o perfil nominal correto';
  end if;
  set constraints public.new_generator_requires_power_profile deferred;

  begin
    insert into public.generators (client_id, identifier)
    values ('f9000000-0000-4000-8000-000000000002', 'INSERT sem nominal');
    set constraints public.new_generator_requires_power_profile immediate;
    raise exception 'INSERT direto permitiu novo gerador sem nominal';
  exception when check_violation then null;
  end;
  begin
    perform public.register_generator_v2(
      (structure ->> 'client_id')::uuid, (structure ->> 'location_id')::uuid,
      (structure ->> 'cold_room_id')::uuid, 'Cadastro legado bloqueado', '2026-01-01',
      'Estado legado', '2026-01-01', 'Potência legado', 'legacy-blocked-device', '2026-01-01'
    );
    set constraints public.new_generator_requires_power_profile immediate;
    raise exception 'RPC legada permitiu cadastro sem nominal';
  exception when check_violation then null;
  end;
  begin
    perform public.register_complete_client_structure_v2(
      'Estrutura legada bloqueada', '19131243000197', 'Unidade legada', '', 'America/Fortaleza',
      'Câmara legada', 'flv', 'Gerador legado', '2026-01-01', 'Estado legado', '2026-01-01',
      'Potência legada', 'structure-blocked-device', '2026-01-01'
    );
    set constraints public.new_generator_requires_power_profile immediate;
    raise exception 'estrutura legada permitiu cadastro sem nominal';
  exception when check_violation then null;
  end;
  if exists (select 1 from public.generators where identifier in ('INSERT sem nominal', 'Cadastro legado bloqueado'))
    or exists (select 1 from public.clients where cnpj = '19131243000197') then
    raise exception 'cadastro bloqueado deixou resultado parcial';
  end if;

  -- Existing pending records remain editable and can receive their first profile.
  update public.generators set identifier = 'Legado preservado'
  where id = 'f9000000-0000-4000-8000-000000000003';
  if not exists (select 1 from public.list_admin_generator_power_configuration(now(), true)
    where generator_id = 'f9000000-0000-4000-8000-000000000003') then
    raise exception 'legado pendente foi alterado ou ocultado';
  end if;
  perform public.version_generator_power_profile('f9000000-0000-4000-8000-000000000003', '100', '2026-01-01');
  set constraints public.new_generator_requires_power_profile immediate;
end;
$$;
reset role;
select extensions.pass('spec 12.5 required nominal power tests passed');
select * from extensions.finish();
rollback;
