"use client";

export default function PortalError({ reset }: { reset: () => void }) {
  return (
    <main className="app-shell client-portal-shell">
      <section className="portal-error-state" role="alert">
        <p className="eyebrow">Consulta indisponível</p>
        <h1>Não foi possível carregar os registros</h1>
        <p>
          Tente novamente. Se a dificuldade continuar, fale com a equipe
          responsável pelo monitoramento.
        </p>
        <button className="primary-button" onClick={reset} type="button">
          Tentar novamente
        </button>
      </section>
    </main>
  );
}
