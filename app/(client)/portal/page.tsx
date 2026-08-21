import { AppHeader } from "@/components/app-header";
import { requireClientProfile } from "@/lib/auth/profile";

export default async function PortalPage() {
  const profile = await requireClientProfile();

  return (
    <main className="app-shell">
      <AppHeader area="Portal do cliente" userName={profile.fullName} />
      <section className="content-card">
        <p className="eyebrow">Acesso do cliente</p>
        <h1>Registros da sua empresa</h1>
        <p>
          Seu acesso está ativo. A consulta dos estados públicos será
          implementada na especificação do portal.
        </p>
      </section>
    </main>
  );
}
