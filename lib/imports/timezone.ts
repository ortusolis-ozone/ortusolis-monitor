export const TIME_NORMALIZATION_VERSION = 1;
export type TelemetryTimeBasis = "utc" | "location";
export type TimezoneChoice =
  | { mode: "location_default" }
  | { mode: "file_override"; sourceTimezone: string };
export type TemporalSnapshot = {
  locationId: string;
  locationTimeZone: string;
  timeZoneRevision: number;
  telemetryRevision: number;
  telemetryTimeBasis: TelemetryTimeBasis | null;
  sourceTimezone: string;
  origin: "location_default" | "file_override" | "state";
};

export function isPowerTimezone(value: unknown): value is string {
  if (typeof value !== "string" || !(value === "UTC" || /^[A-Za-z_]+\/[A-Za-z0-9_+\-/]+$/.test(value))) return false;
  try { new Intl.DateTimeFormat("en", { timeZone: value }).format(); return true; }
  catch { return false; }
}

export function powerTimezoneOptions(timeZone: string) {
  return [...new Set(["UTC", timeZone, "America/Fortaleza"])].filter(isPowerTimezone);
}

export function resolvePowerTimezone(
  basis: string | null, timeZone: string, choice: TimezoneChoice | undefined,
): { sourceTimezone: string; origin: "location_default" | "file_override" } {
  if (basis !== "utc" && basis !== "location") {
    throw new Error("Configure o horário dos arquivos de telemetria no cadastro do local.");
  }
  if (!choice || (choice.mode !== "location_default" && choice.mode !== "file_override")) {
    throw new Error("Atualize a tela e valide novamente para usar a configuração temporal do local.");
  }
  const sourceTimezone = choice.mode === "location_default"
    ? (basis === "utc" ? "UTC" : timeZone) : choice.sourceTimezone;
  if (!isPowerTimezone(sourceTimezone) || !powerTimezoneOptions(timeZone).includes(sourceTimezone)) {
    throw new Error("Informe um fuso suportado para este arquivo de potência.");
  }
  return { sourceTimezone, origin: choice.mode };
}

export function sameTemporalSnapshot(a: TemporalSnapshot | undefined, b: TemporalSnapshot) {
  return !!a && a.locationId === b.locationId && a.locationTimeZone === b.locationTimeZone &&
    a.timeZoneRevision === b.timeZoneRevision && a.sourceTimezone === b.sourceTimezone && a.origin === b.origin &&
    (b.origin === "state" || (a.telemetryRevision === b.telemetryRevision && a.telemetryTimeBasis === b.telemetryTimeBasis));
}
