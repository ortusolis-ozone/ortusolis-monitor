import { AppHeader } from "@/components/app-header";
import { requireMaster } from "@/lib/auth/profile";

export default async function AdminPage() {
  const profile = await requireMaster();

  return (
    <main className="app-shell">
      <AppHeader area="Administração" userName={profile.fullName} />
      <section className="content-card">
        <p className="eyebrow">Acesso Master</p>
        <h1>Área administrativa</h1>
        <p>
          A autenticação está pronta. Os cadastros e fluxos operacionais entram
          nas próximas especificações.
        </p>
      </section>
    </main>
  );
}
