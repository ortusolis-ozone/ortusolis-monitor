import "server-only";

import { headers } from "next/headers";

function normalizedConfiguredOrigin(value: string | undefined) {
  if (!value) {
    return null;
  }

  const withProtocol = value.startsWith("http") ? value : `https://${value}`;

  try {
    const url = new URL(withProtocol);
    const isLocalHttp =
      url.protocol === "http:" &&
      ["localhost", "127.0.0.1"].includes(url.hostname);

    return url.protocol === "https:" || isLocalHttp ? url.origin : null;
  } catch {
    return null;
  }
}

export function safeRedirectPath(value: string | null, fallback: string) {
  if (!value || !value.startsWith("/")) {
    return fallback;
  }

  try {
    const trustedOrigin = "https://ortusolis.invalid";
    const parsedUrl = new URL(value, trustedOrigin);

    if (parsedUrl.origin !== trustedOrigin) {
      return fallback;
    }

    return `${parsedUrl.pathname}${parsedUrl.search}${parsedUrl.hash}`;
  } catch {
    return fallback;
  }
}

export async function getRequestOrigin() {
  const configuredOrigin = normalizedConfiguredOrigin(
    process.env.NEXT_PUBLIC_SITE_URL ??
      process.env.NEXT_PUBLIC_VERCEL_URL ??
      process.env.VERCEL_PROJECT_PRODUCTION_URL,
  );

  if (configuredOrigin) {
    return configuredOrigin;
  }

  const requestHeaders = await headers();
  const origin = requestHeaders.get("origin");

  if (origin) {
    try {
      const parsedOrigin = new URL(origin);
      const isLocalHttp =
        parsedOrigin.protocol === "http:" &&
        ["localhost", "127.0.0.1"].includes(parsedOrigin.hostname);

      if (parsedOrigin.protocol === "https:" || isLocalHttp) {
        return parsedOrigin.origin;
      }
    } catch {
      // Continua para os cabeçalhos normalizados pelo provedor.
    }
  }

  const host = requestHeaders.get("x-forwarded-host") ?? requestHeaders.get("host");
  const protocol = requestHeaders.get("x-forwarded-proto") ?? "https";

  if (host && (protocol === "https" || protocol === "http")) {
    return `${protocol}://${host}`;
  }

  return "http://localhost:3000";
}
