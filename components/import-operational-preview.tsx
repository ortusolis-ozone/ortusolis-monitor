import type { ImportOperationalSummary } from "@/lib/imports/types";
import { formatPower, formatPowerDate } from "@/lib/operations/power-profiles/format";

const reasons: Record<string, string> = {
  no_power_controller_for_application_period: "Sem controlador de potência vigente para a aplicação",
  application_outside_confirmed_power_coverage: "Aplicação fora da cobertura de potência confirmada",
  on_and_off_transitions_not_found_within_tolerance: "Sem leituras de início e fim dentro da tolerância",
  on_transition_not_found_within_tolerance: "Sem leitura de início dentro da tolerância",
  off_transition_not_found_within_tolerance: "Sem leitura de fim dentro da tolerância",
  transition_order_is_not_valid: "Sequência das leituras incompatível",
  reference_power_at_or_above_minimum: "Leitura de início dentro do esperado",
  reference_power_below_minimum: "Leitura de início abaixo do mínimo",
  power_on_reading_not_valid: "Leitura de início inválida",
  power_on_reading_not_available: "Sem leitura de início disponível",
};

export function ImportOperationalPreview({ summary }: { summary: ImportOperationalSummary }) {
  return <section aria-label="Avaliação operacional projetada" aria-live="polite">
    <h3>Avaliação operacional projetada</h3>
    <dl className="source-preview-summary">
      <div><dt>Dentro do esperado</dt><dd>{summary.within_expected}</dd></div>
      <div><dt>Abaixo do esperado</dt><dd>{summary.below_expected}</dd></div>
      <div><dt>Não avaliáveis</dt><dd>{summary.not_evaluable}</dd></div>
    </dl>
    <p>A avaliação usa a leitura correlacionada ao início de cada aplicação. Resultados baixos orientam a verificação do equipamento e da coleta.</p>
    {summary.profiles.map(profile => <p key={profile.id}>
      Vigência: {formatPowerDate(profile.valid_from)} — {formatPowerDate(profile.valid_until)}.
      {" "}Potência nominal: {formatPower(profile.nominal_power_w)}.
      {" "}Mínimo calculado: {formatPower(profile.minimum_acceptable_power_w)}.
    </p>)}
    <ul>{summary.groups.map(group => <li key={`${group.status}:${group.reason}`}>
      {reasons[group.reason] ?? group.reason}: {group.count}
    </li>)}</ul>
    <p>A confirmação revalida os dois arquivos e a configuração vigente no período.</p>
  </section>;
}
