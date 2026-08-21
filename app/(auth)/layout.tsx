import type { ReactNode } from "react";

export default function AuthLayout({ children }: { children: ReactNode }) {
  return (
    <main className="auth-shell" data-layout="auth">
      {children}
    </main>
  );
}
