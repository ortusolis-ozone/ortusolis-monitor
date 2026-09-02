begin;

select extensions.plan(1);

insert into public.clients (id, legal_name, cnpj)
values (
  'a1000000-0000-4000-8000-000000000001',
  'Cliente Troca de Controlador',
  '04252011000110'
);

insert into auth.users (id)
values ('a2000000-0000-4000-8000-000000000001');

insert into public.profiles (id, client_id, full_name, role)
values (
  'a2000000-0000-4000-8000-000000000001',
  null,
  'Master Troca de Controlador',
  'master'
);

insert into public.locations (id, client_id, name, time_zone)
values (
  'a3000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'Unidade Troca de Controlador',
  'America/Fortaleza'
);

insert into public.cold_rooms (id, client_id, location_id, name, category)
values (
  'a4000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a3000000-0000-4000-8000-000000000001',
  'Câmara Troca de Controlador',
  'bovinos'
);

set local role authenticated;
set local request.jwt.claim.sub = 'a2000000-0000-4000-8000-000000000001';

do $$
declare
  generator_id_value uuid;
  old_state_controller_id uuid;
  old_power_controller_id uuid;
  new_state_controller_id uuid;
  new_power_controller_id uuid;
  confirmation jsonb;
  old_state_event jsonb := jsonb_build_array(jsonb_build_object(
    'occurred_at', '2026-08-14T15:00:00.000Z',
    'occurred_at_raw', '14/08/2026 12:00:00',
    'operation', 'turn_on',
    'operation_raw', 'Ligar',
    'source_original', 'Agendamento',
    'source_normalized', 'agendamento',
    'source_classification', 'programmed',
    'fingerprint', repeat('1', 64)
  ));
  boundary_state_event jsonb := jsonb_build_array(jsonb_build_object(
    'occurred_at', '2026-08-15T03:00:00.000Z',
    'occurred_at_raw', '15/08/2026 00:00:00',
    'operation', 'turn_off',
    'operation_raw', 'Desligar',
    'source_original', 'Agendamento',
    'source_normalized', 'agendamento',
    'source_classification', 'programmed',
    'fingerprint', repeat('2', 64)
  ));
  old_power_reading jsonb := jsonb_build_array(jsonb_build_object(
    'occurred_at', '2026-08-14T15:00:05.000Z',
    'occurred_at_raw', '2026-08-14 12:00:05:000',
    'power_w', 0,
    'power_raw', '0W',
    'device_name', 'Medidor antigo',
    'device_id', 'device-old',
    'device_id_normalized', 'device-old',
    'event_type', 'Report',
    'event_name', 'Power',
    'event_detail', '0W',
    'request_from', 'Device',
    'source_detail', '',
    'fingerprint', repeat('3', 64)
  ));
  boundary_old_power_reading jsonb := jsonb_build_array(jsonb_build_object(
    'occurred_at', '2026-08-15T03:00:00.000Z',
    'occurred_at_raw', '2026-08-15 00:00:00:000',
    'power_w', 0,
    'power_raw', '0W',
    'device_name', 'Medidor antigo',
    'device_id', 'device-old',
    'device_id_normalized', 'device-old',
    'event_type', 'Report',
    'event_name', 'Power',
    'event_detail', '0W',
    'request_from', 'Device',
    'source_detail', '',
    'fingerprint', repeat('4', 64)
  ));
  boundary_new_power_reading jsonb := jsonb_build_array(jsonb_build_object(
    'occurred_at', '2026-08-15T03:00:00.000Z',
    'occurred_at_raw', '2026-08-15 00:00:00:000',
    'power_w', 0,
    'power_raw', '0W',
    'device_name', 'Medidor novo',
    'device_id', 'device-new',
    'device_id_normalized', 'device-new',
    'event_type', 'Report',
    'event_name', 'Power',
    'event_detail', '0W',
    'request_from', 'Device',
    'source_detail', '',
    'fingerprint', repeat('5', 64)
  ));
