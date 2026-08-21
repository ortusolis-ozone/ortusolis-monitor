import { NextResponse, type NextRequest } from "next/server";

import { safeRedirectPath } from "@/lib/auth/url";
import { createClient } from "@/lib/supabase/server";

export async function GET(request: NextRequest) {
  const code = request.nextUrl.searchParams.get("code");
  const nextPath = safeRedirectPath(
    request.nextUrl.searchParams.get("next"),
    "/",
  );

  if (code) {
    const supabase = await createClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);

    if (!error) {
      return NextResponse.redirect(new URL(nextPath, request.url));
    }
  }

  return NextResponse.redirect(
    new URL("/login?notice=invalid-auth-link", request.url),
  );
}
