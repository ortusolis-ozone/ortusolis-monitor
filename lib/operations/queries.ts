import "server-only";

import { requireMaster } from "@/lib/auth/profile";
import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";
import type { Tables } from "@/lib/supabase/database.types";

import type { StatusFilter } from "./constants";

type Client = Tables<"clients">;
type Location = Tables<"locations">;
type ColdRoom = Tables<"cold_rooms">;
type Generator = Tables<"generators">;
type Assignment = Tables<"generator_assignments">;
type Controller = Tables<"controllers">;
type Profile = Tables<"profiles">;

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

function matchesStatus(isActive: boolean, status: StatusFilter) {
  return (
    status === "all" ||
    (status === "active" && isActive) ||
    (status === "inactive" && !isActive)
  );
}

async function getMasterClient() {
  await requireMaster();
  return createClient();
}

export async function getClients(options?: {
  query?: string;
  status?: StatusFilter;
}) {
  const supabase = await getMasterClient();
  const response = await supabase
    .from("clients")
    .select("id, legal_name, cnpj, is_active, created_at, updated_at")
    .order("legal_name");
  const clients = assertData(response.data, response.error, "os clientes");
  const query = options?.query?.trim().toLocaleLowerCase("pt-BR") ?? "";
  const digits = query.replace(/\D/g, "");
  const status = options?.status ?? "all";

  return clients.filter((client) => {
    const matchesQuery =
      !query ||
      client.legal_name.toLocaleLowerCase("pt-BR").includes(query) ||
      (digits.length > 0 && client.cnpj.includes(digits));

    return matchesQuery && matchesStatus(client.is_active, status);
  });
}

export async function getLocations(status: StatusFilter = "all") {
  const supabase = await getMasterClient();
  const [locationsResponse, clientsResponse] = await Promise.all([
    supabase.from("locations").select("*").order("name"),
    supabase.from("clients").select("id, legal_name").order("legal_name"),
  ]);
  const locations = assertData(
    locationsResponse.data,
    locationsResponse.error,
    "as unidades",
  );
  const clients = assertData(
    clientsResponse.data,
    clientsResponse.error,
    "os clientes das unidades",
  );
  const clientNames = new Map(
    clients.map((client) => [client.id, client.legal_name]),
  );

  return locations
    .filter((location) => matchesStatus(location.is_active, status))
    .map((location) => ({
      ...location,
      clientName: clientNames.get(location.client_id) ?? "Cliente não encontrado",
    }));
}

export async function getColdRooms(status: StatusFilter = "all") {
  const supabase = await getMasterClient();
  const [roomsResponse, locationsResponse, clientsResponse] = await Promise.all([
    supabase.from("cold_rooms").select("*").order("name"),
    supabase.from("locations").select("id, name").order("name"),
    supabase.from("clients").select("id, legal_name").order("legal_name"),
  ]);
  const rooms = assertData(
    roomsResponse.data,
    roomsResponse.error,
    "as câmaras",
  );
  const locations = assertData(
    locationsResponse.data,
    locationsResponse.error,
    "as unidades das câmaras",
  );
  const clients = assertData(
    clientsResponse.data,
    clientsResponse.error,
    "os clientes das câmaras",
  );
  const locationNames = new Map(
    locations.map((location) => [location.id, location.name]),
  );
  const clientNames = new Map(
    clients.map((client) => [client.id, client.legal_name]),
  );

  return rooms
    .filter((room) => matchesStatus(room.is_active, status))
    .map((room) => ({
      ...room,
      clientName: clientNames.get(room.client_id) ?? "Cliente não encontrado",
      locationName:
        locationNames.get(room.location_id) ?? "Unidade não encontrada",
    }));
}

export type GeneratorListItem = Generator & {
  clientName: string;
  currentAssignment:
    | (Assignment & { coldRoomName: string; locationName: string })
    | null;
  assignmentHistory: Array<
    Assignment & { coldRoomName: string; locationName: string }
  >;
};

