import type { ReactNode } from "react";

import { AdminNavigation } from "@/components/admin-navigation";
import { AppHeader } from "@/components/app-header";
import { requireMaster } from "@/lib/auth/profile";

export default async function AdminLayout({ children }: { children: ReactNode }) {
  const profile = await requireMaster();

  return (
    <div className="app-shell" data-layout="admin">
      <AppHeader
        area="Administração"
        homeHref="/admin"
        userName={profile.fullName}
      />
      <AdminNavigation />
      {children}
    </div>
  );
}
