// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, expect, test, vi } from "vitest";

const mocks = vi.hoisted(() => ({ preview: vi.fn(), confirm: vi.fn(), filePreview: vi.fn(), refresh: vi.fn() }));
vi.mock("next/navigation", () => ({ useRouter: () => ({ refresh: mocks.refresh }) }));
vi.mock("@/lib/imports/actions", () => ({ previewImportSession: mocks.preview, confirmImportSession: mocks.confirm, previewXlsxImport: mocks.filePreview }));
vi.mock("@/lib/supabase/client", () => ({ createClient: () => ({ storage: { from: () => ({ upload: async () => ({ error: null }), remove: async () => ({ error: null }) }) } }) }));
import { ImportWorkflow } from "./import-workflow";
import { NOMINAL_PROFILE_REQUIRED_MESSAGE } from "@/lib/imports/operational-summary";

const summary = { within_expected: 1, below_expected: 2, not_evaluable: 3, not_configured: 0,
  profiles: [
    { id: "p1", valid_from: "2026-08-01T00:00:00Z", valid_until: "2026-08-02T00:00:00Z", nominal_power_w: "72.000", minimum_acceptable_power_w: "61.20000" },
    { id: "p2", valid_from: "2026-08-02T00:00:00Z", valid_until: null, nominal_power_w: "100.000", minimum_acceptable_power_w: "85.00000" },
  ], groups: [{ status: "not_evaluable", reason: "on_transition_not_found_within_tolerance", count: 3 }] };
