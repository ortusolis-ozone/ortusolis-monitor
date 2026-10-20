import { ImportValidationError, type parseImportWorkbook } from "./parser";
import type { RetentionWindow } from "@/lib/retention/queries";
import { IMPORT_PREVIEW_ROWS } from "./constants";

type Parsed = Awaited<ReturnType<typeof parseImportWorkbook>>;

export function retainImportRows(parsed: Parsed, window: RetentionWindow, timeZone: string) {
  if (!window.operational_start_date) return { parsed, expiredRows: 0 };
  const format = new Intl.DateTimeFormat("en-CA", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" });
  const allowed = (row: { occurred_at: string }) => {
    const date = format.format(new Date(row.occurred_at));
    return date >= window.operational_start_date! && date <= window.today;
  };
  const rows = (parsed.dataKind === "state_events" ? parsed.events : parsed.readings).filter(allowed);
  if (!rows.length) throw new ImportValidationError("Todos os registros estão fora do período de retenção de 90 dias.");
  const times = rows.map(row => row.occurred_at).sort();
  const common = { totalRows: rows.length, periodStart: times[0], periodEnd: times[times.length - 1] };
  const expiredRows = parsed.totalRows - rows.length;
  if (parsed.dataKind === "state_events") {
    const events = parsed.events.filter(allowed);
    return { expiredRows, parsed: { ...parsed, ...common, events, sample: events.slice(0, IMPORT_PREVIEW_ROWS), unknownSourceRows: events.filter(row => row.source_classification === "unknown").length } };
  }
  const readings = parsed.readings.filter(allowed);
  return { expiredRows, parsed: { ...parsed, ...common, readings, sample: readings.slice(0, IMPORT_PREVIEW_ROWS),
    rawPeriodStart: readings.reduce((a, b) => a.occurred_at < b.occurred_at ? a : b).occurred_at_raw,
    rawPeriodEnd: readings.reduce((a, b) => a.occurred_at > b.occurred_at ? a : b).occurred_at_raw,
    minPowerW: Math.min(...readings.map(row => row.power_w)), maxPowerW: Math.max(...readings.map(row => row.power_w)),
    onRows: readings.filter(row => row.electrical_state === "on").length,
    offRows: readings.filter(row => row.electrical_state === "off").length,
    hysteresisRows: readings.filter(row => row.electrical_state === "hysteresis").length,
  } };
}
