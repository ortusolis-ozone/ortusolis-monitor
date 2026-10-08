-- Manual identifies the command's origin; test remains readable for legacy data.
alter table public.source_mappings
  drop constraint source_mappings_classification_check,
  add constraint source_mappings_classification_check
    check (classification in ('programmed', 'manual', 'test'));

alter table public.raw_events
  drop constraint raw_events_source_classification_check,
  add constraint raw_events_source_classification_check
    check (source_classification in ('programmed', 'manual', 'test', 'unknown'));

-- Extend the canonical functions in place, preserving the telemetry/fuso fixes
-- introduced by intervening migrations. Fail closed if their contracts changed.
do $$
declare
  definition text;
  previous text;
begin
  definition := pg_get_functiondef('private.reprocess_generator(uuid)'::regprocedure);
  previous := 'if event_record.source_classification = ''test'' then';
  if strpos(definition, previous) = 0 then
    raise exception 'state reprocessor contract changed; review manual exclusion';
  end if;
  execute replace(definition, previous,
    'if event_record.source_classification in (''manual'', ''test'') then');

  definition := pg_get_functiondef(
    'public.confirm_xlsx_import(uuid,uuid,uuid,uuid,uuid,text,text,jsonb)'::regprocedure
  );
  previous := 'event.source_classification not in (''programmed'', ''test'', ''unknown'')';
  if strpos(definition, previous) = 0 then
    raise exception 'state import contract changed; review manual classification';
  end if;
  execute replace(definition, previous,
    'event.source_classification not in (''programmed'', ''manual'', ''test'', ''unknown'')');
end;
$$;

create or replace function public.set_source_mapping(
  p_normalized_source text,
  p_classification text
)
returns bigint
language plpgsql
security invoker
set search_path = ''
as $$
declare
  normalized_value text;
  stored_mapping_id bigint;
begin
  if not (select private.is_active_master()) then
    raise exception 'apenas usuários Master ativos podem alterar mapeamentos'
      using errcode = '42501';
  end if;

  normalized_value := lower(btrim(coalesce(p_normalized_source, '')));
  if normalized_value = '' then
    raise exception 'a origem é obrigatória' using errcode = '23514';
  end if;

  -- Legacy test mappings can be read, but cannot be created by this command.
  if p_classification is null or p_classification not in ('programmed', 'manual', 'unknown') then
    raise exception 'selecione Programada, Manual ou Desconhecida'
      using errcode = '23514';
  end if;

  if p_classification = 'unknown' then
    update public.source_mappings
    set is_active = false, updated_at = transaction_timestamp()
    where normalized_source = normalized_value and is_active
    returning id into stored_mapping_id;
  else
    insert into public.source_mappings (
      normalized_source, classification, is_active, created_by
    ) values (
      normalized_value, p_classification, true, (select auth.uid())
    )
    on conflict (normalized_source) do update
    set classification = excluded.classification,
        is_active = true,
        updated_at = transaction_timestamp()
    where (source_mappings.classification, source_mappings.is_active)
      is distinct from (excluded.classification, true)
    returning id into stored_mapping_id;
  end if;

  if stored_mapping_id is null then
    select id into stored_mapping_id from public.source_mappings
    where normalized_source = normalized_value;
  end if;
  return stored_mapping_id;
end;
$$;

-- The existing audit contract records only actor/action/entity. Add the minimal
-- mapping transition context, under the same Master-only RLS and grants.
alter table public.audit_logs
  add column metadata jsonb not null default '{}'::jsonb;

create or replace function private.audit_source_mapping_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  previous_classification text;
  current_classification text;
  affected_generators jsonb;
  audit_action text;
begin
  if tg_op = 'UPDATE' then
    if (old.classification, old.is_active, old.normalized_source)
      is not distinct from (new.classification, new.is_active, new.normalized_source) then
      return new;
    end if;
    previous_classification := case when old.is_active then old.classification else 'unknown' end;
  end if;
  current_classification := case when new.is_active then new.classification else 'unknown' end;
  audit_action := case
    when tg_op = 'INSERT' then 'created'
    when old.is_active is distinct from new.is_active then
      case when new.is_active then 'activated' else 'deactivated' end
    else 'updated'
  end;

  select coalesce(jsonb_agg(affected.generator_id order by affected.generator_id), '[]'::jsonb)
  into affected_generators
  from (
    select distinct event.generator_id
    from public.raw_events as event
    join public.import_batches as batch
      on batch.id = event.import_batch_id and batch.status = 'confirmed'
    where event.source_normalized = new.normalized_source
      or (tg_op = 'UPDATE' and event.source_normalized = old.normalized_source)
  ) as affected;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, metadata)
  values ((select auth.uid()), audit_action, 'source_mappings', new.id::text,
    jsonb_build_object(
      'normalized_source', new.normalized_source,
      'previous_classification', previous_classification,
      'classification', current_classification,
      'affected_generator_ids', affected_generators
    ));
  return new;
end;
$$;

revoke all on function private.audit_source_mapping_change() from public, anon, authenticated;

drop trigger source_mappings_audit_admin_change on public.source_mappings;
create trigger source_mappings_audit_admin_change
after insert or update on public.source_mappings
for each row execute function private.audit_source_mapping_change();

-- No global test-to-manual conversion: the Master updates the exact Ortusolis
-- mapping through set_source_mapping, which audits and reprocesses atomically.
