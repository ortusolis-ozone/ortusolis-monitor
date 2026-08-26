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
};

export type ImportFormOptions = {
  clients: ImportClientOption[];
  locations: ImportLocationOption[];
  coldRooms: ImportColdRoomOption[];
  generators: ImportGeneratorOption[];
  controllers: ImportControllerOption[];
};

export type ImportPreviewRow = {
  rowNumber: number;
  occurredAt: string;
  occurredAtRaw: string;
  operation: "turn_on" | "turn_off";
  operationRaw: string;
  sourceOriginal: string;
  sourceClassification: "programmed" | "test" | "unknown";
};

export type ImportPreview = {
  fileName: string;
  fileSha256: string;
  sheetName: string;
  timeZone: string;
  totalRows: number;
  existingDuplicateRows: number;
  repeatedFileRows: number;
  unknownSourceRows: number;
  periodStart: string;
  periodEnd: string;
  sample: ImportPreviewRow[];
};

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

export type ValidatedImportContext = ImportContext & {
  timeZone: string;
  controllerActivatedAt: string;
  controllerDeactivatedAt: string | null;
};
