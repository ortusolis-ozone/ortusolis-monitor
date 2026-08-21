# Spec 01 — Arquitetura base

**Status:** concluída.

## Objetivo

Estabelecer uma fundação suficiente para o MVP, mantendo baixo custo operacional e poucas camadas.

## Arquitetura escolhida

- **Aplicação:** monólito Next.js com App Router e TypeScript.
- **Interface:** React, Tailwind CSS e componentes shadcn/ui quando necessários.
- **Servidor:** Server Components para leitura e operações de servidor para mutações; Route Handler apenas quando upload ou resposta HTTP específica exigir.
- **Dados e autenticação:** Supabase PostgreSQL, Auth, cliente SSR com sessão em cookies e RLS.
- **Hospedagem:** Vercel.
- **Runtime:** Node.js 22 ou superior.

Não serão criados backend separado, microserviços, workers, filas ou cache distribuído no MVP.

## Divisão interna sugerida

```text
app/
  (auth)/
  (admin)/
  (client)/
  api/imports/
lib/
  auth/
  data/
  import/
  processing/
  validation/
```

Os diretórios serão criados quando receberem a primeira implementação real. A fundação inicial mantém apenas os grupos de rota e `lib/supabase`, evitando arquivos vazios ou abstrações antecipadas.

- Rotas organizam experiências, não regras de negócio.
- Consultas e mutações ficam em módulos executados no servidor.
- Parsing e processamento devem ser funções determinísticas, independentes da interface.
- Tipos de domínio compartilhados não devem expor campos operacionais ao portal do cliente.

## Fluxo principal

```text
Administrador → upload XLSX → validação → prévia → confirmação
→ raw_events → processamento → applications/inconsistencies
→ client_daily_status → portal do cliente
```

## Decisões de simplicidade

- Dados derivados podem ser reconstruídos a partir de `raw_events`.
- O processamento pode reconstruir todo o histórico do gerador após uma importação; otimização incremental fica para quando o volume justificar.
- A API usada pela interface é interna ao próprio app.
- Não haverá camada genérica de repositórios; consultas reutilizadas serão funções pequenas e explícitas.
- O XLSX não será armazenado: a prévia é transitória e o arquivo é revalidado quando o administrador confirma.
- A Data API terá acesso concedido explicitamente apenas aos objetos necessários; RLS continuará obrigatória em todas as tabelas do schema exposto.

## Critérios de aceite

- Segredos administrativos nunca são enviados ao navegador.
- Código de parsing e processamento pode ser testado sem renderizar páginas.
- Rotas administrativas e do cliente possuem limites de layout independentes, preparados para as autorizações da spec 03.
- A arquitetura permite substituir o algoritmo de processamento sem migrar os eventos brutos.

## Resultado da execução

- Runtime mínimo declarado como Node.js 22.
- Clientes Supabase de navegador e servidor isolados em módulos próprios.
- Cliente de servidor preparado para sessões em cookies e protegido contra importação acidental no navegador.
- Grupos de rota de autenticação, administração e cliente separados por layout.
- Variáveis públicas e segredo administrativo documentados em `.env.example`.
- Proxy de sessão, login e autorização mantidos na spec 03.