begin
  generator_id_value := public.register_generator_v2(
    'a1000000-0000-4000-8000-000000000001',
    'a3000000-0000-4000-8000-000000000001',
    'a4000000-0000-4000-8000-000000000001',
    'Gerador Troca de Controlador',
    '2026-08-01',
    'Estado antigo',
    '2026-08-01',
    'Potência antiga',
    'device-old',
    '2026-08-01',
    5,
    1,
    120
  );

  select controller.id into old_state_controller_id
  from public.controllers as controller
  where controller.generator_id = generator_id_value
    and controller.role = 'state'
    and controller.is_active;

  select controller.id into old_power_controller_id
  from public.controllers as controller
  where controller.generator_id = generator_id_value
    and controller.role = 'power_telemetry'
    and controller.is_active;

  new_state_controller_id := public.replace_controller_v2(
    generator_id_value,
    'state',
    'Estado novo',
    '2026-08-15'
  );

  new_power_controller_id := public.replace_controller_v2(
    generator_id_value,
    'power_telemetry',
    'Potência nova',
    '2026-08-15',
    'device-new',
    5,
    1,
    120
  );

  if exists (
    select 1
    from public.controllers as controller
    where controller.id in (old_state_controller_id, old_power_controller_id)
      and (
        controller.is_active
        or controller.deactivated_at <> '2026-08-15 03:00:00+00'
      )
  ) then
    raise exception 'a substituição não encerrou a vigência dos controladores antigos';
  end if;

  if (
    select count(*)
    from public.controllers as controller
    where controller.id in (new_state_controller_id, new_power_controller_id)
      and controller.is_active
      and controller.activated_at = '2026-08-15 03:00:00+00'
      and controller.deactivated_at is null
  ) <> 2 then
    raise exception 'os novos controladores não assumiram o corte de vigência';
  end if;

  confirmation := public.confirm_xlsx_import(
    'a1000000-0000-4000-8000-000000000001',
    'a3000000-0000-4000-8000-000000000001',
    'a4000000-0000-4000-8000-000000000001',
    generator_id_value,
    old_state_controller_id,
    'estado-antigo-retroativo.xlsx',
    repeat('a', 64),
    old_state_event
  );

  if (confirmation ->> 'inserted_rows')::integer <> 1 then
    raise exception 'a importação retroativa do controlador de estado antigo falhou';
  end if;

  begin
    perform public.confirm_xlsx_import(
      'a1000000-0000-4000-8000-000000000001',
      'a3000000-0000-4000-8000-000000000001',
      'a4000000-0000-4000-8000-000000000001',
      generator_id_value,
      old_state_controller_id,
      'estado-antigo-fora-vigencia.xlsx',
      repeat('b', 64),
      boundary_state_event
    );
    raise exception 'o controlador de estado antigo aceitou evento no corte';
  exception when check_violation then null;
  end;

  confirmation := public.confirm_xlsx_import(
    'a1000000-0000-4000-8000-000000000001',
    'a3000000-0000-4000-8000-000000000001',
    'a4000000-0000-4000-8000-000000000001',
    generator_id_value,
    new_state_controller_id,
    'estado-novo.xlsx',
    repeat('c', 64),
    boundary_state_event
  );

  if (confirmation ->> 'inserted_rows')::integer <> 1 then
    raise exception 'o novo controlador de estado não aceitou evento no corte';
  end if;

  confirmation := public.confirm_power_xlsx_import(
    'a1000000-0000-4000-8000-000000000001',
    'a3000000-0000-4000-8000-000000000001',
    'a4000000-0000-4000-8000-000000000001',
    generator_id_value,
    old_power_controller_id,
    'potencia-antiga-retroativa.xlsx',
    repeat('d', 64),
    old_power_reading
  );

  if (confirmation ->> 'inserted_rows')::integer <> 1 then
    raise exception 'a importação retroativa do controlador de potência antigo falhou';
  end if;

  begin
    perform public.confirm_power_xlsx_import(
      'a1000000-0000-4000-8000-000000000001',
      'a3000000-0000-4000-8000-000000000001',
      'a4000000-0000-4000-8000-000000000001',
      generator_id_value,
      old_power_controller_id,
      'potencia-antiga-fora-vigencia.xlsx',
      repeat('e', 64),
      boundary_old_power_reading
    );
    raise exception 'o controlador de potência antigo aceitou leitura no corte';
  exception when check_violation then null;
  end;

  confirmation := public.confirm_power_xlsx_import(
    'a1000000-0000-4000-8000-000000000001',
    'a3000000-0000-4000-8000-000000000001',
    'a4000000-0000-4000-8000-000000000001',
    generator_id_value,
    new_power_controller_id,
    'potencia-nova.xlsx',
    repeat('f', 64),
    boundary_new_power_reading
  );

  if (confirmation ->> 'inserted_rows')::integer <> 1 then
    raise exception 'o novo controlador de potência não aceitou leitura no corte';
  end if;

  if (
    select count(*)
    from public.raw_events as event
    where event.generator_id = generator_id_value
      and event.controller_id in (old_state_controller_id, new_state_controller_id)
  ) <> 2 then
    raise exception 'o histórico de estado não permaneceu ligado aos controladores corretos';
  end if;

  if (
    select count(*)
    from public.power_readings as reading
    where reading.generator_id = generator_id_value
      and reading.controller_id in (old_power_controller_id, new_power_controller_id)
  ) <> 2 then
    raise exception 'o histórico de potência não permaneceu ligado aos controladores corretos';
  end if;
end;
$$;

reset role;

select extensions.pass('controller replacement validity import tests passed');
select * from extensions.finish();

rollback;
