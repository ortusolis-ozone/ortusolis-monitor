"use client";

import { useId } from "react";
import { FieldError, OperationalForm, useOperationalFieldError } from "./operational-form";
import { NominalPowerFields } from "./nominal-power-fields";
import { versionGeneratorPowerProfileAction } from "@/lib/operations/power-profiles/actions";
import type { OperationalActionState } from "@/lib/operations/action-state";

// The visible local datetime is explicitly interpreted in Fortaleza (UTC-03),
// independent of the browser's or server's timezone.
async function submitVersion(state: OperationalActionState, data: FormData) {
  const local = data.get("valid_from");
  if (typeof local === "string") data.set("valid_from", `${local}-03:00`);
  return versionGeneratorPowerProfileAction(state, data);
}

export function PowerProfileVersionForm({ generatorId, expectedProfileId }: {
  generatorId: string;
  expectedProfileId: string | null;
}) {
  return (
    <OperationalForm action={submitVersion} submitLabel={expectedProfileId ? "Registrar nova vigência" : "Configurar potência"}>
      <input type="hidden" name="generator_id" value={generatorId} />
      <input type="hidden" name="expected_profile_id" value={expectedProfileId ?? ""} />
      <NominalPowerFields />
      <VersionDateField />
      <FieldError name="expected_profile_id" />
      <FieldError name="generator_id" />
    </OperationalForm>
  );
}

function VersionDateField() {
  const id = useId();
  const error = useOperationalFieldError("valid_from");
  return <>
    <label htmlFor={`${id}-from`}>Início da vigência</label>
    <input
      id={`${id}-from`} type="datetime-local" name="valid_from" required
      aria-invalid={Boolean(error)}
      aria-describedby={`${id}-zone${error ? ` ${id}-error` : ""}`}
    />
    <small className="field-hint" id={`${id}-zone`}>Horário de Fortaleza (UTC−03:00). Os valores anteriores serão preservados no histórico.</small>
    {error ? <span id={`${id}-error`} className="field-error" role="alert">{error}</span> : null}
  </>;
}
