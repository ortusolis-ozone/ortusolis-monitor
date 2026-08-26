"use client";

import { useEffect } from "react";

export default function AdminError({
  error,
  retry,
}: {
  error: Error & { digest?: string };
  retry: () => void;
}) {
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <main className="admin-main">
      <section className="listing-card admin-error-state" role="alert">
        <p className="eyebrow">Não foi possível carregar</p>
        <h1>O painel encontrou um erro</h1>
        <p>
          Os dados não foram alterados. Tente consultar novamente; se o erro
          continuar, verifique a conexão com o banco.
        </p>
        <button className="primary-button" onClick={retry} type="button">
          Tentar novamente
        </button>
      </section>
    </main>
  );
}
