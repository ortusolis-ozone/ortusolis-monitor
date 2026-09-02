export type ImportContext = {
  clientId: string;
  locationId: string;
  coldRoomId: string;
  generatorId: string;
  controllerId: string;
};

export type ImportUploadRequest = {
  objectPath: string;
  fileName: string;
  context: ImportContext;
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
