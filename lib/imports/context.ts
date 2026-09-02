import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";

import type { Database } from "@/lib/supabase/database.types";

import { ImportValidationError } from "./parser";
import type { ImportContext, ValidatedImportContext } from "./types";

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function hasValidIds(context: ImportContext) {
  return Object.values(context).every((value) => uuidPattern.test(value));
}
export async function validateImportContext(
  supabase: SupabaseClient<Database>,
  context: ImportContext,
): Promise<ValidatedImportContext> {
  if (!hasValidIds(context)) {
    throw new ImportValidationError("Selecione toda a hierarquia operacional.");
  }

  const [client, location, coldRoom, generator, assignment, controller] =
    await Promise.all([
      supabase
        .from("clients")
        .select("id")
        .eq("id", context.clientId)
        .eq("is_active", true)
        .maybeSingle(),
      supabase
        .from("locations")
        .select("id, time_zone")
        .eq("id", context.locationId)
        .eq("client_id", context.clientId)
        .eq("is_active", true)
        .maybeSingle(),
      supabase
        .from("cold_rooms")
        .select("id")
        .eq("id", context.coldRoomId)
        .eq("client_id", context.clientId)
        .eq("location_id", context.locationId)
        .eq("is_active", true)
        .maybeSingle(),
      supabase
        .from("generators")
        .select("id")
        .eq("id", context.generatorId)
        .eq("client_id", context.clientId)
        .eq("is_active", true)
        .maybeSingle(),
      supabase
        .from("generator_assignments")
        .select("id")
        .eq("generator_id", context.generatorId)
        .eq("client_id", context.clientId)
        .eq("location_id", context.locationId)
        .eq("cold_room_id", context.coldRoomId)
        .is("valid_until", null)
        .maybeSingle(),
      supabase
        .from("controllers")
        .select(
          "id, activated_at, deactivated_at, role, external_device_id, external_device_id_normalized, power_on_threshold_w, power_off_threshold_w",
        )
        .eq("id", context.controllerId)
        .eq("client_id", context.clientId)
        .eq("generator_id", context.generatorId)
        .maybeSingle(),
    ]);

  const responses = [client, location, coldRoom, generator, assignment, controller];
  if (responses.some((response) => response.error)) {
    throw new Error("Não foi possível validar a hierarquia da importação.");
  }

  if (
    !client.data ||
    !location.data ||
    !coldRoom.data ||
    !generator.data ||
    !assignment.data ||
    !controller.data
  ) {
    throw new ImportValidationError(
      "A hierarquia operacional deve estar ativa e coerente, e o controlador deve pertencer ao gerador selecionado.",
    );
  }

  if (
    controller.data.role !== "state" &&
    controller.data.role !== "power_telemetry"
  ) {
    throw new Error("O papel do controlador armazenado é inválido.");
  }

  try {
    new Intl.DateTimeFormat("pt-BR", {
      timeZone: location.data.time_zone,
    }).format();
  } catch {
    throw new ImportValidationError(
      "O fuso horário configurado para a unidade é inválido.",
    );
  }

  return {
    ...context,
    timeZone: location.data.time_zone,
    controllerActivatedAt: controller.data.activated_at,
    controllerDeactivatedAt: controller.data.deactivated_at,
    controllerRole: controller.data.role,
    externalDeviceId: controller.data.external_device_id,
    externalDeviceIdNormalized: controller.data.external_device_id_normalized,
    powerOnThresholdW: controller.data.power_on_threshold_w,
    powerOffThresholdW: controller.data.power_off_threshold_w,
  };
}
