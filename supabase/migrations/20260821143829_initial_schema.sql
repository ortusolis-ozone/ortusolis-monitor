create extension if not exists btree_gist with schema extensions;

set search_path = public, extensions;

create table public.clients (
  id uuid primary key default gen_random_uuid(),
  legal_name text not null,
  cnpj text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint clients_legal_name_nonempty check (btrim(legal_name) <> ''),
  constraint clients_cnpj_format check (cnpj ~ '^[0-9]{14}$'),
  constraint clients_cnpj_key unique (cnpj)
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  client_id uuid references public.clients (id),
  full_name text not null,
  role text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_full_name_nonempty check (btrim(full_name) <> ''),
  constraint profiles_role_check check (
    role in ('master', 'client_admin', 'operator', 'viewer')
  ),
  constraint profiles_role_client_check check (
    (role = 'master' and client_id is null)
    or (role <> 'master' and client_id is not null)
  )
);

create table public.locations (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id),
  name text not null,
  description text,
  time_zone text not null default 'America/Fortaleza',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint locations_name_nonempty check (btrim(name) <> ''),
  constraint locations_time_zone_nonempty check (btrim(time_zone) <> ''),
  constraint locations_client_name_key unique (client_id, name),
  constraint locations_id_client_key unique (id, client_id)
);

create table public.cold_rooms (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null,
  location_id uuid not null,
  name text not null,
  category text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint cold_rooms_name_nonempty check (btrim(name) <> ''),
  constraint cold_rooms_category_check check (
    category in ('flv', 'bovinos', 'suinos', 'aves', 'pescados', 'outros')
  ),
  constraint cold_rooms_location_name_key unique (location_id, name),
  constraint cold_rooms_id_hierarchy_key unique (id, client_id, location_id),
  constraint cold_rooms_location_client_fkey foreign key (location_id, client_id)
    references public.locations (id, client_id)
);

create table public.generators (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id),
  identifier text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint generators_identifier_nonempty check (btrim(identifier) <> ''),
  constraint generators_client_identifier_key unique (client_id, identifier),
  constraint generators_id_client_key unique (id, client_id)
);

create table public.generator_assignments (
  id bigint generated always as identity primary key,
  generator_id uuid not null,
  client_id uuid not null,
  location_id uuid not null,
  cold_room_id uuid not null,
  valid_from timestamptz not null,
  valid_until timestamptz,
  created_at timestamptz not null default now(),
  constraint generator_assignments_period_check check (
    valid_until is null or valid_until > valid_from
  ),
  constraint generator_assignments_generator_client_fkey
    foreign key (generator_id, client_id)
    references public.generators (id, client_id),
  constraint generator_assignments_cold_room_hierarchy_fkey
    foreign key (cold_room_id, client_id, location_id)
    references public.cold_rooms (id, client_id, location_id),
  constraint generator_assignments_no_overlap exclude using gist (
    generator_id with =,
    tstzrange(valid_from, coalesce(valid_until, 'infinity'::timestamptz), '[)') with &&
  ) deferrable initially immediate
);

create table public.controllers (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null,
  generator_id uuid not null,
  identifier text not null,
  activated_at timestamptz not null,
  deactivated_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint controllers_identifier_nonempty check (btrim(identifier) <> ''),
  constraint controllers_period_check check (
    deactivated_at is null or deactivated_at > activated_at
  ),
  constraint controllers_active_period_check check (
    (is_active and deactivated_at is null)
    or (not is_active and deactivated_at is not null)
  ),
  constraint controllers_generator_identifier_key unique (generator_id, identifier),
  constraint controllers_id_hierarchy_key unique (id, client_id, generator_id),
  constraint controllers_generator_client_fkey
    foreign key (generator_id, client_id)
    references public.generators (id, client_id),
  constraint controllers_no_overlap exclude using gist (
    generator_id with =,
    tstzrange(activated_at, coalesce(deactivated_at, 'infinity'::timestamptz), '[)') with &&
  ) deferrable initially immediate
);

