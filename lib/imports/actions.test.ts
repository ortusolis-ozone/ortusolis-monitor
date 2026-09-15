import { beforeEach, expect, test, vi } from "vitest";
import type { ImportSessionConfirmationRequest } from "./types";

const mocks = vi.hoisted(() => ({ requireMaster: vi.fn(), createClient: vi.fn(), rpc: vi.fn(), parse: vi.fn(), context: vi.fn(), remove: vi.fn(), revalidate: vi.fn() }));
vi.mock("@/lib/auth/profile", () => ({ requireMaster: mocks.requireMaster }));
vi.mock("@/lib/supabase/server", () => ({ createClient: mocks.createClient }));
vi.mock("next/cache", () => ({ revalidatePath: mocks.revalidate }));
vi.mock("./context", () => ({ validateImportContext: mocks.context }));
vi.mock("./parser", async importOriginal => ({ ...await importOriginal<object>(), parseImportWorkbook: mocks.parse }));
import { confirmImportSession, previewImportSession } from "./actions";
import { NOMINAL_PROFILE_REQUIRED_MESSAGE } from "./operational-summary";

const id = "f5000000-0000-4000-8000-000000000001";
const context = { clientId: id, locationId: id, coldRoomId: id, generatorId: id };
const request: ImportSessionConfirmationRequest = {
  context, coverageWarningAcknowledged: true,
  state: { context: { ...context, controllerId: id }, objectPath: `${id}/${id}.xlsx`, fileName: "state.xlsx", expectedFileSha256: "a".repeat(64) },
  power: { context: { ...context, controllerId: id }, objectPath: `${id}/f5000000-0000-4000-8000-000000000002.xlsx`, fileName: "power.xlsx", expectedFileSha256: "b".repeat(64) },
};
const summary = { within_expected: 1, below_expected: 1, not_evaluable: 1, not_configured: 0, groups: [], profiles: [] };
beforeEach(() => {
  vi.resetAllMocks();
  mocks.requireMaster.mockResolvedValue({ id });
  mocks.context.mockResolvedValue({ timeZone: "America/Fortaleza" });
  mocks.createClient.mockResolvedValue({
    rpc: mocks.rpc,
    storage: { from: () => ({ download: async () => ({ data: new Blob(["xlsx"]), error: null }), remove: mocks.remove }) },
    from: () => ({ select: () => ({ eq: async () => ({ data: [], error: null }) }) }),
  });
  mocks.parse.mockImplementation(async (_buffer, _context, _mappings, kind) => ({
    dataKind: kind, fileSha256: (kind === "state_events" ? "a" : "b").repeat(64),
    periodStart: "2026-08-01T00:00:00Z", periodEnd: "2026-08-02T00:00:00Z",
    events: [{ occurred_at: "2026-08-01T00:00:00Z", operation: "turn_on" }],
    readings: [{ occurred_at: "2026-08-01T00:00:00Z", power_w: 61.2 }],
  }));
  mocks.rpc.mockResolvedValue({ data: summary, error: null });
});
test("preview reparses both uploads and calls only the canonical preview RPC", async () => {
  expect(await previewImportSession(request)).toEqual({ status: "preview", preview: summary });
  expect(mocks.parse).toHaveBeenCalledTimes(2);
  expect(mocks.remove).toHaveBeenCalledTimes(2);
  expect(mocks.rpc).toHaveBeenCalledExactlyOnceWith("preview_import_session", expect.objectContaining({ p_state_events: expect.any(Array), p_power_readings: expect.any(Array) }));
  expect(mocks.revalidate).not.toHaveBeenCalled();
});
test.each([previewImportSession, confirmImportSession])("missing nominal is actionable and never reported as low power", async action => {
  mocks.rpc.mockResolvedValue({ data: null, error: { code: "P1206", message: "internal details" } });
  expect(await action(request)).toEqual({ status: "error", message: NOMINAL_PROFILE_REQUIRED_MESSAGE });
  expect(mocks.rpc).toHaveBeenCalledTimes(1);
});
test.each(["state", "power"] as const)("changed %s file blocks both preview and confirmation", async source => {
  const changed = { ...request, [source]: { ...request[source], expectedFileSha256: "c".repeat(64) } };
  expect((await previewImportSession(changed)).status).toBe("error");
  expect((await confirmImportSession(changed)).status).toBe("error");
  expect(mocks.rpc).not.toHaveBeenCalled();
});
test("authorization occurs before upload access", async () => {
  mocks.requireMaster.mockRejectedValue(new Error("forbidden"));
  await expect(previewImportSession(request)).rejects.toThrow("forbidden");
  expect(mocks.createClient).not.toHaveBeenCalled();
});
test("mismatched hierarchy is rejected before parsing", async () => {
  expect((await previewImportSession({ ...request, context: { ...context, generatorId: "other" } })).status).toBe("error");
  expect(mocks.parse).not.toHaveBeenCalled();
});
test("invalid summary fails closed without leaking RPC details", async () => {
  mocks.rpc.mockResolvedValue({ data: { ...summary, not_configured: 1 }, error: null });
  expect((await previewImportSession(request)).status).toBe("error");
});
test("confirmation returns the actual recomputed summary", async () => {
  const batch = { batch_id: id, already_confirmed: true, total_rows: 2, inserted_rows: 0, duplicate_rows: 2, unknown_source_rows: 0, period_start: "2026-08-01", period_end: "2026-08-02" };
  mocks.rpc.mockResolvedValue({ error: null, data: {
    operational_summary: summary, session_id: id, already_confirmed: true, coverage_status: "full", coverage_warning_acknowledged: false,
    state_period_start: "2026-08-01", state_period_end: "2026-08-02", power_period_start: "2026-08-01", power_period_end: "2026-08-02", intersection_start: "2026-08-01", intersection_end: "2026-08-02", state_batch: batch, power_batch: batch,
  } });
  expect(await confirmImportSession(request)).toMatchObject({ status: "confirmed", confirmation: { alreadyConfirmed: true, operationalSummary: summary } });
  expect(mocks.parse).toHaveBeenCalledTimes(2);
  expect(mocks.rpc.mock.calls[0][0]).toBe("confirm_import_session");
});
test("confirmation failure returns a sanitized atomicity message", async () => {
  vi.spyOn(console, "error").mockImplementation(() => {});
  mocks.rpc.mockResolvedValue({ data: null, error: { code: "23514", message: "internal constraint" } });
  const result = await confirmImportSession(request);
  expect(result).toEqual({ status: "error", message: "Não foi possível confirmar a atualização. Nenhum lote parcial foi mantido." });
  expect(mocks.rpc.mock.calls[1][0]).toBe("record_failed_import_session");
});

test("failure persistence and logs exclude raw database content", async () => {
  const logger = vi.spyOn(console, "error").mockImplementation(() => {});
  mocks.rpc.mockResolvedValueOnce({ data: null, error: { code: "23514", message: "SECRET RAW ROW", details: "PRIVATE READING" } }).mockResolvedValueOnce({ data: null, error: null });
  await confirmImportSession(request);
  expect(mocks.rpc.mock.calls[1][1].p_error_message).toBe("Não foi possível confirmar a sessão de importação.");
  expect(JSON.stringify(logger.mock.calls)).not.toMatch(/SECRET|PRIVATE/);
  expect(logger).toHaveBeenCalledWith("Falha operacional", { operation: "session_processing", code: "23514" });
  logger.mockRestore();
});
