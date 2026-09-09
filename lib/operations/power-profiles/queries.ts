import "server-only";

import { requireMaster } from "@/lib/auth/profile";
import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/lib/supabase/database.types";

type Functions = Database["public"]["Functions"];
type ConfigurationRow = Functions["list_admin_generator_power_configuration"]["Returns"][number];
type NullableConfigurationFields = "power_profile_id" | "nominal_power_w" | "minimum_acceptable_power_w" | "valid_from" | "valid_until";
// PostgreSQL function metadata does not describe nullability of returned columns.
export type GeneratorPowerConfiguration = Omit<ConfigurationRow, NullableConfigurationFields> & {
  [Field in NullableConfigurationFields]: string | null;
};
type HistoryRow = Functions["list_admin_generator_power_history"]["Returns"][number];
export type GeneratorPowerHistoryEntry = Omit<HistoryRow, "valid_until"> & { valid_until: string | null };

export async function getGeneratorPowerConfigurations(options: {
  at?: string;
  onlyPending?: boolean;
  generatorId?: string;
} = {}): Promise<GeneratorPowerConfiguration[]> {
  await requireMaster();
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("list_admin_generator_power_configuration", {
    p_at: options.at,
    p_only_pending: options.onlyPending ?? false,
    p_generator_id: options.generatorId,
  });
  if (error || data === null) throw new Error("Não foi possível carregar a configuração de potência dos geradores.");
  return data;
}

export async function getGeneratorPowerHistory(generatorId: string): Promise<GeneratorPowerHistoryEntry[]> {
  await requireMaster();
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("list_admin_generator_power_history", { p_generator_id: generatorId });
  if (error || data === null) throw new Error("Não foi possível carregar o histórico de potência do gerador.");
  return data;
}
