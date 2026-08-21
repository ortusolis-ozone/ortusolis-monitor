"use client";

import Link from "next/link";
import { useActionState } from "react";
import { useFormStatus } from "react-dom";

import { initialAuthActionState } from "@/lib/auth/action-state";
import { loginAction } from "@/lib/auth/actions";

function SubmitButton() {
  const { pending } = useFormStatus();

  return (
    <button className="primary-button" type="submit" disabled={pending}>
      {pending ? "Entrando..." : "Entrar"}
    </button>
  );
}

export function LoginForm() {
  const [state, formAction] = useActionState(
    loginAction,
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

      <label htmlFor="password">Senha</label>
      <input
        id="password"
        name="password"
        type="password"
        autoComplete="current-password"
        required
      />

      {state.status === "error" ? (
        <p className="form-message error" role="alert">
          {state.message}
        </p>
      ) : null}

      <SubmitButton />

      <Link className="text-link" href="/forgot-password">
        Esqueci minha senha
      </Link>
    </form>
  );
}
