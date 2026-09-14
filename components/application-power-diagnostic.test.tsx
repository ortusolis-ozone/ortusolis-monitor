// @vitest-environment jsdom
import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, expect, test, vi } from "vitest";
vi.mock("@/lib/admin/actions", () => ({ reviewInconsistencyAction: vi.fn() }));
vi.mock("./operational-form", () => ({ FieldError: () => null, OperationalForm: ({ children, submitLabel }: { children: React.ReactNode; submitLabel: string }) => <form>{children}<button>{submitLabel}</button></form> }));
import { ApplicationPowerDiagnostic } from "./application-power-diagnostic";
import type { PowerDiagnostic, PowerDiagnosticInconsistency } from "@/lib/admin/power-diagnostics";
const diagnostic: PowerDiagnostic = {
  application_id: 1, generator_id: "generator", generator_identifier: "Gerador", client_name: "Cliente", location_name: "Unidade", cold_room_name: "Câmara",
  start_at: "2026-01-01T10:00:00Z", end_at: "2026-01-01T11:00:00Z", correlation_status: "missing_power_off", correlation_reason: "off_transition_not_found_within_tolerance", operational_status: "below_expected", operational_reason: "reference_power_below_minimum",
  nominal_power_w: "72.000", minimum_power_w: "61.20000", observed_power_w: "61.199", difference_w: "10.801", difference_percent: "-15.001", reference_reading_id: 7, reference_reading_at: "2026-01-01T10:00:10Z",
  power_controller_id: "pc", power_controller_identifier: "Medidor", power_batch_id: "pb", power_file_name: "potencia.xlsx", state_controller_id: "sc", state_controller_identifier: "Estado", start_event_id: 2, end_event_id: 3, state_batch_id: "sb", state_file_name: "estado.xlsx", end_batch_id: "sb2", end_file_name: "estado-fim.xlsx", power_profile_id: "profile", profile_valid_from: "2025-01-01T00:00:00Z", profile_valid_until: null, evaluated_at: "2026-01-01T12:00:00Z", rule_version: "nominal-power-v1",
};
afterEach(cleanup);
test("shows orthogonal states, exact snapshots, differences and origin", () => {
  render(<ApplicationPowerDiagnostic diagnostic={diagnostic} inconsistencies={[]} runs={[]} />);
  expect(screen.getByText("Leitura de fim ausente")).toBeTruthy();
  expect(screen.getByText("Abaixo do esperado")).toBeTruthy();
  for (const value of ["72 W", "61,2 W", "61,199 W", "10,801 W", "-15,001%", "potencia.xlsx"]) expect(screen.getByText(value, { exact: false })).toBeTruthy();
  expect(screen.getByText(/leitura de desligamento não entra/)).toBeTruthy();
});
test.each([
  ["within_expected", "Dentro do esperado", "reference_power_at_or_above_minimum"],
  ["not_evaluable", "Não avaliável", "power_on_reading_not_available"],
  ["not_configured", "Potência nominal não configurada", "nominal_power_profile_not_configured"],
])("distinguishes %s and explains missing evaluation", (status, label, reason) => {
  render(<ApplicationPowerDiagnostic diagnostic={{ ...diagnostic, operational_status: status, operational_reason: reason, observed_power_w: null, difference_w: null, difference_percent: null, reference_reading_id: null }} inconsistencies={[]} runs={[]} />);
  expect(screen.getByText(label)).toBeTruthy();
  expect(screen.queryByText("Abaixo do esperado")).toBeNull();
  expect(screen.getByText("Sem leitura de início válida")).toBeTruthy();
  if (status === "not_configured") expect(screen.getByRole("link", { name: /Completar/ })).toBeTruthy();
});
test.each(["reviewed", "resolved"])("preserves low status and historical note when inconsistency is %s", status => {
  const issue: PowerDiagnosticInconsistency = { id: 4, type: "power_below_expected", status, review_note: "Conferência registrada", reviewed_by_name: "Master", reviewed_at: "2026-01-02T00:00:00Z", resolved_at: status === "resolved" ? "2026-01-03T00:00:00Z" : null, created_at: "2026-01-01T12:00:00Z", power_reading_id: 7, power_profile_id: "profile" };
  render(<ApplicationPowerDiagnostic diagnostic={diagnostic} inconsistencies={[issue]} runs={[]} />);
  expect(screen.getByText("Abaixo do esperado")).toBeTruthy();
  expect(screen.getByText(/Nota interna: Conferência registrada/)).toBeTruthy();
  expect(screen.queryByRole("button", { name: "Reconhecer e registrar nota" })).toBeNull();
});
test("identifies run counts as generator aggregates", () => {
  render(<ApplicationPowerDiagnostic diagnostic={diagnostic} inconsistencies={[]} runs={[{ id: 8, affected_from: null, affected_until: null, reason: "power_profile_inserted", rule_version: "nominal-power-v1", processed_at: "2026-01-01T12:00:00Z", within_expected_count: 2, below_expected_count: 1, not_evaluable_count: 3, not_configured_count: 4 }]} />);
  expect(screen.getByText(/não são resultados históricos individuais/)).toBeTruthy();
  expect(screen.getByText(/Perfil nominal criado/)).toBeTruthy();
  expect(screen.getByText(/Não avaliáveis: 3/)).toBeTruthy();
});
