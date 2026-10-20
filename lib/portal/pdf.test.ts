import { expect, test } from "vitest";
import { PDFDocument } from "pdf-lib";
import { createHistoryPdf } from "./pdf";
import type { PortalPageData } from "./types";

export const pdfFixture: PortalPageData = {
  clientName: "Empresa de Alimentos São José",
  updatedThrough: "2026-10-19", applicationCount: 150, generatorCount: 1, attentionCount: 150,
  filters: { month: "2026-10", startDate: "2026-10-01", endDate: "2026-10-19" },
  options: { locations: [], coldRooms: [], generators: [] }, hasPublishedStatus: true,
  applications: [{ date: "2026-10-19", applications: Array.from({ length: 150 }, (_, i) => ({
    statusDate: "2026-10-19", startedAt: "07:00", endedAt: "07:30", maxMeasuredPowerW: "85.25",
    locationId: "l", locationName: "Unidade Fortaleza", coldRoomId: "c", coldRoomName: "Câmara de conservação",
    generatorId: "g", generatorIdentifier: `Gerador ${i + 1}`, attentionStatus: "attention" as const,
  })) }],
};
test("produces a real multipage PDF for the entire result", async () => {
  const bytes = await createHistoryPdf(pdfFixture, new Date("2026-10-19T15:00:00Z"));
  const document = await PDFDocument.load(bytes);
  expect(document.getPageCount()).toBeGreaterThan(5);
  expect(document.getTitle()).toContain("Histórico");
  // Optional local render fixture; no artifact is written during normal tests.
  if (process.env.SPEC16_PDF_SAMPLE) {
    const { writeFile } = await import("node:fs/promises");
    await writeFile(process.env.SPEC16_PDF_SAMPLE, bytes);
  }
});
test("does not create an empty PDF", async () => {
  await expect(createHistoryPdf({ ...pdfFixture, applicationCount: 0, applications: [] })).rejects.toThrow("Sem registros");
});
