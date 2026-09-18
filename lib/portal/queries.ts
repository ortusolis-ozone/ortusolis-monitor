import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";

import { requireClientProfile } from "@/lib/auth/profile";
import type { Database } from "@/lib/supabase/database.types";
import { createClient } from "@/lib/supabase/server";

import { isAttentionStatus } from "./constants";
import type {
  PortalApplicationItem,
  PortalCalendarDay,
  PortalFilters,
  PortalPageData,
  ResolvedPortalFilters,
} from "./types";

type PortalApplicationRow =
  Database["public"]["Functions"]["list_client_application_details"]["Returns"][number];
type PortalDailyStatusRow =
  Database["public"]["Functions"]["list_client_application_status"]["Returns"][number];

type ResolvedApplicationRow = {
  client_id: string;
  location_id: string;
  cold_room_id: string;
  generator_id: string;
  status_date: string;
  application_started_at: string | null;
  application_ended_at: string | null;
  max_measured_power_w: string | number | null;
  attention_status: string;
};

const PAGE_SIZE = 1000;
const monthPattern = /^\d{4}-(0[1-9]|1[0-2])$/;

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

function isMissingApplicationDetailsRpc(
  error: { code?: string; message: string } | null,
) {
  return (
    error?.code === "PGRST202" ||
    error?.code === "42883" ||
    /list_client_application_details/i.test(error?.message ?? "")
  );
}

function isoDateToday() {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Fortaleza",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}

function isMonth(value: string | undefined): value is string {
  return Boolean(value && monthPattern.test(value));
}

function monthBounds(month: string) {
  const [year, monthNumber] = month.split("-").map(Number);
  const lastDay = new Date(Date.UTC(year, monthNumber, 0))
    .toISOString()
    .slice(0, 10);

  return { startDate: `${month}-01`, endDate: lastDay };
}

export function resolvePortalFilters(
  filters: PortalFilters,
  latestStatusDate: string | null,
): ResolvedPortalFilters {
  const legacyMonth = filters.endDate?.slice(0, 7);
  const month = isMonth(filters.month)
    ? filters.month
    : isMonth(legacyMonth)
      ? legacyMonth
      : (latestStatusDate ?? isoDateToday()).slice(0, 7);

  return {
    month,
    ...monthBounds(month),
    ...(filters.locationId ? { locationId: filters.locationId } : {}),
    ...(filters.coldRoomId ? { coldRoomId: filters.coldRoomId } : {}),
    ...(filters.generatorId ? { generatorId: filters.generatorId } : {}),
  };
}

async function getApplicationRows(
  supabase: SupabaseClient<Database>,
  filters: ResolvedPortalFilters,
) {
  const rows: ResolvedApplicationRow[] = [];

  for (let offset = 0; ; offset += PAGE_SIZE) {
    const { data, error } = await supabase.rpc("list_client_application_details", {
      p_start_date: filters.startDate,
      p_end_date: filters.endDate,
      p_location_id: filters.locationId,
      p_cold_room_id: filters.coldRoomId,
      p_generator_id: filters.generatorId,
      p_offset: offset,
    });
    if (isMissingApplicationDetailsRpc(error)) {
      return getLegacyApplicationRows(supabase, filters);
    }

    const page = assertData<PortalApplicationRow[]>(
      data,
      error,
      "a agenda de aplicações",
    );

    rows.push(...page);

    if (page.length < PAGE_SIZE) return rows;
  }
}

async function getLegacyApplicationRows(
  supabase: SupabaseClient<Database>,
  filters: ResolvedPortalFilters,
) {
  const rows: ResolvedApplicationRow[] = [];

  for (let offset = 0; ; offset += PAGE_SIZE) {
    const { data, error } = await supabase.rpc("list_client_application_status", {
      p_start_date: filters.startDate,
      p_end_date: filters.endDate,
      p_location_id: filters.locationId,
      p_cold_room_id: filters.coldRoomId,
      p_generator_id: filters.generatorId,
      p_offset: offset,
    });
    const page = assertData<PortalDailyStatusRow[]>(
      data,
      error,
      "a agenda de aplicações",
    );
    const applications = page.flatMap((row) =>
      row.application_status === "registered"
        ? [
            {
              ...row,
              application_started_at: null,
              application_ended_at: null,
              max_measured_power_w: null,
            },
          ]
        : [],
    );

    rows.push(...applications);

    if (page.length < PAGE_SIZE) return rows;
  }
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
    supabase.rpc("list_client_application_status").limit(1).maybeSingle(),
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

  const updatedThrough = latestStatusResponse.data?.status_date ?? null;
  const filters = resolvePortalFilters(requestedFilters, updatedThrough);
  const rows = await getApplicationRows(supabase, filters);
  const locationNames = new Map(
    locations.map((location) => [location.id, location.name]),
  );
  const coldRoomNames = new Map(
    coldRooms.map((room) => [room.id, room.name]),
  );
  const generatorNames = new Map(
    generators.map((generator) => [generator.id, generator.identifier]),
  );
  const applicationsByDate = new Map<string, PortalApplicationItem[]>();

  for (const row of rows) {
    if (!isAttentionStatus(row.attention_status)) continue;

    const application: PortalApplicationItem = {
      statusDate: row.status_date,
      startedAt: row.application_started_at,
      endedAt: row.application_ended_at,
      maxMeasuredPowerW:
        row.max_measured_power_w === null
          ? null
          : String(row.max_measured_power_w),
      locationId: row.location_id,
      locationName:
        locationNames.get(row.location_id) ?? "Unidade indisponível",
      coldRoomId: row.cold_room_id,
      coldRoomName:
        coldRoomNames.get(row.cold_room_id) ?? "Câmara indisponível",
      generatorId: row.generator_id,
      generatorIdentifier:
        generatorNames.get(row.generator_id) ?? "Gerador indisponível",
      attentionStatus: row.attention_status,
    };
    applicationsByDate.set(row.status_date, [
      ...(applicationsByDate.get(row.status_date) ?? []),
      application,
    ]);
  }

  const applications: PortalCalendarDay[] = Array.from(
    applicationsByDate.entries(),
  )
    .map(([date, dayApplications]) => ({
      date,
      applications: dayApplications.sort((left, right) =>
        left.generatorIdentifier.localeCompare(
          right.generatorIdentifier,
          "pt-BR",
        ),
      ),
    }))
    .sort((left, right) => left.date.localeCompare(right.date));
  const allApplications = applications.flatMap((day) => day.applications);

  return {
    clientName: client.legal_name,
    updatedThrough,
    applications,
    applicationCount: allApplications.length,
    generatorCount: new Set(
      allApplications.map((application) => application.generatorId),
    ).size,
    attentionCount: allApplications.filter(
      (application) => application.attentionStatus === "attention",
    ).length,
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
    hasPublishedStatus: updatedThrough !== null,
  };
}
