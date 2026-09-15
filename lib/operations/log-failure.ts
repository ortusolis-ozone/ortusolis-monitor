import "server-only";

type OperationalFailure =
  | "import_preview"
  | "import_confirmation"
  | "import_failure_record"
  | "session_processing"
  | "session_failure_record"
  | "inconsistency_review"
  | "inconsistency_reopen"
  | "source_mapping_update"
  | "power_profile_create"
  | "power_profile_version";

// Database messages/details can contain rejected rows or file content.
// Keep only a bounded SQLSTATE; never serialize the supplied error itself.
export function logOperationalFailure(operation: OperationalFailure, error: unknown) {
  const code = typeof error === "object" && error !== null && "code" in error
    ? error.code
    : null;
  console.error("Falha operacional", {
    operation,
    code: typeof code === "string" && /^[0-9A-Z]{5}$/.test(code)
      ? code
      : "unexpected",
  });
}
