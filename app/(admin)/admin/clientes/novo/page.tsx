import Link from "next/link";

import { FieldError, OperationalForm } from "@/components/operational-form";
import { createCompleteClientStructureAction } from "@/lib/operations/actions";
import { coldRoomCategories } from "@/lib/operations/constants";

function todayInFortaleza() {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Fortaleza",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}

const registrationSteps = [
  "Cliente",
  "Unidade",
  "Câmara",
  "Gerador",
  "Controlador",
];

export default function NewCompleteClientStructurePage() {
  const today = todayInFortaleza();

  return (
    <main className="admin-main">
      <section className="page-heading page-heading-row">
        <div>
          <p className="eyebrow">Cadastro guiado</p>
          <h1>Nova estrutura completa</h1>
          <p>
            Inclua os cinco níveis necessários para importar eventos sem trocar
            de tela. Se alguma etapa falhar, nenhum cadastro será gravado.
          </p>
        </div>
        <Link className="secondary-button" href="/admin/clientes">
          Voltar aos clientes
        </Link>
      </section>

      <section
        aria-labelledby="complete-registration-title"
        className="complete-registration-card"
      >
        <div className="registration-flow-summary">
          <div>
            <p className="eyebrow">Uma única confirmação</p>
            <h2 id="complete-registration-title">O que será criado</h2>
          </div>
          <ol>
            {registrationSteps.map((step, index) => (
              <li key={step}>
                <span aria-hidden="true">{index + 1}</span>
                {step}
              </li>
            ))}
          </ol>
        </div>

        <OperationalForm
          action={createCompleteClientStructureAction}
          className="operational-form complete-registration-form"
          pendingLabel="Cadastrando estrutura..."
          submitLabel="Cadastrar estrutura completa"
        >
          <fieldset className="registration-step">
            <legend>
              <span aria-hidden="true">1</span>
              <span>
                <strong>Cliente</strong>
                <small>Dados jurídicos do novo cliente.</small>
              </span>
            </legend>
            <div className="registration-fields">
              <label>
                Razão social ou nome
                <input
                  autoComplete="organization"
                  name="client_legal_name"
                  required
                />
                <FieldError name="client_legal_name" />
              </label>
              <label>
                CNPJ
                <input
                  autoComplete="off"
                  inputMode="numeric"
                  name="client_cnpj"
                  placeholder="00.000.000/0000-00"
                  required
                />
                <FieldError name="client_cnpj" />
              </label>
            </div>
          </fieldset>

          <fieldset className="registration-step">
            <legend>
              <span aria-hidden="true">2</span>
              <span>
                <strong>Primeira unidade</strong>
                <small>Local e fuso usados nas datas operacionais.</small>
              </span>
            </legend>
            <div className="registration-fields">
              <label>
                Nome da unidade
                <input name="location_name" required />
                <FieldError name="location_name" />
              </label>
              <label>
                Fuso IANA
                <input
                  defaultValue="America/Fortaleza"
                  name="location_time_zone"
                  required
                />
                <FieldError name="location_time_zone" />
              </label>
              <label className="registration-field-wide">
                Identificação ou localização
                <textarea name="location_description" rows={2} />
              </label>
            </div>
          </fieldset>

          <fieldset className="registration-step">
            <legend>
              <span aria-hidden="true">3</span>
              <span>
                <strong>Primeira câmara</strong>
                <small>Ambiente monitorado dentro da unidade.</small>
              </span>
            </legend>
            <div className="registration-fields">
              <label>
                Nome ou identificação
                <input name="cold_room_name" required />
                <FieldError name="cold_room_name" />
              </label>
              <label>
                Categoria
                <select
                  defaultValue="outros"
                  name="cold_room_category"
                  required
                >
                  {coldRoomCategories.map((category) => (
                    <option key={category.value} value={category.value}>
                      {category.label}
                    </option>
                  ))}
                </select>
                <FieldError name="cold_room_category" />
              </label>
            </div>
          </fieldset>

          <fieldset className="registration-step">
            <legend>
              <span aria-hidden="true">4</span>
              <span>
                <strong>Gerador e alocação</strong>
                <small>O gerador já será alocado na câmara acima.</small>
              </span>
            </legend>
            <div className="registration-fields">
              <label>
                Identificação do gerador
                <input name="generator_identifier" required />
                <FieldError name="generator_identifier" />
              </label>
              <label>
                Início da alocação
                <input
                  defaultValue={today}
                  name="generator_valid_from"
                  required
                  type="date"
                />
                <small className="field-hint">
                  Use a primeira data em que o gerador deve aceitar eventos.
                </small>
                <FieldError name="generator_valid_from" />
              </label>
            </div>
          </fieldset>

          <fieldset className="registration-step">
            <legend>
              <span aria-hidden="true">5</span>
              <span>
                <strong>Primeiro controlador</strong>
                <small>Controlador inicialmente vinculado ao gerador.</small>
              </span>
            </legend>
            <div className="registration-fields">
              <label>
                Identificação do controlador
                <input name="controller_identifier" required />
                <FieldError name="controller_identifier" />
              </label>
              <label>
                Data de ativação
                <input
                  defaultValue={today}
                  name="controller_activated_on"
                  required
                  type="date"
                />
                <small className="field-hint">
                  Use a primeira data em que este controlador deve aceitar
                  eventos.
                </small>
                <FieldError name="controller_activated_on" />
              </label>
            </div>
          </fieldset>
        </OperationalForm>
      </section>
    </main>
  );
}
