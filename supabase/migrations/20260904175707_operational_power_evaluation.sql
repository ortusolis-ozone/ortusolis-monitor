alter table public.generator_power_profiles
add constraint generator_power_profiles_id_generator_key
unique (id, generator_id);

alter table public.application_power_verifications
add column operational_power_status text not null default 'not_configured',
add column power_profile_id uuid,
add column reference_power_reading_id bigint,
add column nominal_power_w_snapshot numeric,
add column minimum_acceptable_power_w_snapshot numeric,
add column observed_power_w_snapshot numeric(14, 3),
add column operational_reason text not null
  default 'nominal_power_profile_not_configured';

alter table public.application_power_verifications
add constraint application_power_verifications_operational_status_check check (
  operational_power_status in (
    'within_expected',
    'below_expected',
    'not_evaluable',
    'not_configured'
  )
),
add constraint application_power_verifications_operational_reason_check check (
  btrim(operational_reason) <> ''
),
add constraint application_power_verifications_nominal_snapshot_check check (
  nominal_power_w_snapshot is null
  or (
    nominal_power_w_snapshot::text not in ('NaN', 'Infinity', '-Infinity')
    and nominal_power_w_snapshot > 0
    and scale(nominal_power_w_snapshot) between 0 and 3
  )
),
add constraint application_power_verifications_minimum_snapshot_check check (
  minimum_acceptable_power_w_snapshot is null
  or (
    minimum_acceptable_power_w_snapshot::text
      not in ('NaN', 'Infinity', '-Infinity')
    and minimum_acceptable_power_w_snapshot > 0
    and minimum_acceptable_power_w_snapshot
      = nominal_power_w_snapshot * 0.85
  )
),
add constraint application_power_verifications_observed_snapshot_check check (
  observed_power_w_snapshot is null or observed_power_w_snapshot >= 0
),
add constraint application_power_verifications_reference_reading_check check (
  reference_power_reading_id is null
  or reference_power_reading_id = power_on_reading_id
),
add constraint application_power_verifications_operational_shape_check check (
  (
    operational_power_status = 'not_configured'
    and power_profile_id is null
    and nominal_power_w_snapshot is null
    and minimum_acceptable_power_w_snapshot is null
  )
  or (
    operational_power_status = 'not_evaluable'
    and power_profile_id is not null
    and nominal_power_w_snapshot is not null
    and minimum_acceptable_power_w_snapshot is not null
    and reference_power_reading_id is null
    and observed_power_w_snapshot is null
  )
  or (
    operational_power_status in ('within_expected', 'below_expected')
    and power_profile_id is not null
    and nominal_power_w_snapshot is not null
    and minimum_acceptable_power_w_snapshot is not null
    and reference_power_reading_id is not null
    and observed_power_w_snapshot is not null
  )
),
add constraint application_power_verifications_operational_result_check check (
  operational_power_status not in ('within_expected', 'below_expected')
  or (
    operational_power_status = 'within_expected'
    and observed_power_w_snapshot >= minimum_acceptable_power_w_snapshot
  )
  or (
    operational_power_status = 'below_expected'
    and observed_power_w_snapshot < minimum_acceptable_power_w_snapshot
  )
),
add constraint application_power_verifications_power_profile_context_fkey
foreign key (power_profile_id, generator_id)
references public.generator_power_profiles (id, generator_id),
add constraint application_power_verifications_reference_context_fkey
foreign key (reference_power_reading_id, generator_id, controller_id)
references public.power_readings (id, generator_id, controller_id);

create index application_power_verifications_power_profile_idx
on public.application_power_verifications (power_profile_id)
where power_profile_id is not null;

create index application_power_verifications_reference_reading_idx
on public.application_power_verifications (reference_power_reading_id)
where reference_power_reading_id is not null;

create index app_power_verifications_generator_operational_status_idx
on public.application_power_verifications (
  generator_id,
  operational_power_status
);

comment on column
  public.application_power_verifications.operational_power_status is
  'Avaliação da leitura ligada contra o perfil nominal vigente no início.';

comment on column
  public.application_power_verifications.reference_power_reading_id is
  'Snapshot validado da power_on_reading_id usada na avaliação operacional.';