export async function getGenerators(
  status: StatusFilter = "all",
): Promise<GeneratorListItem[]> {
  const supabase = await getMasterClient();
  const [
    generatorsResponse,
    assignmentsResponse,
    roomsResponse,
    locationsResponse,
    clientsResponse,
  ] = await Promise.all([
    supabase.from("generators").select("*").order("identifier"),
    supabase
      .from("generator_assignments")
      .select("*")
      .order("valid_from", { ascending: false }),
    supabase.from("cold_rooms").select("id, name"),
    supabase.from("locations").select("id, name"),
    supabase.from("clients").select("id, legal_name"),
  ]);
  const generators = assertData(
    generatorsResponse.data,
    generatorsResponse.error,
    "os geradores",
  );
  const assignments = assertData(
    assignmentsResponse.data,
    assignmentsResponse.error,
    "as alocações",
  );
  const rooms = assertData(
    roomsResponse.data,
    roomsResponse.error,
    "as câmaras dos geradores",
  );
  const locations = assertData(
    locationsResponse.data,
    locationsResponse.error,
    "as unidades dos geradores",
  );
  const clients = assertData(
    clientsResponse.data,
    clientsResponse.error,
    "os clientes dos geradores",
  );
  const roomNames = new Map(rooms.map((room) => [room.id, room.name]));
  const locationNames = new Map(
    locations.map((location) => [location.id, location.name]),
  );
  const clientNames = new Map(
    clients.map((client) => [client.id, client.legal_name]),
  );

  return generators
    .filter((generator) => matchesStatus(generator.is_active, status))
    .map((generator) => {
      const history = assignments
        .filter((assignment) => assignment.generator_id === generator.id)
        .map((assignment) => ({
          ...assignment,
          coldRoomName:
            roomNames.get(assignment.cold_room_id) ?? "Câmara não encontrada",
          locationName:
            locationNames.get(assignment.location_id) ??
            "Unidade não encontrada",
        }));

      return {
        ...generator,
        clientName:
          clientNames.get(generator.client_id) ?? "Cliente não encontrado",
        currentAssignment:
          history.find((assignment) => assignment.valid_until === null) ?? null,
        assignmentHistory: history,
      };
    });
}

export async function getControllers(status: StatusFilter = "all") {
  const supabase = await getMasterClient();
  const [controllersResponse, generatorsResponse, clientsResponse] =
    await Promise.all([
      supabase
        .from("controllers")
        .select("*")
        .order("activated_at", { ascending: false }),
      supabase.from("generators").select("id, identifier"),
      supabase.from("clients").select("id, legal_name"),
    ]);
  const controllers = assertData(
    controllersResponse.data,
    controllersResponse.error,
    "os controladores",
  );
  const generators = assertData(
    generatorsResponse.data,
    generatorsResponse.error,
    "os geradores dos controladores",
  );
  const clients = assertData(
    clientsResponse.data,
    clientsResponse.error,
    "os clientes dos controladores",
  );
  const generatorNames = new Map(
    generators.map((generator) => [generator.id, generator.identifier]),
  );
  const clientNames = new Map(
    clients.map((client) => [client.id, client.legal_name]),
  );

  return controllers
    .filter((controller) => matchesStatus(controller.is_active, status))
    .map((controller) => ({
      ...controller,
      clientName:
        clientNames.get(controller.client_id) ?? "Cliente não encontrado",
      generatorName:
        generatorNames.get(controller.generator_id) ??
        "Gerador não encontrado",
    }));
}

export async function getUsers(status: StatusFilter = "all") {
  const supabase = await getMasterClient();
  const [profilesResponse, clientsResponse] = await Promise.all([
    supabase
      .from("profiles")
      .select("*")
      .not("client_id", "is", null)
      .order("full_name"),
    supabase.from("clients").select("id, legal_name"),
  ]);
  const profiles = assertData(
    profilesResponse.data,
    profilesResponse.error,
    "os usuários",
  );
  const clients = assertData(
    clientsResponse.data,
    clientsResponse.error,
    "os clientes dos usuários",
  );
  const admin = createAdminClient();
  const { data: authData, error: authError } =
    await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });

  if (authError) {
    throw new Error("Não foi possível carregar os e-mails dos usuários.");
  }

  const clientNames = new Map(
    clients.map((client) => [client.id, client.legal_name]),
  );
  const emails = new Map(
    authData.users.map((user) => [user.id, user.email ?? "E-mail indisponível"]),
  );

  return profiles
    .filter((profile) => matchesStatus(profile.is_active, status))
    .map((profile) => ({
      ...profile,
      clientName:
        clientNames.get(profile.client_id ?? "") ?? "Cliente não encontrado",
      email: emails.get(profile.id) ?? "E-mail indisponível",
    }));
}

export type OperationalFormOptions = {
  clients: Client[];
  locations: Location[];
  coldRooms: ColdRoom[];
  generators: Generator[];
  controllers: Controller[];
};

