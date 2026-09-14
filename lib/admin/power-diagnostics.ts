import "server-only";

import { requireMaster } from "@/lib/auth/profile";
import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/lib/supabase/database.types";

type Functions = Database["public"]["Functions"];
type DiagnosticRow = Functions["list_admin_application_power_diagnostics"]["Returns"][number];
type OptionalFields = "nominal_power_w" | "minimum_power_w" | "observed_power_w" | "difference_w" | "difference_percent" | "reference_reading_id" | "reference_reading_at" | "power_controller_id" | "power_controller_identifier" | "power_batch_id" | "power_file_name" | "power_profile_id" | "profile_valid_from" | "profile_valid_until" | "evaluated_at" | "rule_version";
export type PowerDiagnostic = Omit<DiagnosticRow, OptionalFields> & { [K in OptionalFields]: DiagnosticRow[K] | null };
type InconsistencyRow = Functions["list_admin_application_power_inconsistencies"]["Returns"][number];
type OptionalReviewFields = "review_note" | "reviewed_by_name" | "reviewed_at" | "resolved_at" | "power_reading_id" | "power_profile_id";
export type PowerDiagnosticInconsistency = Omit<InconsistencyRow, OptionalReviewFields> & { [K in OptionalReviewFields]: InconsistencyRow[K] | null };
type RunRow = Functions["list_admin_application_power_runs"]["Returns"][number];
export type PowerDiagnosticRun = Omit<RunRow, "affected_from" | "affected_until"> & { affected_from: string | null; affected_until: string | null };

export function parseDiagnosticPage(value?: string) {
  const page = Number(value ?? 0);
  return Number.isSafeInteger(page) && page >= 0 && page <= 1_000_000 ? page : 0;
}

export async function getGeneratorApplicationDiagnostics(generatorId: string, page = 0): Promise<PowerDiagnostic[]> {
  await requireMaster();
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("list_admin_application_power_diagnostics", {
    p_generator_id: generatorId, p_offset: page * 50,
  });
  if (error || data === null) throw new Error("Não foi possível carregar as aplicações do gerador.");
  return data;
}

export async function getApplicationPowerDiagnostic(applicationId: number, historyPage = 0): Promise<{
  diagnostic: PowerDiagnostic | null;
  inconsistencies: PowerDiagnosticInconsistency[];
  runs: PowerDiagnosticRun[];
}> {
  await requireMaster();
  const supabase = await createClient();
  const [diagnostics, inconsistencies, runs] = await Promise.all([
    supabase.rpc("list_admin_application_power_diagnostics", { p_application_id: applicationId }),
    supabase.rpc("list_admin_application_power_inconsistencies", { p_application_id: applicationId }),
    supabase.rpc("list_admin_application_power_runs", { p_application_id: applicationId, p_offset: historyPage * 20 }),
  ]);
  if (diagnostics.error || inconsistencies.error || runs.error || !diagnostics.data || !inconsistencies.data || !runs.data) {
    throw new Error("Não foi possível carregar o diagnóstico da aplicação.");
  }
  return { diagnostic: diagnostics.data[0] ?? null, inconsistencies: inconsistencies.data, runs: runs.data };
}
