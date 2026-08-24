"use client";

import {
  createContext,
  type FormEvent,
  type ReactNode,
  useActionState,
  useContext,
} from "react";

import {
  initialOperationalActionState,
  type OperationalActionState,
} from "@/lib/operations/action-state";

type OperationalAction = (
  state: OperationalActionState,
  formData: FormData,
) => Promise<OperationalActionState>;

const ActionStateContext = createContext<OperationalActionState>(
  initialOperationalActionState,
);

type OperationalFormProps = {
  action: OperationalAction;
  children: ReactNode;
  submitLabel: string;
  pendingLabel?: string;
  confirmation?: string;
  className?: string;
  buttonClassName?: string;
};

export function OperationalForm({
  action,
  children,
  submitLabel,
  pendingLabel = "Salvando...",
  confirmation,
  className = "operational-form",
  buttonClassName = "primary-button",
}: OperationalFormProps) {
  const [state, formAction, pending] = useActionState(
    action,
    initialOperationalActionState,
  );

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    if (confirmation && !window.confirm(confirmation)) {
      event.preventDefault();
    }
  }

  return (
    <ActionStateContext.Provider value={state}>
      <form action={formAction} className={className} onSubmit={handleSubmit}>
        {children}

        {state.message ? (
          <p
            aria-live="polite"
            className={`form-message ${state.status === "success" ? "success" : "error"}`}
          >
            {state.message}
          </p>
        ) : null}

        <button className={buttonClassName} disabled={pending} type="submit">
          {pending ? pendingLabel : submitLabel}
        </button>
      </form>
    </ActionStateContext.Provider>
  );
}

export function FieldError({ name }: { name: string }) {
  const state = useContext(ActionStateContext);
  const message = state.fieldErrors?.[name];

  return message ? (
    <span className="field-error" role="alert">
      {message}
    </span>
  ) : null;
}
