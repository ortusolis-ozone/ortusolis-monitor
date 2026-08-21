import Link from "next/link";

import { PasswordResetRequestForm } from "./password-reset-request-form";

export default function ForgotPasswordPage() {
  return (
    <section className="auth-card" aria-labelledby="forgot-password-title">
      <div className="auth-heading">
        <p className="eyebrow">Recuperação de acesso</p>
        <h1 id="forgot-password-title">Redefina sua senha</h1>
        <p>Informe o e-mail usado no seu cadastro.</p>
      </div>

      <PasswordResetRequestForm />

      <Link className="text-link" href="/login">
        Voltar para o login
      </Link>
    </section>
  );
}
