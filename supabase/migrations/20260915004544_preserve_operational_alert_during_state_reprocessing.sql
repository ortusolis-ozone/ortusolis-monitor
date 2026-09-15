-- State reconstruction must not resolve the independent nominal-power alert.
-- Its canonical evaluator owns resolution; this also avoids false audit transitions
-- when identical imports reconstruct state before recalculating power.
do $$
declare
  v_definition text := pg_get_functiondef('private.reprocess_generator(uuid)'::regprocedure);
  v_previous text := E'and inconsistency.status = ''pending''\n    and not exists (';
  v_next text := E'and inconsistency.status = ''pending''\n    and inconsistency.type <> ''power_below_expected''\n    and not exists (';
begin
  if strpos(v_definition, v_previous) = 0 then
    raise exception 'state reprocessor contract changed; review nominal-power exclusion';
  end if;
  execute replace(v_definition, v_previous, v_next);
end;
$$;
