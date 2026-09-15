import { afterEach, expect, test, vi } from "vitest";
import { logOperationalFailure } from "./log-failure";
afterEach(() => vi.restoreAllMocks());
test("logs a SQLSTATE without the rejected row, file, note or stack", () => {
  const logger = vi.spyOn(console, "error").mockImplementation(() => {});
  logOperationalFailure("power_profile_version", { code: "23P01", message: "SECRET file.xlsx", details: "PRIVATE 61.199", hint: "raw row", stack: "token" });
  expect(logger).toHaveBeenCalledExactlyOnceWith("Falha operacional", { operation: "power_profile_version", code: "23P01" });
});
test.each([new Error("raw file content"), { code: "filename.xlsx" }, null, "secret", { code: 12345 }])("does not serialize unexpected error values", error => {
  const logger = vi.spyOn(console, "error").mockImplementation(() => {});
  logOperationalFailure("session_processing", error);
  expect(logger).toHaveBeenCalledExactlyOnceWith("Falha operacional", { operation: "session_processing", code: "unexpected" });
});
