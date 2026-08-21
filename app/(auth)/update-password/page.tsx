import { redirect } from "next/navigation";

import { UpdatePasswordForm } from "./update-password-form";
import { createClient } from "@/lib/supabase/server";

export default async function UpdatePasswordPage() {
  const supabase = await createClient();
  const { data, error } = await supabase.auth.getClaims();

  if (error || !data?.claims.sub) {
    redirect("/login");
  }

  return (
    <section className="auth-card" aria-labelledby="update-password-title">
      <div className="auth-heading">
        <p className="eyebrow">Segurança</p>
        <h1 id="update-password-title">Crie uma nova senha</h1>
        <p>Use pelo menos 8 caracteres.</p>
      </div>

      <UpdatePasswordForm />
    </section>
  );
}
