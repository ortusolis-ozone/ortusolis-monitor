import { beforeEach, describe, expect, test, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  requireMaster: vi.fn(), createClient: vi.fn(), rpc: vi.fn(), revalidatePath: vi.fn(),
}));
vi.mock("@/lib/auth/profile", () => ({ requireMaster: mocks.requireMaster }));
vi.mock("@/lib/supabase/server", () => ({ createClient: mocks.createClient }));
vi.mock("next/cache", () => ({ revalidatePath: mocks.revalidatePath }));

import { createGeneratorWithPowerProfileAction, versionGeneratorPowerProfileAction } from "./actions";
import { getGeneratorPowerConfigurations, getGeneratorPowerHistory } from "./queries";
import { initialOperationalActionState as initial } from "../action-state";
import { createCompleteClientStructureAction, createGeneratorAction } from "../actions";

const id = "f5000000-0000-4000-8000-000000000001";
const profileId = "f7000000-0000-4000-8000-000000000001";
function form(values: Record<string, string> = {}) {
  const data = new FormData();
  Object.entries({
    cold_room_id: id, generator_id: id, identifier: "Gerador", valid_from: "2026-07-01",
    nominal_power_w: "72,000", state_controller_identifier: "Estado",
    power_controller_identifier: "Potência", power_controller_device_id: "device",
    power_on_threshold_w: "5", power_off_threshold_w: "1", correlation_tolerance_seconds: "120",
    ...values,
  }).forEach(([key, value]) => data.set(key, value));
  return data;
}
beforeEach(() => {
  vi.resetAllMocks();
  mocks.requireMaster.mockResolvedValue({ id: "session-author", role: "master" });
  mocks.createClient.mockResolvedValue({ rpc: mocks.rpc });
  mocks.rpc.mockResolvedValue({ data: id, error: null });
});

