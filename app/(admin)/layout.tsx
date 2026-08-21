import type { ReactNode } from "react";

import { requireMaster } from "@/lib/auth/profile";

export default async function AdminLayout({ children }: { children: ReactNode }) {
  await requireMaster();

  return <div data-layout="admin">{children}</div>;
}
