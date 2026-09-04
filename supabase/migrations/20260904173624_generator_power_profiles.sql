set search_path = public, extensions;

create table public.generator_power_profiles (
  id uuid primary key default gen_random_uuid(),
  generator_id uuid not null references public.generators (id),
  nominal_power_w numeric not null,
  reduction_limit_percent numeric(5, 3) not null default 15.000,
  minimum_acceptable_power_w numeric generated always as (
    nominal_power_w * (1 - reduction_limit_percent / 100)
  ) stored not null,
  valid_from timestamptz not null,
  valid_until timestamptz,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  constraint generator_power_profiles_nominal_finite_check check (
    nominal_power_w::text not in ('NaN', 'Infinity', '-Infinity')
  ),
  constraint generator_power_profiles_nominal_positive_check check (
    nominal_power_w > 0
  ),
  constraint generator_power_profiles_nominal_scale_check check (
    scale(nominal_power_w) between 0 and 3
  ),
  constraint generator_power_profiles_reduction_limit_check check (
    reduction_limit_percent = 15.000
  ),
  constraint generator_power_profiles_period_check check (
    valid_until is null or valid_until > valid_from
  ),
  constraint generator_power_profiles_no_overlap exclude using gist (
    generator_id with =,
    tstzrange(
      valid_from,
      coalesce(valid_until, 'infinity'::timestamptz),
      '[)'
    ) with &&
  ) deferrable initially immediate
);

comment on table public.generator_power_profiles is
  'Histórico de potência nominal do gerador por vigência semiaberta.';

comment on column public.generator_power_profiles.minimum_acceptable_power_w is
  'Mínimo operacional exato calculado pela redução fixa de 15%.';

create index generator_power_profiles_generator_valid_from_idx
on public.generator_power_profiles (generator_id, valid_from desc);

create unique index generator_power_profiles_current_key
on public.generator_power_profiles (generator_id)
where valid_until is null;

create index generator_power_profiles_created_by_idx
on public.generator_power_profiles (created_by);

alter table public.generator_power_profiles enable row level security;

revoke all on table public.generator_power_profiles
from public, anon, authenticated;

grant select, insert, update, delete on table
  public.generator_power_profiles
to service_role;

grant select on table public.generator_power_profiles to authenticated;

grant insert (
  generator_id,
  nominal_power_w,
  valid_from,
  valid_until,
  created_by
) on public.generator_power_profiles to authenticated;

grant update (valid_until)
on public.generator_power_profiles
to authenticated;

create policy generator_power_profiles_select_master
on public.generator_power_profiles
for select
to authenticated
using ((select private.is_active_master()));

create policy generator_power_profiles_insert_master
on public.generator_power_profiles
for insert
to authenticated
with check (
  (select private.is_active_master())
  and created_by = (select auth.uid())
);

create policy generator_power_profiles_update_master
on public.generator_power_profiles
for update
to authenticated
using ((select private.is_active_master()))
with check ((select private.is_active_master()));

create trigger generator_power_profiles_prevent_delete
before delete on public.generator_power_profiles
for each row execute function private.prevent_operational_delete();

create trigger generator_power_profiles_audit_operational_change
after insert or update on public.generator_power_profiles
for each row execute function private.audit_operational_change();
