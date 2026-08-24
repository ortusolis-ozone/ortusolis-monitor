import { ImportWorkflow } from "@/components/import-workflow";
import { getImportPageData } from "@/lib/imports/queries";

export default async function ImportsPage() {
  const { profileId, options, recentBatches } = await getImportPageData();

  return (
    <main className="admin-main">
      <section className="page-heading">
        <p className="eyebrow">Importação operacional</p>
        <h1>Eventos do eWeLink</h1>
        <p>
          Valide o arquivo no contexto correto, revise a prévia e confirme sem
          criar eventos duplicados.
        </p>
      </section>

      <ImportWorkflow
        options={options}
        profileId={profileId}
        recentBatches={recentBatches}
      />
    </main>
  );
}
