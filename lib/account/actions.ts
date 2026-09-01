"use server";

import { revalidatePath } from "next/cache";

import { requireMaster } from "@/lib/auth/profile";
import {
  createAdminClient,
  createPasswordVerificationClient,
} from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";

import {
  accountFieldError,
  type AccountActionState,
} from "./action-state";
import {
  normalizeAccountEmail,
  validateAccountEmail,
  validateAccountName,
  validateCurrentPassword,
  validatePasswordChange,
} from "./validation";

function formText(formData: FormData, field: string) {
  const value = formData.get(field);
  return typeof value === "string" ? value.trim() : "";
}

function formValue(formData: FormData, field: string) {
  const value = formData.get(field);
  return typeof value === "string" ? value : "";
}

function validationError({
  field,
  message,
}: {
  field: string;
  message: string;
}): AccountActionState {
  return accountFieldError(field, message);
}

function success(message: string): AccountActionState {
  revalidatePath("/admin", "layout");
  return { status: "success", message };
}

async function verifyMasterPassword({
  expectedUserId,
  email,
  password,
}: {
  expectedUserId: string;
  email: string;
  password: string;
}) {
  const verificationClient = createPasswordVerificationClient();
  const { data, error } = await verificationClient.auth.signInWithPassword({
    email,
    password,
  });

  const verified = !error && data.user?.id === expectedUserId;

  if (data.session) {
    await verificationClient.auth.signOut({ scope: "local" });
  }

  return verified;
}

async function getVerifiedMaster(currentPassword: string) {
  const profile = await requireMaster();
  const admin = createAdminClient();
  const { data, error } = await admin.auth.admin.getUserById(profile.id);
  const email = data.user?.email;

  if (error || !data.user || !email) {
    return { status: "account-error" as const };
  }

  const verified = await verifyMasterPassword({
    expectedUserId: profile.id,
    email,
    password: currentPassword,
  });

  if (!verified) {
    return { status: "password-error" as const };
  }

  return { status: "verified" as const, admin, email, profile };
}

export async function updateAdminNameAction(
  _previousState: AccountActionState,
  formData: FormData,
): Promise<AccountActionState> {
  const profile = await requireMaster();
  const fullName = formText(formData, "full_name");
  const invalidName = validateAccountName(fullName);

  if (invalidName) return validationError(invalidName);

  if (fullName === profile.fullName) {
    return { status: "success", message: "O nome já está atualizado." };
  }

  const supabase = await createClient();
  const { data, error } = await supabase
    .from("profiles")
    .update({ full_name: fullName })
    .eq("id", profile.id)
    .eq("role", "master")
    .select("id")
    .maybeSingle();

  if (error || !data) {
    return {
      status: "error",
      message: "Não foi possível atualizar o nome. Tente novamente.",
    };
  }

  return success("Nome atualizado com sucesso.");
}

export async function updateAdminEmailAction(
  _previousState: AccountActionState,
  formData: FormData,
): Promise<AccountActionState> {
  const email = normalizeAccountEmail(formText(formData, "email"));
  const currentPassword = formValue(formData, "current_password");
  const invalidEmail = validateAccountEmail(email);
  const invalidPassword = validateCurrentPassword(currentPassword);

  if (invalidEmail) return validationError(invalidEmail);
  if (invalidPassword) return validationError(invalidPassword);

  const verification = await getVerifiedMaster(currentPassword);

  if (verification.status === "account-error") {
    return {
      status: "error",
      message: "Não foi possível validar a conta Master. Tente novamente.",
    };
  }

  if (verification.status === "password-error") {
    return accountFieldError("current_password", "A senha atual está incorreta.");
  }

  if (verification.email.toLowerCase() === email) {
    return { status: "success", message: "O e-mail já está atualizado." };
  }

  const { error } = await verification.admin.auth.admin.updateUserById(
    verification.profile.id,
    { email, email_confirm: true },
  );

  if (error) {
    const duplicateEmail =
      error.code === "email_exists" || error.code === "user_already_exists";

    return duplicateEmail
      ? accountFieldError("email", "Esse e-mail já possui uma conta.")
      : {
          status: "error",
          message: "Não foi possível atualizar o e-mail. Tente novamente.",
        };
  }

  const sessionClient = await createClient();
  await sessionClient.auth.refreshSession();

  return success("E-mail atualizado. Use o novo endereço no próximo acesso.");
}

export async function updateAdminPasswordAction(
  _previousState: AccountActionState,
  formData: FormData,
): Promise<AccountActionState> {
  const currentPassword = formValue(formData, "current_password");
  const newPassword = formValue(formData, "new_password");
  const confirmation = formValue(formData, "password_confirmation");
  const invalidPassword = validatePasswordChange({
    currentPassword,
    newPassword,
    confirmation,
  });

  if (invalidPassword) return validationError(invalidPassword);

  const verification = await getVerifiedMaster(currentPassword);

  if (verification.status === "account-error") {
    return {
      status: "error",
      message: "Não foi possível validar a conta Master. Tente novamente.",
    };
  }

  if (verification.status === "password-error") {
    return accountFieldError("current_password", "A senha atual está incorreta.");
  }

  const { error } = await verification.admin.auth.admin.updateUserById(
    verification.profile.id,
    { password: newPassword },
  );

  if (error) {
    return error.code === "weak_password"
      ? accountFieldError(
          "new_password",
          "Escolha uma senha mais forte e menos previsível.",
        )
      : {
          status: "error",
          message: "Não foi possível atualizar a senha. Tente novamente.",
        };
  }

  return { status: "success", message: "Senha atualizada com sucesso." };
}
