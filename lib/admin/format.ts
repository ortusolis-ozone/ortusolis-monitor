const dateTimeFormatter = new Intl.DateTimeFormat("pt-BR", {
  dateStyle: "short",
  timeStyle: "short",
  timeZone: "America/Fortaleza",
});

const dateFormatter = new Intl.DateTimeFormat("pt-BR", {
  dateStyle: "short",
  timeZone: "UTC",
});

export function formatAdminDateTime(value: string | null) {
  return value ? dateTimeFormatter.format(new Date(value)) : "—";
}

export function formatAdminDate(value: string | null) {
  return value ? dateFormatter.format(new Date(`${value}T12:00:00Z`)) : "—";
}

export function eventOperationLabel(value: string | null) {
  if (value === "turn_on") return "Ligar";
  if (value === "turn_off") return "Desligar";
  return "—";
}