describe("nominal power server contracts", () => {
  test("the old server action now also requires nominal power", async () => {
    const result = await createGeneratorAction(initial, form({ nominal_power_w: "" }));
    expect(result.fieldErrors?.nominal_power_w).toBeTruthy();
    expect(mocks.rpc).not.toHaveBeenCalled();
  });
  test("the complete structure rejects a missing nominal before creating a client", async () => {
    const result = await createCompleteClientStructureAction(initial, form({ nominal_power_w: "" }));
    expect(result.fieldErrors?.nominal_power_w).toBeTruthy();
    expect(mocks.rpc).not.toHaveBeenCalled();
  });
  test("the complete structure uses the atomic nominal contract", async () => {
    mocks.rpc.mockResolvedValue({ data: { client_id: id }, error: null });
    await expect(createCompleteClientStructureAction(initial, form({
      client_legal_name: "Cliente", client_cnpj: "04252011000110",
      location_name: "Unidade", location_time_zone: "America/Fortaleza",
      cold_room_name: "Câmara", cold_room_category: "flv",
      generator_identifier: "Gerador", generator_valid_from: "2026-07-01",
      state_controller_activated_on: "2026-07-01", power_controller_activated_on: "2026-07-01",
    }))).rejects.toThrow("NEXT_REDIRECT");
    expect(mocks.rpc).toHaveBeenCalledWith("register_complete_client_structure_with_power_profile", expect.objectContaining({ p_nominal_power_w: "72.000" }));
    expect(mocks.rpc.mock.calls[0][1]).not.toHaveProperty("p_minimum_acceptable_power_w");
  });
  test("registers once and discards browser-supplied author, minimum and hierarchy", async () => {
    const result = await createGeneratorWithPowerProfileAction(initial, form({
      nominal_power_w: "9007199254740993.001", created_by: "spoofed", minimum_acceptable_power_w: "1",
      client_id: "spoofed", location_id: "spoofed", reduction_limit_percent: "0",
    }));
    expect(result.status).toBe("success");
    expect(mocks.rpc).toHaveBeenCalledExactlyOnceWith("register_generator_with_power_profile", {
      p_cold_room_id: id, p_identifier: "Gerador", p_valid_from: "2026-07-01",
      p_nominal_power_w: "9007199254740993.001", p_state_controller_identifier: "Estado",
      p_power_controller_identifier: "Potência", p_power_controller_device_id: "device",
      p_power_on_threshold_w: 5, p_power_off_threshold_w: 1, p_correlation_tolerance_seconds: 120,
    });
    expect(mocks.revalidatePath).toHaveBeenCalledWith("/admin", "layout");
  });
  test.each(["", "NaN", "Infinity", "0", "-1", "72.0001"])("blocks invalid nominal %s before calling RPC", async (value) => {
    const result = await createGeneratorWithPowerProfileAction(initial, form({ nominal_power_w: value }));
    expect(result.fieldErrors?.nominal_power_w).toBeTruthy();
    expect(mocks.rpc).not.toHaveBeenCalled();
  });
  test.each([
    ["cold_room_id", "invalid"], ["valid_from", "2026-02-30"], ["identifier", ""],
    ["state_controller_identifier", ""], ["power_controller_identifier", ""], ["power_controller_device_id", ""],
    ["power_on_threshold_w", "0"], ["correlation_tolerance_seconds", "1.2"],
  ])("validates registration field %s", async (field, value) => {
    expect((await createGeneratorWithPowerProfileAction(initial, form({ [field]: value }))).fieldErrors?.[field]).toBeTruthy();
    expect(mocks.rpc).not.toHaveBeenCalled();
  });
  test("versions with the expected profile and explicit timezone", async () => {
    const result = await versionGeneratorPowerProfileAction(initial, form({ valid_from: "2026-07-01T10:00:00-03:00", expected_profile_id: profileId }));
    expect(result.status).toBe("success");
    expect(mocks.rpc).toHaveBeenCalledWith("version_generator_power_profile", {
      p_generator_id: id, p_nominal_power_w: "72.000", p_valid_from: "2026-07-01T10:00:00-03:00", p_expected_profile_id: profileId,
    });
  });
  test("allows an initial legacy profile without inventing an expected ID", async () => {
    await versionGeneratorPowerProfileAction(initial, form({ valid_from: "2026-07-01T10:00:00Z" }));
    expect(mocks.rpc.mock.calls[0][1]).not.toHaveProperty("p_expected_profile_id");
  });
  test.each([
    ["generator_id", "invalid"], ["nominal_power_w", "0.000"],
    ["valid_from", "2026-07-01T10:00"], ["expected_profile_id", "invalid"],
  ])("validates version field %s", async (field, value) => {
    const result = await versionGeneratorPowerProfileAction(initial, form({ valid_from: "2026-07-01T10:00:00Z", [field]: value }));
    expect(result.fieldErrors?.[field]).toBeTruthy();
    expect(mocks.rpc).not.toHaveBeenCalled();
  });
  test.each(["40001", "23P01", "23505", "23514", "42501", "P0002", "XX000"])("sanitizes database error %s", async (code) => {
    mocks.rpc.mockResolvedValue({ data: null, error: { code, message: "secret internal SQL", details: "raw data" } });
    const result = await versionGeneratorPowerProfileAction(initial, form({ valid_from: "2026-07-01T10:00:00Z" }));
    expect(result.status).toBe("error");
    expect(JSON.stringify(result)).not.toMatch(/secret|raw data/);
    expect(mocks.revalidatePath).not.toHaveBeenCalled();
    if (code === "40001") expect(result.message).toContain("Atualize o histórico");
  });
  test("all actions and queries authorize before accessing the database", async () => {
    mocks.requireMaster.mockRejectedValue(new Error("denied"));
    await expect(createGeneratorWithPowerProfileAction(initial, form())).rejects.toThrow("denied");
    await expect(versionGeneratorPowerProfileAction(initial, form())).rejects.toThrow("denied");
    await expect(getGeneratorPowerConfigurations()).rejects.toThrow("denied");
    await expect(getGeneratorPowerHistory(id)).rejects.toThrow("denied");
    expect(mocks.createClient).not.toHaveBeenCalled();
  });
  test("queries pass temporal and pending filters and keep exact decimals", async () => {
    const rows = [{ generator_id: id, nominal_power_w: "9007199254740993.001", valid_until: null }];
    mocks.rpc.mockResolvedValue({ data: rows, error: null });
    expect(await getGeneratorPowerConfigurations({ at: "2026-07-01T00:00:00Z", onlyPending: true, generatorId: id })).toEqual(rows);
    expect(mocks.rpc).toHaveBeenCalledWith("list_admin_generator_power_configuration", {
      p_at: "2026-07-01T00:00:00Z", p_only_pending: true, p_generator_id: id,
    });
    expect(await getGeneratorPowerHistory(id)).toEqual(rows);
    expect(mocks.rpc).toHaveBeenLastCalledWith("list_admin_generator_power_history", { p_generator_id: id });
  });
  test("query failures never return raw database messages", async () => {
    mocks.rpc.mockResolvedValue({ data: null, error: { message: "secret internal SQL" } });
    await expect(getGeneratorPowerConfigurations()).rejects.toThrow("Não foi possível carregar a configuração");
    await expect(getGeneratorPowerHistory(id)).rejects.toThrow("Não foi possível carregar o histórico");
  });
});
