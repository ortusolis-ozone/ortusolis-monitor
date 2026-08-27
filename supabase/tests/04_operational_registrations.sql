begin;

insert into public.clients (id, legal_name, cnpj)
values
  ('61000000-0000-0000-0000-000000000001', 'Cliente Operacional A', '04252011000110'),
  ('61000000-0000-0000-0000-000000000002', 'Cliente Operacional B', '11444777000161'),
  ('61000000-0000-0000-0000-000000000003', 'Cliente sem vínculos', '19131243000197');

insert into auth.users (id)
values
  ('62000000-0000-0000-0000-000000000001'),
  ('62000000-0000-0000-0000-000000000002');

insert into public.profiles (id, client_id, full_name, role)
values
  ('62000000-0000-0000-0000-000000000001', null, 'Master Operacional', 'master'),
  ('62000000-0000-0000-0000-000000000002', '61000000-0000-0000-0000-000000000001', 'Operador Operacional', 'operator');

insert into public.locations (id, client_id, name, time_zone)
values
  ('63000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000001', 'Unidade A1', 'America/Fortaleza'),
  ('63000000-0000-0000-0000-000000000002', '61000000-0000-0000-0000-000000000001', 'Unidade A2', 'America/Fortaleza'),
  ('63000000-0000-0000-0000-000000000003', '61000000-0000-0000-0000-000000000002', 'Unidade B', 'America/Fortaleza');

insert into public.cold_rooms (id, client_id, location_id, name, category)
values
  ('64000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000001', '63000000-0000-0000-0000-000000000001', 'Câmara A1', 'bovinos'),
  ('64000000-0000-0000-0000-000000000002', '61000000-0000-0000-0000-000000000001', '63000000-0000-0000-0000-000000000002', 'Câmara A2', 'outros'),
  ('64000000-0000-0000-0000-000000000003', '61000000-0000-0000-0000-000000000002', '63000000-0000-0000-0000-000000000003', 'Câmara B', 'pescados');

set local role authenticated;
set local request.jwt.claim.sub = '62000000-0000-0000-0000-000000000001';

do $$
declare
  generator_id uuid;
  controller_id uuid;
  replacement_id uuid;
begin
  generator_id := public.register_generator(
    '61000000-0000-0000-0000-000000000001',
    '63000000-0000-0000-0000-000000000001',
    '64000000-0000-0000-0000-000000000001',
    'Gerador histórico',
    '2026-01-01'
  );

  controller_id := public.register_controller(
    generator_id,
    'Controlador inicial',
    '2026-01-01'
  );

  perform public.reassign_generator(
    generator_id,
    '63000000-0000-0000-0000-000000000002',
    '64000000-0000-0000-0000-000000000002',
    '2026-02-01'
  );

  replacement_id := public.replace_controller(
    generator_id,
    'Controlador substituto',
    '2026-02-10'
  );

  if generator_id is null or controller_id is null or replacement_id is null then
    raise exception 'as operações transacionais não retornaram os identificadores';
  end if;

  begin
    perform public.reassign_generator(
      generator_id,
      '63000000-0000-0000-0000-000000000003',
      '64000000-0000-0000-0000-000000000003',
      '2026-03-01'
    );

    raise exception 'a realocação aceitou uma câmara de outro cliente';
  exception
    when check_violation then null;
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
      generator_id,
      '61000000-0000-0000-0000-000000000001',
      '63000000-0000-0000-0000-000000000001',
      '64000000-0000-0000-0000-000000000001',
      '2026-02-15 03:00:00+00'
    );

    raise exception 'uma alocação sobreposta foi aceita';
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
      '61000000-0000-0000-0000-000000000001',
      generator_id,
      'Controlador sobreposto',
      '2026-02-20 03:00:00+00'
    );

    raise exception 'um controlador sobreposto foi aceito';
  exception
    when exclusion_violation then null;
  end;

  update public.generators
  set identifier = 'Gerador histórico editado'
  where id = generator_id;
end
$$;

do $$
declare
  structure jsonb;
  complete_client_id uuid;
