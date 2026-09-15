import "server-only";

import { requireMaster } from "@/lib/auth/profile";
import { createClient } from "@/lib/supabase/server";

import type {
  ImportBatchListItem,
  ImportFormOptions,
  ImportSessionBatchSummary,
  ImportSessionListItem,
  LatestImportSource,
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

function sessionStatus(value: string): "confirmed" | "failed" {
  if (value === "confirmed" || value === "failed") return value;
  throw new Error("O estado de uma sessão de importação está inválido.");
}

function coverageStatus(
  value: string,
): "full" | "partial" | "no_intersection" | "unknown" {
  if (
    value === "full" ||
    value === "partial" ||
    value === "no_intersection" ||
    value === "unknown"
  ) {
    return value;
  }
  throw new Error("A cobertura de uma sessão de importação está inválida.");
}

export async function getImportPageData(): Promise<{
  profileId: string;
  options: ImportFormOptions;
  latestSources: LatestImportSource[];
  recentSessions: ImportSessionListItem[];
  legacyBatches: ImportBatchListItem[];
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
    latestSourcesResponse,
    sessionsResponse,
    sessionLinksResponse,
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
      .limit(24),
    supabase
      .from("latest_confirmed_import_batches")
      .select(
        "id, client_id, location_id, cold_room_id, generator_id, controller_id, data_kind, file_name, confirmed_at, period_start, period_end, total_rows, created_by",
      ),
    supabase
      .from("import_sessions")
      .select(
        "id, status, coverage_status, coverage_warning_acknowledged, error_message, created_at, confirmed_at, state_period_start, state_period_end, power_period_start, power_period_end, intersection_start, intersection_end, client_id, location_id, cold_room_id, generator_id, state_controller_id, power_controller_id, state_batch_id, power_batch_id, created_by, failed_state_file_name, failed_power_file_name",
      )
      .order("created_at", { ascending: false })
      .limit(12),
    supabase
      .from("import_sessions")
      .select("state_batch_id, power_batch_id"),
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
  const latestStoredSources = assertData(
    latestSourcesResponse.data,
    latestSourcesResponse.error,
    "as últimas confirmações das fontes",
  );
  const sessions = assertData(
    sessionsResponse.data,
    sessionsResponse.error,
    "as sessões recentes de importação",
  );
  const sessionLinks = assertData(
    sessionLinksResponse.data,
    sessionLinksResponse.error,
    "os vínculos das sessões de importação",
  );

  const recentSessionBatchIds = [
    ...new Set(
      sessions.flatMap((session) =>
        [session.state_batch_id, session.power_batch_id].filter(
          (id): id is string => id !== null,
        ),
      ),
    ),
  ];
  const sessionBatchesResponse =
    recentSessionBatchIds.length > 0
      ? await supabase
          .from("import_batches")
          .select(
            "id, file_name, source_timezone, normalization_version, controller_id, period_start, period_end, total_rows, inserted_rows, duplicate_rows, unknown_source_rows",
          )
          .in("id", recentSessionBatchIds)
      : { data: [], error: null };
  const sessionBatches = assertData(
    sessionBatchesResponse.data,
    sessionBatchesResponse.error,
    "os lotes das sessões recentes",
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
  const sessionBatchById = new Map(
    sessionBatches.map((batch) => [batch.id, batch]),
  );
  const associatedBatchIds = new Set(
    sessionLinks.flatMap((session) =>
      [session.state_batch_id, session.power_batch_id].filter(
        (id): id is string => id !== null,
      ),
    ),
  );

  function sessionBatchSummary(
    batchId: string | null,
  ): ImportSessionBatchSummary | null {
    if (!batchId) return null;
    const batch = sessionBatchById.get(batchId);
    if (!batch) return null;

    return {
      id: batch.id,
      sourceTimezone: batch.source_timezone,
      normalizationVersion: batch.normalization_version,
      fileName: batch.file_name,
      controllerName:
        controllerNames.get(batch.controller_id) ?? "Controlador indisponível",
      periodStart: batch.period_start,
      periodEnd: batch.period_end,
      totalRows: batch.total_rows,
      insertedRows: batch.inserted_rows,
      duplicateRows: batch.duplicate_rows,
      unknownSourceRows: batch.unknown_source_rows,
    };
  }

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
    latestSources: latestStoredSources.flatMap((source) => {
      if (
        !source.id ||
        !source.client_id ||
        !source.location_id ||
        !source.cold_room_id ||
        !source.generator_id ||
        !source.controller_id ||
        !source.data_kind ||
        !source.file_name ||
        !source.confirmed_at ||
        !source.period_start ||
        !source.period_end ||
        source.total_rows === null ||
        !source.created_by
      ) {
        return [];
      }

      return [{
        batchId: source.id,
        clientId: source.client_id,
        locationId: source.location_id,
        coldRoomId: source.cold_room_id,
        generatorId: source.generator_id,
        controllerId: source.controller_id,
        dataKind: importDataKind(source.data_kind),
        fileName: source.file_name,
        confirmedAt: source.confirmed_at,
        periodStart: source.period_start,
        periodEnd: source.period_end,
        totalRows: source.total_rows,
        authorName:
          profileNames.get(source.created_by) ?? "Usuário indisponível",
      }];
    }),
    recentSessions: sessions.map((session) => ({
      id: session.id,
      status: sessionStatus(session.status),
      coverageStatus: coverageStatus(session.coverage_status),
      coverageWarningAcknowledged: session.coverage_warning_acknowledged,
      errorMessage: session.error_message,
      createdAt: session.created_at,
      confirmedAt: session.confirmed_at,
      statePeriodStart: session.state_period_start,
      statePeriodEnd: session.state_period_end,
      powerPeriodStart: session.power_period_start,
      powerPeriodEnd: session.power_period_end,
      intersectionStart: session.intersection_start,
      intersectionEnd: session.intersection_end,
      clientName:
        clientNames.get(session.client_id) ?? "Cliente indisponível",
      locationName:
        locationNames.get(session.location_id) ?? "Unidade indisponível",
      coldRoomName:
        roomNames.get(session.cold_room_id) ?? "Câmara indisponível",
      generatorName:
        generatorNames.get(session.generator_id) ?? "Gerador indisponível",
      stateControllerName:
        controllerNames.get(session.state_controller_id) ??
        "Controlador indisponível",
      powerControllerName:
        controllerNames.get(session.power_controller_id) ??
        "Controlador indisponível",
      authorName:
        profileNames.get(session.created_by) ?? "Usuário indisponível",
      stateBatch: sessionBatchSummary(session.state_batch_id),
      powerBatch: sessionBatchSummary(session.power_batch_id),
      failedStateFileName: session.failed_state_file_name,
      failedPowerFileName: session.failed_power_file_name,
    })),
    legacyBatches: batches
      .filter((batch) => !associatedBatchIds.has(batch.id))
      .map((batch) => ({
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
