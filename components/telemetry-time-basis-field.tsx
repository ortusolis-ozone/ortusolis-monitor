import { FieldError } from "@/components/operational-form";

export function TelemetryTimeBasisField({ value, required = true }: { value?: string | null; required?: boolean }) {
  return <label>
    Horário dos arquivos de telemetria
    <select key={value ?? ""} aria-label="Horário dos arquivos de telemetria" name="telemetry_time_basis" defaultValue={value ?? ""} required={required}>
      <option value="">{required ? "Selecione" : "Não configurado"}</option>
      <option value="utc">UTC</option>
      <option value="location">Horário da unidade</option>
    </select>
    <small>Use UTC quando o arquivo trouxer horários universais. Use Horário da unidade quando já trouxer horários locais. Nesse modo, mudar o fuso da unidade afeta as próximas importações.</small>
    <FieldError name="telemetry_time_basis" />
  </label>;
}
