import "server-only";

import { createClient } from "@supabase/supabase-js";

import { getPublicSupabaseConfig } from "./config";
import type { Database } from "./database.types";

export function createAdminClient() {
  const secretKey = process.env.SUPABASE_SECRET_KEY;

  if (!secretKey) {
    throw new Error("Configure SUPABASE_SECRET_KEY no ambiente do servidor.");
  }

  const { url } = getPublicSupabaseConfig();

  return createClient<Database>(url, secretKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}

export function createPasswordVerificationClient() {
  const { url, publishableKey } = getPublicSupabaseConfig();

  return createClient<Database>(url, publishableKey, {
    auth: {
      autoRefreshToken: false,
      detectSessionInUrl: false,
      persistSession: false,
    },
  });
}
