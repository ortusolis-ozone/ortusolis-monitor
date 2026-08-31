# Spec 03 — Autenticação e autorização

**Status do MVP original:** concluída.

**Evolução Spec 10:** pendente de implementação.

> **Evolução:** as políticas, os privilégios e os testes de isolamento das novas tabelas de telemetria são definidos pela [spec 10](./10-duplo-controlador-e-telemetria-de-potencia.md).

## Objetivo

Garantir autenticação individual e isolamento entre os clientes antes de desenvolver os fluxos operacionais.

## Autenticação

- Supabase Auth com e-mail e senha.
- Confirmação ou código por e-mail na ativação, conforme suporte configurado no Auth.
- Recuperação de senha por e-mail.
- Sessão em cookies integrada ao Next.js com o pacote SSR indicado pelo Supabase.
- O Master cria ou convida usuários no MVP.
- OTP não será exigido em todo login, salvo decisão posterior de segurança.

## Papéis

- `master`: acesso administrativo a todos os clientes e dados operacionais.
- `client_admin`: consulta dos dados do próprio cliente.
- `operator`: mesma consulta no MVP.
- `viewer`: mesma consulta no MVP.

Os papéis distintos são armazenados para evolução futura, sem criar diferenças artificiais agora.

## RLS

- Todas as tabelas em schemas expostos possuem RLS habilitada.
- `GRANT` define quais objetos `anon` e `authenticated` alcançam; RLS limita as linhas desses objetos.
- Master acessa os dados necessários por políticas administrativas verificadas no servidor.
- Usuário de cliente lê apenas a hierarquia pertencente ao seu `client_id`.
- Usuário de cliente lê `client_daily_status` somente para seu `client_id`.
- Usuário de cliente não possui `SELECT` em lotes, eventos, aplicações técnicas, inconsistências detalhadas, mapeamentos ou auditoria.
- Nenhum usuário de cliente realiza mutações operacionais no MVP.
- Operações que exigem chave de serviço executam exclusivamente no servidor.
- Papéis e cliente não são lidos de `user_metadata`, pois esse conteúdo pode ser alterado pelo usuário; a fonte de autorização é o banco ou metadata administrativa não editável.
- Caso uma view seja criada, ela deve respeitar RLS como `security_invoker` ou não ser exposta à Data API.

## Proteção nas rotas

- Usuário não autenticado é redirecionado para login.
- Usuário de cliente não entra em rotas administrativas.
- Master não depende de escolher um cliente para autenticar; o contexto é selecionado na operação.
- A autorização deve ser validada na operação de servidor, não somente no menu ou layout.

## Auditoria mínima

Registrar:

- criação, edição e desativação de cadastros;
- convite ou desativação de usuário;
- confirmação de importação;
- revisão de inconsistência;
- alteração de mapeamento de origem.

## Critérios de aceite

- Testes com dois clientes comprovam isolamento em consultas diretas ao banco.
- Alterar manualmente IDs em URLs ou requisições não amplia o acesso.
- Nenhuma resposta destinada ao cliente contém campos técnicos protegidos.
- Recuperação de senha e encerramento de sessão funcionam de ponta a ponta.
