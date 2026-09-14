import Link from "next/link";
import type { PowerDiagnostic, PowerDiagnosticInconsistency, PowerDiagnosticRun } from "@/lib/admin/power-diagnostics";
import { correlationLabels, diagnosticReasons, operationalLabels, reprocessingReasons } from "@/lib/admin/power-diagnostic-labels";
import { inconsistencyStatusLabel, inconsistencyTypeLabel } from "@/lib/admin/constants";
import { formatPower, formatPowerDate } from "@/lib/operations/power-profiles/format";
import { reviewInconsistencyAction } from "@/lib/admin/actions";
import { FieldError, OperationalForm } from "./operational-form";

function power(value: string | null) { return value === null ? "Indisponível" : formatPower(value); }
function reason(value: string) { return diagnosticReasons[value] ?? value; }

export function ApplicationPowerDiagnostic({ diagnostic: d, inconsistencies, runs }: {
  diagnostic: PowerDiagnostic; inconsistencies: PowerDiagnosticInconsistency[]; runs: PowerDiagnosticRun[];
}) {
  return <>
    <section className="power-detail-card" aria-labelledby="diagnostic-title">
      <h2 id="diagnostic-title">Aplicação registrada</h2>
      <p>{formatPowerDate(d.start_at)} — {formatPowerDate(d.end_at)} · Horários de Fortaleza</p>
      <div className="power-detail-grid">
        <div><h3>Correlação elétrica</h3><p>{correlationLabels[d.correlation_status] ?? d.correlation_status}</p><p>{reason(d.correlation_reason)}</p><small>Código: {d.correlation_reason}</small></div>
        <div><h3>Avaliação operacional</h3><p className={d.operational_status === "below_expected" ? "power-pending" : undefined}>{operationalLabels[d.operational_status] ?? d.operational_status}</p><p>{reason(d.operational_reason)}</p><small>Código: {d.operational_reason}</small></div>
      </div>
      <dl className="power-values">
        <div><dt>Potência nominal utilizada</dt><dd>{power(d.nominal_power_w)}</dd></div>
        <div><dt>Mínimo calculado utilizado</dt><dd>{power(d.minimum_power_w)}</dd></div>
        <div><dt>Potência observada no início</dt><dd>{power(d.observed_power_w)}</dd></div>
        <div><dt>Diferença absoluta em relação ao nominal</dt><dd>{power(d.difference_w)}</dd></div>
        <div><dt>Variação em relação ao nominal</dt><dd>{d.difference_percent === null ? "Indisponível" : formatPower(d.difference_percent).replace(/ W$/, "%")}</dd></div>
      </dl>
      <p>A variação é (observado − nominal) ÷ nominal. Percentual negativo indica consumo menor que o nominal.</p>
      <p>Verifique o equipamento e a coleta quando o consumo estiver abaixo do esperado. A leitura pontual não comprova defeito nem permite concluir ausência de geração de ozônio.</p>
      <p>Reconhecer uma inconsistência ou registrar uma nota não modifica o resultado da avaliação operacional.</p>
      {d.operational_status === "not_configured" ? <Link href={`/admin/geradores/${d.generator_id}`}>Completar a configuração nominal para o período da aplicação</Link> : null}
      <p>Regra: {d.rule_version ?? "Indisponível"} · Avaliação atualizada em {d.evaluated_at ? formatPowerDate(d.evaluated_at) : "data indisponível"}.</p>
    </section>

    <section className="power-detail-card" aria-labelledby="diagnostic-origin-title">
      <h2 id="diagnostic-origin-title">Origem da avaliação</h2>
      <dl className="power-values diagnostic-origins">
        <div><dt>Leitura de referência</dt><dd>{d.reference_reading_id === null ? "Sem leitura de início válida" : `#${d.reference_reading_id} · ${formatPowerDate(d.reference_reading_at)}`}</dd></div>
        <div><dt>Controlador de potência</dt><dd>{d.power_controller_identifier ?? "Indisponível"}<br />{d.power_controller_id}</dd></div>
        <div><dt>Arquivo de potência</dt><dd>{d.power_file_name ?? "Sem arquivo de referência"}<br />Lote: {d.power_batch_id ?? "Indisponível"}</dd></div>
        <div><dt>Perfil nominal utilizado</dt><dd>{d.power_profile_id ?? "Sem perfil vigente no início"}{d.profile_valid_from ? <><br />{formatPowerDate(d.profile_valid_from)} — {formatPowerDate(d.profile_valid_until)}</> : null}</dd></div>
        <div><dt>Controlador de estado</dt><dd>{d.state_controller_identifier}<br />{d.state_controller_id}</dd></div>
        <div><dt>Evento Ligar</dt><dd>#{d.start_event_id} · {d.state_file_name}<br />Lote: {d.state_batch_id}</dd></div>
        <div><dt>Evento Desligar</dt><dd>#{d.end_event_id} · {d.end_file_name}<br />Lote: {d.end_batch_id}</dd></div>
      </dl>
      <p>Os valores exibidos são os snapshots usados na avaliação. A leitura de desligamento não entra na comparação com o mínimo.</p>
    </section>

    <section className="power-detail-card" aria-labelledby="diagnostic-inconsistencies-title">
      <h2 id="diagnostic-inconsistencies-title">Acompanhamento administrativo</h2>
      {inconsistencies.length === 0 ? <p>Nenhuma inconsistência vinculada à aplicação.</p> : inconsistencies.map(item => <article key={item.id} className="inconsistency-card">
        <h3>#{item.id} · {inconsistencyTypeLabel(item.type)}</h3>
        <p>{inconsistencyStatusLabel(item.status)} · Criada em {formatPowerDate(item.created_at)}</p>
        <p>Leitura: {item.power_reading_id === null ? "Não vinculada" : `#${item.power_reading_id}`} · Perfil: {item.power_profile_id ?? "Não vinculado"}</p>
        {item.reviewed_at ? <p>Reconhecida por {item.reviewed_by_name ?? "Usuário indisponível"} em {formatPowerDate(item.reviewed_at)}.</p> : null}
        {item.review_note ? <p>Nota interna: {item.review_note}</p> : null}
        {item.resolved_at ? <p>Resolvida automaticamente em {formatPowerDate(item.resolved_at)}.</p> : null}
        {item.status === "pending" ? <OperationalForm action={reviewInconsistencyAction} className="review-form" submitLabel="Reconhecer e registrar nota" pendingLabel="Registrando..." confirmation="Registrar o acompanhamento administrativo? A avaliação operacional será preservada.">
          <input type="hidden" name="inconsistency_id" value={item.id} />
          <label>Nota interna (opcional)<textarea name="review_note" maxLength={2000} rows={3} /><FieldError name="review_note" /></label>
        </OperationalForm> : null}
      </article>)}
    </section>

    <section className="power-detail-card" aria-labelledby="diagnostic-runs-title" id="reprocessamentos">
      <h2 id="diagnostic-runs-title">Histórico disponível de reprocessamento</h2>
      <p>Execuções do gerador cujo intervalo inclui o início desta aplicação. As contagens resumem toda a execução; não são resultados históricos individuais desta aplicação.</p>
      {runs.length === 0 ? <p>Nenhum reprocessamento registrado para este intervalo.</p> : <ol className="power-history-list">{runs.map(run => <li key={run.id}>
        <strong>#{run.id} · {formatPowerDate(run.processed_at)}</strong>
        <span>{reprocessingReasons[run.reason] ?? run.reason} · Regra {run.rule_version}</span>
        <span>Intervalo: {run.affected_from ? formatPowerDate(run.affected_from) : "Sem limite inicial"} — {run.affected_until ? formatPowerDate(run.affected_until) : "Sem limite final"} (fim exclusivo)</span>
        <span>Dentro do esperado: {run.within_expected_count} · Abaixo: {run.below_expected_count} · Não avaliáveis: {run.not_evaluable_count} · Sem perfil: {run.not_configured_count}</span>
      </li>)}</ol>}
    </section>
  </>;
}
