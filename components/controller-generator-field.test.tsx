// @vitest-environment jsdom
import { afterEach, expect, test, vi } from "vitest";
import { act, cleanup, fireEvent, render, screen, within } from "@testing-library/react";
import { ControllerGeneratorField } from "./controller-generator-field";
import ControllersPage from "@/app/(admin)/admin/controladores/page";

vi.mock("@/lib/operations/actions", () => ({
  createControllerAction: vi.fn(), deactivateControllerAction: vi.fn(),
  editControllerAction: vi.fn(), reactivateControllerAction: vi.fn(), replaceControllerAction: vi.fn(),
}));
vi.mock("@/lib/operations/queries", () => ({
  getControllers: vi.fn(async () => [
    { id: "controller-power", generator_id: "generator-a", generatorName: "Gerador A", identifier: "Medidor A", role: "power_telemetry", is_active: false, activated_at: "2026-01-01T03:00:00Z", deactivated_at: null },
    { id: "controller-state", generator_id: "generator-b", generatorName: "Gerador B", identifier: "Estado B", role: "state", is_active: false, activated_at: "2026-01-01T03:00:00Z", deactivated_at: null },
  ]),
  getOperationalFormOptions: vi.fn(async () => ({
    clients: [{ id: "client", legal_name: "Cliente" }],
    generators: [{ id: "generator-a", client_id: "client", identifier: "Gerador A" }],
    controllers: [],
  })),
}));

afterEach(cleanup);

test("registration links to the selected generator and preserves the controller form in its tab", () => {
  render(<form><ControllerGeneratorField generators={[
    { id: "generator-a", label: "Gerador A" }, { id: "generator-b", label: "Gerador B" },
  ]} /></form>);
  expect(screen.queryByRole("link")).toBeNull();
  const select = screen.getByLabelText("Gerador") as HTMLSelectElement;
  fireEvent.change(select, { target: { value: "generator-a" } });
  expect(screen.getByRole("link").getAttribute("href")).toBe("/admin/geradores/generator-a#edit-power-title");
  expect(screen.getByRole("link").getAttribute("target")).toBe("_blank");
  fireEvent.change(select, { target: { value: "generator-b" } });
  expect(screen.getByRole("link").getAttribute("href")).toBe("/admin/geradores/generator-b#edit-power-title");
  expect(new FormData(select.form!).get("generator_id")).toBe("generator-b");
  fireEvent.change(select, { target: { value: "" } });
  expect(screen.queryByRole("link")).toBeNull();
  fireEvent.change(select, { target: { value: "generator-a" } });
  act(() => select.form!.reset());
  expect(select.value).toBe("");
  expect(screen.queryByRole("link")).toBeNull();
});

test("power controllers expose nominal configuration in the listing and edit panel using the generator ID", async () => {
  render(await ControllersPage({ searchParams: Promise.resolve({}) }));
  const row = screen.getByText("Medidor A").closest("tr")!;
  expect(within(row).getByRole("link", { name: "Configurar potência nominal do gerador" }).getAttribute("href"))
    .toBe("/admin/geradores/generator-a#edit-power-title");
  const edit = within(row).getByText("Editar").closest("details")!;
  edit.open = true;
  expect(within(edit).getByRole("link", { name: "Cadastrar ou editar potência nominal" }).getAttribute("href"))
    .toBe("/admin/geradores/generator-a#edit-power-title");
  expect(within(edit).getByText(/preservando o histórico/)).toBeTruthy();
  expect(within(edit).getByLabelText("Limite ligado (W)")).toBeTruthy();
  expect(within(edit).queryByLabelText("Potência nominal (W)")).toBeNull();
  const stateRow = screen.getByText("Estado B").closest("tr")!;
  expect(within(stateRow).queryByText("Cadastrar ou editar potência nominal")).toBeNull();
});
