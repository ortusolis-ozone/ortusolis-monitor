import {
  assignableClientRoles,
  coldRoomCategories,
} from "./constants";

const dateFormatter = new Intl.DateTimeFormat("pt-BR", {
  dateStyle: "short",
  timeZone: "America/Fortaleza",
});

export function formatOperationalDate(value: string | null) {
  return value ? dateFormatter.format(new Date(value)) : "Em aberto";
}

export function categoryLabel(value: string) {
  return (
    coldRoomCategories.find((category) => category.value === value)?.label ??
    value
  );
}

export function roleLabel(value: string) {
  return assignableClientRoles.find((role) => role.value === value)?.label ?? value;
}