create or replace function private.operational_power_evaluations(
  p_generator_id uuid
)
returns table (
  application_id bigint,
  generator_id uuid,
  operational_power_status text,
  power_profile_id uuid,
  reference_power_reading_id bigint,
  nominal_power_w_snapshot numeric,
  minimum_acceptable_power_w_snapshot numeric,
  observed_power_w_snapshot numeric,
  operational_reason text
)
language sql
stable
security definer
set search_path = ''
as $$
  with evaluation_context as (
    select
      application.id as application_id,
      application.generator_id,
      verification.power_on_reading_id as candidate_power_on_reading_id,
      verification.technical_reason as correlation_reason,
      power_profile.id as power_profile_id,
      power_profile.nominal_power_w,
      power_profile.minimum_acceptable_power_w,
      reference_reading.id as reference_power_reading_id,
      reference_reading.power_w as observed_power_w
    from public.applications as application
    join public.raw_events as start_event
      on start_event.id = application.start_event_id
      and start_event.generator_id = application.generator_id
      and start_event.controller_id = application.controller_id
      and start_event.operation = 'turn_on'
    join public.raw_events as end_event
      on end_event.id = application.end_event_id
      and end_event.generator_id = application.generator_id
      and end_event.controller_id = application.controller_id
      and end_event.operation = 'turn_off'
    left join public.application_power_verifications as verification
      on verification.application_id = application.id
      and verification.generator_id = application.generator_id
    left join lateral (
      select profile.*
      from public.generator_power_profiles as profile
      where profile.generator_id = application.generator_id
        and profile.valid_from <= start_event.occurred_at
        and (
          profile.valid_until is null
          or start_event.occurred_at < profile.valid_until
        )
      order by profile.valid_from desc, profile.id
      limit 1
    ) as power_profile on true
    left join lateral (
      select reading.id, reading.power_w
      from public.power_readings as reading
      join public.import_batches as batch
        on batch.id = reading.import_batch_id
        and batch.generator_id = reading.generator_id
        and batch.controller_id = reading.controller_id
        and batch.status = 'confirmed'
        and batch.data_kind = 'power_readings'
      join public.controllers as controller
        on controller.id = reading.controller_id
        and controller.generator_id = reading.generator_id
        and controller.role = 'power_telemetry'
        and controller.activated_at <= start_event.occurred_at
        and (
          controller.deactivated_at is null
          or end_event.occurred_at < controller.deactivated_at
        )
        and reading.occurred_at >= controller.activated_at
        and (
          controller.deactivated_at is null
          or reading.occurred_at < controller.deactivated_at
        )
        and reading.power_w >= controller.power_on_threshold_w
      where reading.id = verification.power_on_reading_id
        and reading.generator_id = application.generator_id
        and reading.controller_id = verification.controller_id
      limit 1
    ) as reference_reading on true
    where application.generator_id = p_generator_id
  )
  select
    context.application_id,
    context.generator_id,
    case
      when context.power_profile_id is null then 'not_configured'
      when context.reference_power_reading_id is null then 'not_evaluable'
      when context.observed_power_w >= context.minimum_acceptable_power_w
        then 'within_expected'
      else 'below_expected'
    end as operational_power_status,
    context.power_profile_id,
    context.reference_power_reading_id,
    context.nominal_power_w as nominal_power_w_snapshot,
    context.minimum_acceptable_power_w
      as minimum_acceptable_power_w_snapshot,
    context.observed_power_w as observed_power_w_snapshot,
    case
      when context.power_profile_id is null
        then 'nominal_power_profile_not_configured'
      when context.reference_power_reading_id is null
        and context.candidate_power_on_reading_id is not null
        then 'power_on_reading_not_valid'
      when context.reference_power_reading_id is null
        then coalesce(
          nullif(btrim(context.correlation_reason), ''),
          'power_on_reading_not_available'
        )
      when context.observed_power_w >= context.minimum_acceptable_power_w
        then 'reference_power_at_or_above_minimum'
      else 'reference_power_below_minimum'
    end as operational_reason
  from evaluation_context as context;
$$;

revoke all on function private.operational_power_evaluations(uuid)
from public, anon, authenticated;
