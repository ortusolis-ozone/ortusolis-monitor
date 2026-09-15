-- The daily processing table is now an administrative surface only.
-- Keep its internal evidence column for deterministic processing and diagnostics.
drop policy client_daily_status_select_authorized on public.client_daily_status;
create policy client_daily_status_select_master
on public.client_daily_status for select to authenticated
using ((select private.is_active_master()));
revoke all on public.client_daily_status from public, anon;
comment on table public.client_daily_status is
  'Agregado interno de processamento, consultável somente pelo Master. O portal usa list_client_application_status.';