create table public.source_mappings (
  id bigint generated always as identity primary key,
  normalized_source text not null,
  classification text not null,
  is_active boolean not null default true,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint source_mappings_source_nonempty check (btrim(normalized_source) <> ''),
  constraint source_mappings_source_normalized check (
    normalized_source = lower(btrim(normalized_source))
  ),
  constraint source_mappings_classification_check check (
    classification in ('programmed', 'test')
  ),
  constraint source_mappings_normalized_source_key unique (normalized_source)
);

create table public.import_batches (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id),
  location_id uuid not null,
  cold_room_id uuid not null,
  generator_id uuid not null,
  controller_id uuid not null,
  file_name text not null,
  file_sha256 text not null,
  status text not null default 'processing',
  total_rows integer not null default 0,
  inserted_rows integer not null default 0,
  duplicate_rows integer not null default 0,
  unknown_source_rows integer not null default 0,
  period_start timestamptz,
  period_end timestamptz,
  error_message text,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  confirmed_at timestamptz,
  constraint import_batches_file_name_nonempty check (btrim(file_name) <> ''),
  constraint import_batches_file_sha256_format check (file_sha256 ~ '^[0-9a-f]{64}$'),
  constraint import_batches_status_check check (
    status in ('processing', 'confirmed', 'failed')
  ),
  constraint import_batches_totals_check check (
    total_rows >= 0
    and inserted_rows >= 0
    and duplicate_rows >= 0
    and unknown_source_rows >= 0
    and inserted_rows + duplicate_rows <= total_rows
    and unknown_source_rows <= total_rows
  ),
  constraint import_batches_period_check check (
    period_end is null or period_start is null or period_end >= period_start
  ),
  constraint import_batches_confirmation_check check (
    status <> 'confirmed' or confirmed_at is not null
  ),
  constraint import_batches_context_key unique (
    file_sha256,
    client_id,
    location_id,
    cold_room_id,
    generator_id,
    controller_id
  ),
  constraint import_batches_id_generator_controller_key unique (
    id,
    generator_id,
    controller_id
  ),
  constraint import_batches_cold_room_hierarchy_fkey
    foreign key (cold_room_id, client_id, location_id)
    references public.cold_rooms (id, client_id, location_id),
  constraint import_batches_generator_client_fkey
    foreign key (generator_id, client_id)
    references public.generators (id, client_id),
  constraint import_batches_controller_hierarchy_fkey
    foreign key (controller_id, client_id, generator_id)
    references public.controllers (id, client_id, generator_id)
);

create table public.raw_events (
  id bigint generated always as identity primary key,
  import_batch_id uuid not null,
  generator_id uuid not null,
  controller_id uuid not null,
  occurred_at timestamptz not null,
  occurred_at_raw text not null,
  operation text not null,
  operation_raw text not null,
  source_original text not null,
  source_normalized text not null,
  source_classification text not null,
  fingerprint text not null,
  created_at timestamptz not null default now(),
  constraint raw_events_raw_values_nonempty check (
    btrim(occurred_at_raw) <> ''
    and btrim(operation_raw) <> ''
    and btrim(source_original) <> ''
    and btrim(source_normalized) <> ''
  ),
  constraint raw_events_operation_check check (
    operation in ('turn_on', 'turn_off')
  ),
  constraint raw_events_source_classification_check check (
    source_classification in ('programmed', 'test', 'unknown')
  ),
  constraint raw_events_fingerprint_format check (fingerprint ~ '^[0-9a-f]{64}$'),
  constraint raw_events_fingerprint_key unique (fingerprint),
  constraint raw_events_id_generator_key unique (id, generator_id),
  constraint raw_events_id_generator_controller_key unique (
    id,
    generator_id,
    controller_id
  ),
  constraint raw_events_batch_context_fkey
    foreign key (import_batch_id, generator_id, controller_id)
    references public.import_batches (id, generator_id, controller_id)
);

