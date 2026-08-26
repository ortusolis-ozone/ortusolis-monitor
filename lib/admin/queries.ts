import "server-only";

import { requireMaster } from "@/lib/auth/profile";
import type { ImportBatchListItem } from "@/lib/imports/types";
import { createClient } from "@/lib/supabase/server";

import type {
  AdminOverviewData,
  InconsistencyFilters,
  InconsistencyFilterOptions,
  SourceValue,
} from "./types";

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

function assertCount(
  count: number | null,
  error: { message: string } | null,
  context: string,
) {
  if (error || count === null) {
    throw new Error(`Não foi possível carregar ${context}.`);
  }

  return count;
}

export async function getAdminOverview(): Promise<AdminOverviewData> {
  await requireMaster();
  const supabase = await createClient();
  const [
    clientsCountResponse,
    generatorsCountResponse,
    inconsistenciesCountResponse,
    batchesResponse,
    clientsResponse,
    locationsResponse,
    roomsResponse,
    generatorsResponse,
    controllersResponse,
    profilesResponse,
  ] = await Promise.all([
    supabase
      .from("clients")
      .select("id", { count: "exact", head: true })
      .eq("is_active", true),
    supabase
      .from("generators")
      .select("id", { count: "exact", head: true })
      .eq("is_active", true),
    supabase
      .from("inconsistencies")
      .select("id", { count: "exact", head: true })
      .eq("status", "pending"),
    supabase
      .from("import_batches")
      .select(
        "id, file_name, status, created_at, confirmed_at, period_start, period_end, total_rows, inserted_rows, duplicate_rows, unknown_source_rows, error_message, client_id, location_id, cold_room_id, generator_id, controller_id, created_by",
      )
      .order("created_at", { ascending: false })
      .limit(5),
    supabase.from("clients").select("id, legal_name"),
    supabase.from("locations").select("id, name"),
    supabase.from("cold_rooms").select("id, name"),
    supabase.from("generators").select("id, identifier"),
    supabase.from("controllers").select("id, identifier"),
    supabase.from("profiles").select("id, full_name"),
  ]);

  const batches = assertData(
    batchesResponse.data,
    batchesResponse.error,
    "as importações recentes",
  );
  const clients = assertData(
    clientsResponse.data,
    clientsResponse.error,
    "os nomes dos clientes",
  );
  const locations = assertData(
    locationsResponse.data,
    locationsResponse.error,
    "os nomes das unidades",
  );
  const rooms = assertData(
    roomsResponse.data,
    roomsResponse.error,
    "os nomes das câmaras",
  );
  const generators = assertData(
    generatorsResponse.data,
    generatorsResponse.error,
    "os nomes dos geradores",
  );
  const controllers = assertData(
    controllersResponse.data,
    controllersResponse.error,
    "os nomes dos controladores",
  );
  const profiles = assertData(
    profilesResponse.data,
    profilesResponse.error,
    "os responsáveis pelas importações",
  );
  const clientNames = new Map(
    clients.map((client) => [client.id, client.legal_name]),
  );
  const locationNames = new Map(
    locations.map((location) => [location.id, location.name]),
  );
  const roomNames = new Map(rooms.map((room) => [room.id, room.name]));
  const generatorNames = new Map(
    generators.map((generator) => [generator.id, generator.identifier]),
  );
  const controllerNames = new Map(
    controllers.map((controller) => [controller.id, controller.identifier]),
  );
  const profileNames = new Map(
    profiles.map((profile) => [profile.id, profile.full_name]),
  );
  const recentImports: ImportBatchListItem[] = batches.map((batch) => ({
    id: batch.id,
    fileName: batch.file_name,
    status:
      batch.status === "confirmed" || batch.status === "failed"
        ? batch.status
        : "processing",
    createdAt: batch.created_at,
    confirmedAt: batch.confirmed_at,
    periodStart: batch.period_start,
    periodEnd: batch.period_end,
    totalRows: batch.total_rows,
    insertedRows: batch.inserted_rows,
    duplicateRows: batch.duplicate_rows,
    unknownSourceRows: batch.unknown_source_rows,
    errorMessage: batch.error_message,
    clientName: clientNames.get(batch.client_id) ?? "Cliente indisponível",
    locationName:
      locationNames.get(batch.location_id) ?? "Unidade indisponível",
    coldRoomName: roomNames.get(batch.cold_room_id) ?? "Câmara indisponível",
    generatorName:
      generatorNames.get(batch.generator_id) ?? "Gerador indisponível",
    controllerName:
      controllerNames.get(batch.controller_id) ?? "Controlador indisponível",
    authorName:
      profileNames.get(batch.created_by) ?? "Usuário indisponível",
  }));

  return {
    activeClients: assertCount(
      clientsCountResponse.count,
      clientsCountResponse.error,
      "o total de clientes ativos",
    ),
    activeGenerators: assertCount(
      generatorsCountResponse.count,
      generatorsCountResponse.error,
      "o total de geradores ativos",
    ),
    pendingInconsistencies: assertCount(
      inconsistenciesCountResponse.count,
      inconsistenciesCountResponse.error,
      "o total de inconsistências pendentes",
    ),
    recentImports,
  };
}

export async function getInconsistencyPageData(
  filters: InconsistencyFilters,
) {
  await requireMaster();
  const supabase = await createClient();
  const rpcArguments = {
    p_status: filters.status,
    ...(filters.type !== "all" ? { p_type: filters.type } : {}),
    ...(filters.clientId ? { p_client_id: filters.clientId } : {}),
    ...(filters.locationId ? { p_location_id: filters.locationId } : {}),
    ...(filters.generatorId ? { p_generator_id: filters.generatorId } : {}),
    ...(filters.startDate ? { p_start_date: filters.startDate } : {}),
    ...(filters.endDate ? { p_end_date: filters.endDate } : {}),
  };
  const [
    inconsistenciesResponse,
    clientsResponse,
    locationsResponse,
    generatorsResponse,
  ] = await Promise.all([
    supabase.rpc("list_admin_inconsistencies", rpcArguments),
    supabase.from("clients").select("id, legal_name").order("legal_name"),
    supabase
      .from("locations")
      .select("id, client_id, name")
      .order("name"),
    supabase
      .from("generators")
      .select("id, client_id, identifier")
      .order("identifier"),
  ]);

  const inconsistencies = assertData(
    inconsistenciesResponse.data,
    inconsistenciesResponse.error,
    "as inconsistências",
  );
  const clients = assertData(
    clientsResponse.data,
    clientsResponse.error,
    "os clientes do filtro",
  );
  const locations = assertData(
    locationsResponse.data,
    locationsResponse.error,
    "as unidades do filtro",
  );
  const generators = assertData(
    generatorsResponse.data,
    generatorsResponse.error,
    "os geradores do filtro",
  );
  const options: InconsistencyFilterOptions = {
    clients: clients.map((client) => ({
      id: client.id,
      legalName: client.legal_name,
    })),
    locations: locations.map((location) => ({
      id: location.id,
      clientId: location.client_id,
      name: location.name,
    })),
    generators: generators.map((generator) => ({
      id: generator.id,
      clientId: generator.client_id,
      identifier: generator.identifier,
    })),
  };

  return { inconsistencies, options };
}

export async function getSourceValues(): Promise<SourceValue[]> {
  await requireMaster();
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("list_source_values");

  return assertData(data, error, "os valores de origem importados");
}
