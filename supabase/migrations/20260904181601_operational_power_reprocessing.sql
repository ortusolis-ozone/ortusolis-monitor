alter table public.application_power_verifications
add column operational_rule_version text not null
  default 'nominal-power-v1',
add constraint application_power_verifications_rule_version_check check (
  btrim(operational_rule_version) <> ''
);

comment on column
  public.application_power_verifications.operational_rule_version is
  'Versão imutável da regra usada para produzir os snapshots operacionais.';

alter table public.application_power_verifications
drop constraint application_power_verifications_reference_reading_check;

alter table public.application_power_verifications
alter constraint application_power_verifications_reference_context_fkey
deferrable initially immediate;

create or replace function private.validate_operational_power_reference()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  stored_reference_id bigint;
  stored_power_on_id bigint;
begin
  select
    verification.reference_power_reading_id,
    verification.power_on_reading_id
  into stored_reference_id, stored_power_on_id
  from public.application_power_verifications as verification
  where verification.application_id = new.application_id;

  if found
    and stored_reference_id is not null
    and stored_reference_id is distinct from stored_power_on_id then
    raise exception 'a leitura operacional deve ser a leitura ligada correlacionada'
      using
        errcode = '23514',
        constraint = 'app_power_verifications_reference_consistency';
  end if;

  return null;
end;
$$;

revoke all on function private.validate_operational_power_reference()
from public, anon, authenticated;

create constraint trigger
  app_power_verifications_reference_consistency
after insert or update on public.application_power_verifications
deferrable initially immediate
for each row execute function private.validate_operational_power_reference();

alter table public.inconsistencies
add column power_profile_id uuid,
drop constraint inconsistencies_type_check,
drop constraint inconsistencies_review_check,
add constraint inconsistencies_type_check check (
  type in (
    'unmatched_turn_on',
    'unmatched_turn_off',
    'consecutive_turn_on',
    'controller_mismatch',
    'unknown_source',
    'invalid_sequence',
    'missing_power_on',
    'missing_power_off',
    'missing_power_both',
    'unexpected_power',
    'power_below_expected'
  )
),
add constraint inconsistencies_review_check check (
  (
    status = 'pending'
    and reviewed_by is null
    and reviewed_at is null
  )
  or (
    status = 'reviewed'
    and reviewed_by is not null
    and reviewed_at is not null
  )
  or (
    status = 'resolved'
    and (
      (reviewed_by is null and reviewed_at is null)
      or (reviewed_by is not null and reviewed_at is not null)
    )
  )
),
add constraint inconsistencies_operational_power_source_check check (
  type <> 'power_below_expected'
  or (
    application_id is not null
    and power_reading_id is not null
    and power_profile_id is not null
  )
),
add constraint inconsistencies_power_profile_context_fkey
foreign key (power_profile_id, generator_id)
references public.generator_power_profiles (id, generator_id);

comment on column public.inconsistencies.power_profile_id is
  'Perfil efetivo associado à inconsistência de potência operacional.';

drop index public.inconsistencies_state_derivation_key_idx;

create unique index inconsistencies_state_derivation_key_idx
on public.inconsistencies (
  generator_id,
  event_id,
  related_event_id,
  type,
  public_date
)
nulls not distinct
where event_id is not null
  and type not like 'missing_power_%'
  and type <> 'power_below_expected';

create unique index inconsistencies_below_power_derivation_key_idx
on public.inconsistencies (
  application_id,
  power_reading_id,
  power_profile_id,
  type
)
where type = 'power_below_expected';

create index inconsistencies_power_profile_id_idx
on public.inconsistencies (power_profile_id)
where power_profile_id is not null;

create table private.operational_power_reprocessing_runs (
  id bigint generated always as identity primary key,
  generator_id uuid not null references public.generators (id),
  affected_from timestamptz,
  affected_until timestamptz,
  reason text not null,
  rule_version text not null,
  within_expected_count bigint not null,
  below_expected_count bigint not null,
  not_evaluable_count bigint not null,
  not_configured_count bigint not null,
  processed_at timestamptz not null default transaction_timestamp(),
  constraint operational_power_runs_period_check check (
    affected_until is null
    or affected_from is null
    or affected_until > affected_from
  ),
  constraint operational_power_runs_reason_check check (
    reason in (
      'migration_backfill',
      'power_telemetry_reprocess',
      'power_profile_inserted',
      'power_profile_values_changed',
      'power_profile_generator_changed',
      'power_profile_valid_from_changed',
      'power_profile_valid_until_changed'
    )
  ),
  constraint operational_power_runs_rule_check check (btrim(rule_version) <> ''),
  constraint operational_power_runs_counts_check check (
    within_expected_count >= 0
    and below_expected_count >= 0
    and not_evaluable_count >= 0
    and not_configured_count >= 0
  )
);

