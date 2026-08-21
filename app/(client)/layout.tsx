import type { ReactNode } from "react";

import { requireClientProfile } from "@/lib/auth/profile";

export default async function ClientLayout({ children }: { children: ReactNode }) {
  await requireClientProfile();

  return <div data-layout="client">{children}</div>;
}
