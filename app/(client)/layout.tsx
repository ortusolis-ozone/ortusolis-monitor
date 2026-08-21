import type { ReactNode } from "react";

export default function ClientLayout({ children }: { children: ReactNode }) {
  return <div data-layout="client">{children}</div>;
}
