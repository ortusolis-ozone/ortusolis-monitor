export function formText(data: FormData, field: string) {
  const value = data.get(field);
  return typeof value === "string" ? value.trim() : "";
}

export function isUuid(value: string) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

// Keep decimals as strings all the way to PostgreSQL; Number loses precision.
export function parseNominalPower(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const normalized = value.trim().replace(",", ".");
  if (!/^\d+(\.\d{1,3})?$/.test(normalized) || !/[1-9]/.test(normalized)) {
    return null;
  }
  return normalized;
}

export function isDate(value: string) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value) || value.startsWith("0000")) return false;
  const parsed = new Date(`${value}T00:00:00Z`);
  return Number.isFinite(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value;
}

// An explicit offset is required so server timezone never changes the meaning.
export function isTimestamp(value: string) {
  if (!/^\d{4}-\d{2}-\d{2}T([01]\d|2[0-3]):[0-5]\d(:[0-5]\d(\.\d{1,3})?)?(Z|[+-]([01]\d|2[0-3]):[0-5]\d)$/.test(value)) return false;
  return isDate(value.slice(0, 10)) && Number.isFinite(Date.parse(value));
}
