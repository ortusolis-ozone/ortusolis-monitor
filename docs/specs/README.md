# Plano de especificações — Ortusolis Monitor MVP

Este diretório organiza as especificações na mesma ordem recomendada para implementação. O objetivo é construir um monólito simples, seguro e fácil de manter, sem antecipar necessidades posteriores ao MVP.

## Princípios

- Next.js concentra interface e operações de servidor.
- Supabase concentra autenticação, PostgreSQL e RLS.
- A Data API usa permissões explícitas; RLS não substitui `GRANT`.
- O banco é a fonte de verdade.
- Eventos importados são preservados; aplicações e estados são dados derivados e reconstruíveis.
- O cliente acessa somente dados sanitizados.
- Não haverá microserviços, filas, cache distribuído ou API pública no MVP.
- Perfis de cliente compartilham a mesma experiência no MVP, embora o papel seja armazenado.

## Ordem de execução

| Ordem | Especificação | Resultado esperado | Status |
| --- | --- | --- | --- |
| 0 | [Regras e escopo](./00-regras-e-escopo.md) | Vocabulário e regras de negócio congelados | Concluída |
| 1 | [Arquitetura base](./01-arquitetura-base.md) | Fundação técnica e limites entre as camadas | Pendente |
| 2 | [Modelo de dados](./02-modelo-de-dados.md) | Schema, relacionamentos e histórico operacional | Pendente |
| 3 | [Autenticação e autorização](./03-autenticacao-e-autorizacao.md) | Login, perfis, isolamento e políticas RLS | Pendente |
| 4 | [Cadastros operacionais](./04-cadastros-operacionais.md) | Estrutura Cliente → Controlador utilizável | Pendente |
| 5 | [Importação XLSX](./05-importacao-xlsx.md) | Validação, prévia e confirmação idempotente | Pendente |
| 6 | [Processamento e estados](./06-processamento-e-estados.md) | Aplicações, inconsistências e visão sanitizada | Pendente |
| 7 | [Painel administrativo](./07-painel-administrativo.md) | Operação completa pela Ortusolis | Pendente |
| 8 | [Portal do cliente](./08-portal-do-cliente.md) | Consulta segura e responsiva dos estados públicos | Pendente |
| 9 | [Qualidade e entrega](./09-qualidade-e-entrega.md) | Testes, segurança e critérios para publicação | Pendente |

## Marcos

1. **Fundação segura:** specs 0 a 3.
2. **Núcleo operacional:** specs 4 a 6.
3. **Produto utilizável:** specs 7 e 8.
4. **Liberação do MVP:** spec 9.

Cada spec deve ser detalhada imediatamente antes de sua implementação. Uma etapa só avança quando os critérios de aceite da anterior estiverem atendidos.
