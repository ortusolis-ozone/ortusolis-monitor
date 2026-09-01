import { AdminProfileForms } from "@/components/admin-profile-forms";
import { getAdminAccount } from "@/lib/account/queries";

export default async function AdminProfilePage() {
  const account = await getAdminAccount();

  return (
    <main className="admin-main">
      <section className="page-heading">
        <p className="eyebrow">Conta Master</p>
        <h1>Meu perfil</h1>
        <p>
          Atualize sua identificação e as credenciais usadas para acessar o
          painel administrativo.
        </p>
      </section>

      <AdminProfileForms email={account.email} fullName={account.fullName} />
    </main>
  );
}
