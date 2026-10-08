import { beforeEach, expect, test, vi } from "vitest";
import { parseImportWorkbook } from "./parser";
import type { ValidatedImportContext } from "./types";

const mocks = vi.hoisted(() => ({ workbook: vi.fn() }));
vi.mock("read-excel-file/node", () => ({ default: mocks.workbook }));

const context: ValidatedImportContext = {
  clientId: "c", locationId: "l", coldRoomId: "r", generatorId: "g", controllerId: "s",
  timeZone: "America/Fortaleza", controllerRole: "state",
  controllerActivatedAt: "2026-01-01T00:00:00Z", controllerDeactivatedAt: null,
  externalDeviceId: null, externalDeviceIdNormalized: null,
  powerOnThresholdW: null, powerOffThresholdW: null,
};
const mappings = [
  { normalized_source: "cronômetros regressivos", classification: "programmed" },
  { normalized_source: "dispositivo-inching", classification: "programmed" },
  { normalized_source: "ortusolis@ortusolis.com.br", classification: "manual" },
  { normalized_source: "teste antigo", classification: "test" },
  { normalized_source: "inválida", classification: "unsupported" },
];

beforeEach(() => mocks.workbook.mockResolvedValue([{ sheet: "Estado", data: [
  ["Tempo", "Operação", "Acionado por"],
  ["08/10/2026 04:00:00", "Ligar", "Cronômetros regressivos"],
  ["08/10/2026 04:05:00", "Desligar", "ortusolis@ortusolis.com.br"],
  ["08/10/2026 04:10:00", "Desligar", "Dispositivo-Inching"],
  ["08/10/2026 16:00:00", "Ligar", "Teste antigo"],
  ["08/10/2026 17:00:00", "Ligar", "outro@ortusolis.com.br"],
  ["08/10/2026 18:00:00", "Ligar", "Inválida"],
  ["08/10/2026 19:00:00", "Desligar", "Cronômetros regressivos"],
] }]));

test("preserves manual and legacy origins, fails closed for unsupported mappings and keeps the real operation", async () => {
  const parsed = await parseImportWorkbook(Buffer.from("state"), context, mappings, "state_events");
  if (parsed.dataKind !== "state_events") throw new Error("wrong data kind");
  expect(parsed.events.map(event => event.source_classification)).toEqual([
    "programmed", "manual", "programmed", "test", "unknown", "unknown", "programmed",
  ]);
  expect(parsed.unknownSourceRows).toBe(2);
  expect(parsed.events[1]).toMatchObject({
    operation: "turn_off", operation_raw: "Desligar",
    source_original: "ortusolis@ortusolis.com.br", source_classification: "manual",
  });
  expect(parsed.events[6].operation).toBe("turn_off");
});

test("reclassifying an existing source preserves file identity, event identity and raw values", async () => {
  const legacy = await parseImportWorkbook(Buffer.from("state"), context,
    mappings.map(mapping => mapping.classification === "manual" ? { ...mapping, classification: "test" } : mapping));
  const manual = await parseImportWorkbook(Buffer.from("state"), context, mappings);
  if (legacy.dataKind !== "state_events" || manual.dataKind !== "state_events") throw new Error("wrong data kind");
  expect(manual.fileSha256).toBe(legacy.fileSha256);
  expect(manual.events[1]).toEqual({ ...legacy.events[1], source_classification: "manual" });
});
