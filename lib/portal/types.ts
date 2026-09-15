import type { PortalStatus, AttentionStatus } from "./constants";

export type PortalFilters = {
  startDate?: string;
  endDate?: string;
  locationId?: string;
  coldRoomId?: string;
  generatorId?: string;
};

export type ResolvedPortalFilters = {
  startDate: string;
  endDate: string;
  locationId?: string;
  coldRoomId?: string;
  generatorId?: string;
  dateRangeWasAdjusted: boolean;
};

export type PortalFilterOptions = {
  locations: Array<{ id: string; name: string }>;
  coldRooms: Array<{
    id: string;
    locationId: string;
    locationName: string;
    name: string;
  }>;
  generators: Array<{ id: string; identifier: string }>;
};

export type PortalGeneratorOverview = {
  id: string;
  identifier: string;
  status: PortalStatus;
  attentionStatus: AttentionStatus;
};

export type PortalColdRoomOverview = {
  id: string;
  name: string;
  status: PortalStatus | null;
  generators: PortalGeneratorOverview[];
};

export type PortalLocationOverview = {
  id: string;
  name: string;
  status: PortalStatus | null;
  coldRooms: PortalColdRoomOverview[];
};

export type PortalHistoryItem = {
  statusDate: string;
  locationId: string;
  locationName: string;
  coldRoomId: string;
  coldRoomName: string;
  generatorId: string;
  generatorIdentifier: string;
  status: PortalStatus;
  attentionStatus: AttentionStatus;
};

export type PortalVerificationItem = Omit<
  PortalHistoryItem,
  "status" | "attentionStatus"
>;

export type PortalPageData = {
  clientName: string;
  updatedThrough: string | null;
  overviewDate: string | null;
  overallStatus: PortalStatus | null;
  overview: PortalLocationOverview[];
  generatorsWithoutPublishedContext: Array<{
    id: string;
    identifier: string;
  }>;
  verificationItems: PortalVerificationItem[];
  history: PortalHistoryItem[];
  filters: ResolvedPortalFilters;
  options: PortalFilterOptions;
  hasPublishedStatus: boolean;
};
