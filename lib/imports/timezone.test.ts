import { beforeEach, expect, test, vi } from "vitest";
const mocks = vi.hoisted(() => ({ workbook: vi.fn() }));
vi.mock("read-excel-file/node", () => ({ default: mocks.workbook }));
import { parseImportWorkbook, parseLocalDateTimeText } from "./parser";
import type { ValidatedImportContext } from "./types";
const headers = ["Device Name","Device ID","Event Type","Event Name","Event Detail","Request From","Source Detail","Event Time"];
const rows = [
  ["Medidor","device-zone","Report","Power","0W","Device","","2026-09-11 22:59:00"],
  ["Medidor","device-zone","Report","Power","61.2W","Device","","2026-09-11 23:00:00:813"],
  ["Medidor","device-zone","Report","Power","0W","Device","","2026-09-12 00:30:00"],
];
const context: ValidatedImportContext = {
  clientId:"c",locationId:"l",coldRoomId:"r",generatorId:"g",controllerId:"p",
  timeZone:"America/Fortaleza", controllerRole:"power_telemetry",controllerActivatedAt:"2026-01-01T00:00:00Z",controllerDeactivatedAt:null,
  externalDeviceId:"device-zone",externalDeviceIdNormalized:"device-zone",powerOnThresholdW:5,powerOffThresholdW:1,
};
beforeEach(() => mocks.workbook.mockResolvedValue([{sheet:"Power",data:[headers,...rows]}]));
test("UTC preserves raw milliseconds and converts the instant across local midnight", async () => {
  const result = await parseImportWorkbook(Buffer.from("file"),context,[],"power_readings","UTC");
  if(result.dataKind !== "power_readings") throw new Error("wrong type");
  expect(result.readings[1]).toMatchObject({occurred_at:"2026-09-11T23:00:00.813Z",occurred_at_raw:rows[1][7],source_timezone:"UTC",normalization_version:1});
  expect(result.periodEnd).toBe("2026-09-12T00:30:00.000Z");
  expect(result.rawPeriodEnd).toBe("2026-09-12 00:30:00");
});
test("same file with different zone has a different reading identity and preserves the file hash", async () => {
  const utc = await parseImportWorkbook(Buffer.from("file"),context,[],"power_readings","UTC");
  const local = await parseImportWorkbook(Buffer.from("file"),context,[],"power_readings","America/Fortaleza");
  if(utc.dataKind !== "power_readings" || local.dataKind !== "power_readings") throw new Error("wrong type");
  expect(utc.fileSha256).toBe(local.fileSha256);
  expect(local.readings[1].occurred_at).toBe("2026-09-12T02:00:00.813Z");
  expect(local.readings[1].fingerprint).not.toBe(utc.readings[1].fingerprint);
  expect(await parseImportWorkbook(Buffer.from("file"),context,[],"power_readings","UTC")).toEqual(utc);
});
test.each([undefined,"","GMT+3","Europe/Paris"])("rejects missing or unsupported source zone %s", async zone => {
  await expect(parseImportWorkbook(Buffer.from("file"),context,[],"power_readings",zone)).rejects.toThrow(/fuso/);
});
test("uses converted instants at controller activation and exclusive deactivation boundaries",async () => {
  mocks.workbook.mockResolvedValue([{sheet:"Power",data:[headers,rows[1]]}]);
  const boundary = {...context, controllerActivatedAt:"2026-09-11T23:00:00.813Z"};
  await expect(parseImportWorkbook(Buffer.from("f"),boundary,[],"power_readings","UTC")).resolves.toBeTruthy();
  await expect(parseImportWorkbook(Buffer.from("f"),{...context,controllerDeactivatedAt:boundary.controllerActivatedAt},[],"power_readings","UTC")).rejects.toThrow(/vigência/);
});
test("invalid dates and ambiguous or missing historical local hours fail closed", () => {
  expect(parseLocalDateTimeText("2026-02-30 23:00:00","UTC")).toBeNull();
  expect(parseLocalDateTimeText("2000-02-26 23:30:00","America/Fortaleza")).toBeNull();
  expect(parseLocalDateTimeText("1999-10-03 00:30:00","America/Fortaleza")).toBeNull();
});
test("state file still uses the location timezone even if UTC is supplied for power",async () => {
  mocks.workbook.mockResolvedValue([{sheet:"State",data:[["Tempo","Operação","Acionado por"],["11/09/2026 20:00:00","Ligar","Agendamento"]]}]);
  const result=await parseImportWorkbook(Buffer.from("f"),{...context,controllerRole:"state"},[{normalized_source:"agendamento",classification:"programmed"}],"state_events","UTC");
  if(result.dataKind!=="state_events") throw new Error("wrong type");
  expect(result.events[0].occurred_at).toBe("2026-09-11T23:00:00.000Z");
});
