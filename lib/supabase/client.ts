import { createBrowserClient } from "@supabase/ssr";

import { getPublicSupabaseConfig } from "./config";
import type { Database } from "./database.types";

export function createClient() {
  const { url, publishableKey } = getPublicSupabaseConfig();

  return createBrowserClient<Database>(url, publishableKey);
}
