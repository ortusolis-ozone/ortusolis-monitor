"use client";

import { useEffect, useId, useRef, useState } from "react";
import { useOperationalFieldError } from "./operational-form";
import { formatPower, minimumPowerPreview } from "@/lib/operations/power-profiles/format";
import { parseNominalPower } from "@/lib/operations/power-profiles/validation";

const invalidMessage = "Informe uma potência positiva com até três casas decimais.";

export function NominalPowerFields() {
  const id = useId();
  const inputRef = useRef<HTMLInputElement>(null);
  const [value, setValue] = useState("");
  const [touched, setTouched] = useState(false);
  const serverError = useOperationalFieldError("nominal_power_w");
  const preview = minimumPowerPreview(value);
  const error = serverError || (touched && preview === null ? invalidMessage : null);

  useEffect(() => {
    const input = inputRef.current;
    const form = input?.form;
    function reset() {
      setValue("");
      setTouched(false);
      input?.setCustomValidity("");
    }
    form?.addEventListener("reset", reset);
    return () => form?.removeEventListener("reset", reset);
  }, []);

  return (
    <div className="nominal-power-fields">
      <label htmlFor={`${id}-nominal`}>Potência nominal (W)</label>
      <input
        id={`${id}-nominal`}
        ref={inputRef}
        name="nominal_power_w"
        type="text"
        inputMode="decimal"
        required
        pattern="[0-9]+([.,][0-9]{1,3})?"
        aria-describedby={`${id}-hint${error ? ` ${id}-error` : ""}`}
        aria-invalid={Boolean(error)}
        onChange={(event) => {
          const next = event.target.value;
          setValue(next);
          event.target.setCustomValidity(parseNominalPower(next) === null ? invalidMessage : "");
        }}
        onBlur={() => setTouched(true)}
        onInvalid={() => setTouched(true)}
      />
      <p className="field-hint" id={`${id}-hint`}>
        Informe a potência do gerador. A redução máxima admitida é de 15%.
        Os limites elétricos do controlador servem para detectar liga/desliga e são configurações separadas.
      </p>
      {error ? <span className="field-error" id={`${id}-error`} role="alert">{error}</span> : null}
      <label htmlFor={`${id}-minimum`}>Potência mínima calculada</label>
      <output id={`${id}-minimum`} htmlFor={`${id}-nominal`} aria-live="polite" className="power-preview">
        {preview === null ? "Informe a potência nominal para calcular." : formatPower(preview)}
      </output>
      <small className="field-hint">85% da potência nominal. Valor calculado automaticamente.</small>
    </div>
  );
}
