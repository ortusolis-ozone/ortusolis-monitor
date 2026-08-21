create schema if not exists private;

revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;

create or replace function private.is_active_master()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'master'
      and client_id is null
      and is_active
  );
$$;

create or replace function private.current_client_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select profile.client_id
  from public.profiles as profile
  join public.clients as client
    on client.id = profile.client_id
  where profile.id = (select auth.uid())
    and profile.role in ('client_admin', 'operator', 'viewer')
    and profile.is_active
    and client.is_active;
$$;

revoke all on function private.is_active_master() from public, anon;
revoke all on function private.current_client_id() from public, anon;
grant execute on function private.is_active_master() to authenticated;
grant execute on function private.current_client_id() to authenticated;

grant select on table
  public.profiles,
  public.clients,
  public.locations,
  public.cold_rooms,
  public.generators,
  public.client_daily_status
to authenticated;

create policy profiles_select_authorized
on public.profiles
for select
to authenticated
using (
  (select private.is_active_master())
  or (
    id = (select auth.uid())
    and is_active
    and (
      role = 'master'
      or client_id = (select private.current_client_id())
    )
  )
);

create policy clients_select_authorized
on public.clients
for select
to authenticated
using (
  (select private.is_active_master())
  or id = (select private.current_client_id())
);

create policy locations_select_authorized
on public.locations
for select
to authenticated
using (
  (select private.is_active_master())
  or client_id = (select private.current_client_id())
);

create policy cold_rooms_select_authorized
on public.cold_rooms
for select
to authenticated
using (
  (select private.is_active_master())
  or client_id = (select private.current_client_id())
);

create policy generators_select_authorized
on public.generators
for select
to authenticated
using (
  (select private.is_active_master())
  or client_id = (select private.current_client_id())
);

create policy client_daily_status_select_authorized
on public.client_daily_status
for select
to authenticated
using (
  (select private.is_active_master())
  or client_id = (select private.current_client_id())
);
