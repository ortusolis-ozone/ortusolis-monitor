export type ImportHierarchyContext = {
  clientId: string;
  locationId: string;
  coldRoomId: string;
  generatorId: string;
};

export type ImportContext = ImportHierarchyContext & {
  controllerId: string;
};

export type ImportDataKind = "state_events" | "power_readings";

export type ImportUploadRequest = {
  objectPath: string;
  fileName: string;
  context: ImportContext;
  expectedDataKind?: ImportDataKind;
};

export type ImportConfirmationRequest = ImportUploadRequest & {
  expectedFileSha256: string;
};

export type ImportClientOption = {
  id: string;
  legalName: string;
};

export type ImportLocationOption = {
  id: string;
  clientId: string;
  name: string;
  timeZone: string;
};

export type ImportColdRoomOption = {
  id: string;
  clientId: string;
  locationId: string;
  name: string;
};

export type ImportGeneratorOption = {
  id: string;
  clientId: string;
  coldRoomId: string;
  locationId: string;
  identifier: string;
};

export type ImportControllerOption = {
  id: string;
  clientId: string;
  generatorId: string;
  identifier: string;
  role: "state" | "power_telemetry";
  isActive: boolean;
  activatedAt: string;
  deactivatedAt: string | null;
};

export type ImportFormOptions = {
  clients: ImportClientOption[];
  locations: ImportLocationOption[];
  coldRooms: ImportColdRoomOption[];
  generators: ImportGeneratorOption[];
  controllers: ImportControllerOption[];
};

export type StateImportPreviewRow = {
  rowNumber: number;
  occurredAt: string;
  occurredAtRaw: string;
  operation: "turn_on" | "turn_off";
  operationRaw: string;
  sourceOriginal: string;
  sourceClassification: "programmed" | "test" | "unknown";
};

export type PowerImportPreviewRow = {
  rowNumber: number;
  occurredAt: string;
  occurredAtRaw: string;
  powerW: number;
  powerRaw: string;
  electricalState: "on" | "off" | "hysteresis";
  deviceName: string;
  deviceId: string;
};

type ImportPreviewBase = {
  fileName: string;
  fileSha256: string;
  sheetName: string;
  timeZone: string;
  totalRows: number;
  existingDuplicateRows: number;
  repeatedFileRows: number;
  periodStart: string;
  periodEnd: string;
  alreadyImported: boolean;
  existingBatchId: string | null;
};

export type StateImportPreview = ImportPreviewBase & {
  dataKind: "state_events";
  unknownSourceRows: number;
  sample: StateImportPreviewRow[];
};

export type PowerImportPreview = ImportPreviewBase & {
  dataKind: "power_readings";
  deviceName: string;
  deviceId: string;
  minPowerW: number;
  maxPowerW: number;
  onRows: number;
  offRows: number;
  hysteresisRows: number;
  invalidRows: number;
  sample: PowerImportPreviewRow[];
};

export type ImportPreview = StateImportPreview | PowerImportPreview;

export type ImportConfirmation = {
  batchId: string;
  alreadyConfirmed: boolean;
  totalRows: number;
  insertedRows: number;
  duplicateRows: number;
  unknownSourceRows: number;
  periodStart: string | null;
  periodEnd: string | null;
};

export type ImportActionResult =
  | { status: "error"; message: string }
  | { status: "preview"; preview: ImportPreview }
  | { status: "confirmed"; confirmation: ImportConfirmation };

export type ImportSessionConfirmationRequest = {
  context: ImportHierarchyContext;
  state: ImportConfirmationRequest;
  power: ImportConfirmationRequest;
  coverageWarningAcknowledged: boolean;
};

export type ImportCoverageStatus =
  | "full"
  | "partial"
  | "no_intersection"
  | "unknown";

export type ImportSessionConfirmation = {
  operationalSummary: ImportOperationalSummary;
  sessionId: string;
  alreadyConfirmed: boolean;
  coverageStatus: "full" | "partial";
  coverageWarningAcknowledged: boolean;
  statePeriodStart: string;
  statePeriodEnd: string;
  powerPeriodStart: string;
  powerPeriodEnd: string;
  intersectionStart: string;
  intersectionEnd: string;
  stateBatch: ImportConfirmation;
  powerBatch: ImportConfirmation;
};

