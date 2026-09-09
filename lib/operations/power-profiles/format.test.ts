import { expect, test } from "vitest";
import { formatPower, minimumPowerPreview } from "./format";

test.each([
  ["72", "61,2 W"], ["72,000", "61,2 W"], ["0.001", "0,00085 W"],
  ["9007199254740993.001", "7.656.119.366.529.844,05085 W"],
])("calculates 85 percent exactly for %s", (input, expected) => {
  expect(formatPower(minimumPowerPreview(input))).toBe(expected);
});
test("does not preview missing or invalid nominal power", () => {
  expect(minimumPowerPreview("")).toBeNull();
  expect(minimumPowerPreview("0")).toBeNull();
  expect(minimumPowerPreview("NaN")).toBeNull();
});
