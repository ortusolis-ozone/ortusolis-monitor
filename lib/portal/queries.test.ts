import { beforeEach, expect, test, vi } from "vitest";
const mocks = vi.hoisted(() => ({ profile: vi.fn(), client: vi.fn(), rpc: vi.fn(), from: vi.fn() }));
vi.mock("@/lib/auth/profile", () => ({ requireClientProfile: mocks.profile }));
vi.mock("@/lib/supabase/server", () => ({ createClient: mocks.client }));
import { getPortalPageData } from "./queries";
const row = { client_id: "client", location_id: "location", cold_room_id: "room", generator_id: "generator", status_date: "2026-09-14", application_status: "registered", attention_status: "none" };
function response(data: unknown) {
  const result = { data, error: null };
  return { ...result, select: () => response(data), eq: () => response(data), order: () => response(data), limit: () => response(data), maybeSingle: () => Promise.resolve(result) };
}
beforeEach(() => {
  vi.resetAllMocks();
  mocks.profile.mockResolvedValue({ clientId: "client" });
  mocks.client.mockResolvedValue({ from: mocks.from, rpc: mocks.rpc });
  mocks.from.mockImplementation((table: string) => {
    const data: Record<string, unknown> = { clients: { legal_name: "Empresa" }, locations: [{ id: "location", name: "Unidade" }], cold_rooms: [{ id: "room", location_id: "location", name: "Câmara" }], generators: [{ id: "generator", identifier: "Gerador" }] };
    if (!(table in data)) throw new Error("Unexpected table " + table);
    return response(data[table]);
  });
  mocks.rpc.mockImplementation((_name, args) => args === undefined ? response(row) : response([row]));
});
test.each(["none", "attention"])("maps only sanitized fields for %s", async (attention) => {
  mocks.rpc.mockImplementation((_name, args) => args === undefined ? response(row) : response([{ ...row, attention_status: attention, observed_power_w: "SECRET", power_profile_id: "PRIVATE" }]));
  const data = await getPortalPageData({});
  expect(data.history).toHaveLength(1);
  expect(data.history[0]).toMatchObject({ status: "registered", attentionStatus: attention });
  expect(JSON.stringify(data)).not.toMatch(/SECRET|PRIVATE|observed_power|power_profile|powerEvidence/);
  expect(mocks.from.mock.calls.flat()).not.toContain("client_daily_status");
  expect(data.updatedThrough).toBe("2026-09-14");
});
test("passes filters and paginates using the RPC offset", async () => {
  mocks.rpc.mockImplementation((_name, args) => args === undefined ? response(row) : response(args.p_offset === 0 ? Array.from({ length: 1000 }, () => row) : []));
  await getPortalPageData({ startDate: "2026-09-01", endDate: "2026-09-14", generatorId: "generator" });
  expect(mocks.rpc).toHaveBeenCalledWith("list_client_application_status", expect.objectContaining({ p_start_date: "2026-09-01", p_generator_id: "generator", p_offset: 1000 }));
});
test("requires authorization before accessing data", async () => {
  mocks.profile.mockRejectedValue(new Error("Unauthorized"));
  await expect(getPortalPageData({})).rejects.toThrow("Unauthorized");
  expect(mocks.client).not.toHaveBeenCalled();
});
test("sanitizes RPC errors", async () => {
  mocks.rpc.mockReturnValue({ ...response(null), error: { message: "secret database error" }, limit: () => ({ maybeSingle: () => ({ data: null, error: { message: "secret database error" } }) }) });
  await expect(getPortalPageData({})).rejects.toThrow("Não foi possível carregar a atualização dos registros.");
});
