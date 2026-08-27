"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import type { PostgrestError } from "@supabase/supabase-js";

import { requireMaster } from "@/lib/auth/profile";
import { getRequestOrigin } from "@/lib/auth/url";
import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";
import { isValidCnpj, normalizeCnpj } from "@/lib/validation/cnpj";

import {
  isAssignableClientRole,
  isColdRoomCategory,
} from "./constants";
import {
  fieldError,
  type OperationalActionState,
} from "./action-state";

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function formText(formData: FormData, field: string) {
  const value = formData.get(field);
  return typeof value === "string" ? value.trim() : "";
}

function isValidDate(value: string) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return false;
  }

  const [year, month, day] = value.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));

  return (
    date.getUTCFullYear() === year &&
    date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day
  );
}

function isValidTimeZone(value: string) {
  try {
    new Intl.DateTimeFormat("pt-BR", { timeZone: value }).format();
    return true;
  } catch {
    return false;
  }
}

function success(message: string): OperationalActionState {
  revalidatePath("/admin", "layout");

  return { status: "success", message };
}

function databaseError(
  error: PostgrestError,
  fallbackField?: string,
): OperationalActionState {
  if (error.code === "23505") {
    const field = error.message.includes("cnpj")
      ? "cnpj"
      : error.message.includes("locations_client_name") ||
          error.message.includes("cold_rooms_location_name")
        ? "name"
        : error.message.includes("identifier")
          ? "identifier"
          : fallbackField;

    if (field) {
      return fieldError(field, "Já existe um cadastro com esse valor.");
    }
  }

  if (error.code === "23P01") {
    return fieldError(
      fallbackField ?? "effective_on",
      "A data informada sobrepõe uma vigência já registrada.",
    );
  }

  if (error.code === "23503") {
    return fieldError(
      fallbackField ?? "client_id",
      "A relação selecionada não pertence à mesma hierarquia.",
    );
  }

  if (error.code === "23514") {
    return fallbackField
      ? fieldError(fallbackField, error.message)
      : { status: "error", message: error.message };
  }

  return {
    status: "error",
    message: "Não foi possível salvar a alteração. Tente novamente.",
  };
}

function validateId(id: string, field = "id") {
  return uuidPattern.test(id)
    ? null
    : fieldError(field, "Seleção inválida.");
}

async function masterContext() {
  const profile = await requireMaster();
  const supabase = await createClient();

  return { profile, supabase };
}

export async function createClientAction(
  _previousState: OperationalActionState,
  formData: FormData,
): Promise<OperationalActionState> {
  await requireMaster();
  const legalName = formText(formData, "legal_name");
  const cnpjInput = formText(formData, "cnpj");
  const cnpj = normalizeCnpj(cnpjInput);

  if (!legalName) {
    return fieldError("legal_name", "Informe a razão social ou o nome.");
  }

  if (!isValidCnpj(cnpj)) {
    return fieldError("cnpj", "Informe um CNPJ válido.");
  }

  const supabase = await createClient();
  const { error } = await supabase.from("clients").insert({
    legal_name: legalName,
    cnpj,
  });

  return error
    ? databaseError(error, "cnpj")
    : success("Cliente cadastrado com sucesso.");
}

