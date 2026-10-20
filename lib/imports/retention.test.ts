import { expect, test } from "vitest";
import { retainImportRows } from "./retention";
import type { parseImportWorkbook } from "./parser";
const window = { location_id: "l", today: "2026-10-19", operational_start_date: "2026-07-22", client_start_date: "2026-09-15", activates_at: "2026-10-19T00:00:00Z" };
const parsed = {
  dataKind: "state_events", totalRows: 3, events: [
    { occurred_at: "2026-07-22T02:59:59Z", source_classification: "unknown" },
    { occurred_at: "2026-07-22T03:00:00Z", source_classification: "programmed" },
    { occurred_at: "2026-10-20T02:59:59Z", source_classification: "unknown" },
  ],
} as Extract<Awaited<ReturnType<typeof parseImportWorkbook>>, { dataKind: "state_events" }>;
test("filters by local calendar date and recomputes eligible preview", () => {
  const result = retainImportRows(parsed, window, "America/Fortaleza");
  expect(result.expiredRows).toBe(1);
  expect(result.parsed).toMatchObject({ totalRows: 2, unknownSourceRows: 1, periodStart: "2026-07-22T03:00:00Z", periodEnd: "2026-10-20T02:59:59Z" });
  expect(result.parsed.sample).toHaveLength(2);
});
test("preserves the full file during notice", () => {
  expect(retainImportRows(parsed, { ...window, operational_start_date: null }, "America/Fortaleza")).toEqual({ parsed, expiredRows: 0 });
});
test("rejects entirely expired files", () => {
  expect(() => retainImportRows(parsed, { ...window, operational_start_date: "2026-10-20" }, "America/Fortaleza")).toThrow("Todos os registros");
});
test("uses the unit's midnight across a month boundary in UTC+14", () => {
  const result = retainImportRows({
    ...parsed,
    totalRows: 2,
    events: [
      { ...parsed.events[0], occurred_at: "2026-01-31T09:59:59Z" },
      { ...parsed.events[1], occurred_at: "2026-01-31T10:00:00Z" },
    ],
  }, { ...window, today: "2026-05-01", operational_start_date: "2026-02-01" }, "Pacific/Kiritimati");
  expect(result.expiredRows).toBe(1);
  expect(result.parsed.totalRows).toBe(1);
  expect(result.parsed.periodStart).toBe("2026-01-31T10:00:00Z");
});
