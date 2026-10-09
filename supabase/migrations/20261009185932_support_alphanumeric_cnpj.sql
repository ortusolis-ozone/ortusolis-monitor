-- Mantém CNPJs numéricos e aceita letras maiúsculas nas primeiras 12 posições.
-- A aplicação normaliza a entrada e valida os dígitos verificadores.
alter table public.clients
  drop constraint clients_cnpj_format,
  add constraint clients_cnpj_format
    check (cnpj ~ '^[A-Z0-9]{12}[0-9]{2}$');
