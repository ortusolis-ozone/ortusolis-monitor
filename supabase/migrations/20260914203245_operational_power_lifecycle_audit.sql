-- Complete the lifecycle audit without recording readings, files or review notes.
create or replace function private.audit_operational_power_lifecycle()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_action text;
begin
  if new.type <> 'power_below_expected' then
    return new;
  end if;

  if tg_op = 'INSERT' then
    v_action := 'power_below_expected_created';
  elsif old.status <> 'resolved' and new.status = 'resolved' then
    v_action := 'power_below_expected_resolved';
  elsif old.status = 'resolved' and new.status <> 'resolved' then
    v_action := 'power_below_expected_reactivated';
  else
    return new;
  end if;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id)
  values ((select auth.uid()), v_action, 'inconsistencies', new.id::text);
  return new;
end;
$$;

revoke all on function private.audit_operational_power_lifecycle()
from public, anon, authenticated;

create trigger inconsistencies_audit_operational_power_lifecycle
after insert or update of status on public.inconsistencies
for each row execute function private.audit_operational_power_lifecycle();
