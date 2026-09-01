import Link from "next/link";

const navigation = [
  { href: "/admin", label: "Visão geral" },
  { href: "/admin/clientes", label: "Clientes e instalações" },
  { href: "/admin/importacoes", label: "Importações" },
  { href: "/admin/inconsistencias", label: "Inconsistências" },
  { href: "/admin/usuarios", label: "Usuários" },
  { href: "/admin/mapeamentos", label: "Mapeamento de origens" },
  { href: "/admin/perfil", label: "Meu perfil" },
];

export function AdminNavigation() {
  return (
    <nav aria-label="Painel administrativo" className="admin-navigation">
      {navigation.map((item) => (
        <Link href={item.href} key={item.href}>
          {item.label}
        </Link>
      ))}
    </nav>
  );
}