begin
  structure := public.register_complete_client_structure(
    'Cliente completo',
    '90000000000004',
    'Unidade completa',
    'Endereço completo',
    'America/Fortaleza',
    'Câmara completa',
    'aves',
    'Gerador completo',
    '2025-01-01',
    'Controlador completo',
    '2025-01-01'
  );

  complete_client_id := (structure ->> 'client_id')::uuid;

  if complete_client_id is null
    or not exists (
      select 1
      from public.locations
      where id = (structure ->> 'location_id')::uuid
        and client_id = complete_client_id
    )
    or not exists (
      select 1
      from public.cold_rooms
      where id = (structure ->> 'cold_room_id')::uuid
        and client_id = complete_client_id
        and location_id = (structure ->> 'location_id')::uuid
    )
    or not exists (
      select 1
      from public.generator_assignments
      where generator_id = (structure ->> 'generator_id')::uuid
        and client_id = complete_client_id
        and cold_room_id = (structure ->> 'cold_room_id')::uuid
        and valid_from = '2025-01-01 03:00:00+00'
    )
    or not exists (
      select 1
      from public.controllers
      where id = (structure ->> 'controller_id')::uuid
        and generator_id = (structure ->> 'generator_id')::uuid
        and client_id = complete_client_id
        and activated_at = '2025-01-01 03:00:00+00'
    ) then
    raise exception 'o cadastro completo não criou uma hierarquia coerente';
  end if;

  begin
    perform public.register_complete_client_structure(
      'Cliente incompleto',
      '99999999999999',
      'Unidade incompleta',
      null,
      'America/Fortaleza',
      'Câmara incompleta',
      'categoria_invalida',
      'Gerador incompleto',
      '2025-01-01',
      'Controlador incompleto',
      '2025-01-01'
    );

    raise exception 'o cadastro completo aceitou uma categoria inválida';
  exception
    when check_violation then null;
  end;

  if exists (
    select 1 from public.clients where cnpj = '99999999999999'
  ) then
    raise exception 'uma falha no cadastro completo deixou dados parciais';
  end if;

  begin
    perform public.register_complete_client_structure(
      'Cliente com datas inválidas',
      '77777777777777',
      'Unidade com datas inválidas',
      null,
      'America/Fortaleza',
      'Câmara com datas inválidas',
      'outros',
      'Gerador com datas inválidas',
      '2025-02-01',
      'Controlador com datas inválidas',
      '2025-01-31'
    );

    raise exception 'o controlador começou antes da alocação do gerador';
  exception
    when check_violation then null;
  end;

  if exists (
    select 1 from public.clients where cnpj = '77777777777777'
  ) then
    raise exception 'a validação de datas deixou dados parciais';
  end if;
end
$$;

reset role;
set local role authenticated;
set local request.jwt.claim.sub = '62000000-0000-0000-0000-000000000002';

do $$
declare
  affected_rows integer;
begin
  update public.clients
  set legal_name = 'Alteração indevida'
  where id = '61000000-0000-0000-0000-000000000001';

  get diagnostics affected_rows = row_count;

  if affected_rows <> 0 then
    raise exception 'um usuário de cliente alterou cadastro operacional';
  end if;

  if exists (select 1 from public.generator_assignments)
    or exists (select 1 from public.controllers) then
    raise exception 'um usuário de cliente consultou vigências técnicas';
  end if;

  begin
    perform public.register_generator(
      '61000000-0000-0000-0000-000000000001',
      '63000000-0000-0000-0000-000000000001',
      '64000000-0000-0000-0000-000000000001',
      'Gerador indevido',
      '2026-04-01'
    );

    raise exception 'um usuário de cliente cadastrou gerador';
  exception
    when insufficient_privilege then null;
  end;

  begin
    perform public.register_complete_client_structure(
      'Cliente indevido',
      '88888888888888',
      'Unidade indevida',
      null,
      'America/Fortaleza',
      'Câmara indevida',
      'outros',
      'Gerador indevido',
      '2026-04-01',
      'Controlador indevido',
      '2026-04-01'
    );

    raise exception 'um usuário de cliente executou o cadastro completo';
  exception
    when insufficient_privilege then null;
  end;
end
$$;

reset role;

