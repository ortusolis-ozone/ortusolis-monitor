import { existsSync } from "node:fs";
import { readFile } from "node:fs/promises";

import { describe, expect, test, vi } from "vitest";

vi.mock("server-only", () => ({}));

import {
  ImportValidationError,
  parseImportWorkbook,
  parseLocalDateTimeText,
  parsePowerText,
  validateExpectedDataKind,
} from "./parser";
import type { ValidatedImportContext } from "./types";

const referenceWorkbook =
  process.env.SPEC10_POWER_FIXTURE ??
  "/Users/eduardolopes/Downloads/e1a13fe9-ea07-451a-97b8-ce910f9a25b3.xlsx";

const powerContext: ValidatedImportContext = {
  clientId: "11000000-0000-4000-8000-000000000001",
  locationId: "12000000-0000-4000-8000-000000000001",
  coldRoomId: "13000000-0000-4000-8000-000000000001",
  generatorId: "14000000-0000-4000-8000-000000000001",
  controllerId: "15000000-0000-4000-8000-000000000001",
  timeZone: "America/Fortaleza",
  controllerActivatedAt: "2026-01-01T03:00:00.000Z",
  controllerDeactivatedAt: null,
  controllerRole: "power_telemetry",
  externalDeviceId: "ebd862b9f547471587payu",
  externalDeviceIdNormalized: "ebd862b9f547471587payu",
  powerOnThresholdW: 5,
  powerOffThresholdW: 1,
};

describe("power parser primitives", () => {
  test("directs a workbook selected in the wrong field to the correct source", () => {
    expect(() =>
      validateExpectedDataKind("power_readings", "state_events"),
    ).toThrow(/campo Potência consumida/);
    expect(() =>
      validateExpectedDataKind("state_events", "power_readings"),
    ).toThrow(/campo Horários programados/);
    expect(() =>
      validateExpectedDataKind("state_events", "state_events"),
    ).not.toThrow();
  });

  test("accepts unambiguous dot and comma decimals only in watts", () => {
    expect(parsePowerText("71.80W")?.power).toBe(71.8);
    expect(parsePowerText("71,80 W")?.power).toBe(71.8);
    expect(parsePowerText("0.00W")?.power).toBe(0);
    expect(parsePowerText("1,234.5W")).toBeNull();
    expect(parsePowerText("1000mW")).toBeNull();
    expect(parsePowerText("0.0718kW")).toBeNull();
    expect(parsePowerText("-1W")).toBeNull();
  });

  test("preserves milliseconds while applying the unit time zone", () => {
    expect(
      parseLocalDateTimeText(
        "2026-08-27 07:00:32:813",
        "America/Fortaleza",
      ),
    ).toBe("2026-08-27T10:00:32.813Z");
    expect(
      parseLocalDateTimeText("27/08/2026 07:30:08.064", "America/Fortaleza"),
    ).toBe("2026-08-27T10:30:08.064Z");
    expect(
      parseLocalDateTimeText("2026-02-30 07:00:00", "America/Fortaleza"),
    ).toBeNull();
  });
});

describe("reference power workbook", () => {
  test.skipIf(!existsSync(referenceWorkbook))(
    "detects the real descending eWeLink export and preserves its readings",
    async () => {
      const parsed = await parseImportWorkbook(
        await readFile(referenceWorkbook),
        powerContext,
        [],
      );

      expect(parsed.dataKind).toBe("power_readings");
      if (parsed.dataKind !== "power_readings") return;

      expect(parsed.sheetName).toBe("device_logs");
      expect(parsed.totalRows).toBe(57);
      expect(parsed.deviceName).toBe("Charbon 2");
      expect(parsed.deviceId).toBe("ebd862b9f547471587payu");
      expect(parsed.minPowerW).toBe(0);
      expect(parsed.maxPowerW).toBe(75.3);
      expect(parsed.onRows).toBe(27);
      expect(parsed.offRows).toBe(30);
      expect(parsed.hysteresisRows).toBe(0);
      expect(parsed.readings[0].occurred_at).toMatch(/\.\d{3}Z$/);
      expect(parsed.periodStart < parsed.periodEnd).toBe(true);
      expect(new Set(parsed.readings.map((row) => row.fingerprint)).size).toBe(
        parsed.totalRows,
      );
    },
  );

  test.skipIf(!existsSync(referenceWorkbook))(
    "rejects an incompatible controller role or Device ID",
    async () => {
      const buffer = await readFile(referenceWorkbook);

      await expect(
        parseImportWorkbook(
          buffer,
          { ...powerContext, controllerRole: "state" },
          [],
        ),
      ).rejects.toThrow(ImportValidationError);

      await expect(
        parseImportWorkbook(
          buffer,
          {
            ...powerContext,
            externalDeviceId: "outro-device",
            externalDeviceIdNormalized: "outro-device",
          },
          [],
        ),
      ).rejects.toThrow(/Device ID/);
    },
  );
});
