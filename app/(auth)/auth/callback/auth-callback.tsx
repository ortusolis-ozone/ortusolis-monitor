"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";

import { createAuthCallbackClient } from "@/lib/supabase/client";

type CallbackStatus = "validating" | "error";

export function AuthCallback() {
  const started = useRef(false);
  const [status, setStatus] = useState<CallbackStatus>("validating");

  useEffect(() => {
    if (started.current) {
      return;
    }

    started.current = true;

    async function completeAuthentication() {
      const callbackUrl = new URL(window.location.href);
      const fragment = new URLSearchParams(callbackUrl.hash.slice(1));
      const code = callbackUrl.searchParams.get("code");
      const accessToken = fragment.get("access_token");
      const refreshToken = fragment.get("refresh_token");
      const callbackError =
        callbackUrl.searchParams.get("error") ?? fragment.get("error");

      window.history.replaceState(
        window.history.state,
        "",
        callbackUrl.pathname,
      );

      if (callbackError || (!code && (!accessToken || !refreshToken))) {
        setStatus("error");
        return;
      }

      const supabase = createAuthCallbackClient();
      const { error } = code
        ? await supabase.auth.exchangeCodeForSession(code)
        : await supabase.auth.setSession({
            access_token: accessToken!,
            refresh_token: refreshToken!,
          });

      if (error) {
        setStatus("error");
        return;
      }

      window.location.replace("/update-password");
    }

    void completeAuthentication().catch(() => {
      setStatus("error");
    });
  }, []);

  const hasError = status === "error";

  return (
    <section
      className="auth-card"
      aria-busy={!hasError}
      aria-labelledby="auth-callback-title"
    >
      <div className="auth-heading">
        <p className="eyebrow">Acesso seguro</p>
        <h1 id="auth-callback-title">
          {hasError ? "Não foi possível validar o link" : "Validando seu acesso"}
        </h1>
        <p>
          {hasError
            ? "O link pode ter expirado ou já ter sido utilizado."
            : "Aguarde um instante para criar sua senha no Ortusolis Monitor."}
        </p>
      </div>

      {hasError ? (
        <>
          <p className="form-message error" role="alert">
            Solicite um novo link para continuar com segurança.
          </p>
          <Link className="text-link" href="/forgot-password">
            Solicitar novo link
          </Link>
        </>
      ) : (
        <p className="form-message success" role="status" aria-live="polite">
          Preparando a criação da sua senha...
        </p>
      )}
    </section>
  );
}
