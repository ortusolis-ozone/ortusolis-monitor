import type { PortalFilters } from "./types";

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const datePattern = /^\d{4}-\d{2}-\d{2}$/;
const monthPattern = /^\d{4}-(0[1-9]|1[0-2])$/;

function firstValue(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}
function isValidIsoDate(value: string | undefined): value is string {
  if (!value || !datePattern.test(value)) return false;

  const [year, month, day] = value.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));

  return date.toISOString().slice(0, 10) === value;
}

export function parseFilters(
  values: Record<string, string | string[] | undefined>,
): PortalFilters {
  const month = firstValue(values.month);
  const from = firstValue(values.from);
  const to = firstValue(values.to);
  const location = firstValue(values.location);
  const room = firstValue(values.room);
  const generator = firstValue(values.generator);

  return {
    ...(month && monthPattern.test(month) ? { month } : {}),
    ...(isValidIsoDate(from) ? { startDate: from } : {}),
    ...(isValidIsoDate(to) ? { endDate: to } : {}),
    ...(location && uuidPattern.test(location) ? { locationId: location } : {}),
    ...(room && uuidPattern.test(room) ? { coldRoomId: room } : {}),
    ...(generator && uuidPattern.test(generator)
      ? { generatorId: generator }
      : {}),
  };
}

