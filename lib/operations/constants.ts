export const coldRoomCategories = [
  { value: "flv", label: "FLV" },
  { value: "bovinos", label: "Bovinos" },
  { value: "suinos", label: "Suínos" },
  { value: "aves", label: "Aves" },
  { value: "pescados", label: "Pescados" },
  { value: "outros", label: "Outros" },
] as const;

export type ColdRoomCategory = (typeof coldRoomCategories)[number]["value"];

export function isColdRoomCategory(
  value: string,
): value is ColdRoomCategory {
  return coldRoomCategories.some((category) => category.value === value);
}

export const assignableClientRoles = [
  { value: "client_admin", label: "Administrador do cliente" },
  { value: "operator", label: "Operador" },
  { value: "viewer", label: "Visualizador" },
] as const;

export type AssignableClientRole =
  (typeof assignableClientRoles)[number]["value"];

export function isAssignableClientRole(
  value: string,
): value is AssignableClientRole {
  return assignableClientRoles.some((role) => role.value === value);
}

export const statusFilters = [
  { value: "all", label: "Todos" },
  { value: "active", label: "Ativos" },
  { value: "inactive", label: "Inativos" },
] as const;

export type StatusFilter = (typeof statusFilters)[number]["value"];

export function parseStatusFilter(value: string | undefined): StatusFilter {
  return statusFilters.some((status) => status.value === value)
    ? (value as StatusFilter)
    : "all";
}
