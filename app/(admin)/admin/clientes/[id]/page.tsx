import Link from "next/link";
import { notFound } from "next/navigation";

import { StatusBadge } from "@/components/status-badge";
import {
  categoryLabel,
  formatOperationalDate,
  roleLabel,
} from "@/lib/operations/format";
import { getClientHierarchy } from "@/lib/operations/queries";
import { formatCnpj } from "@/lib/validation/cnpj";

type ClientDetailPageProps = {
  params: Promise<{ id: string }>;
};

export default async function ClientDetailPage({
  params,
}: ClientDetailPageProps) {
  const { id } = await params;
  const hierarchy = await getClientHierarchy(id);

  if (!hierarchy) {
    notFound();
  }

  const {
    client,
    locations,
    coldRooms,
    generators,
    assignments,
    controllers,
    profiles,
  } = hierarchy;

  return (
    <main className="admin-main">
      <Link className="back-link" href="/admin/clientes">
        ← Voltar para clientes
      </Link>

      <section className="page-heading page-heading-row">
        <div>
          <p className="eyebrow">Hierarquia do cliente</p>
          <h1>{client.legal_name}</h1>
          <p>{formatCnpj(client.cnpj)}</p>
        </div>
        <StatusBadge isActive={client.is_active} />
      </section>

      <section className="hierarchy-card">
        <div className="section-title-row">
          <div>
            <p className="eyebrow">Estrutura atual</p>
            <h2>Unidades, câmaras e equipamentos</h2>
          </div>
          <div className="section-links">
            <Link href="/admin/locais">Gerenciar unidades</Link>
            <Link href="/admin/camaras">Gerenciar câmaras</Link>
            <Link href="/admin/geradores">Gerenciar geradores</Link>
          </div>
        </div>

        <div className="hierarchy-tree">
          {locations.map((location) => {
            const locationRooms = coldRooms.filter(
              (room) => room.location_id === location.id,
            );

            return (
              <article className="hierarchy-location" key={location.id}>
                <header>
                  <div>
                    <h3>{location.name}</h3>
                    <p>{location.description || location.time_zone}</p>
                  </div>
                  <StatusBadge isActive={location.is_active} />
                </header>

                {locationRooms.map((room) => {
                  const roomGenerators = generators.filter((generator) =>
                    assignments.some(
                      (assignment) =>
                        assignment.generator_id === generator.id &&
                        assignment.cold_room_id === room.id &&
                        assignment.valid_until === null,
                    ),
                  );

                  return (
                    <section className="hierarchy-room" key={room.id}>
                      <div className="hierarchy-node-heading">
                        <div>
                          <h4>{room.name}</h4>
                          <p>{categoryLabel(room.category)}</p>
                        </div>
                        <StatusBadge isActive={room.is_active} />
                      </div>

                      {roomGenerators.map((generator) => {
                        const generatorAssignments = assignments.filter(
                          (assignment) =>
                            assignment.generator_id === generator.id,
                        );
                        const generatorControllers = controllers.filter(
                          (controller) =>
                            controller.generator_id === generator.id,
                        );

                        return (
                          <div className="hierarchy-generator" key={generator.id}>
                            <div className="hierarchy-node-heading">
                              <div>
                                <h5>{generator.identifier}</h5>
                                <p>
                                  Estado: {generatorControllers.find(
                                    (controller) =>
                                      controller.is_active && controller.role === "state",
                                  )?.identifier ?? "pendente"}
                                  {" · "}Potência: {generatorControllers.find(
                                    (controller) =>
                                      controller.is_active &&
                                      controller.role === "power_telemetry",
                                  )?.identifier ?? "pendente"}
                                </p>
                              </div>
                              <StatusBadge isActive={generator.is_active} />
                            </div>

                            <details className="history-details">
                              <summary>Histórico técnico</summary>
                              <div className="history-columns">
                                <div>
                                  <strong>Alocações</strong>
                                  {generatorAssignments.map((assignment) => {
                                    const historicalRoom = coldRooms.find(
                                      (item) => item.id === assignment.cold_room_id,
                                    );
                                    const historicalLocation = locations.find(
                                      (item) => item.id === assignment.location_id,
                                    );

                                    return (
                                      <p key={assignment.id}>
                                        {historicalLocation?.name} /{" "}
                                        {historicalRoom?.name}: {" "}
                                        {formatOperationalDate(
                                          assignment.valid_from,
                                        )}{" "}
                                        — {" "}
                                        {formatOperationalDate(
                                          assignment.valid_until,
                                        )}
                                      </p>
                                    );
                                  })}
                                </div>
                                <div>
                                  <strong>Controladores</strong>
                                  {generatorControllers.map((controller) => (
                                    <p key={controller.id}>
                                      {controller.role === "state"
                                        ? "Estado liga/desliga"
                                        : "Telemetria de potência"}: {controller.identifier}
                                      {controller.role === "power_telemetry"
                                        ? ` · Device ID ${controller.external_device_id}`
                                        : ""}: {" "}
                                      {formatOperationalDate(
                                        controller.activated_at,
                                      )}{" "}
                                      — {" "}
                                      {formatOperationalDate(
                                        controller.deactivated_at,
                                      )}
                                    </p>
                                  ))}
                                </div>
                              </div>
                            </details>
                          </div>
                        );
                      })}

                      {roomGenerators.length === 0 ? (
                        <p className="node-empty">Nenhum gerador alocado.</p>
                      ) : null}
                    </section>
                  );
                })}

                {locationRooms.length === 0 ? (
                  <p className="node-empty">Nenhuma câmara cadastrada.</p>
                ) : null}
              </article>
            );
          })}

          {locations.length === 0 ? (
            <p className="empty-state">Este cliente ainda não possui unidades.</p>
          ) : null}
        </div>
      </section>

      <section className="listing-card">
        <div className="section-title-row">
          <div>
            <p className="eyebrow">Acessos</p>
            <h2>Usuários vinculados</h2>
          </div>
          <Link href="/admin/usuarios">Gerenciar usuários</Link>
        </div>

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Nome</th>
                <th>E-mail</th>
                <th>Papel</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {profiles.map((profile) => (
                <tr key={profile.id}>
                  <td>{profile.full_name}</td>
                  <td>{profile.email}</td>
                  <td>{roleLabel(profile.role)}</td>
                  <td>
                    <StatusBadge isActive={profile.is_active} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {profiles.length === 0 ? (
          <p className="empty-state">Nenhum usuário vinculado.</p>
        ) : null}
      </section>
    </main>
  );
}
