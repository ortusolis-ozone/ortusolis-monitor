import { beforeEach, expect, test, vi } from "vitest";
const mocks = vi.hoisted(() => ({ query: vi.fn(), pdf: vi.fn() }));
vi.mock("@/lib/portal/queries", () => ({ getPortalPageData: mocks.query }));
vi.mock("@/lib/portal/pdf", () => ({ createHistoryPdf: mocks.pdf }));
import { GET } from "./route";
beforeEach(() => vi.resetAllMocks());
test("passes only validated filters and returns a private attachment", async () => {
  mocks.query.mockResolvedValue({ applicationCount: 1, filters: { month: "2026-10" } });
  mocks.pdf.mockResolvedValue(new Uint8Array([37, 80, 68, 70]));
  const response = await GET(new Request("http://localhost/portal/relatorio?month=2026-10&client=other&generator=invalid"));
  expect(mocks.query).toHaveBeenCalledWith({ month: "2026-10" });
  expect(response.headers.get("Content-Type")).toBe("application/pdf");
  expect(response.headers.get("Cache-Control")).toBe("private, no-store");
  expect(response.headers.get("Content-Disposition")).toContain("attachment");
});
test("does not generate a report for an empty authorized result", async () => {
  mocks.query.mockResolvedValue({ applicationCount: 0 });
  expect((await GET(new Request("http://localhost/portal/relatorio"))).status).toBe(404);
  expect(mocks.pdf).not.toHaveBeenCalled();
});
test("authentication failures prevent PDF generation", async () => {
  mocks.query.mockRejectedValue(new Error("unauthorized"));
  await expect(GET(new Request("http://localhost/portal/relatorio"))).rejects.toThrow("unauthorized");
  expect(mocks.pdf).not.toHaveBeenCalled();
});
