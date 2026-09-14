import { beforeEach, expect, test, vi } from "vitest";
const mocks = vi.hoisted(() => ({ requireMaster: vi.fn(), createClient: vi.fn(), rpc: vi.fn(), revalidate: vi.fn() }));
vi.mock("@/lib/auth/profile", () => ({ requireMaster: mocks.requireMaster }));
vi.mock("@/lib/supabase/server", () => ({ createClient: mocks.createClient }));
vi.mock("next/cache", () => ({ revalidatePath: mocks.revalidate }));
import { getApplicationPowerDiagnostic, getGeneratorApplicationDiagnostics, parseDiagnosticPage } from "./power-diagnostics";
import { reviewInconsistencyAction } from "./actions";
beforeEach(() => {
  vi.resetAllMocks();
  mocks.requireMaster.mockResolvedValue({ role: "master" });
  mocks.createClient.mockResolvedValue({ rpc: mocks.rpc });
  mocks.rpc.mockResolvedValue({ data: [], error: null });
});
test("reads diagnosis, inconsistencies and bounded history from Master RPCs", async () => {
  mocks.rpc.mockImplementation(async (name) => ({ data: name === "list_admin_application_power_diagnostics" ? [{ application_id: 17, nominal_power_w: "9007199254740993.001", observed_power_w: null }] : [], error: null }));
  const result = await getApplicationPowerDiagnostic(17, 2);
  expect(result.diagnostic?.nominal_power_w).toBe("9007199254740993.001");
  expect(result.diagnostic?.observed_power_w).toBeNull();
  expect(mocks.rpc).toHaveBeenCalledWith("list_admin_application_power_runs", { p_application_id: 17, p_offset: 40 });
  expect(mocks.rpc).toHaveBeenCalledWith("list_admin_application_power_inconsistencies", { p_application_id: 17 });
});
test("paginates the generator application list", async () => {
  await getGeneratorApplicationDiagnostics("generator", 1);
  expect(mocks.rpc).toHaveBeenCalledWith("list_admin_application_power_diagnostics", { p_generator_id: "generator", p_offset: 50 });
});
test.each([() => getApplicationPowerDiagnostic(1), () => getGeneratorApplicationDiagnostics("generator")])("rejects unauthorized access before database queries", async query => {
  mocks.requireMaster.mockRejectedValue(new Error("forbidden"));
  await expect(query()).rejects.toThrow("forbidden");
  expect(mocks.createClient).not.toHaveBeenCalled();
});
test("database failures return a sanitized error", async () => {
  mocks.rpc.mockResolvedValue({ data: null, error: { message: "internal database details" } });
  await expect(getApplicationPowerDiagnostic(1)).rejects.toThrow("Não foi possível carregar o diagnóstico da aplicação.");
});
test("absent application is distinguishable from a failed query", async () => {
  expect((await getApplicationPowerDiagnostic(123)).diagnostic).toBeNull();
});
test("recognition sends only the note and inconsistency ID, then refreshes diagnosis", async () => {
  mocks.rpc.mockResolvedValue({ data: true, error: null });
  const form = new FormData();
  form.set("inconsistency_id", "17"); form.set("review_note", "Conferir coleta");
  form.set("operational_status", "within_expected"); form.set("observed_power_w", "72");
  await reviewInconsistencyAction({ status: "idle", message: "" }, form);
  expect(mocks.rpc).toHaveBeenCalledExactlyOnceWith("review_inconsistency", { p_inconsistency_id: 17, p_review_note: "Conferir coleta" });
  expect(mocks.revalidate).toHaveBeenCalledWith("/admin/aplicacoes/[id]", "page");
});
test.each([undefined, "-1", "NaN", "Infinity", "1.5", "1000001"])("rejects invalid page %s", value => expect(parseDiagnosticPage(value)).toBe(0));
