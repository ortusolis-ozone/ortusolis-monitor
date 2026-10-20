import { parseFilters } from "@/lib/portal/filters";
import { getPortalPageData } from "@/lib/portal/queries";
import { createHistoryPdf } from "@/lib/portal/pdf";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
const headers = { "Cache-Control": "private, no-store", "X-Content-Type-Options": "nosniff" };

export async function GET(request: Request) {
  // The shared query authenticates the active client and applies RLS/RPC limits.
  const data = await getPortalPageData(parseFilters(Object.fromEntries(new URL(request.url).searchParams)));
  if (data.applicationCount === 0) return new Response("Sem registros disponíveis para exportar.", { status: 404, headers });
  const bytes = await createHistoryPdf(data);
  return new Response(new Uint8Array(bytes), { headers: { ...headers,
    "Content-Type": "application/pdf",
    "Content-Disposition": `attachment; filename="historico-${data.filters.month}.pdf"`,
  } });
}
