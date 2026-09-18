import "server-only";

import { requireMaster } from "@/lib/auth/profile";
import { isAttentionStatus } from "@/lib/portal/constants";
import { resolvePortalFilters } from "@/lib/portal/queries";
import type { PortalApplicationItem, PortalCalendarDay, PortalFilters, PortalPageData } from "@/lib/portal/types";
import type { Database } from "@/lib/supabase/database.types";
import { createClient } from "@/lib/supabase/server";

type Row = Database["public"]["Functions"]["list_admin_client_application_details"]["Returns"][number];

function assertData<T>(data: T | null, error: { message: string } | null, context: string): T {
  if (error || data === null) throw new Error(`Não foi possível carregar ${context}.`);
  return data;
}

export async function getAdminClientApplicationCalendar(clientId: string, requestedFilters: PortalFilters): Promise<PortalPageData> {
  await requireMaster();
  const supabase = await createClient();
  const [clientResponse, locationsResponse, roomsResponse, generatorsResponse, latestResponse] = await Promise.all([
    supabase.from("clients").select("id, legal_name").eq("id", clientId).maybeSingle(),
    supabase.from("locations").select("id, name").eq("client_id", clientId).order("name"),
    supabase.from("cold_rooms").select("id, location_id, name").eq("client_id", clientId).order("name"),
    supabase.from("generators").select("id, identifier").eq("client_id", clientId).order("identifier"),
    supabase.from("client_daily_status").select("status_date").eq("client_id", clientId).order("status_date", { ascending: false }).limit(1).maybeSingle(),
  ]);
  const client = assertData(clientResponse.data, clientResponse.error, "o cliente");
  const locations = assertData(locationsResponse.data, locationsResponse.error, "as unidades do cliente");
  const coldRooms = assertData(roomsResponse.data, roomsResponse.error, "as câmaras do cliente");
  const generators = assertData(generatorsResponse.data, generatorsResponse.error, "os geradores do cliente");
  if (latestResponse.error) throw new Error("Não foi possível carregar a atualização dos registros.");
  const updatedThrough = latestResponse.data?.status_date ?? null;
  const filters = resolvePortalFilters(requestedFilters, updatedThrough);
  const rows: Row[] = [];
  for (let offset = 0; ; offset += 1000) {
    const { data, error } = await supabase.rpc("list_admin_client_application_details", {
      p_client_id: clientId, p_start_date: filters.startDate, p_end_date: filters.endDate,
      p_location_id: filters.locationId, p_cold_room_id: filters.coldRoomId,
      p_generator_id: filters.generatorId, p_offset: offset,
    });
    const batch = assertData(data, error, "a agenda de aplicações");
    rows.push(...batch);
    if (batch.length < 1000) break;
  }
  const locationNames = new Map(locations.map((item) => [item.id, item.name]));
  const roomNames = new Map(coldRooms.map((item) => [item.id, item.name]));
  const generatorNames = new Map(generators.map((item) => [item.id, item.identifier]));
  const byDate = new Map<string, PortalApplicationItem[]>();
  for (const row of rows) {
    if (!isAttentionStatus(row.attention_status)) continue;
    const item: PortalApplicationItem = {
      statusDate: row.status_date, startedAt: row.application_started_at, endedAt: row.application_ended_at,
      maxMeasuredPowerW: row.max_measured_power_w === null ? null : String(row.max_measured_power_w), locationId: row.location_id,
      locationName: locationNames.get(row.location_id) ?? "Unidade indisponível", coldRoomId: row.cold_room_id,
      coldRoomName: roomNames.get(row.cold_room_id) ?? "Câmara indisponível", generatorId: row.generator_id,
      generatorIdentifier: generatorNames.get(row.generator_id) ?? "Gerador indisponível", attentionStatus: row.attention_status,
    };
    byDate.set(row.status_date, [...(byDate.get(row.status_date) ?? []), item]);
  }
  const applications: PortalCalendarDay[] = Array.from(byDate, ([date, applications]) => ({
    date, applications: applications.sort((a, b) => a.generatorIdentifier.localeCompare(b.generatorIdentifier, "pt-BR")),
  })).sort((a, b) => a.date.localeCompare(b.date));
  const items = applications.flatMap((day) => day.applications);
  return { clientName: client.legal_name, updatedThrough, applications, applicationCount: items.length,
    generatorCount: new Set(items.map((item) => item.generatorId)).size,
    attentionCount: items.filter((item) => item.attentionStatus === "attention").length, filters,
    options: { locations, coldRooms: coldRooms.map((room) => ({ id: room.id, locationId: room.location_id, locationName: locationNames.get(room.location_id) ?? "Unidade indisponível", name: room.name })), generators },
    hasPublishedStatus: updatedThrough !== null };
}
