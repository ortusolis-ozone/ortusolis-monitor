export type AccountValidationError = {
  field: string;
  message: string;
};

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function normalizeAccountEmail(value: string) {
  return value.trim().toLowerCase();
}

export function validateAccountName(value: string): AccountValidationError | null {
  if (!value) {
    return { field: "full_name", message: "Informe o nome do usuário." };
  }

  if (value.length > 120) {
    return {
      field: "full_name",
      message: "O nome deve ter no máximo 120 caracteres.",
    };
  }

  return null;
}

export function validateAccountEmail(
  value: string,
): AccountValidationError | null {
  if (!emailPattern.test(value) || value.length > 254) {
    return { field: "email", message: "Informe um e-mail válido." };
  }

  return null;
}

export function validateCurrentPassword(
  value: string,
): AccountValidationError | null {
  return value
    ? null
    : { field: "current_password", message: "Informe sua senha atual." };
}

export function validatePasswordChange({
  currentPassword,
  newPassword,
  confirmation,
}: {
  currentPassword: string;
  newPassword: string;
  confirmation: string;
}): AccountValidationError | null {
  const invalidCurrentPassword = validateCurrentPassword(currentPassword);

  if (invalidCurrentPassword) return invalidCurrentPassword;

  if (newPassword.length < 8) {
    return {
      field: "new_password",
      message: "A nova senha deve ter pelo menos 8 caracteres.",
    };
  }

  if (newPassword.length > 128) {
    return {
      field: "new_password",
      message: "A nova senha deve ter no máximo 128 caracteres.",
    };
  }

  if (newPassword === currentPassword) {
    return {
      field: "new_password",
      message: "A nova senha deve ser diferente da senha atual.",
    };
  }

  if (newPassword !== confirmation) {
    return {
      field: "password_confirmation",
      message: "As senhas não coincidem.",
    };
  }

  return null;
}
