import { redirect } from "next/navigation";

import { LoginForm } from "./login-form";
import { getCurrentProfile, homePathForRole } from "@/lib/auth/profile";

type LoginPageProps = {
  searchParams: Promise<{ notice?: string | string[] }>;
};

export default async function LoginPage({ searchParams }: LoginPageProps) {
  const profile = await getCurrentProfile();

  if (profile) {
    redirect(homePathForRole(profile.role));
  }

  const { notice } = await searchParams;
  const noticeMessage =
    notice === "password-updated"
      ? "Senha atualizada. Entre novamente para continuar."
      : notice === "invalid-auth-link"
        ? "O link é inválido ou expirou. Solicite um novo link."
        : null;

  return (
    <section className="auth-card" aria-labelledby="login-title">
      <div className="auth-heading">
        <p className="eyebrow">Monitoramento operacional</p>
        <h1 id="login-title">Acesse sua conta</h1>
        <p>Consulte os registros vinculados ao seu acesso.</p>
      </div>

      {noticeMessage ? (
        <p
          className={`form-message ${
            notice === "password-updated" ? "success" : "error"
          }`}
          role={notice === "password-updated" ? "status" : "alert"}
        >
          {noticeMessage}
        </p>
      ) : null}

      <LoginForm />
    </section>
  );
}
