import { beforeEach, expect, test, vi } from "vitest";

const mocks = vi.hoisted(() => ({ requireMaster: vi.fn(), rpc: vi.fn(), revalidate: vi.fn() }));
vi.mock("@/lib/auth/profile", () => ({ requireMaster: mocks.requireMaster }));
vi.mock("@/lib/supabase/server", () => ({ createClient: async () => ({ rpc: mocks.rpc }) }));
vi.mock("next/cache", () => ({ revalidatePath: mocks.revalidate }));
import { setSourceMappingAction } from "./actions";

beforeEach(() => { vi.clearAllMocks(); mocks.rpc.mockResolvedValue({ data: 1, error: null }); });

function mappingForm(classification: string) {
  const form = new FormData();
  form.set("normalized_source", "ortusolis@ortusolis.com.br");
  form.set("classification", classification);
  return form;
}

test("saves Manual through the authorized RPC and refreshes affected administrative views", async () => {
  const result = await setSourceMappingAction({ status: "idle", message: "" }, mappingForm("manual"));
  expect(mocks.requireMaster).toHaveBeenCalledOnce();
  expect(mocks.rpc).toHaveBeenCalledWith("set_source_mapping", {
    p_normalized_source: "ortusolis@ortusolis.com.br", p_classification: "manual",
  });
  expect(result.status).toBe("success");
  expect(mocks.revalidate).toHaveBeenCalledWith("/admin/mapeamentos");
  expect(mocks.revalidate).toHaveBeenCalledWith("/admin/importacoes");
});

test.each(["test", "unsupported"])("rejects a new %s mapping without silently changing its classification", async classification => {
  const result = await setSourceMappingAction({ status: "idle", message: "" }, mappingForm(classification));
  expect(result.status).toBe("error");
  expect(mocks.rpc).not.toHaveBeenCalled();
});

test("does not mutate a mapping when authorization fails", async () => {
  mocks.requireMaster.mockRejectedValueOnce(new Error("unauthorized"));
  await expect(setSourceMappingAction({ status: "idle", message: "" }, mappingForm("manual"))).rejects.toThrow("unauthorized");
  expect(mocks.rpc).not.toHaveBeenCalled();
});
