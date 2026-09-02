import "server-only";

import { requireMaster } from "@/lib/auth/profile";
import { createClient } from "@/lib/supabase/server";

import type {
  ImportBatchListItem,
  ImportFormOptions,
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

function controllerRole(value: string): "state" | "power_telemetry" {
  if (value === "state" || value === "power_telemetry") return value;
  throw new Error("O papel de um controlador está inválido.");
}

function importDataKind(value: string): "state_events" | "power_readings" {
  if (value === "state_events" || value === "power_readings") return value;
  throw new Error("O tipo de uma importação está inválido.");
}

export async function getImportPageData(): Promise<{
  profileId: string;
  options: ImportFormOptions;
  recentBatches: ImportBatchListItem[];
}> {
  const profile = await requireMaster();
  const supabase = await createClient();
  const [
    clientsResponse,
    locationsResponse,
    roomsResponse,
    generatorsResponse,
    assignmentsResponse,
    controllersResponse,
    profilesResponse,
    batchesResponse,
  ] = await Promise.all([
    supabase
      .from("clients")
      .select("id, legal_name, is_active")
      .order("legal_name"),
    supabase
      .from("locations")
      .select("id, client_id, name, time_zone, is_active")
      .order("name"),
    supabase
      .from("cold_rooms")
      .select("id, client_id, location_id, name, is_active")
      .order("name"),
    supabase
      .from("generators")
      .select("id, client_id, identifier, is_active")
      .order("identifier"),
    supabase
      .from("generator_assignments")
      .select("generator_id, client_id, location_id, cold_room_id")
      .is("valid_until", null),
    supabase
      .from("controllers")
      .select(
        "id, client_id, generator_id, identifier, role, is_active, activated_at, deactivated_at",
      )
      .order("identifier"),
    supabase
      .from("profiles")
      .select("id, full_name"),
    supabase
      .from("import_batches")
      .select(
        "id, data_kind, file_name, status, created_at, confirmed_at, period_start, period_end, total_rows, inserted_rows, duplicate_rows, unknown_source_rows, error_message, client_id, location_id, cold_room_id, generator_id, controller_id, created_by",
      )
      .order("created_at", { ascending: false })
      .limit(12),
  ]);

  const clients = assertData(
    clientsResponse.data,
    clientsResponse.error,
    "os clientes da importação",
  );
  const locations = assertData(
    locationsResponse.data,
    locationsResponse.error,
    "as unidades da importação",
  );
  const rooms = assertData(
    roomsResponse.data,
    roomsResponse.error,
    "as câmaras da importação",
  );
  const generators = assertData(
    generatorsResponse.data,
    generatorsResponse.error,
    "os geradores da importação",
  );
  const assignments = assertData(
    assignmentsResponse.data,
    assignmentsResponse.error,
    "as alocações atuais da importação",
  );
  const controllers = assertData(
    controllersResponse.data,
    controllersResponse.error,
    "os controladores da importação",
  );
  const profiles = assertData(
    profilesResponse.data,
    profilesResponse.error,
    "os autores das importações",
  );
  const batches = assertData(
    batchesResponse.data,
    batchesResponse.error,
    "o histórico de importações",
  );
  const activeClients = clients.filter((client) => client.is_active);
  const activeClientIds = new Set(activeClients.map((client) => client.id));
  const activeLocations = locations.filter(
    (location) =>
      location.is_active && activeClientIds.has(location.client_id),
  );
  const activeLocationIds = new Set(
    activeLocations.map((location) => location.id),
  );
  const activeRooms = rooms.filter(
    (room) =>
      room.is_active &&
      activeClientIds.has(room.client_id) &&
      activeLocationIds.has(room.location_id),
  );
  const activeRoomIds = new Set(activeRooms.map((room) => room.id));
  const generatorById = new Map(
    generators
      .filter(
        (generator) =>
          generator.is_active && activeClientIds.has(generator.client_id),
      )
      .map((generator) => [generator.id, generator]),
  );
  const generatorOptions = assignments.flatMap((assignment) => {
    const generator = generatorById.get(assignment.generator_id);
    if (!generator || !activeRoomIds.has(assignment.cold_room_id)) {
      return [];
    }

    return [
      {
        id: generator.id,
        clientId: generator.client_id,
        locationId: assignment.location_id,
        coldRoomId: assignment.cold_room_id,
        identifier: generator.identifier,
      },
    ];
  });
  const allowedGeneratorIds = new Set(
    generatorOptions.map((generator) => generator.id),
  );
  const controllerOptions = controllers
    .filter((controller) => allowedGeneratorIds.has(controller.generator_id))
    .map((controller) => ({
      id: controller.id,
      clientId: controller.client_id,
      generatorId: controller.generator_id,
      identifier: controller.identifier,
      role: controllerRole(controller.role),
      isActive: controller.is_active,
      activatedAt: controller.activated_at,
      deactivatedAt: controller.deactivated_at,
    }))
    .sort((left, right) => {
      if (left.isActive !== right.isActive) return left.isActive ? -1 : 1;
      return right.activatedAt.localeCompare(left.activatedAt);
    });
  const clientNames = new Map(
    clients.map((client) => [client.id, client.legal_name]),
  );
  const generatorNames = new Map(
    generators.map((generator) => [generator.id, generator.identifier]),
  );
  const locationNames = new Map(
    locations.map((location) => [location.id, location.name]),
  );
  const roomNames = new Map(rooms.map((room) => [room.id, room.name]));
  const controllerNames = new Map(
    controllers.map((controller) => [controller.id, controller.identifier]),
  );
  const profileNames = new Map(
    profiles.map((storedProfile) => [storedProfile.id, storedProfile.full_name]),
  );

  return {
    profileId: profile.id,
    options: {
      clients: activeClients.map((client) => ({
        id: client.id,
        legalName: client.legal_name,
      })),
      locations: activeLocations.map((location) => ({
        id: location.id,
        clientId: location.client_id,
        name: location.name,
        timeZone: location.time_zone,
      })),
      coldRooms: activeRooms.map((room) => ({
        id: room.id,
        clientId: room.client_id,
        locationId: room.location_id,
        name: room.name,
      })),
      generators: generatorOptions,
      controllers: controllerOptions,
    },
    recentBatches: batches.map((batch) => ({
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
      dataKind: importDataKind(batch.data_kind),
    })),
  };
}
