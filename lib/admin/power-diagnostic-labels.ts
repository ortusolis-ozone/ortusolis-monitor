export const operationalLabels: Record<string, string> = {
  within_expected: "Dentro do esperado",
  below_expected: "Abaixo do esperado",
  not_evaluable: "Não avaliável",
  not_configured: "Potência nominal não configurada",
  not_processed: "Avaliação ainda não processada",
};
export const correlationLabels: Record<string, string> = {
  verified: "Início e fim correlacionados",
  missing_power_on: "Leitura de início ausente",
  missing_power_off: "Leitura de fim ausente",
  missing_power_both: "Leituras de início e fim ausentes",
  no_coverage: "Sem cobertura de potência",
  not_processed: "Correlação ainda não processada",
};
export const diagnosticReasons: Record<string, string> = {
  nominal_power_profile_not_configured: "Não existe perfil nominal vigente no início da aplicação.",
  power_on_reading_not_valid: "A leitura correlacionada ao início não atende às validações técnicas.",
  power_on_reading_not_available: "Não há leitura de início disponível para avaliação.",
  reference_power_at_or_above_minimum: "A leitura de início é maior ou igual ao mínimo calculado.",
  reference_power_below_minimum: "A leitura de início é menor que o mínimo calculado.",
  no_power_controller_for_application_period: "Sem controlador de potência vigente para o período da aplicação.",
  application_outside_confirmed_power_coverage: "Aplicação fora da cobertura de potência confirmada.",
  on_and_off_transitions_not_found_within_tolerance: "Sem leituras de início e fim dentro da tolerância.",
  on_transition_not_found_within_tolerance: "Sem leitura de início dentro da tolerância.",
  off_transition_not_found_within_tolerance: "Sem leitura de fim dentro da tolerância.",
  transition_order_is_not_valid: "A sequência temporal das leituras é incompatível.",
  power_transitions_correlated: "As leituras de início e fim foram correlacionadas.",
  not_processed: "A aplicação ainda não possui avaliação persistida.",
};
export const reprocessingReasons: Record<string, string> = {
  migration_backfill: "Avaliação inicial do histórico",
  power_telemetry_reprocess: "Reconstrução da correlação de potência",
  power_profile_inserted: "Perfil nominal criado",
  power_profile_values_changed: "Valores do perfil alterados",
  power_profile_generator_changed: "Gerador do perfil alterado",
  power_profile_valid_from_changed: "Início da vigência alterado",
  power_profile_valid_until_changed: "Fim da vigência alterado",
};