create table public.applications (
  id bigint generated always as identity primary key,
  generator_id uuid not null references public.generators (id),
  controller_id uuid not null references public.controllers (id),
  start_event_id bigint not null,
  end_event_id bigint not null,
  public_date date not null,
  created_at timestamptz not null default now(),
  constraint applications_distinct_events_check check (
    start_event_id <> end_event_id
  ),
  constraint applications_start_event_key unique (start_event_id),
  constraint applications_end_event_key unique (end_event_id),
  constraint applications_start_event_context_fkey
    foreign key (start_event_id, generator_id, controller_id)
    references public.raw_events (id, generator_id, controller_id)
    on delete cascade,
  constraint applications_end_event_context_fkey
    foreign key (end_event_id, generator_id, controller_id)
    references public.raw_events (id, generator_id, controller_id)
    on delete cascade
);

create table public.inconsistencies (
  id bigint generated always as identity primary key,
  generator_id uuid not null references public.generators (id),
  event_id bigint not null,
  related_event_id bigint,
  type text not null,
  public_date date not null,
  status text not null default 'pending',
  review_note text,
  reviewed_by uuid references public.profiles (id),
  reviewed_at timestamptz,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  constraint inconsistencies_type_check check (
    type in (
      'unmatched_turn_on',
      'unmatched_turn_off',
      'consecutive_turn_on',
      'controller_mismatch',
      'unknown_source',
      'invalid_sequence'
    )
  ),
  constraint inconsistencies_status_check check (
    status in ('pending', 'reviewed', 'resolved')
  ),
  constraint inconsistencies_distinct_events_check check (
    related_event_id is null or related_event_id <> event_id
  ),
  constraint inconsistencies_review_check check (
    (status = 'reviewed' and reviewed_by is not null and reviewed_at is not null)
    or (status <> 'reviewed' and reviewed_by is null and reviewed_at is null)
  ),
  constraint inconsistencies_resolution_check check (
    (status = 'resolved' and resolved_at is not null)
    or (status <> 'resolved' and resolved_at is null)
  ),
  constraint inconsistencies_event_generator_fkey
    foreign key (event_id, generator_id)
    references public.raw_events (id, generator_id)
    on delete cascade,
  constraint inconsistencies_related_event_generator_fkey
    foreign key (related_event_id, generator_id)
    references public.raw_events (id, generator_id)
    on delete cascade
);

create table public.client_daily_status (
  client_id uuid not null references public.clients (id),
  location_id uuid not null,
  cold_room_id uuid not null,
  generator_id uuid not null,
  status_date date not null,
  status text not null,
  updated_at timestamptz not null default now(),
  primary key (generator_id, status_date),
  constraint client_daily_status_status_check check (
    status in (
      'verification_required',
      'completed',
      'no_data',
      'awaiting_update'
    )
  ),
  constraint client_daily_status_cold_room_hierarchy_fkey
    foreign key (cold_room_id, client_id, location_id)
    references public.cold_rooms (id, client_id, location_id),
  constraint client_daily_status_generator_client_fkey
    foreign key (generator_id, client_id)
    references public.generators (id, client_id)
);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles (id),
  action text not null,
  entity_type text not null,
  entity_id text not null,
  occurred_at timestamptz not null default now(),
  constraint audit_logs_action_nonempty check (btrim(action) <> ''),
  constraint audit_logs_entity_type_nonempty check (btrim(entity_type) <> ''),
  constraint audit_logs_entity_id_nonempty check (btrim(entity_id) <> '')
);

create index profiles_client_id_idx on public.profiles (client_id)
where client_id is not null;

create index locations_client_id_idx on public.locations (client_id);

create index cold_rooms_client_location_idx
  on public.cold_rooms (client_id, location_id);

create index generators_client_id_idx on public.generators (client_id);

create index generator_assignments_cold_room_id_idx
  on public.generator_assignments (cold_room_id);

create index generator_assignments_client_location_idx
  on public.generator_assignments (client_id, location_id);

create index controllers_client_generator_idx
  on public.controllers (client_id, generator_id);