export async function createCompleteClientStructureAction(
  _previousState: OperationalActionState,
  formData: FormData,
): Promise<OperationalActionState> {
  await requireMaster();

  const clientLegalName = formText(formData, "client_legal_name");
  const clientCnpj = normalizeCnpj(formText(formData, "client_cnpj"));
  const locationName = formText(formData, "location_name");
  const locationDescription = formText(formData, "location_description");
  const locationTimeZone =
    formText(formData, "location_time_zone") || "America/Fortaleza";
  const coldRoomName = formText(formData, "cold_room_name");
  const coldRoomCategory = formText(formData, "cold_room_category");
  const generatorIdentifier = formText(formData, "generator_identifier");
  const generatorValidFrom = formText(formData, "generator_valid_from");
  const controllerIdentifier = formText(formData, "controller_identifier");
  const controllerActivatedOn = formText(
    formData,
    "controller_activated_on",
  );

  if (!clientLegalName) {
    return fieldError(
      "client_legal_name",
      "Informe a razão social ou o nome.",
    );
  }
  if (!isValidCnpj(clientCnpj)) {
    return fieldError("client_cnpj", "Informe um CNPJ válido.");
  }
  if (!locationName) {
    return fieldError("location_name", "Informe o nome da unidade.");
  }
  if (!isValidTimeZone(locationTimeZone)) {
    return fieldError(
      "location_time_zone",
      "Informe um fuso IANA válido.",
    );
  }
  if (!coldRoomName) {
    return fieldError("cold_room_name", "Informe o nome da câmara.");
  }
  if (!isColdRoomCategory(coldRoomCategory)) {
    return fieldError(
      "cold_room_category",
      "Selecione uma categoria válida.",
    );
  }
  if (!generatorIdentifier) {
    return fieldError(
      "generator_identifier",
      "Informe a identificação do gerador.",
    );
  }
  if (!isValidDate(generatorValidFrom)) {
    return fieldError(
      "generator_valid_from",
      "Informe uma data inicial válida.",
    );
  }
  if (!controllerIdentifier) {
    return fieldError(
      "controller_identifier",
      "Informe a identificação do controlador.",
    );
  }
  if (!isValidDate(controllerActivatedOn)) {
    return fieldError(
      "controller_activated_on",
      "Informe uma data de ativação válida.",
    );
  }
  if (controllerActivatedOn < generatorValidFrom) {
    return fieldError(
      "controller_activated_on",
      "A ativação não pode ser anterior ao início da alocação do gerador.",
    );
  }

  const supabase = await createClient();
  const { data, error } = await supabase.rpc(
    "register_complete_client_structure",
    {
      p_client_legal_name: clientLegalName,
      p_client_cnpj: clientCnpj,
      p_location_name: locationName,
      p_location_description: locationDescription,
      p_location_time_zone: locationTimeZone,
      p_cold_room_name: coldRoomName,
      p_cold_room_category: coldRoomCategory,
      p_generator_identifier: generatorIdentifier,
      p_generator_valid_from: generatorValidFrom,
      p_controller_identifier: controllerIdentifier,
      p_controller_activated_on: controllerActivatedOn,
    },
  );

  if (error) {
    if (error.code === "23505" && error.message.includes("cnpj")) {
      return fieldError("client_cnpj", "Já existe um cliente com esse CNPJ.");
    }

    return databaseError(error);
  }

  const clientId =
    data &&
    typeof data === "object" &&
    !Array.isArray(data) &&
    typeof data.client_id === "string" &&
    uuidPattern.test(data.client_id)
      ? data.client_id
      : null;

  revalidatePath("/admin", "layout");
  redirect(clientId ? `/admin/clientes/${clientId}` : "/admin/clientes");
}

export async function editClientAction(
  _previousState: OperationalActionState,
  formData: FormData,
): Promise<OperationalActionState> {
  await requireMaster();
  const id = formText(formData, "id");
  const invalidId = validateId(id);
  const legalName = formText(formData, "legal_name");
  const cnpj = normalizeCnpj(formText(formData, "cnpj"));

  if (invalidId) return invalidId;
  if (!legalName) {
    return fieldError("legal_name", "Informe a razão social ou o nome.");
  }
  if (!isValidCnpj(cnpj)) {
    return fieldError("cnpj", "Informe um CNPJ válido.");
  }

  const supabase = await createClient();
  const { data, error } = await supabase
    .from("clients")
    .update({ legal_name: legalName, cnpj })
    .eq("id", id)
    .select("id")
    .maybeSingle();

  if (error) return databaseError(error, "cnpj");
  if (!data) return { status: "error", message: "Cliente não encontrado." };
  return success("Cliente atualizado com sucesso.");
}

export async function setClientStatusAction(
  _previousState: OperationalActionState,
  formData: FormData,
): Promise<OperationalActionState> {
  await requireMaster();
  const id = formText(formData, "id");
  const invalidId = validateId(id);
  const isActive = formText(formData, "is_active") === "true";

  if (invalidId) return invalidId;

  const supabase = await createClient();
  const { data, error } = await supabase
    .from("clients")
    .update({ is_active: isActive })
    .eq("id", id)
    .select("id")
    .maybeSingle();

  if (error) return databaseError(error);
  if (!data) return { status: "error", message: "Cliente não encontrado." };
  return success(isActive ? "Cliente reativado." : "Cliente inativado.");
}

