import { PDFDocument, StandardFonts, rgb } from "pdf-lib";
import type { PortalPageData } from "./types";

function date(value: string) { return value.split("-").reverse().join("/"); }

/** The standard font covers Portuguese. Unsupported glyphs are replaced explicitly. */
export async function createHistoryPdf(data: PortalPageData, issuedAt = new Date()) {
  if (!data.applicationCount) throw new Error("Sem registros disponíveis para exportar.");
  const pdf = await PDFDocument.create();
  pdf.setTitle("Histórico de aplicações - Ortusolis Monitor");
  pdf.setCreationDate(issuedAt);
  const font = await pdf.embedFont(StandardFonts.Helvetica);
  const bold = await pdf.embedFont(StandardFonts.HelveticaBold);
  const safe = (text: string) => Array.from(text.normalize("NFC")).map(char => {
    try { font.encodeText(char); return char; } catch { return "?"; }
  }).join("");
  const wrap = (text: string, width: number, size = 9) => {
    const lines: string[] = [];
    let line = "";
    for (const word of safe(text).split(/\s+/)) {
      const candidate = line ? `${line} ${word}` : word;
      if (font.widthOfTextAtSize(candidate, size) <= width) { line = candidate; continue; }
      if (line) { lines.push(line); line = ""; }
      // Split only words that cannot fit on a line by themselves.
      for (const char of word) {
        if (font.widthOfTextAtSize(line + char, size) > width && line) { lines.push(line); line = ""; }
        line += char;
      }
    }
    if (line) lines.push(line);
    return lines.length ? lines : [""];
  };
  const widths = [63, 148, 145, 90, 85, 95, 144];
  const headers = ["Data", "Unidade", "Câmara / Gerador", "Início / Fim", "Potência máx.", "Situação", "Observação"];
  let page = pdf.addPage([842, 595]);
  let y = 0;
  const drawText = (text: string, x: number, at: number, size = 9, strong = false) =>
    page.drawText(safe(text), { x, y: at, font: strong ? bold : font, size, color: rgb(0.12, 0.17, 0.22) });
  const header = () => {
    y = 562;
    drawText("Ortusolis Monitor - Histórico de aplicações", 36, y, 15, true);
    y -= 21;
    for (const line of wrap(data.clientName, 765, 10)) { drawText(line, 36, y, 10); y -= 13; }
    drawText(`Emissão: ${new Intl.DateTimeFormat("pt-BR", { dateStyle: "short", timeStyle: "short", timeZone: "America/Fortaleza" }).format(issuedAt)} (Fortaleza)`, 36, y); y -= 15;
    const periods = data.retention?.periods ?? [{ locationName: "Período", from: data.filters.startDate, to: data.filters.endDate }];
    // Summarize the effective date range across the selected units.
    const starts = periods.map(p => p.from).sort(); const ends = periods.map(p => p.to).sort();
    drawText(`Período disponível: ${date(starts[0] ?? data.filters.startDate)} a ${date(ends.at(-1) ?? data.filters.endDate)}. Horários locais de cada unidade.`, 36, y); y -= 22;
    let x = 36;
    headers.forEach((label, index) => { drawText(label, x + 3, y, 8, true); x += widths[index]; });
    y -= 10;
    page.drawLine({ start: { x: 36, y }, end: { x: 806, y }, thickness: 0.7, color: rgb(0.65, 0.7, 0.75) });
    y -= 14;
  };
  header();
  for (const day of data.applications) for (const item of day.applications) {
    const cells = [date(day.date), item.locationName, `${item.coldRoomName} / ${item.generatorIdentifier}`,
      `${item.startedAt?.slice(0, 5) ?? "-"} / ${item.endedAt?.slice(0, 5) ?? "-"}`,
      item.maxMeasuredPowerW === null ? "Não disponível" : `${new Intl.NumberFormat("pt-BR", { maximumFractionDigits: 2 }).format(Number(item.maxMeasuredPowerW))} W`,
      item.attentionStatus === "attention" ? "Atenção necessária" : "Registrada",
      item.attentionStatus === "attention" ? "Consumo abaixo do esperado. A Ortusolis deve verificar o equipamento." : "-"];
    const lines = cells.map((cell, index) => wrap(cell, widths[index] - 8));
    const height = Math.max(...lines.map(cell => cell.length));
    if (height * 12 + 8 <= 400 && y - height * 12 < 48) { page = pdf.addPage([842, 595]); header(); }
    // Very long names may span pages without dropping text.
    for (let line = 0; line < height; line++) {
      if (y < 48) { page = pdf.addPage([842, 595]); header(); }
      let x = 36;
      lines.forEach((cell, index) => { if (cell[line]) drawText(cell[line], x + 3, y); x += widths[index]; });
      y -= 12;
    }
    y -= 8;
  }
  const pages = pdf.getPages();
  pages.forEach((p, index) => p.drawText(`Página ${index + 1} de ${pages.length}`, { x: 713, y: 22, size: 9, font }));
  return pdf.save();
}
