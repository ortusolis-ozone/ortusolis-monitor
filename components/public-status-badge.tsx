import {
  portalStatusDetails,
  type PortalStatus,
} from "@/lib/portal/constants";

type PublicStatusBadgeProps = {
  status: PortalStatus;
  compact?: boolean;
};

export function PublicStatusBadge({
  status,
  compact = false,
}: PublicStatusBadgeProps) {
  return (
    <span
      className={`public-status-badge ${status}${compact ? " compact" : ""}`}
    >
      {portalStatusDetails[status].label}
    </span>
  );
}