export async function createLocationAction(
  _previousState: OperationalActionState,
  formData: FormData,
): Promise<OperationalActionState> {
  await requireMaster();
  const clientId = formText(formData, "client_id");
  const name = formText(formData, "name");
  const description = formText(formData, "description");
  const timeZone = formText(formData, "time_zone") || "America/Fortaleza";
  const invalidClient = validateId(clientId, "client_id");

  if (invalidClient) return invalidClient;
  if (!name) return fieldError("name", "Informe o nome da unidade.");
  if (!isValidTimeZone(timeZone)) {
    return fieldError("time_zone", "Informe um fuso IANA válido.");
  }

  const supabase = await createClient();
  const { data: client } = await supabase
    .from("clients")
    .select("id")
    .eq("id", clientId)
    .eq("is_active", true)
    .maybeSingle();

  if (!client) {
    return fieldError("client_id", "Selecione um cliente ativo.");
  }

  const { error } = await supabase.from("locations").insert({
    client_id: client.id,
    name,
    description: description || null,
    time_zone: timeZone,
  });

  return error
    ? databaseError(error, "name")
    : success("Unidade cadastrada com sucesso.");
}

export async function editLocationAction(
  _previousState: OperationalActionState,
  formData: FormData,
): Promise<OperationalActionState> {
  await requireMaster();
  const id = formText(formData, "id");
  const name = formText(formData, "name");
  const description = formText(formData, "description");
  const timeZone = formText(formData, "time_zone");
  const invalidId = validateId(id);

  if (invalidId) return invalidId;
  if (!name) return fieldError("name", "Informe o nome da unidade.");
  if (!isValidTimeZone(timeZone)) {
    return fieldError("time_zone", "Informe um fuso IANA válido.");
  }

  const supabase = await createClient();
  const { data, error } = await supabase
    .from("locations")
    .update({ name, description: description || null, time_zone: timeZone })
    .eq("id", id)
    .select("id")
    .maybeSingle();

  if (error) return databaseError(error, "name");
  if (!data) return { status: "error", message: "Unidade não encontrada." };
  return success("Unidade atualizada com sucesso.");
}

export async function setLocationStatusAction(
  _previousState: OperationalActionState,
  formData: FormData,
): Promise<OperationalActionState> {
  await requireMaster();
  const id = formText(formData, "id");
  const invalidId = validateId(id);
  const isActive = formText(formData, "is_active") === "true";

  if (invalidId) return invalidId;

  const supabase = await createClient();
  const { data, error } = await supabase
    .from("locations")
    .update({ is_active: isActive })
    .eq("id", id)
    .select("id")
    .maybeSingle();

  if (error) return databaseError(error);
  if (!data) return { status: "error", message: "Unidade não encontrada." };
  return success(isActive ? "Unidade reativada." : "Unidade inativada.");
}

export async function createColdRoomAction(
  _previousState: OperationalActionState,
  formData: FormData,
): Promise<OperationalActionState> {
  await requireMaster();
  const locationId = formText(formData, "location_id");
  const name = formText(formData, "name");
  const category = formText(formData, "category");
  const invalidLocation = validateId(locationId, "location_id");

  if (invalidLocation) return invalidLocation;
  if (!name) return fieldError("name", "Informe o nome da câmara.");
  if (!isColdRoomCategory(category)) {
    return fieldError("category", "Selecione uma categoria válida.");
  }

  const supabase = await createClient();
  const { data: location } = await supabase
    .from("locations")
    .select("id, client_id")
    .eq("id", locationId)
    .eq("is_active", true)
    .maybeSingle();

  if (!location) {
    return fieldError("location_id", "Selecione uma unidade ativa.");
  }

  const { data: client } = await supabase
    .from("clients")
    .select("id")
    .eq("id", location.client_id)
    .eq("is_active", true)
    .maybeSingle();

  if (!client) {
    return fieldError("location_id", "O cliente da unidade está inativo.");
  }

  const { error } = await supabase.from("cold_rooms").insert({
    client_id: client.id,
    location_id: location.id,
    name,
    category,
  });

  return error
    ? databaseError(error, "name")
    : success("Câmara cadastrada com sucesso.");
}

