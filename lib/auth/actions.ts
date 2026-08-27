"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import type { AuthActionState } from "./action-state";
import { homePathForRole, userRoles, type UserRole } from "./profile";
import { getRequestOrigin } from "./url";
import { createClient } from "@/lib/supabase/server";

function formText(formData: FormData, field: string) {
  const value = formData.get(field);
  return typeof value === "string" ? value.trim() : "";
}

function formValue(formData: FormData, field: string) {
  const value = formData.get(field);
  return typeof value === "string" ? value : "";
}

function isUserRole(value: string): value is UserRole {
  return userRoles.some((role) => role === value);
}

export async function loginAction(
  _previousState: AuthActionState,
  formData: FormData,
): Promise<AuthActionState> {
  const email = formText(formData, "email").toLowerCase();
  const password = formValue(formData, "password");

  if (!email || !password) {
    return {
      status: "error",
      message: "Informe e-mail e senha.",
    };
  }

  const supabase = await createClient();
  const { data: authData, error: authError } =
    await supabase.auth.signInWithPassword({ email, password });

  if (authError || !authData.user) {
    return {
      status: "error",
      message: "E-mail ou senha inválidos.",
    };
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", authData.user.id)
    .maybeSingle();

  if (profileError || !profile || !isUserRole(profile.role)) {
    await supabase.auth.signOut({ scope: "local" });

    return {
      status: "error",
      message: "Seu acesso não está ativo. Procure a Ortusolis.",
    };
  }

  revalidatePath("/", "layout");
  redirect(homePathForRole(profile.role));
}

export async function requestPasswordResetAction(
  _previousState: AuthActionState,
  formData: FormData,
): Promise<AuthActionState> {
  const email = formText(formData, "email").toLowerCase();

  if (!email) {
    return {
      status: "error",
      message: "Informe seu e-mail.",
    };
  }

  const origin = await getRequestOrigin();
  const supabase = await createClient();
  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: `${origin}/auth/callback`,
  });

  if (error) {
    return {
      status: "error",
      message: "Não foi possível enviar o e-mail agora. Tente novamente.",
    };
  }

  return {
    status: "success",
    message:
      "Se o e-mail estiver cadastrado, você receberá as instruções para redefinir a senha.",
  };
}

export async function updatePasswordAction(
  _previousState: AuthActionState,
  formData: FormData,
): Promise<AuthActionState> {
  const password = formValue(formData, "password");
  const confirmation = formValue(formData, "password_confirmation");

  if (password.length < 8) {
    return {
      status: "error",
      message: "A nova senha deve ter pelo menos 8 caracteres.",
    };
  }

  if (password !== confirmation) {
    return {
      status: "error",
      message: "As senhas não coincidem.",
    };
  }

  const supabase = await createClient();
  const { data: claimsData, error: claimsError } =
    await supabase.auth.getClaims();

  if (claimsError || !claimsData?.claims.sub) {
    return {
      status: "error",
      message: "O link expirou. Solicite uma nova recuperação de senha.",
    };
  }

  const { error: updateError } = await supabase.auth.updateUser({ password });

  if (updateError) {
    return {
      status: "error",
      message: "Não foi possível atualizar a senha. Solicite um novo link.",
    };
  }

  await supabase.auth.signOut({ scope: "local" });
  revalidatePath("/", "layout");
  redirect("/login?notice=password-updated");
}

export async function logoutAction() {
  const supabase = await createClient();
  await supabase.auth.signOut({ scope: "local" });
  revalidatePath("/", "layout");
  redirect("/login");
}