export async function getOperationalFormOptions(): Promise<OperationalFormOptions> {
  const supabase = await getMasterClient();
  const [
    clientsResponse,
    locationsResponse,
    roomsResponse,
    generatorsResponse,
    assignmentsResponse,
    controllersResponse,
  ] = await Promise.all([
    supabase.from("clients").select("*").eq("is_active", true).order("legal_name"),
    supabase.from("locations").select("*").eq("is_active", true).order("name"),
    supabase.from("cold_rooms").select("*").eq("is_active", true).order("name"),
    supabase.from("generators").select("*").eq("is_active", true).order("identifier"),
    supabase
      .from("generator_assignments")
      .select("generator_id, cold_room_id")
      .is("valid_until", null),
    supabase.from("controllers").select("*").order("activated_at", { ascending: false }),
  ]);

  const clients = assertData(
    clientsResponse.data,
    clientsResponse.error,
    "as opções de clientes",
  );
  const activeClientIds = new Set(clients.map((client) => client.id));
  const locations = assertData(
    locationsResponse.data,
    locationsResponse.error,
    "as opções de unidades",
  ).filter((location) => activeClientIds.has(location.client_id));
  const activeLocationIds = new Set(
    locations.map((location) => location.id),
  );
  const coldRooms = assertData(
    roomsResponse.data,
    roomsResponse.error,
    "as opções de câmaras",
  ).filter(
    (room) =>
      activeClientIds.has(room.client_id) &&
      activeLocationIds.has(room.location_id),
  );
  const activeColdRoomIds = new Set(coldRooms.map((room) => room.id));
  const assignments = assertData(
    assignmentsResponse.data,
    assignmentsResponse.error,
    "as alocações atuais",
  );
  const coherentlyAssignedGeneratorIds = new Set(
    assignments
      .filter((assignment) => activeColdRoomIds.has(assignment.cold_room_id))
      .map((assignment) => assignment.generator_id),
  );

  return {
    clients,
    locations,
    coldRooms,
    generators: assertData(
      generatorsResponse.data,
      generatorsResponse.error,
      "as opções de geradores",
    ).filter(
      (generator) =>
        activeClientIds.has(generator.client_id) &&
        coherentlyAssignedGeneratorIds.has(generator.id),
    ),
    controllers: assertData(
      controllersResponse.data,
      controllersResponse.error,
      "os controladores atuais",
    ),
  };
}

export type ClientHierarchy = {
  client: Client;
  locations: Location[];
  coldRooms: ColdRoom[];
  generators: Generator[];
  assignments: Assignment[];
  controllers: Controller[];
  profiles: Array<Profile & { email: string }>;
};

export async function getClientHierarchy(
  clientId: string,
): Promise<ClientHierarchy | null> {
  const supabase = await getMasterClient();
  const clientResponse = await supabase
    .from("clients")
    .select("*")
    .eq("id", clientId)
    .maybeSingle();

  if (clientResponse.error) {
    throw new Error("Não foi possível carregar o cliente.");
  }

  if (!clientResponse.data) {
    return null;
  }

  const [
    locationsResponse,
    roomsResponse,
    generatorsResponse,
    assignmentsResponse,
    controllersResponse,
    profilesResponse,
  ] = await Promise.all([
    supabase.from("locations").select("*").eq("client_id", clientId).order("name"),
    supabase.from("cold_rooms").select("*").eq("client_id", clientId).order("name"),
    supabase.from("generators").select("*").eq("client_id", clientId).order("identifier"),
    supabase
      .from("generator_assignments")
      .select("*")
      .eq("client_id", clientId)
      .order("valid_from", { ascending: false }),
    supabase
      .from("controllers")
      .select("*")
      .eq("client_id", clientId)
      .order("activated_at", { ascending: false }),
    supabase.from("profiles").select("*").eq("client_id", clientId).order("full_name"),
  ]);
  const profiles = assertData(
    profilesResponse.data,
    profilesResponse.error,
    "os usuários do cliente",
  );
  const admin = createAdminClient();
  const { data: authData, error: authError } =
    await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });

  if (authError) {
    throw new Error("Não foi possível carregar os e-mails do cliente.");
  }

  const emails = new Map(
    authData.users.map((user) => [user.id, user.email ?? "E-mail indisponível"]),
  );

  return {
    client: clientResponse.data,
    locations: assertData(
      locationsResponse.data,
      locationsResponse.error,
      "as unidades do cliente",
    ),
    coldRooms: assertData(
      roomsResponse.data,
      roomsResponse.error,
      "as câmaras do cliente",
    ),
    generators: assertData(
      generatorsResponse.data,
      generatorsResponse.error,
      "os geradores do cliente",
    ),
    assignments: assertData(
      assignmentsResponse.data,
      assignmentsResponse.error,
      "as alocações do cliente",
    ),
    controllers: assertData(
      controllersResponse.data,
      controllersResponse.error,
      "os controladores do cliente",
    ),
    profiles: profiles.map((profile) => ({
      ...profile,
      email: emails.get(profile.id) ?? "E-mail indisponível",
    })),
  };
}
