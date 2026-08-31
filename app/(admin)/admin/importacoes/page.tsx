import { ImportWorkflow } from "@/components/import-workflow";
import { getImportPageData } from "@/lib/imports/queries";

export default async function ImportsPage() {
  const { profileId, options, recentBatches } = await getImportPageData();

  return (
    <main className="admin-main">
      <section className="page-heading">
        <p className="eyebrow">Importação operacional</p>
        <h1>Estado e telemetria do eWeLink</h1>
        <p>
          Valide o arquivo no contexto correto, revise a prévia e confirme sem
          duplicar eventos de estado ou leituras de potência.
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
