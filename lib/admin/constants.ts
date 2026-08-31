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
  { value: "unexpected_power", label: "Potência ligada sem aplicação" },
] as const;

export const sourceClassifications = [
  { value: "unknown", label: "Desconhecida" },
  { value: "programmed", label: "Programada" },
  { value: "test", label: "Teste" },
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
  return (
    sourceClassifications.find((option) => option.value === value)?.label ??
    value
  );
}
