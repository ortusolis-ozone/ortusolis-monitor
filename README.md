# Ortusolis Monitor

Aplicação web para importar registros operacionais e apresentar ao cliente os estados públicos definidos no MVP.

## Requisitos

- Node.js 22 ou superior.
- Um projeto Supabase para as etapas que dependem de dados e autenticação.

## Configuração local

Crie o arquivo local de ambiente a partir do exemplo e preencha as credenciais do projeto Supabase:

```bash
cp .env.example .env.local
```

Instale as dependências e inicie o servidor:

```bash
npm install
npm run dev
```

Abra [http://localhost:3000](http://localhost:3000).

## Verificações

```bash
npm run lint
npm run typecheck
npm run build
```

## Arquitetura

- Next.js com App Router e TypeScript.
- Supabase para PostgreSQL e autenticação.
- Server Components para leitura e operações de servidor para mutações.
- Route Handlers somente quando o fluxo exigir uma resposta HTTP específica.

As decisões e a ordem de implementação estão em [`docs/specs`](./docs/specs/README.md).

## Limites de segurança

- Somente variáveis prefixadas com `NEXT_PUBLIC_` podem chegar ao navegador.
- Chaves administrativas permanecem sem esse prefixo e serão acessadas apenas por módulos marcados como `server-only`.
- O portal do cliente consumirá apenas dados sanitizados.
