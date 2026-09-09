"use client";

import {
  createContext,
  type FormEvent,
  type ReactNode,
  startTransition,
  useActionState,
  useContext,
  useEffect,
  useRef,
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
  const formRef = useRef<HTMLFormElement>(null);

  useEffect(() => {
    if (state.status === "success") {
      formRef.current?.reset();
      return;
    }

    const firstInvalidField = Object.keys(state.fieldErrors ?? {})[0];
    const field = firstInvalidField
      ? formRef.current?.elements.namedItem(firstInvalidField)
      : null;

    if (field instanceof HTMLElement) {
      field.focus({ preventScroll: true });
      field.scrollIntoView({ behavior: "smooth", block: "center" });
    }
  }, [state]);

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    if (confirmation && !window.confirm(confirmation)) {
      event.preventDefault();
      return;
    }

    event.preventDefault();
    const formData = new FormData(event.currentTarget);

    startTransition(() => {
      formAction(formData);
    });
  }

  return (
    <ActionStateContext.Provider value={state}>
      <form
        action={formAction}
        className={className}
        onSubmit={handleSubmit}
        ref={formRef}
      >
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

export function useOperationalFieldError(name: string) {
  return useContext(ActionStateContext).fieldErrors?.[name];
}
