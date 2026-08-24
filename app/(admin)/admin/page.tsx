import Link from "next/link";

export default async function AdminPage() {
  return (
    <main className="admin-main">
      <section className="page-heading">
        <p className="eyebrow">Cadastros operacionais</p>
        <h1>Estrutura dos clientes</h1>
        <p>
          Monte a hierarquia de cada cliente e preserve o histórico de
          geradores e controladores.
        </p>
      </section>

      <section className="admin-card-grid" aria-label="Tipos de cadastro">
        <Link className="admin-card" href="/admin/clientes">
          <span>01</span>
          <h2>Clientes</h2>
          <p>Razão social, CNPJ, status e visão completa da hierarquia.</p>
        </Link>
        <Link className="admin-card" href="/admin/locais">
          <span>02</span>
          <h2>Unidades</h2>
          <p>Localização operacional e fuso usado na leitura das datas.</p>
        </Link>
        <Link className="admin-card" href="/admin/camaras">
          <span>03</span>
          <h2>Câmaras</h2>
          <p>Identificação e categoria de produto armazenado.</p>
        </Link>
        <Link className="admin-card" href="/admin/geradores">
          <span>04</span>
          <h2>Geradores</h2>
          <p>Alocação atual, realocação efetiva e histórico de câmaras.</p>
        </Link>
        <Link className="admin-card" href="/admin/controladores">
          <span>05</span>
          <h2>Controladores</h2>
          <p>Vigência e substituição sem criar um novo gerador.</p>
        </Link>
        <Link className="admin-card" href="/admin/usuarios">
          <span>06</span>
          <h2>Usuários</h2>
          <p>Convites individuais vinculados ao cliente e papel de acesso.</p>
        </Link>
        <Link className="admin-card" href="/admin/importacoes">
          <span>07</span>
          <h2>Importações</h2>
          <p>Validação, prévia e confirmação dos eventos exportados do eWeLink.</p>
        </Link>
      </section>
    </main>
  );
}
