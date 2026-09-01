import { describe, expect, test } from "vitest";

import {
  normalizeAccountEmail,
  validateAccountEmail,
  validateAccountName,
  validatePasswordChange,
} from "./validation";

describe("account validation", () => {
  test("normalizes and validates an account email", () => {
    const email = normalizeAccountEmail("  ADMIN@Ortusolis.com.br ");

    expect(email).toBe("admin@ortusolis.com.br");
    expect(validateAccountEmail(email)).toBeNull();
    expect(validateAccountEmail("admin@ortusolis")).toEqual({
      field: "email",
      message: "Informe um e-mail válido.",
    });
  });

  test("requires a bounded account name", () => {
    expect(validateAccountName("")?.field).toBe("full_name");
    expect(validateAccountName("A".repeat(121))?.field).toBe("full_name");
    expect(validateAccountName("Administrador Ortusolis")).toBeNull();
  });

  test("validates current password, strength and confirmation", () => {
    expect(
      validatePasswordChange({
        currentPassword: "",
        newPassword: "nova-senha",
        confirmation: "nova-senha",
      })?.field,
    ).toBe("current_password");
    expect(
      validatePasswordChange({
        currentPassword: "senha-atual",
        newPassword: "curta",
        confirmation: "curta",
      })?.field,
    ).toBe("new_password");
    expect(
      validatePasswordChange({
        currentPassword: "senha-atual",
        newPassword: "senha-atual",
        confirmation: "senha-atual",
      })?.field,
    ).toBe("new_password");
    expect(
      validatePasswordChange({
        currentPassword: "senha-atual",
        newPassword: "nova-senha-segura",
        confirmation: "outra-senha",
      })?.field,
    ).toBe("password_confirmation");
    expect(
      validatePasswordChange({
        currentPassword: "senha-atual",
        newPassword: "nova-senha-segura",
        confirmation: "nova-senha-segura",
      }),
    ).toBeNull();
  });
});