comment on table private.operational_power_reprocessing_runs is
  'Resumo técnico por execução, sem conteúdo bruto dos arquivos importados.';

create index operational_power_runs_generator_processed_idx
on private.operational_power_reprocessing_runs (
  generator_id,
  processed_at desc,
  id desc
);

alter table private.operational_power_reprocessing_runs enable row level security;

revoke all on table private.operational_power_reprocessing_runs
from public, anon, authenticated, service_role;

create or replace function private.reprocess_operational_power(
  p_generator_id uuid,
  p_affected_from timestamptz default null,
  p_affected_until timestamptz default null,
  p_reason text default 'power_telemetry_reprocess'
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  reprocessing_run_id bigint;
  within_expected_total bigint;
  below_expected_total bigint;
  not_evaluable_total bigint;
  not_configured_total bigint;
begin
  if not exists (
    select 1
    from public.generators as generator
    where generator.id = p_generator_id
  ) then
    raise exception 'gerador não encontrado' using errcode = 'P0002';
  end if;

  if p_affected_from is not null
    and p_affected_until is not null
    and p_affected_until <= p_affected_from then
    raise exception 'o intervalo de reprocessamento deve ser semiaberto e positivo'
      using errcode = '22023';
  end if;

  if nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception 'o motivo do reprocessamento é obrigatório'
      using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_generator_id::text, 0)
  );

  with desired_evaluations as materialized (
    select evaluation.*
    from private.operational_power_evaluations(p_generator_id) as evaluation
    join public.applications as application
      on application.id = evaluation.application_id
      and application.generator_id = evaluation.generator_id
    join public.raw_events as start_event
      on start_event.id = application.start_event_id
      and start_event.generator_id = application.generator_id
    where (
      p_affected_from is null
      or start_event.occurred_at >= p_affected_from
    )
      and (
        p_affected_until is null
        or start_event.occurred_at < p_affected_until
      )
  )
  update public.application_power_verifications as verification
  set
    operational_power_status = desired.operational_power_status,
    power_profile_id = desired.power_profile_id,
    reference_power_reading_id = desired.reference_power_reading_id,
    nominal_power_w_snapshot = desired.nominal_power_w_snapshot,
    minimum_acceptable_power_w_snapshot
      = desired.minimum_acceptable_power_w_snapshot,
    observed_power_w_snapshot = desired.observed_power_w_snapshot,
    operational_reason = desired.operational_reason,
    operational_rule_version = 'nominal-power-v1',
    updated_at = transaction_timestamp()
  from desired_evaluations as desired
  where verification.application_id = desired.application_id
    and (
      verification.operational_power_status,
      verification.power_profile_id,
      verification.reference_power_reading_id,
      verification.nominal_power_w_snapshot,
      verification.minimum_acceptable_power_w_snapshot,
      verification.observed_power_w_snapshot,
      verification.operational_reason,
      verification.operational_rule_version
    ) is distinct from (
      desired.operational_power_status,
      desired.power_profile_id,
      desired.reference_power_reading_id,
      desired.nominal_power_w_snapshot,
      desired.minimum_acceptable_power_w_snapshot,
      desired.observed_power_w_snapshot,
      desired.operational_reason,
      'nominal-power-v1'
    );

  update public.inconsistencies as inconsistency
  set
    status = 'resolved',
    resolved_at = transaction_timestamp()
  where inconsistency.generator_id = p_generator_id
    and inconsistency.type = 'power_below_expected'
    and inconsistency.status <> 'resolved'
    and exists (
      select 1
      from public.applications as application
      join public.raw_events as start_event
        on start_event.id = application.start_event_id
        and start_event.generator_id = application.generator_id
      where application.id = inconsistency.application_id
        and (
          p_affected_from is null
          or start_event.occurred_at >= p_affected_from
        )
        and (
          p_affected_until is null
          or start_event.occurred_at < p_affected_until
        )
    )
    and not exists (
      select 1
      from public.application_power_verifications as verification
      where verification.application_id = inconsistency.application_id
        and verification.operational_power_status = 'below_expected'
        and verification.reference_power_reading_id
          = inconsistency.power_reading_id
        and verification.power_profile_id = inconsistency.power_profile_id
    );

  update public.inconsistencies as inconsistency
  set
    status = case
      when inconsistency.reviewed_by is null then 'pending'
      else 'reviewed'
    end,
    resolved_at = null
  from public.application_power_verifications as verification
  join public.applications as application
    on application.id = verification.application_id
    and application.generator_id = verification.generator_id
  join public.raw_events as start_event
    on start_event.id = application.start_event_id
    and start_event.generator_id = application.generator_id
  where inconsistency.application_id = verification.application_id
    and inconsistency.generator_id = p_generator_id
    and inconsistency.type = 'power_below_expected'
    and inconsistency.status = 'resolved'
    and verification.operational_power_status = 'below_expected'
    and inconsistency.power_reading_id
      = verification.reference_power_reading_id
    and inconsistency.power_profile_id = verification.power_profile_id
    and (
      p_affected_from is null
      or start_event.occurred_at >= p_affected_from
    )
    and (
      p_affected_until is null
      or start_event.occurred_at < p_affected_until
    );

  insert into public.inconsistencies (
    generator_id,
    event_id,
    application_id,
    power_reading_id,
    power_profile_id,
    type,
    public_date
  )
  select
    verification.generator_id,
    application.start_event_id,
    verification.application_id,
    verification.reference_power_reading_id,
    verification.power_profile_id,
    'power_below_expected',
    application.public_date
  from public.application_power_verifications as verification
  join public.applications as application
    on application.id = verification.application_id
    and application.generator_id = verification.generator_id
  join public.raw_events as start_event
    on start_event.id = application.start_event_id
    and start_event.generator_id = application.generator_id
  where verification.generator_id = p_generator_id
    and verification.operational_power_status = 'below_expected'
    and (
      p_affected_from is null
      or start_event.occurred_at >= p_affected_from
    )
    and (
      p_affected_until is null
      or start_event.occurred_at < p_affected_until
    )
  on conflict (
    application_id,
    power_reading_id,
    power_profile_id,
    type
  )
  where type = 'power_below_expected'
  do nothing;

  update public.client_daily_status as daily_status
  set
    status = case
      when exists (
        select 1
        from public.inconsistencies as inconsistency
        where inconsistency.generator_id = p_generator_id
          and inconsistency.public_date = daily_status.status_date
          and inconsistency.status = 'pending'
          and inconsistency.type <> 'power_below_expected'
      ) then 'verification_required'
      else 'completed'
    end,
    updated_at = transaction_timestamp()
  where daily_status.generator_id = p_generator_id
    and exists (
      select 1
      from public.applications as application
      join public.raw_events as start_event
        on start_event.id = application.start_event_id
        and start_event.generator_id = application.generator_id
      where application.generator_id = p_generator_id
        and application.public_date = daily_status.status_date
        and (
          p_affected_from is null
          or start_event.occurred_at >= p_affected_from
        )
        and (
          p_affected_until is null
          or start_event.occurred_at < p_affected_until
        )
    )
    and daily_status.status is distinct from case
      when exists (
        select 1
        from public.inconsistencies as inconsistency
        where inconsistency.generator_id = p_generator_id
          and inconsistency.public_date = daily_status.status_date
          and inconsistency.status = 'pending'
          and inconsistency.type <> 'power_below_expected'
      ) then 'verification_required'
      else 'completed'
    end;

  select
    count(*) filter (
      where verification.operational_power_status = 'within_expected'
    ),
    count(*) filter (
      where verification.operational_power_status = 'below_expected'
    ),
    count(*) filter (
      where verification.operational_power_status = 'not_evaluable'
    ),
    count(*) filter (
      where verification.operational_power_status = 'not_configured'
    )
  into
    within_expected_total,
    below_expected_total,
    not_evaluable_total,
    not_configured_total
  from public.application_power_verifications as verification
  join public.applications as application
    on application.id = verification.application_id
    and application.generator_id = verification.generator_id
  join public.raw_events as start_event
    on start_event.id = application.start_event_id
    and start_event.generator_id = application.generator_id
  where verification.generator_id = p_generator_id
    and (
      p_affected_from is null
      or start_event.occurred_at >= p_affected_from
    )
    and (
      p_affected_until is null
      or start_event.occurred_at < p_affected_until
    );

  insert into private.operational_power_reprocessing_runs (
    generator_id,
    affected_from,
    affected_until,
    reason,
    rule_version,
    within_expected_count,
    below_expected_count,
    not_evaluable_count,
    not_configured_count
  )
  values (
    p_generator_id,
    p_affected_from,
    p_affected_until,
    btrim(p_reason),
    'nominal-power-v1',
    within_expected_total,
    below_expected_total,
    not_evaluable_total,
    not_configured_total
  )
  returning id into reprocessing_run_id;

  return reprocessing_run_id;