export async function editColdRoomAction(
  _previousState: OperationalActionState,
  formData: FormData,
): Promise<OperationalActionState> {
  await requireMaster();
  const id = formText(formData, "id");
  const name = formText(formData, "name");
  const category = formText(formData, "category");
  const invalidId = validateId(id);

  if (invalidId) return invalidId;
  if (!name) return fieldError("name", "Informe o nome da câmara.");
  if (!isColdRoomCategory(category)) {
    return fieldError("category", "Selecione uma categoria válida.");
  }

  const supabase = await createClient();
  const { data, error } = await supabase
    .from("cold_rooms")
    .update({ name, category })
    .eq("id", id)
    .select("id")
    .maybeSingle();

  if (error) return databaseError(error, "name");
  if (!data) return { status: "error", message: "Câmara não encontrada." };
  return success("Câmara atualizada com sucesso.");
}

export async function setColdRoomStatusAction(
  _previousState: OperationalActionState,
  formData: FormData,
): Promise<OperationalActionState> {
  await requireMaster();
  const id = formText(formData, "id");
  const invalidId = validateId(id);
  const isActive = formText(formData, "is_active") === "true";

  if (invalidId) return invalidId;

  const supabase = await createClient();
  const { data, error } = await supabase
    .from("cold_rooms")
    .update({ is_active: isActive })
    .eq("id", id)
    .select("id")
    .maybeSingle();

  if (error) return databaseError(error);
  if (!data) return { status: "error", message: "Câmara não encontrada." };
  return success(isActive ? "Câmara reativada." : "Câmara inativada.");
}

export async function createGeneratorAction(
  _previousState: OperationalActionState,
  formData: FormData,
): Promise<OperationalActionState> {
  await requireMaster();
  const coldRoomId = formText(formData, "cold_room_id");
  const identifier = formText(formData, "identifier");
  const validFrom = formText(formData, "valid_from");
  const invalidRoom = validateId(coldRoomId, "cold_room_id");

  if (invalidRoom) return invalidRoom;
  if (!identifier) {
    return fieldError("identifier", "Informe a identificação do gerador.");
  }
  if (!isValidDate(validFrom)) {
    return fieldError("valid_from", "Informe uma data inicial válida.");
  }

  const supabase = await createClient();
  const { data: room } = await supabase
    .from("cold_rooms")
    .select("client_id, location_id")
    .eq("id", coldRoomId)
    .maybeSingle();

  if (!room) {
    return fieldError("cold_room_id", "Selecione uma câmara válida.");
  }

  const { error } = await supabase.rpc("register_generator", {
    p_client_id: room.client_id,
    p_location_id: room.location_id,
    p_cold_room_id: coldRoomId,
    p_identifier: identifier,
    p_valid_from: validFrom,
  });

  return error
    ? databaseError(error, "cold_room_id")
    : success("Gerador cadastrado e alocado com sucesso.");
}

export async function editGeneratorAction(
  _previousState: OperationalActionState,
  formData: FormData,
): Promise<OperationalActionState> {
  await requireMaster();
  const id = formText(formData, "id");
  const identifier = formText(formData, "identifier");
  const invalidId = validateId(id);

  if (invalidId) return invalidId;
  if (!identifier) {
    return fieldError("identifier", "Informe a identificação do gerador.");
  }

  const supabase = await createClient();
  const { data, error } = await supabase
    .from("generators")
    .update({ identifier })
    .eq("id", id)
    .select("id")
    .maybeSingle();

  if (error) return databaseError(error, "identifier");
  if (!data) return { status: "error", message: "Gerador não encontrado." };
  return success("Gerador atualizado com sucesso.");
}

export async function setGeneratorStatusAction(
  _previousState: OperationalActionState,
  formData: FormData,
): Promise<OperationalActionState> {
  await requireMaster();
  const id = formText(formData, "id");
  const invalidId = validateId(id);
  const isActive = formText(formData, "is_active") === "true";

  if (invalidId) return invalidId;

  const supabase = await createClient();
  const { data, error } = await supabase
    .from("generators")
    .update({ is_active: isActive })
    .eq("id", id)
    .select("id")
    .maybeSingle();

  if (error) return databaseError(error);
  if (!data) return { status: "error", message: "Gerador não encontrado." };
  return success(isActive ? "Gerador reativado." : "Gerador inativado.");
}

