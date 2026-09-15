import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";

import { requireClientProfile } from "@/lib/auth/profile";
import type { Database } from "@/lib/supabase/database.types";
import { createClient } from "@/lib/supabase/server";

import {
  consolidatePortalStatuses,
  isAttentionStatus,
  isPortalStatus,
} from "./constants";
import type {
  PortalFilters,
  PortalLocationOverview,
  PortalPageData,
  ResolvedPortalFilters,
} from "./types";

type PortalDailyStatusRow = Database["public"]["Functions"]["list_client_application_status"]["Returns"][number];

const PAGE_SIZE = 1000;

function assertData<T>(
  data: T | null,
  error: { message: string } | null,
  context: string,
): T {
  if (error || data === null) {
    throw new Error(`Não foi possível carregar ${context}.`);
  }

  return data;
}

function isoDateToday() {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Fortaleza",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}

function shiftIsoDate(value: string, days: number) {
  const [year, month, day] = value.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

function resolveFilters(
  filters: PortalFilters,
  latestStatusDate: string | null,
): ResolvedPortalFilters {
  let endDate = filters.endDate ?? latestStatusDate ?? isoDateToday();
  let startDate = filters.startDate ?? shiftIsoDate(endDate, -29);
  let dateRangeWasAdjusted = false;

  if (startDate > endDate) {
    [startDate, endDate] = [endDate, startDate];
    dateRangeWasAdjusted = true;
  }

  return {
    startDate,
    endDate,
    ...(filters.locationId ? { locationId: filters.locationId } : {}),
    ...(filters.coldRoomId ? { coldRoomId: filters.coldRoomId } : {}),
    ...(filters.generatorId ? { generatorId: filters.generatorId } : {}),
    dateRangeWasAdjusted,
  };
}

async function getDailyStatusRows(
  supabase: SupabaseClient<Database>,
  filters: ResolvedPortalFilters,
) {
  const rows: PortalDailyStatusRow[] = [];

  for (let offset = 0; ; offset += PAGE_SIZE) {
    const { data, error } = await supabase.rpc("list_client_application_status", {
      p_start_date: filters.startDate,
      p_end_date: filters.endDate,
      p_location_id: filters.locationId,
      p_cold_room_id: filters.coldRoomId,
      p_generator_id: filters.generatorId,
      p_offset: offset,
    });
    const page = assertData(data, error, "o histórico de registros");

    rows.push(...page);

    if (page.length < PAGE_SIZE) {
      return rows;
    }
  }
}

async function getOverviewStatusRows(
  supabase: SupabaseClient<Database>,
  statusDate: string | null,
) {
  if (!statusDate) return [];

  return getDailyStatusRows(supabase, {
    startDate: statusDate,
    endDate: statusDate,
    dateRangeWasAdjusted: false,
  });
}

async function getVerificationStatusRows(
  supabase: SupabaseClient<Database>,
) {
  const rows: PortalDailyStatusRow[] = [];

  for (let offset = 0; ; offset += PAGE_SIZE) {
    const { data, error } = await supabase
      .rpc("list_client_application_status", { p_offset: offset });
    const page = assertData(
      data,
      error,
      "os registros que precisam de verificação",
    );

    rows.push(...page.filter((row) => row.application_status === "verification_required"));

    if (page.length < PAGE_SIZE) {
      return rows;
    }
  }
}

function buildOverview(
  locations: Array<{ id: string; name: string }>,
  coldRooms: Array<{ id: string; location_id: string; name: string }>,
  generators: Array<{ id: string; identifier: string }>,
  statusRows: PortalDailyStatusRow[],
) {
  const generatorNames = new Map(
    generators.map((generator) => [generator.id, generator.identifier]),
  );
  const publishedGeneratorIds = new Set<string>();
  const overviewByLocation = new Map<
    string,
    PortalLocationOverview & {
      coldRoomsById: Map<
        string,
        PortalLocationOverview["coldRooms"][number]
      >;
    }
  >();

  for (const location of locations) {
    overviewByLocation.set(location.id, {
      id: location.id,
      name: location.name,
      status: null,
      coldRooms: [],
      coldRoomsById: new Map(),
    });
  }

  for (const room of coldRooms) {
    const location = overviewByLocation.get(room.location_id);

    if (!location) continue;

    const roomOverview = {
      id: room.id,
      name: room.name,
      status: null,
      generators: [],
    };

    location.coldRooms.push(roomOverview);
    location.coldRoomsById.set(room.id, roomOverview);
  }

  for (const row of statusRows) {
    if (
      !isPortalStatus(row.application_status) ||
      !isAttentionStatus(row.attention_status)
    ) continue;

    const location = overviewByLocation.get(row.location_id);
    const room = location?.coldRoomsById.get(row.cold_room_id);
    const identifier = generatorNames.get(row.generator_id);

    if (!location || !room || !identifier) continue;

    publishedGeneratorIds.add(row.generator_id);
    room.generators.push({
      id: row.generator_id,
      identifier,
      status: row.application_status,
      attentionStatus: row.attention_status,
    });
  }

  const overview = Array.from(overviewByLocation.values())
    .map((locationWithRooms) => {
      const location: PortalLocationOverview = {
        id: locationWithRooms.id,
        name: locationWithRooms.name,
        status: locationWithRooms.status,
        coldRooms: locationWithRooms.coldRooms,
      };

      location.coldRooms.sort((left, right) =>
        left.name.localeCompare(right.name, "pt-BR"),
      );

      for (const room of location.coldRooms) {
        room.generators.sort((left, right) =>
          left.identifier.localeCompare(right.identifier, "pt-BR"),
        );
        room.status = consolidatePortalStatuses(
          room.generators.map((generator) => generator.status),
        );
      }

      location.status = consolidatePortalStatuses(
        location.coldRooms.flatMap((room) =>
          room.status ? [room.status] : [],
        ),
      );

      return location;
    })
    .sort((left, right) => left.name.localeCompare(right.name, "pt-BR"));

  const overallStatus = consolidatePortalStatuses(
    overview.flatMap((location) =>
      location.status ? [location.status] : [],
    ),
  );

  return {
    overview,
    overallStatus,
    generatorsWithoutPublishedContext: generators.filter(
      (generator) => !publishedGeneratorIds.has(generator.id),
    ),
  };
}

export async function getPortalPageData(
  requestedFilters: PortalFilters,
): Promise<PortalPageData> {
  const profile = await requireClientProfile();
  const supabase = await createClient();
  const [
    clientResponse,
    locationsResponse,
    coldRoomsResponse,
    generatorsResponse,
    latestStatusResponse,
  ] = await Promise.all([
    supabase
      .from("clients")
      .select("id, legal_name")
      .eq("id", profile.clientId)
      .maybeSingle(),
    supabase
      .from("locations")
      .select("id, name")
      .eq("client_id", profile.clientId)
      .order("name"),
    supabase
      .from("cold_rooms")
      .select("id, location_id, name")
      .eq("client_id", profile.clientId)
      .order("name"),
    supabase
      .from("generators")
      .select("id, identifier")
      .eq("client_id", profile.clientId)
      .order("identifier"),
    supabase
      .rpc("list_client_application_status")
      .limit(1)
      .maybeSingle(),
  ]);
  const client = assertData(
    clientResponse.data,
    clientResponse.error,
    "a empresa vinculada ao seu acesso",
  );
  const locations = assertData(
    locationsResponse.data,
    locationsResponse.error,
    "as unidades da empresa",
  );
  const coldRooms = assertData(
    coldRoomsResponse.data,
    coldRoomsResponse.error,
    "as câmaras da empresa",
  );
  const generators = assertData(
    generatorsResponse.data,
    generatorsResponse.error,
    "os geradores da empresa",
  );

  if (latestStatusResponse.error) {
    throw new Error("Não foi possível carregar a atualização dos registros.");
  }

  const overviewDate = latestStatusResponse.data?.status_date ?? null;
  const filters = resolveFilters(requestedFilters, overviewDate);
  const [overviewStatusRows, verificationStatusRows, historyStatusRows] =
    await Promise.all([
      getOverviewStatusRows(supabase, overviewDate),
      getVerificationStatusRows(supabase),
      getDailyStatusRows(supabase, filters),
    ]);
  const locationNames = new Map(
    locations.map((location) => [location.id, location.name]),
  );
  const coldRoomNames = new Map(
    coldRooms.map((room) => [room.id, room.name]),
  );
  const generatorNames = new Map(
    generators.map((generator) => [generator.id, generator.identifier]),
  );
  const overviewData = buildOverview(
    locations,
    coldRooms,
    generators,
    overviewStatusRows,
  );
  const verificationGeneratorIds = new Set<string>();
  const verificationItems = verificationStatusRows.flatMap((row) => {
    if (verificationGeneratorIds.has(row.generator_id)) return [];

    verificationGeneratorIds.add(row.generator_id);

    return [
      {
        statusDate: row.status_date,
        locationId: row.location_id,
        locationName:
          locationNames.get(row.location_id) ?? "Unidade indisponível",
        coldRoomId: row.cold_room_id,
        coldRoomName:
          coldRoomNames.get(row.cold_room_id) ?? "Câmara indisponível",
        generatorId: row.generator_id,
        generatorIdentifier:
          generatorNames.get(row.generator_id) ?? "Gerador indisponível",
      },
    ];
  });

  return {
    clientName: client.legal_name,
    updatedThrough: overviewDate,
    overviewDate,
    ...overviewData,
    verificationItems,
    history: historyStatusRows.flatMap((row) => {
      if (
        !isPortalStatus(row.application_status) ||
        !isAttentionStatus(row.attention_status)
      ) return [];

      return [
        {
          statusDate: row.status_date,
          locationId: row.location_id,
          locationName:
            locationNames.get(row.location_id) ?? "Unidade indisponível",
          coldRoomId: row.cold_room_id,
          coldRoomName:
            coldRoomNames.get(row.cold_room_id) ?? "Câmara indisponível",
          generatorId: row.generator_id,
          generatorIdentifier:
            generatorNames.get(row.generator_id) ?? "Gerador indisponível",
          status: row.application_status,
          attentionStatus: row.attention_status,
        },
      ];
    }),
    filters,
    options: {
      locations,
      coldRooms: coldRooms.map((room) => ({
        id: room.id,
        locationId: room.location_id,
        locationName:
          locationNames.get(room.location_id) ?? "Unidade indisponível",
        name: room.name,
      })),
      generators,
    },
    hasPublishedStatus: overviewDate !== null,
  };
}
