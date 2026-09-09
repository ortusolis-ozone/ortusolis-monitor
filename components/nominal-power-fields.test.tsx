// @vitest-environment jsdom
import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { act, cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { OperationalForm } from "./operational-form";
import { NominalPowerFields } from "./nominal-power-fields";
import { PowerProfileVersionForm } from "./power-profile-version-form";
import type { OperationalActionState } from "@/lib/operations/action-state";

const versionAction = vi.hoisted(() => vi.fn());
vi.mock("@/lib/operations/power-profiles/actions", () => ({ versionGeneratorPowerProfileAction: versionAction }));
afterEach(cleanup);
beforeEach(() => {
  vi.resetAllMocks();
  HTMLElement.prototype.scrollIntoView = vi.fn();
});

test("empty and invalid power are rejected; the exact preview is read-only and announced", () => {
  render(<OperationalForm action={vi.fn()} submitLabel="Cadastrar"><NominalPowerFields /></OperationalForm>);
  const input = screen.getByLabelText("Potência nominal (W)") as HTMLInputElement;
  expect(input.required).toBe(true);
  expect(input.checkValidity()).toBe(false);
  const output = screen.getByLabelText("Potência mínima calculada");
  expect(output.tagName).toBe("OUTPUT");
  expect(output.getAttribute("aria-live")).toBe("polite");
  for (const invalid of ["0", "-1", "72.0001", "NaN"]) {
    fireEvent.change(input, { target: { value: invalid } });
    fireEvent.blur(input);
    expect(input.checkValidity()).toBe(false);
    expect(input.getAttribute("aria-invalid")).toBe("true");
  }
  fireEvent.change(input, { target: { value: "72,000" } });
  expect(input.checkValidity()).toBe(true);
  expect(output.textContent).toBe("61,2 W");
  fireEvent.change(input, { target: { value: "0.001" } });
  expect(output.textContent).toBe("0,00085 W");
  expect(new FormData(input.form!).has("minimum_acceptable_power_w")).toBe(false);
});

test("shows saving, prevents repeat button submission and resets the preview on success", async () => {
  let complete!: (state: OperationalActionState) => void;
  const action = vi.fn(() => new Promise<OperationalActionState>((resolve) => { complete = resolve; }));
  render(<OperationalForm action={action} submitLabel="Cadastrar"><NominalPowerFields /></OperationalForm>);
  const input = screen.getByLabelText("Potência nominal (W)") as HTMLInputElement;
  fireEvent.change(input, { target: { value: "72" } });
  fireEvent.submit(input.form!);
  await waitFor(() => expect((screen.getByRole("button", { name: "Salvando..." }) as HTMLButtonElement).disabled).toBe(true));
  await act(async () => complete({ status: "success", message: "Cadastrado" }));
  expect(screen.getByText("Cadastrado")).toBeTruthy();
  expect(input.value).toBe("");
  expect(screen.getByLabelText("Potência mínima calculada").textContent).toContain("Informe a potência");
  expect(action).toHaveBeenCalledTimes(1);
});

test("server error retains input, announces the error and focuses the nominal field", async () => {
  const action = vi.fn(async (): Promise<OperationalActionState> => ({
    status: "error", message: "Revise o campo destacado.", fieldErrors: { nominal_power_w: "Potência inválida no servidor." },
  }));
  render(<OperationalForm action={action} submitLabel="Cadastrar"><NominalPowerFields /></OperationalForm>);
  const input = screen.getByLabelText("Potência nominal (W)") as HTMLInputElement;
  fireEvent.change(input, { target: { value: "72" } });
  fireEvent.submit(input.form!);
  await waitFor(() => expect(document.activeElement).toBe(input));
  expect(input.value).toBe("72");
  expect(input.getAttribute("aria-invalid")).toBe("true");
  const alert = screen.getByRole("alert");
  expect(alert.textContent).toBe("Potência inválida no servidor.");
  expect(input.getAttribute("aria-describedby")).toContain(alert.id);
});

test("version form submits explicit Fortaleza offset and the last open profile", async () => {
  versionAction.mockResolvedValue({ status: "success", message: "Nova vigência registrada." });
  render(<PowerProfileVersionForm generatorId="generator" expectedProfileId="profile" />);
  fireEvent.change(screen.getByLabelText("Potência nominal (W)"), { target: { value: "100" } });
  const from = screen.getByLabelText("Início da vigência") as HTMLInputElement;
  fireEvent.change(from, { target: { value: "2026-10-01T10:30" } });
  fireEvent.submit(from.form!);
  await waitFor(() => expect(versionAction).toHaveBeenCalledTimes(1));
  const data = versionAction.mock.calls[0][1] as FormData;
  expect(data.get("valid_from")).toBe("2026-10-01T10:30-03:00");
  expect(data.get("expected_profile_id")).toBe("profile");
  expect(data.get("nominal_power_w")).toBe("100");
});

test("version conflicts identify and focus the visible date field", async () => {
  versionAction.mockResolvedValue({ status: "error", message: "Revise a vigência.", fieldErrors: { valid_from: "Escolha uma data posterior." } });
  render(<PowerProfileVersionForm generatorId="generator" expectedProfileId="profile" />);
  fireEvent.change(screen.getByLabelText("Potência nominal (W)"), { target: { value: "100" } });
  const from = screen.getByLabelText("Início da vigência") as HTMLInputElement;
  fireEvent.change(from, { target: { value: "2026-10-01T10:30" } });
  fireEvent.submit(from.form!);
  await waitFor(() => expect(document.activeElement).toBe(from));
  expect(from.getAttribute("aria-invalid")).toBe("true");
  expect(from.getAttribute("aria-describedby")).toContain(screen.getByRole("alert").id);
});
