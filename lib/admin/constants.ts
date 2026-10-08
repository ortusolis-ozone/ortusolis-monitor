export const inconsistencyStatuses = [
  { value: "pending", label: "Pendente" },
  { value: "reviewed", label: "Revisada" },
  { value: "resolved", label: "Resolvida automaticamente" },
  { value: "all", label: "Todas" },
] as const;

export const inconsistencyTypes = [
  { value: "all", label: "Todos os tipos" },
  { value: "unmatched_turn_on", label: "Ligar sem desligar" },
  { value: "unmatched_turn_off", label: "Desligar sem ligar" },
  { value: "consecutive_turn_on", label: "Ligar consecutivo" },
  { value: "controller_mismatch", label: "Controladores divergentes" },
  { value: "unknown_source", label: "Origem desconhecida" },
  { value: "invalid_sequence", label: "Sequência inválida" },
  { value: "missing_power_on", label: "Potência ligada ausente" },
  { value: "missing_power_off", label: "Potência desligada ausente" },
  { value: "missing_power_both", label: "Potência ligada e desligada ausentes" },
  { value: "power_below_expected", label: "Potência abaixo do esperado" },
  { value: "unexpected_power", label: "Potência ligada sem aplicação" },
] as const;

export const sourceClassifications = [
  { value: "unknown", label: "Desconhecida" },
  { value: "programmed", label: "Programada" },
  { value: "manual", label: "Manual" },
] as const;

export type InconsistencyStatus =
  (typeof inconsistencyStatuses)[number]["value"];
export type InconsistencyType =
  (typeof inconsistencyTypes)[number]["value"];
export type SourceClassification =
  (typeof sourceClassifications)[number]["value"];

export function inconsistencyStatusLabel(value: string) {
  return (
    inconsistencyStatuses.find((option) => option.value === value)?.label ??
    value
  );
}

export function inconsistencyTypeLabel(value: string) {
  return (
    inconsistencyTypes.find((option) => option.value === value)?.label ?? value
  );
}

export function sourceClassificationLabel(value: string) {
  if (value === "test") return "Teste (legado)";
  return (
    sourceClassifications.find((option) => option.value === value)?.label ??
    value
  );
}

const sourceDescriptions = new Map([
  ["cronômetros regressivos", "Acionamento automático pela agenda programada."],
  ["dispositivo-inching", "Desacionamento automático programado."],
  [
    "ortusolis@ortusolis.com.br",
    "Comando manual do usuário Ortusolis, utilizado fora do horário agendado, geralmente para testes.",
  ],
]);

export function sourceDescription(source: string, classification: string) {
  const knownDescription = sourceDescriptions.get(source.trim().toLowerCase());
  if (knownDescription) return knownDescription;
  if (classification === "programmed") {
    return "Origem classificada como programação automática.";
  }
  if (classification === "manual") return "Comando emitido manualmente.";
  if (classification === "test") {
    return "Origem classificada como teste no mapeamento legado.";
  }
  return "Origem sem mapeamento ativo. Requer classificação pelo Master.";
}
