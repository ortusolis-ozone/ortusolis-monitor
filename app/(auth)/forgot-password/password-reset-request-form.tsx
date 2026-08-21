"use client";

import { useActionState } from "react";
import { useFormStatus } from "react-dom";

import { initialAuthActionState } from "@/lib/auth/action-state";
import { requestPasswordResetAction } from "@/lib/auth/actions";

function SubmitButton() {
  const { pending } = useFormStatus();

  return (
    <button className="primary-button" type="submit" disabled={pending}>
      {pending ? "Enviando..." : "Enviar instruções"}
    </button>
  );
}

export function PasswordResetRequestForm() {
  const [state, formAction] = useActionState(
    requestPasswordResetAction,
    initialAuthActionState,
  );

  return (
    <form action={formAction} className="auth-form">
      <label htmlFor="email">E-mail</label>
      <input
        id="email"
        name="email"
        type="email"
        autoComplete="email"
        required
      />

      {state.status !== "idle" ? (
        <p
          className={`form-message ${state.status}`}
          role={state.status === "error" ? "alert" : "status"}
        >
          {state.message}
        </p>
      ) : null}

      <SubmitButton />
    </form>
  );
}