create index source_mappings_created_by_idx
  on public.source_mappings (created_by);

create index import_batches_client_created_at_idx
  on public.import_batches (client_id, created_at desc);

create index import_batches_location_id_idx
  on public.import_batches (location_id);

create index import_batches_cold_room_id_idx
  on public.import_batches (cold_room_id);

create index import_batches_generator_id_idx
  on public.import_batches (generator_id);

create index import_batches_controller_id_idx
  on public.import_batches (controller_id);

create index import_batches_created_by_idx
  on public.import_batches (created_by);

create index raw_events_import_batch_id_idx
  on public.raw_events (import_batch_id);

create index raw_events_generator_occurred_at_idx
  on public.raw_events (generator_id, occurred_at, id);

create index raw_events_controller_id_idx
  on public.raw_events (controller_id);

create index applications_generator_public_date_idx
  on public.applications (generator_id, public_date);

create index applications_controller_id_idx
  on public.applications (controller_id);

create index inconsistencies_pending_date_idx
  on public.inconsistencies (public_date, generator_id)
  where status = 'pending';

create index inconsistencies_related_event_id_idx
  on public.inconsistencies (related_event_id)
  where related_event_id is not null;

create index inconsistencies_reviewed_by_idx
  on public.inconsistencies (reviewed_by)
  where reviewed_by is not null;

create index client_daily_status_client_date_idx
  on public.client_daily_status (client_id, status_date);

create index client_daily_status_location_date_idx
  on public.client_daily_status (location_id, status_date);

create index client_daily_status_cold_room_date_idx
  on public.client_daily_status (cold_room_id, status_date);

create index audit_logs_actor_id_idx on public.audit_logs (actor_id)
where actor_id is not null;

create index audit_logs_entity_idx
  on public.audit_logs (entity_type, entity_id, occurred_at desc);

alter table public.clients enable row level security;
alter table public.profiles enable row level security;
alter table public.locations enable row level security;
alter table public.cold_rooms enable row level security;
alter table public.generators enable row level security;
alter table public.generator_assignments enable row level security;
alter table public.controllers enable row level security;
alter table public.source_mappings enable row level security;
alter table public.import_batches enable row level security;
alter table public.raw_events enable row level security;
alter table public.applications enable row level security;
alter table public.inconsistencies enable row level security;
alter table public.client_daily_status enable row level security;
alter table public.audit_logs enable row level security;

alter default privileges for role postgres in schema public
  revoke select, insert, update, delete on tables
  from anon, authenticated, service_role;

alter default privileges for role postgres in schema public
  revoke usage, select on sequences
  from anon, authenticated, service_role;

alter default privileges for role postgres in schema public
  revoke execute on functions from anon, authenticated, service_role, public;

revoke all on table
  public.clients,
  public.profiles,
  public.locations,
  public.cold_rooms,
  public.generators,
  public.generator_assignments,
  public.controllers,
  public.source_mappings,
  public.import_batches,
  public.raw_events,
  public.applications,
  public.inconsistencies,
  public.client_daily_status,
  public.audit_logs
from anon, authenticated, public;

grant select, insert, update, delete on table
  public.clients,
  public.profiles,
  public.locations,
  public.cold_rooms,
  public.generators,
  public.generator_assignments,
  public.controllers,
  public.source_mappings,
  public.import_batches,
  public.raw_events,
  public.applications,
  public.inconsistencies,
  public.client_daily_status,
  public.audit_logs
to service_role;

revoke all on sequence
  public.generator_assignments_id_seq,
  public.source_mappings_id_seq,
  public.raw_events_id_seq,
  public.applications_id_seq,
  public.inconsistencies_id_seq,
  public.audit_logs_id_seq
from anon, authenticated, public;

grant usage, select on sequence
  public.generator_assignments_id_seq,
  public.source_mappings_id_seq,
  public.raw_events_id_seq,
  public.applications_id_seq,
  public.inconsistencies_id_seq,
  public.audit_logs_id_seq
to service_role;
