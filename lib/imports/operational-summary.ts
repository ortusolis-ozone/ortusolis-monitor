import type { ImportOperationalSummary } from "./types";

export const NOMINAL_PROFILE_REQUIRED_MESSAGE =
  "Complete a potência nominal do gerador para todo o período das aplicações e valide novamente.";

function record(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
function count(value: unknown): value is number {
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 0;
}
export function isOperationalSummary(value: unknown): value is ImportOperationalSummary {
  return record(value) &&
    count(value.within_expected) && count(value.below_expected) &&
    count(value.not_evaluable) && value.not_configured === 0 &&
    Array.isArray(value.groups) && value.groups.every((group: unknown) =>
      record(group) && typeof group.status === "string" &&
      typeof group.reason === "string" && count(group.count)) &&
    Array.isArray(value.profiles) && value.profiles.every((profile: unknown) =>
      record(profile) && typeof profile.id === "string" &&
      typeof profile.valid_from === "string" &&
      (profile.valid_until === null || typeof profile.valid_until === "string") &&
      typeof profile.nominal_power_w === "string" &&
      typeof profile.minimum_acceptable_power_w === "string");
}
