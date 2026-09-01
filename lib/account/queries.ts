import "server-only";

import { requireMaster } from "@/lib/auth/profile";
import { createClient } from "@/lib/supabase/server";

export async function getAdminAccount() {
  const profile = await requireMaster();
  const supabase = await createClient();
  const { data, error } = await supabase.auth.getUser();

  if (error || !data.user || data.user.id !== profile.id || !data.user.email) {
    throw new Error("Não foi possível carregar os dados da conta Master.");
  }

  return {
    email: data.user.email,
    fullName: profile.fullName,
  };
}
