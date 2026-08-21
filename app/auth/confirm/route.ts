import type { EmailOtpType } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

import { safeRedirectPath } from "@/lib/auth/url";
import { createClient } from "@/lib/supabase/server";

const acceptedEmailOtpTypes = new Set<EmailOtpType>([
  "signup",
  "invite",
  "magiclink",
  "recovery",
  "email_change",
  "email",
]);

export async function GET(request: NextRequest) {
  const tokenHash = request.nextUrl.searchParams.get("token_hash");
  const rawType = request.nextUrl.searchParams.get("type");
  const type =
    rawType && acceptedEmailOtpTypes.has(rawType as EmailOtpType)
      ? (rawType as EmailOtpType)
      : null;
  const fallbackPath = type === "recovery" || type === "invite"
    ? "/update-password"
    : "/";
  const nextPath = safeRedirectPath(
    request.nextUrl.searchParams.get("next"),
    fallbackPath,
  );

  if (tokenHash && type) {
    const supabase = await createClient();
    const { error } = await supabase.auth.verifyOtp({
      token_hash: tokenHash,
      type,
    });

    if (!error) {
      return NextResponse.redirect(new URL(nextPath, request.url));
    }
  }

  return NextResponse.redirect(
    new URL("/login?notice=invalid-auth-link", request.url),
  );
}
