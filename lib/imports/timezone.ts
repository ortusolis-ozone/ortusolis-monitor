export const POWER_TIMEZONES = ["UTC", "America/Fortaleza"] as const;
export type PowerTimezone = (typeof POWER_TIMEZONES)[number];
export const TIME_NORMALIZATION_VERSION = 1;

export function isPowerTimezone(value: unknown): value is PowerTimezone {
  return value === "UTC" || value === "America/Fortaleza";
}
