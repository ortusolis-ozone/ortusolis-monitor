"use server";

import { revalidatePath } from "next/cache";
import { logOperationalFailure } from "../log-failure";
import { requireMaster } from "@/lib/auth/profile";
import { createClient } from "@/lib/supabase/server";
import { fieldError, type OperationalActionState } from "../action-state";
import { formText, isDate, isTimestamp, isUuid, parseNominalPower } from "./validation";

function databaseError(code: string): OperationalActionState {
  if (code === "40001") return { status: "error", message: "O perfil foi alterado. Atualize o histórico antes de salvar novamente." };
  if (code === "23P01") return fieldError("valid_from", "A nova vigência deve ser posterior à anterior e não pode sobrepor outro perfil.");
  if (code === "23505") return { status: "error", message: "Já existe um cadastro com os dados informados." };
  if (code === "42501") return { status: "error", message: "Você não tem permissão para configurar a potência nominal." };
  if (code === "P0002") return fieldError("generator_id", "Selecione um gerador ativo.");
  return { status: "error", message: "Não foi possível salvar a configuração. Confira os dados e tente novamente." };
}

function success(message: string): OperationalActionState {
  revalidatePath("/admin", "layout");
  return { status: "success", message };
}

export async function createGeneratorWithPowerProfileAction(
  _previous: OperationalActionState,
  formData: FormData,
): Promise<OperationalActionState> {
  await requireMaster();
  const nominal = parseNominalPower(formData.get("nominal_power_w"));
  if (nominal === null) return fieldError("nominal_power_w", "Informe uma potência positiva com até três casas decimais.");
  const roomId = formText(formData, "cold_room_id");
  if (!isUuid(roomId)) return fieldError("cold_room_id", "Selecione uma câmara válida.");
  const validFrom = formText(formData, "valid_from");
  if (!isDate(validFrom)) return fieldError("valid_from", "Informe uma data inicial válida.");
  for (const field of ["identifier", "state_controller_identifier", "power_controller_identifier", "power_controller_device_id"]) {
    if (!formText(formData, field)) return fieldError(field, "Preencha este campo.");
  }
  const onText = formText(formData, "power_on_threshold_w").replace(",", ".");
  const offText = formText(formData, "power_off_threshold_w").replace(",", ".");
  const on = Number(onText);
  const off = Number(offText);
  if (!onText || !offText || !Number.isFinite(on) || !Number.isFinite(off) || off < 0 || on <= off) {
    return fieldError("power_on_threshold_w", "O limite ligado deve ser maior que o limite desligado.");
  }
  const toleranceText = formText(formData, "correlation_tolerance_seconds");
  const tolerance = Number(toleranceText);
  if (!toleranceText || !Number.isInteger(tolerance) || tolerance < 0 || tolerance > 86400) {
    return fieldError("correlation_tolerance_seconds", "Informe uma tolerância inteira entre 0 e 86.400 segundos.");
  }
  const supabase = await createClient();
  const { error } = await supabase.rpc("register_generator_with_power_profile", {
    p_cold_room_id: roomId,
    p_identifier: formText(formData, "identifier"),
    p_valid_from: validFrom,
    p_nominal_power_w: nominal,
    p_state_controller_identifier: formText(formData, "state_controller_identifier"),
    p_power_controller_identifier: formText(formData, "power_controller_identifier"),
    p_power_controller_device_id: formText(formData, "power_controller_device_id"),
    p_power_on_threshold_w: on,
    p_power_off_threshold_w: off,
    p_correlation_tolerance_seconds: tolerance,
  });
  if (error) logOperationalFailure("power_profile_create", error);
  return error ? databaseError(error.code) : success("Gerador e potência nominal cadastrados com sucesso.");
}

export async function versionGeneratorPowerProfileAction(
  _previous: OperationalActionState,
  formData: FormData,
): Promise<OperationalActionState> {
  await requireMaster();
  const generatorId = formText(formData, "generator_id");
  if (!isUuid(generatorId)) return fieldError("generator_id", "Selecione um gerador válido.");
  const nominal = parseNominalPower(formData.get("nominal_power_w"));
  if (nominal === null) return fieldError("nominal_power_w", "Informe uma potência positiva com até três casas decimais.");
  const validFrom = formText(formData, "valid_from");
  if (!isTimestamp(validFrom)) return fieldError("valid_from", "Informe data e hora válidas com fuso horário.");
  const expected = formText(formData, "expected_profile_id");
  if (expected && !isUuid(expected)) return fieldError("expected_profile_id", "Atualize o histórico antes de salvar.");
  const supabase = await createClient();
  const { error } = await supabase.rpc("version_generator_power_profile", {
    p_generator_id: generatorId,
    p_nominal_power_w: nominal,
    p_valid_from: validFrom,
    ...(expected ? { p_expected_profile_id: expected } : {}),
  });
  if (error) logOperationalFailure("power_profile_version", error);
  return error ? databaseError(error.code) : success("Nova vigência de potência nominal registrada.");
}
