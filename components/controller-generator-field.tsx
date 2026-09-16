"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { FieldError } from "./operational-form";

export function ControllerGeneratorField({ generators }: {
  generators: { id: string; label: string }[];
}) {
  const [generatorId, setGeneratorId] = useState("");
  const selectRef = useRef<HTMLSelectElement>(null);

  useEffect(() => {
    const form = selectRef.current?.form;
    const reset = () => setGeneratorId("");
    form?.addEventListener("reset", reset);
    return () => form?.removeEventListener("reset", reset);
  }, []);

  return <>
    <label>
      Gerador
      <select ref={selectRef} name="generator_id" required onChange={(event) => setGeneratorId(event.target.value)}>
        <option value="">Selecione</option>
        {generators.map((generator) => (
          <option key={generator.id} value={generator.id}>{generator.label}</option>
        ))}
      </select>
      <FieldError name="generator_id" />
    </label>
    <p className="field-hint">
      A potência nominal pertence ao gerador. O mínimo aceitável é calculado em 85%; os limites do controlador detectam liga/desliga.
      {generatorId ? <>
        {" "}<Link className="text-link" href={`/admin/geradores/${generatorId}#edit-power-title`} target="_blank" rel="noopener noreferrer">
          Configurar potência nominal do gerador (abre em nova aba)
        </Link>
      </> : " Selecione um gerador para acessar a configuração nominal."}
    </p>
  </>;
}
