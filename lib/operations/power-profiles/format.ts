import { parseNominalPower } from "./validation";

export function minimumPowerPreview(value: string): string | null {
  const nominal = parseNominalPower(value);
  if (nominal === null) return null;
  const [whole, fraction = ""] = nominal.split(".");
  const units = BigInt(whole + fraction.padEnd(3, "0")) * BigInt(85);
  const digits = units.toString().padStart(6, "0");
  return `${digits.slice(0, -5)}.${digits.slice(-5)}`;
}

export function formatPower(value: string | null) {
  if (value === null) return "Não configurada";
  const [integer, fraction = ""] = value.split(".");
  const decimal = fraction.replace(/0+$/, "");
  const grouped = integer.replace(/\B(?=(\d{3})+(?!\d))/g, ".");
  return `${grouped}${decimal ? `,${decimal}` : ""} W`;
}

export function formatPowerDate(value: string | null) {
  return value ? new Intl.DateTimeFormat("pt-BR", {
    timeZone: "America/Fortaleza", dateStyle: "short", timeStyle: "short",
  }).format(new Date(value)) : "Em aberto";
}
