import Link from "next/link";

import { BrandLogo } from "@/components/brand-logo";
import { logoutAction } from "@/lib/auth/actions";

type AppHeaderProps = {
  area: string;
  homeHref: "/admin" | "/portal";
  userName: string;
};

export function AppHeader({ area, homeHref, userName }: AppHeaderProps) {
  return (
    <header className="app-header">
      <div className="app-brand">
        <Link className="app-brand-link" href={homeHref}>
          <BrandLogo preload variant="horizontal-negative" />
        </Link>
        <p className="app-area">{area}</p>
      </div>

      <div className="user-actions">
        <span>{userName}</span>
        <form action={logoutAction}>
          <button className="secondary-button" type="submit">
            Sair
          </button>
        </form>
      </div>
    </header>
  );
}
