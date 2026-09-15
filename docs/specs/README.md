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

| Ordem | Especificação | Resultado esperado | MVP original | Evolução Spec 10 |
| --- | --- | --- | --- | --- |
| 0 | [Regras e escopo](./00-regras-e-escopo.md) | Vocabulário e regras de negócio congelados | Concluída | Não impactada |
| 1 | [Arquitetura base](./01-arquitetura-base.md) | Fundação técnica e limites entre as camadas | Concluída | Não impactada |
| 2 | [Modelo de dados](./02-modelo-de-dados.md) | Schema, relacionamentos e histórico operacional | Concluída | Pendente de implementação |
| 3 | [Autenticação e autorização](./03-autenticacao-e-autorizacao.md) | Login, perfis, isolamento e políticas RLS | Concluída | Pendente de implementação |
| 4 | [Cadastros operacionais](./04-cadastros-operacionais.md) | Estrutura Cliente → Controlador utilizável | Concluída | Pendente de implementação |
| 5 | [Importação XLSX](./05-importacao-xlsx.md) | Validação, prévia e confirmação idempotente | Concluída | Pendente de implementação |
| 6 | [Processamento e estados](./06-processamento-e-estados.md) | Aplicações, inconsistências e visão sanitizada | Concluída | Pendente de implementação |
| 7 | [Painel administrativo](./07-painel-administrativo.md) | Operação completa pela Ortusolis | Concluída | Pendente de implementação |
| 8 | [Portal do cliente](./08-portal-do-cliente.md) | Consulta segura e responsiva dos estados públicos | Concluída | Pendente de implementação |
| 9 | [Qualidade e entrega](./09-qualidade-e-entrega.md) | Testes, segurança e critérios para publicação | Pendente de conclusão | Pendente de implementação |
| 10 | [Duplo controlador e telemetria de potência](./10-duplo-controlador-e-telemetria-de-potencia.md) | Dois sinais por gerador, importação de potência e evidência sanitizada | Não se aplica | Concluída |
| 11 | [Importação conjunta de estado e potência](./11-importacao-conjunta-de-estado-e-potencia.md) | Dois campos visíveis, confirmação conjunta e histórico agrupado | Não se aplica | Concluída |
| 12 | [Potência nominal e alerta de redução operacional](./12-potencia-nominal-e-alerta-de-reducao-operacional.md) | Mínimo automático de 85%, diagnóstico técnico e alerta qualitativo | Não se aplica | Concluída; validada localmente |

## Marcos

1. **Fundação segura:** specs 0 a 3.
2. **Núcleo operacional:** specs 4 a 6.
3. **Produto utilizável:** specs 7 e 8.
4. **Liberação do MVP:** spec 9.
5. **Evolução de telemetria:** spec 10 concluída.
6. **Operação conjunta das duas fontes:** spec 11 concluída.
7. **Avaliação da potência operacional:** spec 12 concluída e validada localmente em 15/09/2026.

Cada spec deve ser detalhada imediatamente antes de sua implementação. Uma etapa só avança quando os critérios de aceite da anterior estiverem atendidos.

A spec 10 é uma evolução do domínio já implementado. Nos pontos de controlador e telemetria de potência, sua regra de precedência substitui as premissas correspondentes das specs anteriores sem reabrir as demais decisões do MVP.

A spec 11 evolui apenas a experiência de importação definida nas specs 05 e 10. Ela agrupa os dois lotes em uma sessão administrativa, sem substituir os formatos, a correlação temporal ou a publicação sanitizada da spec 10.

A spec 12 adiciona potência nominal versionada ao gerador e avalia a leitura de início correlacionada pela spec 10. Ela mantém a aplicação como estado principal, calcula automaticamente o mínimo de 85% e expõe ao cliente somente um alerta qualitativo quando houver redução abaixo do esperado.
