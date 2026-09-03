import { describe, expect, test } from "vitest";

import {
  aggregateImportSessionStatus,
  compareImportPeriods,
  missingImportSourceMessage,
} from "./session";

describe("joint import coverage", () => {
  test("accepts full power coverage even when its boundaries are wider", () => {
    expect(
      compareImportPeriods(
        {
          start: "2026-08-27T10:00:00.000Z",
          end: "2026-08-27T11:00:00.000Z",
        },
        {
          start: "2026-08-27T09:55:00.000Z",
          end: "2026-08-27T11:05:00.000Z",
        },
      ),
    ).toEqual({
      status: "full",
      intersectionStart: "2026-08-27T10:00:00.000Z",
      intersectionEnd: "2026-08-27T11:00:00.000Z",
      uncoveredBefore: null,
      uncoveredAfter: null,
    });
  });

  test("reports both uncovered state intervals for partial power coverage", () => {
    expect(
      compareImportPeriods(
        {
          start: "2026-08-27T10:00:00.000Z",
          end: "2026-08-27T11:00:00.000Z",
        },
        {
          start: "2026-08-27T10:10:00.000Z",
          end: "2026-08-27T10:50:00.000Z",
        },
      ),
    ).toEqual({
      status: "partial",
      intersectionStart: "2026-08-27T10:10:00.000Z",
      intersectionEnd: "2026-08-27T10:50:00.000Z",
      uncoveredBefore: {
        start: "2026-08-27T10:00:00.000Z",
        end: "2026-08-27T10:10:00.000Z",
      },
      uncoveredAfter: {
        start: "2026-08-27T10:50:00.000Z",
        end: "2026-08-27T11:00:00.000Z",
      },
    });
  });

  test("blocks periods without any intersection", () => {
    expect(
      compareImportPeriods(
        {
          start: "2026-08-27T10:00:00.000Z",
          end: "2026-08-27T11:00:00.000Z",
        },
        {
          start: "2026-08-27T12:00:00.000Z",
          end: "2026-08-27T13:00:00.000Z",
        },
      ).status,
    ).toBe("no_intersection");
  });
});

describe("joint import UI state", () => {
  test("requires both independently valid sources", () => {
    expect(
      aggregateImportSessionStatus({
        stateStatus: "valid",
        powerStatus: "selected",
      }),
    ).toBe("incomplete");
    expect(missingImportSourceMessage("valid", "selected")).toBe(
      "Falta o arquivo de potência para concluir esta atualização.",
    );
  });

  test("treats an existing batch as ready and surfaces the coverage warning", () => {
    expect(
      aggregateImportSessionStatus({
        stateStatus: "already_imported",
        powerStatus: "valid",
        coverageStatus: "partial",
      }),
    ).toBe("ready_with_warning");
  });

  test("prioritizes progress and terminal states", () => {
    expect(
      aggregateImportSessionStatus({
        stateStatus: "valid",
        powerStatus: "valid",
        confirming: true,
      }),
    ).toBe("confirming");
    expect(
      aggregateImportSessionStatus({
        stateStatus: "confirmed",
        powerStatus: "confirmed",
        confirmed: true,
      }),
    ).toBe("confirmed");
  });
});
