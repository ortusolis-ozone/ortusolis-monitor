// @vitest-environment jsdom
import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, expect, test, vi } from "vitest";
const mocks = vi.hoisted(() => ({ data: vi.fn() }));
vi.mock("@/lib/auth/profile", () => ({ requireClientProfile: async () => ({ fullName: "Cliente" }) }));
vi.mock("@/lib/portal/queries", () => ({ getPortalPageData: mocks.data }));
vi.mock("@/components/app-header", () => ({ AppHeader: () => <header>Portal</header> }));
import PortalPage from "./page";
afterEach(cleanup);
test.each(["none", "attention"])("renders accessible daily state %s without technical evidence", async (attentionStatus) => {
  mocks.data.mockResolvedValue({ clientName: "Empresa", updatedThrough: "2026-09-14", overviewDate: null, overallStatus: null, overview: [], generatorsWithoutPublishedContext: [], verificationItems: [], history: [{ statusDate: "2026-09-14", generatorId: "g", generatorIdentifier: "Gerador", locationName: "Unidade", coldRoomName: "Câmara", status: "registered", attentionStatus }], filters: { startDate: "2026-09-01", endDate: "2026-09-14" }, options: { locations: [], coldRooms: [], generators: [] }, hasPublishedStatus: true });
  const { container } = render(await PortalPage({ searchParams: Promise.resolve({}) }));
  expect(screen.getAllByText("Aplicação registrada").length).toBeGreaterThan(0);
  expect(container.innerHTML).not.toMatch(/Potência confirmada|Evidência de potência|power_evidence|power_profile|observed_power|61,2|72 W/);
  if (attentionStatus === "attention") {
    expect(screen.getAllByRole("status")).toHaveLength(1);
    expect(screen.getByRole("status").textContent).toBe("Aplicação registrada — atenção necessáriaO consumo elétrico registrado ficou abaixo do esperado. A Ortusolis deve verificar o equipamento.");
  } else expect(screen.queryByRole("status")).toBeNull();
});