end;
$$;

revoke all on function private.reprocess_operational_power(
  uuid,
  timestamptz,
  timestamptz,
  text
)
from public, anon, authenticated;

alter function private.reprocess_power_telemetry(uuid)
rename to reprocess_power_telemetry_correlation;

revoke all on function private.reprocess_power_telemetry_correlation(uuid)
from public, anon, authenticated;

create or replace function private.reprocess_power_telemetry(p_generator_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  set constraints
    public.application_power_verifications_reference_context_fkey,
    public.app_power_verifications_reference_consistency
  deferred;

  perform private.reprocess_power_telemetry_correlation(p_generator_id);
  perform private.reprocess_operational_power(
    p_generator_id,
    null,
    null,
    'power_telemetry_reprocess'
  );

  set constraints
    public.application_power_verifications_reference_context_fkey,
    public.app_power_verifications_reference_consistency
  immediate;
end;
$$;

revoke all on function private.reprocess_power_telemetry(uuid)
from public, anon, authenticated;

create or replace function private.reprocess_generator_power_profile_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  affected_from timestamptz;
  affected_until timestamptz;
begin
  if tg_op = 'INSERT' then
    perform private.reprocess_operational_power(
      new.generator_id,
      new.valid_from,
      new.valid_until,
      'power_profile_inserted'
    );
    return new;
  end if;

  if (
    new.generator_id,
    new.nominal_power_w,
    new.reduction_limit_percent
  ) is distinct from (
    old.generator_id,
    old.nominal_power_w,
    old.reduction_limit_percent
  ) then
    if new.generator_id = old.generator_id then
      affected_from = least(new.valid_from, old.valid_from);
      affected_until = case
        when new.valid_until is null or old.valid_until is null then null
        else greatest(new.valid_until, old.valid_until)
      end;

      perform private.reprocess_operational_power(
        new.generator_id,
        affected_from,
        affected_until,
        'power_profile_values_changed'
      );
    else
      perform private.reprocess_operational_power(
        old.generator_id,
        old.valid_from,
        old.valid_until,
        'power_profile_generator_changed'
      );
      perform private.reprocess_operational_power(
        new.generator_id,
        new.valid_from,
        new.valid_until,
        'power_profile_generator_changed'
      );
    end if;

    return new;
  end if;

  if new.valid_from is distinct from old.valid_from then
    perform private.reprocess_operational_power(
      new.generator_id,
      least(new.valid_from, old.valid_from),
      greatest(new.valid_from, old.valid_from),
      'power_profile_valid_from_changed'
    );
  end if;

  if new.valid_until is distinct from old.valid_until then
    affected_from = case
      when new.valid_until is null then old.valid_until
      when old.valid_until is null then new.valid_until
      else least(new.valid_until, old.valid_until)
    end;
    affected_until = case
      when new.valid_until is null or old.valid_until is null then null
      else greatest(new.valid_until, old.valid_until)
    end;

    perform private.reprocess_operational_power(
      new.generator_id,
      affected_from,
      affected_until,
      'power_profile_valid_until_changed'
    );
  end if;

  return new;
end;
$$;

revoke all on function private.reprocess_generator_power_profile_change()
from public, anon, authenticated;

create trigger generator_power_profiles_reprocess_operational_power
after insert or update on public.generator_power_profiles
for each row execute function
  private.reprocess_generator_power_profile_change();

do $$
declare
  existing_generator_id uuid;
begin
  for existing_generator_id in
    select distinct verification.generator_id
    from public.application_power_verifications as verification
    order by verification.generator_id
  loop
    perform private.reprocess_operational_power(
      existing_generator_id,
      null,
      null,
      'migration_backfill'
    );
  end loop;
end;
$$;
