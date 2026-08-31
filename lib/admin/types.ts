import type { Database } from "@/lib/supabase/database.types";

import type {
  InconsistencyStatus,
  InconsistencyType,
} from "./constants";

export type AdminInconsistency =
  Database["public"]["Functions"]["list_admin_inconsistencies_v2"]["Returns"][number];

export type SourceValue =
  Database["public"]["Functions"]["list_source_values"]["Returns"][number];

export type InconsistencyFilters = {
  status: InconsistencyStatus;
  type: InconsistencyType;
  clientId?: string;
  locationId?: string;
  generatorId?: string;
  startDate?: string;
  endDate?: string;
};

export type InconsistencyFilterOptions = {
  clients: { id: string; legalName: string }[];
  locations: { id: string; clientId: string; name: string }[];
  generators: { id: string; clientId: string; identifier: string }[];
};

export type AdminOverviewData = {
  activeClients: number;
  activeGenerators: number;
  pendingInconsistencies: number;
  recentImports: import("@/lib/imports/types").ImportBatchListItem[];
};