export async function reassignGeneratorAction(
  _previousState: OperationalActionState,
  formData: FormData,
): Promise<OperationalActionState> {
  await requireMaster();
  const generatorId = formText(formData, "generator_id");
  const coldRoomId = formText(formData, "cold_room_id");
  const effectiveOn = formText(formData, "effective_on");
  const invalidGenerator = validateId(generatorId, "generator_id");
  const invalidRoom = validateId(coldRoomId, "cold_room_id");

  if (invalidGenerator) return invalidGenerator;
  if (invalidRoom) return invalidRoom;
  if (!isValidDate(effectiveOn)) {
    return fieldError("effective_on", "Informe uma data efetiva válida.");
  }

  const supabase = await createClient();
  const { data: room } = await supabase
    .from("cold_rooms")
    .select("location_id")
    .eq("id", coldRoomId)
    .maybeSingle();

  if (!room) {
    return fieldError("cold_room_id", "Selecione uma câmara válida.");
  }

  const { error } = await supabase.rpc("reassign_generator", {
    p_generator_id: generatorId,
    p_location_id: room.location_id,
    p_cold_room_id: coldRoomId,
    p_effective_on: effectiveOn,
  });

  return error
    ? databaseError(error, "effective_on")
    : success("Gerador realocado e histórico preservado.");
}

