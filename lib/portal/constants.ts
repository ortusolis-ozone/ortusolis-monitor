export const portalStatuses = [
  "verification_required",
  "awaiting_update",
  "no_data",
  "completed",
] as const;

export type PortalStatus = (typeof portalStatuses)[number];

export const portalStatusDetails: Record<
  PortalStatus,
  { label: string; description: string }
> = {
  verification_required: {
    label: "Verificação necessária",
    description:
      "Existe uma inconsistência nos registros. Isso não confirma falha do equipamento.",
  },
  awaiting_update: {
    label: "Aguardando atualização",
    description: "A importação ainda não alcançou o período.",
  },
  no_data: {
    label: "Sem dados",
    description:
      "Não há registro completo disponível para o período já importado.",
  },
  completed: {
    label: "Concluído",
    description: "Há registro completo de aplicação.",
  },
};

const statusPriority: Record<PortalStatus, number> = {
  verification_required: 4,
  awaiting_update: 3,
  no_data: 2,
  completed: 1,
};

export function isPortalStatus(value: string): value is PortalStatus {
  return portalStatuses.some((status) => status === value);
}

export function consolidatePortalStatuses(
  statuses: readonly PortalStatus[],
): PortalStatus | null {
  let consolidated: PortalStatus | null = null;

  for (const status of statuses) {
    if (
      consolidated === null ||
      statusPriority[status] > statusPriority[consolidated]
    ) {
      consolidated = status;
    }
  }

  return consolidated;
}
