"use client";

import { useActionState, useEffect, useRef } from "react";

import {
  updateAdminEmailAction,
  updateAdminNameAction,
  updateAdminPasswordAction,
} from "@/lib/account/actions";
import {
  initialAccountActionState,
  type AccountActionState,
} from "@/lib/account/action-state";

function FieldError({
  field,
  form,
  state,
}: {
  field: string;
  form: string;
  state: AccountActionState;
}) {
  const message = state.fieldErrors?.[field];

  return message ? (
    <span className="field-error" id={`${form}-${field}-error`} role="alert">
      {message}
    </span>
  ) : null;
}

function FormMessage({ state }: { state: AccountActionState }) {
  return state.message ? (
    <p
      aria-live="polite"
      className={`form-message ${state.status === "success" ? "success" : "error"}`}
    >
      {state.message}
    </p>
  ) : null;
}

function NameForm({ fullName }: { fullName: string }) {
  const [state, formAction, pending] = useActionState(
    updateAdminNameAction,
    initialAccountActionState,
  );
  const invalid = Boolean(state.fieldErrors?.full_name);

  return (
    <form action={formAction} className="operational-form profile-form">
      <label>
        Nome do usuário
        <input
          aria-describedby={invalid ? "name-form-full_name-error" : undefined}
          aria-invalid={invalid}
          autoComplete="name"
          defaultValue={fullName}
          maxLength={120}
          name="full_name"
          required
        />
        <FieldError field="full_name" form="name-form" state={state} />
      </label>
      <FormMessage state={state} />
      <button className="primary-button" disabled={pending} type="submit">
        {pending ? "Salvando nome..." : "Salvar nome"}
      </button>
    </form>
  );
}

function EmailForm({ email }: { email: string }) {
  const [state, formAction, pending] = useActionState(
    updateAdminEmailAction,
    initialAccountActionState,
  );
  const invalidEmail = Boolean(state.fieldErrors?.email);
  const invalidPassword = Boolean(state.fieldErrors?.current_password);

  return (
    <form action={formAction} className="operational-form profile-form">
      <label>
        E-mail de acesso
        <input
          aria-describedby={invalidEmail ? "email-form-email-error" : undefined}
          aria-invalid={invalidEmail}
          autoComplete="username"
          defaultValue={email}
          maxLength={254}
          name="email"
          required
          type="email"
        />
        <FieldError field="email" form="email-form" state={state} />
      </label>
      <label>
        Senha atual
        <input
          aria-describedby={
            invalidPassword ? "email-form-current_password-error" : undefined
          }
          aria-invalid={invalidPassword}
          autoComplete="current-password"
          name="current_password"
          required
          type="password"
        />
        <FieldError
          field="current_password"
          form="email-form"
          state={state}
        />
      </label>
      <p className="profile-security-note">
        A senha atual confirma que é você quem está alterando o login.
      </p>
      <FormMessage state={state} />
      <button className="primary-button" disabled={pending} type="submit">
        {pending ? "Salvando e-mail..." : "Salvar e-mail"}
      </button>
    </form>
  );
}

function PasswordForm({ email }: { email: string }) {
  const [state, formAction, pending] = useActionState(
    updateAdminPasswordAction,
    initialAccountActionState,
  );
  const formRef = useRef<HTMLFormElement>(null);

  useEffect(() => {
    if (state.status === "success") formRef.current?.reset();
  }, [state.status]);

  return (
    <form
      action={formAction}
      className="operational-form profile-form profile-password-form"
      ref={formRef}
    >
      <label className="sr-only">
        E-mail de acesso
        <input
          autoComplete="username"
          defaultValue={email}
          name="username"
          readOnly
          tabIndex={-1}
          type="email"
        />
      </label>
      <label>
        Senha atual
        <input
          aria-describedby={
            state.fieldErrors?.current_password
              ? "password-form-current_password-error"
              : undefined
          }
          aria-invalid={Boolean(state.fieldErrors?.current_password)}
          autoComplete="current-password"
          name="current_password"
          required
          type="password"
        />
        <FieldError
          field="current_password"
          form="password-form"
          state={state}
        />
      </label>
      <label>
        Nova senha
        <input
          aria-describedby={
            state.fieldErrors?.new_password
              ? "password-form-new_password-error"
              : "password-requirements"
          }
          aria-invalid={Boolean(state.fieldErrors?.new_password)}
          autoComplete="new-password"
          maxLength={128}
          minLength={8}
          name="new_password"
          required
          type="password"
        />
        <span className="field-hint" id="password-requirements">
          Use pelo menos 8 caracteres e evite senhas previsíveis.
        </span>
        <FieldError field="new_password" form="password-form" state={state} />
      </label>
      <label>
        Confirmar nova senha
        <input
          aria-describedby={
            state.fieldErrors?.password_confirmation
              ? "password-form-password_confirmation-error"
              : undefined
          }
          aria-invalid={Boolean(state.fieldErrors?.password_confirmation)}
          autoComplete="new-password"
          maxLength={128}
          minLength={8}
          name="password_confirmation"
          required
          type="password"
        />
        <FieldError
          field="password_confirmation"
          form="password-form"
          state={state}
        />
      </label>
      <FormMessage state={state} />
      <button className="primary-button" disabled={pending} type="submit">
        {pending ? "Alterando senha..." : "Alterar senha"}
      </button>
    </form>
  );
}

export function AdminProfileForms({
  email,
  fullName,
}: {
  email: string;
  fullName: string;
}) {
  return (
    <section aria-label="Configurações da conta" className="profile-settings-grid">
      <article className="profile-settings-card">
        <header>
          <p className="eyebrow">Identificação</p>
          <h2>Nome do usuário</h2>
          <p>Este nome aparece no cabeçalho e nos registros administrativos.</p>
        </header>
        <NameForm fullName={fullName} />
      </article>

      <article className="profile-settings-card">
        <header>
          <p className="eyebrow">Login</p>
          <h2>E-mail</h2>
          <p>O endereço usado para entrar no painel e recuperar o acesso.</p>
        </header>
        <EmailForm email={email} />
      </article>

      <article className="profile-settings-card profile-settings-card-wide">
        <header>
          <p className="eyebrow">Segurança</p>
          <h2>Senha</h2>
          <p>Confirme a senha atual antes de definir uma nova credencial.</p>
        </header>
        <PasswordForm email={email} />
      </article>
    </section>
  );
}
