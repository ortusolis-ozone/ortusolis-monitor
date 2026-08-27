import type { ReactNode } from "react";

import { BrandLogo } from "@/components/brand-logo";

export default function AuthLayout({ children }: { children: ReactNode }) {
  return (
    <main className="auth-shell" data-layout="auth">
      <div className="auth-layout">
        <BrandLogo
          className="auth-logo"
          preload
          variant="vertical-positive"
        />
        {children}
      </div>
    </main>
  );
}
