"use server";

import { revalidatePath } from "next/cache";

import { requireMaster } from "@/lib/auth/profile";
import {
  fieldError,
  type OperationalActionState,
} from "@/lib/operations/action-state";
import { createClient } from "@/lib/supabase/server";

import { sourceClassifications } from "./constants";

function parseInconsistencyId(formData: FormData) {
  const value = Number(formData.get("inconsistency_id"));

  return Number.isSafeInteger(value) && value > 0 ? value : null;
}

function revalidateInconsistencyViews() {
  revalidatePath("/admin");
  revalidatePath("/admin/inconsistencias");
}

export async function reviewInconsistencyAction(
  _state: OperationalActionState,
  formData: FormData,
): Promise<OperationalActionState> {
  await requireMaster();
  const inconsistencyId = parseInconsistencyId(formData);
  const reviewNote = String(formData.get("review_note") ?? "").trim();

  if (!inconsistencyId) {
    return { status: "error", message: "A inconsistência informada é inválida." };
  }

  if (reviewNote.length > 2000) {
    return fieldError(
      "review_note",
      "Use no máximo 2.000 caracteres na nota interna.",
    );
  }

  const supabase = await createClient();
  const { data, error } = await supabase.rpc("review_inconsistency", {
    p_inconsistency_id: inconsistencyId,
    p_review_note: reviewNote || undefined,
  });

  if (error) {
    console.error("Falha ao revisar inconsistência", error);
    return {
      status: "error",
      message: "Não foi possível concluir a revisão. Tente novamente.",
    };
  }

  if (!data) {
    return {
      status: "error",
      message: "A inconsistência já foi alterada. Atualize a página.",
    };
  }

  revalidateInconsistencyViews();
  return {
    status: "success",
    message: "Inconsistência revisada e estados reprocessados.",
  };
}

export async function reopenInconsistencyAction(
  _state: OperationalActionState,
  formData: FormData,
): Promise<OperationalActionState> {
  await requireMaster();
  const inconsistencyId = parseInconsistencyId(formData);

  if (!inconsistencyId) {
    return { status: "error", message: "A inconsistência informada é inválida." };
  }

  const supabase = await createClient();
  const { data, error } = await supabase.rpc("reopen_inconsistency", {
    p_inconsistency_id: inconsistencyId,
  });

  if (error) {
    console.error("Falha ao reabrir inconsistência", error);
    return {
      status: "error",
      message: "Não foi possível reabrir a revisão. Tente novamente.",
    };
  }

  if (!data) {
    return {
      status: "error",
      message: "A inconsistência já foi alterada. Atualize a página.",
    };
  }

  revalidateInconsistencyViews();
  return {
    status: "success",
    message: "Revisão reaberta e estados reprocessados.",
  };
}

export async function setSourceMappingAction(
  _state: OperationalActionState,
  formData: FormData,
): Promise<OperationalActionState> {
  await requireMaster();
  const normalizedSource = String(
    formData.get("normalized_source") ?? "",
  ).trim();
  const classification = String(formData.get("classification") ?? "");

  if (!normalizedSource) {
    return fieldError("classification", "A origem informada é inválida.");
  }

  if (
    !sourceClassifications.some(
      (option) => option.value === classification,
    )
  ) {
    return fieldError("classification", "Selecione uma classificação válida.");
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc("set_source_mapping", {
    p_normalized_source: normalizedSource,
    p_classification: classification,
  });

  if (error) {
    console.error("Falha ao atualizar mapeamento de origem", error);
    return {
      status: "error",
      message: "Não foi possível salvar o mapeamento. Tente novamente.",
    };
  }

  revalidatePath("/admin");
  revalidatePath("/admin/inconsistencias");
  revalidatePath("/admin/mapeamentos");
  revalidatePath("/admin/importacoes");

  return {
    status: "success",
    message:
      "Mapeamento salvo. Os geradores afetados foram reprocessados automaticamente.",
  };
}