do $$
declare
  target_generator_id uuid;
  closed_assignment_count integer;
  active_assignment_count integer;
  closed_controller_count integer;
  active_controller_count integer;
begin
  select id into target_generator_id
  from public.generators
  where identifier = 'Gerador histórico editado';

  select
    count(*) filter (where valid_until is not null),
    count(*) filter (where valid_until is null)
  into closed_assignment_count, active_assignment_count
  from public.generator_assignments as assignment
  where assignment.generator_id = target_generator_id;

  if closed_assignment_count <> 1 or active_assignment_count <> 1 then
    raise exception 'a realocação não preservou exatamente uma vigência anterior e uma atual';
  end if;

  if not exists (
    select 1
    from public.generator_assignments as assignment
    where assignment.generator_id = target_generator_id
      and cold_room_id = '64000000-0000-0000-0000-000000000001'
      and valid_until = '2026-02-01 03:00:00+00'
  ) or not exists (
    select 1
    from public.generator_assignments as assignment
    where assignment.generator_id = target_generator_id
      and cold_room_id = '64000000-0000-0000-0000-000000000002'
      and valid_from = '2026-02-01 03:00:00+00'
      and valid_until is null
  ) then
    raise exception 'as datas ou os destinos da realocação estão incorretos';
  end if;

  select
    count(*) filter (where deactivated_at is not null),
    count(*) filter (where deactivated_at is null)
  into closed_controller_count, active_controller_count
  from public.controllers as controller
  where controller.generator_id = target_generator_id;

  if closed_controller_count <> 1 or active_controller_count <> 1 then
    raise exception 'a substituição não preservou exatamente um controlador anterior e um atual';
  end if;

  if not exists (
    select 1
    from public.controllers as controller
    where controller.generator_id = target_generator_id
      and identifier = 'Controlador inicial'
      and deactivated_at = '2026-02-10 03:00:00+00'
      and not is_active
  ) or not exists (
    select 1
    from public.controllers as controller
    where controller.generator_id = target_generator_id
      and identifier = 'Controlador substituto'
      and activated_at = '2026-02-10 03:00:00+00'
      and deactivated_at is null
      and is_active
  ) then
    raise exception 'as datas da substituição do controlador estão incorretas';
  end if;

  if (
    select count(*)
    from public.audit_logs
    where actor_id = '62000000-0000-0000-0000-000000000001'
      and entity_type in ('generators', 'generator_assignments', 'controllers')
  ) < 8 then
    raise exception 'as alterações operacionais não foram auditadas';
  end if;

  begin
    delete from public.generator_assignments as assignment
    where assignment.generator_id = target_generator_id
      and assignment.valid_until is not null;

    raise exception 'uma alocação histórica foi excluída fisicamente';
  exception
    when check_violation then null;
  end;

  begin
    delete from public.clients
    where id = '61000000-0000-0000-0000-000000000003';

    raise exception 'um cadastro sem histórico foi excluído fisicamente';
  exception
    when check_violation then null;
  end;
end
$$;

do $$
begin
  if has_function_privilege(
    'anon',
    'public.reassign_generator(uuid,uuid,uuid,date)',
    'execute'
  ) then
    raise exception 'anon recebeu acesso às operações transacionais';
  end if;

  if not has_function_privilege(
    'authenticated',
    'public.reassign_generator(uuid,uuid,uuid,date)',
    'execute'
  ) then
    raise exception 'authenticated não alcança a função protegida por RLS';
  end if;

  if has_function_privilege(
    'anon',
    'public.register_complete_client_structure(text,text,text,text,text,text,text,text,date,text,date)',
    'execute'
  ) then
    raise exception 'anon recebeu acesso ao cadastro completo';
  end if;

  if not has_function_privilege(
    'authenticated',
    'public.register_complete_client_structure(text,text,text,text,text,text,text,text,date,text,date)',
    'execute'
  ) then
    raise exception 'authenticated não alcança o cadastro completo protegido por RLS';
  end if;

  if has_table_privilege('authenticated', 'public.clients', 'delete') then
    raise exception 'authenticated recebeu permissão de exclusão física';
  end if;
end
$$;

rollback;

select 'spec 04 operational registrations tests passed' as result;
