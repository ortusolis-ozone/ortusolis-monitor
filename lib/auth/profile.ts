import "server-only";

import { cache } from "react";
import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";

export const clientRoles = ["client_admin", "operator", "viewer"] as const;
export const userRoles = ["master", ...clientRoles] as const;

export type ClientRole = (typeof clientRoles)[number];
export type UserRole = (typeof userRoles)[number];

export type AuthProfile = {
  id: string;
  clientId: string | null;
  fullName: string;
  role: UserRole;
};

function isUserRole(value: string): value is UserRole {
  return userRoles.some((role) => role === value);
}

export function homePathForRole(role: UserRole) {
  return role === "master" ? "/admin" : "/portal";
}

export const getCurrentProfile = cache(
  async (): Promise<AuthProfile | null> => {
    const supabase = await createClient();
    const { data: claimsData, error: claimsError } =
      await supabase.auth.getClaims();
    const userId = claimsData?.claims.sub;

    if (claimsError || !userId) {
      return null;
    }

    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("id, client_id, full_name, role")
      .eq("id", userId)
      .maybeSingle();

    if (profileError || !profile || !isUserRole(profile.role)) {
      return null;
    }

    return {
      id: profile.id,
      clientId: profile.client_id,
      fullName: profile.full_name,
      role: profile.role,
    };
  },
);

export async function requireProfile() {
  const profile = await getCurrentProfile();

  if (!profile) {
    redirect("/login");
  }

  return profile;
}

export async function requireMaster() {
  const profile = await requireProfile();

  if (profile.role !== "master") {
    redirect("/portal");
  }

  return profile;
}

export async function requireClientProfile() {
  const profile = await requireProfile();

  if (profile.role === "master") {
    redirect("/admin");
  }

  if (!profile.clientId) {
    redirect("/login");
  }

  return profile as AuthProfile & { clientId: string; role: ClientRole };
}