export type ImportSessionActionResult =
  | { status: "error"; message: string }
  | { status: "confirmed"; confirmation: ImportSessionConfirmation };

export type ImportSourceStatus =
  | "empty"
  | "selected"
  | "validating"
  | "valid"
  | "already_imported"
  | "invalid"
  | "confirmed";

export type ImportSessionUiStatus =
  | "incomplete"
  | "validating"
  | "ready"
  | "ready_with_warning"
  | "confirming"
  | "confirmed"
  | "failed";

export type LatestImportSource = {
  batchId: string;
  clientId: string;
  locationId: string;
  coldRoomId: string;
  generatorId: string;
  controllerId: string;
  dataKind: ImportDataKind;
  fileName: string;
  confirmedAt: string;
  periodStart: string;
  periodEnd: string;
  totalRows: number;
  authorName: string;
};

export type ImportSessionBatchSummary = {
  id: string;
  fileName: string;
  controllerName: string;
  periodStart: string | null;
  periodEnd: string | null;
  totalRows: number;
  insertedRows: number;
  duplicateRows: number;
  unknownSourceRows: number;
};

export type ImportSessionListItem = {
  id: string;
  status: "confirmed" | "failed";
  coverageStatus: ImportCoverageStatus;
  coverageWarningAcknowledged: boolean;
  errorMessage: string | null;
  createdAt: string;
  confirmedAt: string | null;
  statePeriodStart: string | null;
  statePeriodEnd: string | null;
  powerPeriodStart: string | null;
  powerPeriodEnd: string | null;
  intersectionStart: string | null;
  intersectionEnd: string | null;
  clientName: string;
  locationName: string;
  coldRoomName: string;
  generatorName: string;
  stateControllerName: string;
  powerControllerName: string;
  authorName: string;
  stateBatch: ImportSessionBatchSummary | null;
  powerBatch: ImportSessionBatchSummary | null;
  failedStateFileName: string | null;
  failedPowerFileName: string | null;
};

export type ImportBatchListItem = {
  id: string;
  fileName: string;
  status: "processing" | "confirmed" | "failed";
  createdAt: string;
  confirmedAt: string | null;
  periodStart: string | null;
  periodEnd: string | null;
  totalRows: number;
  insertedRows: number;
  duplicateRows: number;
  unknownSourceRows: number;
  errorMessage: string | null;
  clientName: string;
  locationName: string;
  coldRoomName: string;
  generatorName: string;
  controllerName: string;
  authorName: string;
  dataKind: "state_events" | "power_readings";
};

export type ParsedImportEvent = {
  rowNumber: number;
  occurred_at: string;
  occurred_at_raw: string;
  operation: "turn_on" | "turn_off";
  operation_raw: string;
  source_original: string;
  source_normalized: string;
  source_classification: "programmed" | "test" | "unknown";
  fingerprint: string;
};

export type ParsedPowerReading = {
  rowNumber: number;
  occurred_at: string;
  occurred_at_raw: string;
  power_w: number;
  power_raw: string;
  device_name: string;
  device_id: string;
  device_id_normalized: string;
  event_type: string;
  event_name: string;
  event_detail: string;
  request_from: string;
  source_detail: string;
  fingerprint: string;
  electrical_state: "on" | "off" | "hysteresis";
};

export type ValidatedImportContext = ImportContext & {
  timeZone: string;
  controllerActivatedAt: string;
  controllerDeactivatedAt: string | null;
  controllerRole: "state" | "power_telemetry";
  externalDeviceId: string | null;
  externalDeviceIdNormalized: string | null;
  powerOnThresholdW: number | null;
  powerOffThresholdW: number | null;
};

export type ImportOperationalSummary = {
  within_expected: number;
  below_expected: number;
  not_evaluable: number;
  not_configured: number;
  groups: { status: string; reason: string; count: number }[];
  profiles: {
    id: string;
    valid_from: string;
    valid_until: string | null;
    nominal_power_w: string;
    minimum_acceptable_power_w: string;
  }[];
};
export type ImportSessionPreviewResult =
  | { status: "error"; message: string }
  | { status: "preview"; preview: ImportOperationalSummary };