export async function createControllerAction(
  _previousState: OperationalActionState,
  formData: FormData,
): Promise<OperationalActionState> {
  await requireMaster();
  const generatorId = formText(formData, "generator_id");
  const identifier = formText(formData, "identifier");
  const activatedOn = formText(formData, "activated_on");
  const invalidGenerator = validateId(generatorId, "generator_id");

  if (invalidGenerator) return invalidGenerator;
  if (!identifier) {
    return fieldError("identifier", "Informe a identificação do controlador.");
  }
  if (!isValidDate(activatedOn)) {
    return fieldError("activated_on", "Informe uma data de ativação válida.");
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc("register_controller", {
    p_generator_id: generatorId,
    p_identifier: identifier,
    p_activated_on: activatedOn,
  });

  return error
    ? databaseError(error, "activated_on")
    : success("Controlador cadastrado com sucesso.");
}

export async function editControllerAction(
  _previousState: OperationalActionState,
  formData: FormData,
): Promise<OperationalActionState> {
  await requireMaster();
  const id = formText(formData, "id");
  const identifier = formText(formData, "identifier");
  const invalidId = validateId(id);

  if (invalidId) return invalidId;
  if (!identifier) {
    return fieldError("identifier", "Informe a identificação do controlador.");
  }

  const supabase = await createClient();
  const { data, error } = await supabase
    .from("controllers")
    .update({ identifier })
    .eq("id", id)
    .select("id")
    .maybeSingle();

  if (error) return databaseError(error, "identifier");
  if (!data) {
    return { status: "error", message: "Controlador não encontrado." };
  }
  return success("Controlador atualizado com sucesso.");
}

export async function replaceControllerAction(
  _previousState: OperationalActionState,
  formData: FormData,
): Promise<OperationalActionState> {
  await requireMaster();
  const generatorId = formText(formData, "generator_id");
  const identifier = formText(formData, "identifier");
  const activatedOn = formText(formData, "activated_on");
  const invalidGenerator = validateId(generatorId, "generator_id");

  if (invalidGenerator) return invalidGenerator;
  if (!identifier) {
    return fieldError("identifier", "Informe o novo controlador.");
  }
  if (!isValidDate(activatedOn)) {
    return fieldError("activated_on", "Informe uma data de ativação válida.");
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc("replace_controller", {
    p_generator_id: generatorId,
    p_identifier: identifier,
    p_activated_on: activatedOn,
  });

  return error
    ? databaseError(error, "activated_on")
    : success("Controlador substituído e histórico preservado.");
}

export async function deactivateControllerAction(
  _previousState: OperationalActionState,
  formData: FormData,
): Promise<OperationalActionState> {
  await requireMaster();
  const controllerId = formText(formData, "controller_id");
  const deactivatedOn = formText(formData, "deactivated_on");
  const invalidController = validateId(controllerId, "controller_id");

  if (invalidController) return invalidController;
  if (!isValidDate(deactivatedOn)) {
    return fieldError(
      "deactivated_on",
      "Informe uma data de desativação válida.",
    );
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc("deactivate_controller", {
    p_controller_id: controllerId,
    p_deactivated_on: deactivatedOn,
  });

  return error
    ? databaseError(error, "deactivated_on")
    : success("Controlador inativado na data informada.");
}

export async function reactivateControllerAction(
  _previousState: OperationalActionState,
  formData: FormData,
): Promise<OperationalActionState> {
  await requireMaster();
  const controllerId = formText(formData, "controller_id");
  const invalidController = validateId(controllerId, "controller_id");

  if (invalidController) return invalidController;

  const supabase = await createClient();
  const { error } = await supabase.rpc("reactivate_controller", {
    p_controller_id: controllerId,
  });

  return error
    ? databaseError(error)
    : success("Controlador reativado com sucesso.");
}

export async function inviteUserAction(
  _previousState: OperationalActionState,
  formData: FormData,
): Promise<OperationalActionState> {
  const { supabase } = await masterContext();
  const clientId = formText(formData, "client_id");
  const fullName = formText(formData, "full_name");
  const email = formText(formData, "email").toLowerCase();
  const role = formText(formData, "role");
  const invalidClient = validateId(clientId, "client_id");

  if (invalidClient) return invalidClient;
  if (!fullName) return fieldError("full_name", "Informe o nome completo.");
  if (!emailPattern.test(email)) {
    return fieldError("email", "Informe um e-mail válido.");
  }
  if (!isAssignableClientRole(role)) {
    return fieldError("role", "Selecione um papel válido.");
  }

  const { data: client } = await supabase
    .from("clients")
    .select("id")
    .eq("id", clientId)
    .eq("is_active", true)
    .maybeSingle();

  if (!client) {
    return fieldError("client_id", "Selecione um cliente ativo.");
  }

  const admin = createAdminClient();
  const origin = await getRequestOrigin();
  const { data: inviteData, error: inviteError } =
    await admin.auth.admin.inviteUserByEmail(email, {
      redirectTo: `${origin}/auth/callback`,
    });

  if (inviteError || !inviteData.user) {
    return fieldError(
      "email",
      inviteError?.message.toLowerCase().includes("already")
        ? "Esse e-mail já possui acesso."
        : "Não foi possível enviar o convite para esse e-mail.",
    );
  }

  const { error: profileError } = await supabase.from("profiles").insert({
    id: inviteData.user.id,
    client_id: client.id,
    full_name: fullName,
    role,
  });

  if (profileError) {
    await admin.auth.admin.deleteUser(inviteData.user.id);
    return databaseError(profileError, "email");
  }

  return success("Convite enviado e usuário vinculado ao cliente.");
}

export async function editUserAction(
  _previousState: OperationalActionState,
  formData: FormData,
): Promise<OperationalActionState> {
  await requireMaster();
  const id = formText(formData, "id");
  const fullName = formText(formData, "full_name");
  const role = formText(formData, "role");
  const invalidId = validateId(id);

  if (invalidId) return invalidId;
  if (!fullName) return fieldError("full_name", "Informe o nome completo.");
  if (!isAssignableClientRole(role)) {
    return fieldError("role", "Selecione um papel válido.");
  }

  const supabase = await createClient();
  const { data, error } = await supabase
    .from("profiles")
    .update({ full_name: fullName, role })
    .eq("id", id)
    .not("client_id", "is", null)
    .select("id")
    .maybeSingle();

  if (error) return databaseError(error);
  if (!data) return { status: "error", message: "Usuário não encontrado." };
  return success("Usuário atualizado com sucesso.");
}

export async function setUserStatusAction(
  _previousState: OperationalActionState,
  formData: FormData,
): Promise<OperationalActionState> {
  await requireMaster();
  const id = formText(formData, "id");
  const invalidId = validateId(id);
  const isActive = formText(formData, "is_active") === "true";

  if (invalidId) return invalidId;

  const supabase = await createClient();
  const { data, error } = await supabase
    .from("profiles")
    .update({ is_active: isActive })
    .eq("id", id)
    .not("client_id", "is", null)
    .select("id")
    .maybeSingle();

  if (error) return databaseError(error);
  if (!data) return { status: "error", message: "Usuário não encontrado." };
  return success(isActive ? "Usuário reativado." : "Usuário inativado.");
}
