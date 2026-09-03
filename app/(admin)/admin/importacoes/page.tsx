import { ImportHistory } from "@/components/import-history";
import { ImportWorkflow } from "@/components/import-workflow";
import { getImportPageData } from "@/lib/imports/queries";

export default async function ImportsPage() {
  const {
    profileId,
    options,
    latestSources,
    recentSessions,
    legacyBatches,
  } = await getImportPageData();

  return (
    <main className="admin-main">
      <section className="page-heading">
        <p className="eyebrow">Importação operacional</p>
        <h1>Estado e telemetria do eWeLink</h1>
        <p>
          Reúna os horários programados e a potência consumida na mesma
          atualização, valide a cobertura e confirme os dois lotes de forma
          atômica.
        </p>
      </section>

      <ImportWorkflow
        latestSources={latestSources}
        options={options}
        profileId={profileId}
      />

      <ImportHistory
        legacyBatches={legacyBatches}
        recentSessions={recentSessions}
      />
    </main>
  );
}
