import { describe, expect, test } from "vitest";
import { isDate, isTimestamp, parseNominalPower } from "./validation";

describe("nominal power validation", () => {
  test.each([null, undefined, 72, NaN, Infinity, "", " ", "NaN", "Infinity", "-Infinity", "zero", "0", "0.000", "-1", "72.0000", "1e2", "0x48", "1.000,00", "1,2,3"])("rejects invalid input %s", (input) => {
    expect(parseNominalPower(input)).toBeNull();
  });
  test.each([
    ["72", "72"], [" 72,000 ", "72.000"], ["0.001", "0.001"],
    ["9007199254740993.001", "9007199254740993.001"],
    ["1" + "0".repeat(310), "1" + "0".repeat(310)],
  ])("preserves exact valid decimal %s", (input, expected) => {
    expect(parseNominalPower(input)).toBe(expected);
  });
  test("validates dates without calendar overflow", () => {
    expect(isDate("2026-02-29")).toBe(false);
    expect(isDate("2028-02-29")).toBe(true);
    expect(isTimestamp("2026-02-30T10:00:00Z")).toBe(false);
    expect(isTimestamp("2026-07-01T10:00")).toBe(false);
    expect(isTimestamp("2026-07-01T24:00:00Z")).toBe(false);
    expect(isTimestamp("2026-07-01T10:00:00-03:00")).toBe(true);
  });
});
