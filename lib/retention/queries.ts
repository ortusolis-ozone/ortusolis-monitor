import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/lib/supabase/database.types";

export type RetentionWindow = Database["public"]["Functions"]["get_history_retention_windows"]["Returns"][number];

export async function getRetentionWindows(client: SupabaseClient<Database>): Promise<RetentionWindow[]> {
  const { data, error } = await client.rpc("get_history_retention_windows");
  if (error || !data) throw new Error("Não foi possível verificar o período disponível do histórico.");
  return data;
}
