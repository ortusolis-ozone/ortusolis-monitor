import type { AttentionStatus } from "./constants";

export type PortalFilters = {
  month?: string;
  startDate?: string;
  endDate?: string;
  locationId?: string;
  coldRoomId?: string;
  generatorId?: string;
};

export type ResolvedPortalFilters = {
  month: string;
  startDate: string;
  endDate: string;
  locationId?: string;
  coldRoomId?: string;
  generatorId?: string;
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

export type PortalApplicationItem = {
  statusDate: string;
  startedAt: string | null;
  endedAt: string | null;
  maxMeasuredPowerW: string | null;
  locationId: string;
  locationName: string;
  coldRoomId: string;
  coldRoomName: string;
  generatorId: string;
  generatorIdentifier: string;
  attentionStatus: AttentionStatus;
};

export type PortalCalendarDay = {
  date: string;
  applications: PortalApplicationItem[];
};

export type PortalPageData = {
  clientName: string;
  updatedThrough: string | null;
  applications: PortalCalendarDay[];
  applicationCount: number;
  generatorCount: number;
  attentionCount: number;
  filters: ResolvedPortalFilters;
  options: PortalFilterOptions;
  hasPublishedStatus: boolean;
};
