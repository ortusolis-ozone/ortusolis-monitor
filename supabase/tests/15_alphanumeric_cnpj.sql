begin;
select extensions.plan(1);

do $$
declare
  invalid_cnpj text;
begin
  insert into public.clients (legal_name, cnpj) values
    ('CNPJ numérico', '04252011000110'),
    ('CNPJ alfanumérico', '12ABC34501DE35');

  update public.clients set cnpj = '00000000E08G12'
  where cnpj = '12ABC34501DE35';

  begin
    insert into public.clients (legal_name, cnpj)
    values ('Duplicado', '00000000E08G12');
    raise exception 'CNPJ duplicado foi aceito';
  exception when unique_violation then null;
  end;

  foreach invalid_cnpj in array array[
    '12abc34501de35', '12ABC34501DE3A', '12ABC34501DE3',
    '12ABC34501DE350', '12.ABC.345/01DE-35', '12ABC34501DÉ35'
  ] loop
    begin
      insert into public.clients (legal_name, cnpj)
      values ('Formato inválido', invalid_cnpj);
      raise exception 'Formato inválido foi aceito: %', invalid_cnpj;
    exception when check_violation then null;
    end;
  end loop;
end
$$;

select extensions.pass('CNPJ alfanumérico: inserção, edição, formato e unicidade');
select * from extensions.finish();
rollback;
