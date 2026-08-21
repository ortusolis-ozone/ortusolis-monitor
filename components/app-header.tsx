import { logoutAction } from "@/lib/auth/actions";

type AppHeaderProps = {
  area: string;
  userName: string;
};

export function AppHeader({ area, userName }: AppHeaderProps) {
  return (
    <header className="app-header">
      <div>
        <p className="eyebrow">Ortusolis Monitor</p>
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
