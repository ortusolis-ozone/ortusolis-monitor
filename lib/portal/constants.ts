export const portalStatuses = [
  "verification_required",
  "awaiting_update",
  "no_data",
  "completed",
] as const;

export type PortalStatus = (typeof portalStatuses)[number];

export const powerEvidenceStatuses = [
  "confirmed",
  "requires_review",
  "partial",
  "unavailable",
  "not_applicable",
] as const;

export type PowerEvidenceStatus = (typeof powerEvidenceStatuses)[number];

export const powerEvidenceDetails: Record<
  PowerEvidenceStatus,
  { label: string; description: string }
> = {
  confirmed: {
    label: "Potência confirmada",
    description: "A aplicação registrada possui evidência de energização.",
  },
  requires_review: {
    label: "Verificação necessária",
    description: "Os registros de estado e potência precisam ser conferidos.",
  },
  partial: {
    label: "Evidência parcial",
    description: "A telemetria está disponível apenas em parte do período.",
  },
  unavailable: {
    label: "Telemetria indisponível",
    description: "Não havia cobertura de potência compatível no período.",
  },
  not_applicable: {
    label: "Sem aplicação concluída",
    description: "A evidência de potência não se aplica a este registro.",
  },
};

export function isPowerEvidenceStatus(
  value: string,
): value is PowerEvidenceStatus {
  return powerEvidenceStatuses.some((status) => status === value);
}

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
