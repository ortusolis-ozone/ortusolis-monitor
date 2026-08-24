import Link from "next/link";

const navigation = [
  { href: "/admin", label: "Visão geral" },
  { href: "/admin/clientes", label: "Clientes" },
  { href: "/admin/locais", label: "Unidades" },
  { href: "/admin/camaras", label: "Câmaras" },
  { href: "/admin/geradores", label: "Geradores" },
  { href: "/admin/controladores", label: "Controladores" },
  { href: "/admin/usuarios", label: "Usuários" },
];

export function AdminNavigation() {
  return (
    <nav aria-label="Cadastros administrativos" className="admin-navigation">
      {navigation.map((item) => (
        <Link href={item.href} key={item.href}>
          {item.label}
        </Link>
      ))}
    </nav>
  );
}
