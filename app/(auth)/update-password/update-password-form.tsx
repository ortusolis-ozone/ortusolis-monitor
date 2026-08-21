"use client";

import { useActionState } from "react";
import { useFormStatus } from "react-dom";

import { initialAuthActionState } from "@/lib/auth/action-state";
import { updatePasswordAction } from "@/lib/auth/actions";

function SubmitButton() {
  const { pending } = useFormStatus();

  return (
    <button className="primary-button" type="submit" disabled={pending}>
      {pending ? "Atualizando..." : "Salvar nova senha"}
    </button>
  );
}

export function UpdatePasswordForm() {
  const [state, formAction] = useActionState(
    updatePasswordAction,
    initialAuthActionState,
  );

  return (
    <form action={formAction} className="auth-form">
      <label htmlFor="password">Nova senha</label>
      <input
        id="password"
        name="password"
        type="password"
        autoComplete="new-password"
        minLength={8}
        required
      />

      <label htmlFor="password_confirmation">Confirme a nova senha</label>
      <input
        id="password_confirmation"
        name="password_confirmation"
        type="password"
        autoComplete="new-password"
        minLength={8}
        required
      />

      {state.status === "error" ? (
        <p className="form-message error" role="alert">
          {state.message}
        </p>
      ) : null}

      <SubmitButton />
    </form>
  );
}