beforeEach(() => {
  vi.resetAllMocks();
  vi.spyOn(window, "confirm").mockReturnValue(true);
  mocks.preview.mockResolvedValue({ status: "preview", preview: summary });
  mocks.filePreview.mockImplementation(async ({ expectedDataKind, sourceTimezone }) => ({ status: "preview", preview: {
    sourceTimezone,
    dataKind: expectedDataKind, fileName: "test.xlsx", fileSha256: "a".repeat(64), timeZone: "America/Fortaleza", totalRows: 2, existingDuplicateRows: 0, repeatedFileRows: 0, unknownSourceRows: 0, periodStart: "2026-08-01T00:00:00Z", periodEnd: "2026-08-03T00:00:00Z", alreadyImported: false, sample: [], minPowerW: 0, maxPowerW: 70, onRows: 1, offRows: 1, hysteresisRows: 0,
  } }));
});
afterEach(cleanup);
async function ready() {
  render(<ImportWorkflow profileId="master" latestSources={[]} options={{
    clients: [{ id: "c", legalName: "Cliente" }], locations: [{ id: "l", clientId: "c", name: "Unidade", timeZone: "America/Fortaleza" }],
    coldRooms: [{ id: "r", clientId: "c", locationId: "l", name: "Câmara" }], generators: [{ id: "g", clientId: "c", locationId: "l", coldRoomId: "r", identifier: "Gerador" }],
    controllers: [ { id: "s", clientId: "c", generatorId: "g", identifier: "Estado", role: "state", isActive: true, activatedAt: "2026-01-01", deactivatedAt: null }, { id: "p", clientId: "c", generatorId: "g", identifier: "Potência", role: "power_telemetry", isActive: true, activatedAt: "2026-01-01", deactivatedAt: null } ],
  }} />);
  for (const [label, value] of [["Cliente", "c"], ["Unidade", "l"], ["Câmara", "r"], ["Gerador", "g"]]) {
    fireEvent.change(screen.getByRole("combobox", { name: label }), { target: { value } });
  }
  for (const source of ["estado", "potência"]) {
    if (source === "potência") fireEvent.change(screen.getByRole("combobox", { name: "Fuso horário do arquivo de potência" }), { target: { value: "UTC" } });
    fireEvent.change(screen.getByLabelText(`Selecionar XLSX de ${source === "estado" ? "horários" : source}`, { exact: false }), { target: { files: [new File(["xlsx"], "test.xlsx")] } });
    fireEvent.click(screen.getByRole("button", { name: `Validar arquivo de ${source}` }));
    await waitFor(() => expect(screen.getByRole("button", { name: `Validar arquivo de ${source}` }).hasAttribute("disabled")).toBe(false));
  }
}
function confirmation() { return screen.getByRole("button", { name: /Confirmar atualização/ }); }
test("changing timezone preserves state preview and file but invalidates power and joint projection", async () => {
  await ready();
  expect(mocks.filePreview.mock.calls[1][0].sourceTimezone).toBe("UTC");
  fireEvent.click(screen.getByRole("button", { name: "Projetar avaliação operacional" }));
  await waitFor(() => expect(confirmation().hasAttribute("disabled")).toBe(false));
  fireEvent.change(screen.getByRole("combobox", { name: "Fuso horário do arquivo de potência" }), {target:{value:"America/Fortaleza"}});
  expect(screen.getByLabelText("Prévia do arquivo de estado")).toBeTruthy();
  expect(screen.queryByLabelText("Prévia do arquivo de potência")).toBeNull();
  expect(confirmation().hasAttribute("disabled")).toBe(true);
  fireEvent.click(screen.getByRole("button", {name:"Validar arquivo de potência"}));
  await waitFor(() => expect(mocks.filePreview).toHaveBeenCalledTimes(3));
  expect(mocks.filePreview.mock.calls[2][0].sourceTimezone).toBe("America/Fortaleza");
});
test("blocks confirmation before projection and guides missing nominal configuration", async () => {
  mocks.preview.mockResolvedValue({ status: "error", message: NOMINAL_PROFILE_REQUIRED_MESSAGE });
  await ready();
  expect(confirmation().hasAttribute("disabled")).toBe(true);
  fireEvent.click(screen.getByRole("button", { name: "Projetar avaliação operacional" }));
  expect(await screen.findByText(NOMINAL_PROFILE_REQUIRED_MESSAGE)).toBeTruthy();
  expect(screen.getByRole("link", { name: /Consultar configuração/ }).getAttribute("href")).toBe("/admin/geradores/g");
  expect(confirmation().hasAttribute("disabled")).toBe(true);
  expect(mocks.confirm).not.toHaveBeenCalled();
});
test("shows multiple profiles and reasons, then invalidates projection when a file changes", async () => {
  await ready();
  fireEvent.click(screen.getByRole("button", { name: "Projetar avaliação operacional" }));
  const projected = await screen.findByRole("region", { name: "Avaliação operacional projetada" });
  expect(projected.textContent).toContain("61,2 W");
  expect(projected.textContent).toContain("85 W");
  expect(projected.textContent).toContain("Sem leitura de início dentro da tolerância: 3");
  await waitFor(() => expect(confirmation().hasAttribute("disabled")).toBe(false));
  fireEvent.change(screen.getByLabelText("Selecionar XLSX de horários", { exact: false }), { target: { files: [new File(["new"], "new.xlsx")] } });
  expect(screen.queryByRole("region", { name: "Avaliação operacional projetada" })).toBeNull();
  expect(confirmation().hasAttribute("disabled")).toBe(true);
});
test("confirmation failure clears the projection and prevents reuse of stale results", async () => {
  mocks.confirm.mockResolvedValue({ status: "error", message: NOMINAL_PROFILE_REQUIRED_MESSAGE });
  await ready();
  fireEvent.click(screen.getByRole("button", { name: "Projetar avaliação operacional" }));
  await waitFor(() => expect(confirmation().hasAttribute("disabled")).toBe(false));
  fireEvent.click(confirmation());
  expect(await screen.findByText(NOMINAL_PROFILE_REQUIRED_MESSAGE)).toBeTruthy();
  expect(confirmation().hasAttribute("disabled")).toBe(true);
  expect(screen.queryByRole("region", { name: "Avaliação operacional projetada" })).toBeNull();
  expect(mocks.refresh).not.toHaveBeenCalled();
});
