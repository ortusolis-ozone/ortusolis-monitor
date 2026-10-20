# Spec 16 — Retenção do histórico e exportação em PDF

**Status:** implementada e validada localmente em 20/10/2026; migration, publicação e início da transição em produção pendentes.

**Dependências:** specs 02, 05, 06, 08, 09, 10 e 11.

## Objetivo e regras

Limitar o crescimento dos dados operacionais, disponibilizando ao cliente os últimos **35 dias**, com download em PDF, e mantendo **90 dias** para consulta administrativa e reprocessamento.

Esta spec substitui as regras anteriores de preservação indefinida de eventos. Cadastros, vigências necessárias e auditoria administrativa continuam preservados.

| Dados | Disponibilidade |
| --- | --- |
| Histórico no portal e PDF | Últimos 35 dias |
| Histórico operacional administrativo | Últimos 90 dias |
| Histórico operacional vencido | Removido pela limpeza diária |
| Cadastros e auditoria administrativa | Preservados |

Os prazos seguem a data dos registros no fuso da unidade, incluindo o dia atual. Para uma data local `D`, o cliente acessa de `D − 34` até `D`; a retenção operacional abrange de `D − 89` até `D`.

Usar a data pública existente para aplicações e estados diários; para eventos e leituras, usar a data local de ocorrência. Importação, correção ou reprocessamento não reiniciam os prazos.

## Portal e PDF

- Limitar calendário, filtros, resultados e contadores ao período permitido.
- Identificar datas vencidas como **“Fora do período disponível”**, sem apresentá-las como ausência de registros.
- Exibir: **“O histórico fica disponível por 35 dias. Baixe o PDF para guardar seus registros.”**
- Adicionar **“Baixar PDF”**, respeitando os filtros selecionados e a janela disponível.
- Incluir empresa, período efetivamente exportado, emissão, unidade, câmara, gerador, aplicações, horários, potência máxima e alertas já exibidos pelo portal.
- Gerar um relatório tabular simples, com paginação e cabeçalho repetido, sem gráficos ou personalização.
- Exportar todos os resultados filtrados, sem truncamento silencioso. Sem resultados, informar isso e não gerar um arquivo vazio.
- Gerar o PDF sob demanda e entregar diretamente ao cliente, sem armazenar cópia no sistema.

Adicionar uma rota autenticada de download no portal, reutilizando as consultas e a autorização existentes. O PDF não pode incluir eventos brutos, origens de comandos ou informações exclusivas da administração.

Aplicar o limite também nas RPCs atuais e legadas e nas políticas de acesso direto às tabelas. Restringir apenas a interface não atende à spec. Respostas do relatório não devem usar cache compartilhado.

## Retenção e processamento

Implementar uma rotina privada de limpeza diária pelo Supabase Cron, sem endpoint público de exclusão.

A limpeza deve:

- Remover eventos, leituras, aplicações, verificações, inconsistências e estados públicos vencidos.
- Remover referências de correções e detalhes operacionais associados aos registros excluídos.
- Remover lotes e sessões quando deixarem de ser necessários aos dados retidos. Lotes mistos não podem provocar exclusão de registros recentes.
- Preservar cadastros e vigências utilizados pelos registros restantes.
- Preservar somente informações administrativas na auditoria; conteúdo operacional vencido não pode sobreviver em campos JSON ou cópias de registros.
- Usar exclusões em lotes e os bloqueios por gerador já existentes, evitando conflito com importações e reprocessamentos.
- Permitir repetição após falhas, sem duplicidade ou corrupção, e registrar contagens, conclusão e erro sem copiar os dados removidos.

Ajustar os mecanismos de imutabilidade apenas para permitir essa manutenção autorizada. Não liberar exclusões comuns para clientes ou administradores.

A remoção não pode deixar referências quebradas. Quando uma avaliação retida perder evidência necessária pelo vencimento, ela deve ficar inconclusiva conforme os estados existentes, sem gerar uma conclusão de falha do equipamento. O reprocessamento não pode recriar histórico vencido.

Na importação:

- Ignorar registros fora dos 90 dias, mostrando a quantidade na prévia.
- Importar normalmente os registros válidos de arquivos mistos.
- Impedir confirmação quando todos os registros estiverem vencidos.
- Revalidar o prazo na confirmação; se a quantidade elegível mudou desde a prévia, solicitar nova validação.
- Aplicar a regra também nos caminhos legados e nas funções de confirmação do banco.

Manter a remoção imediata dos XLSX temporários e adicionar limpeza diária de arquivos abandonados há mais de 24 horas, usando a API de Storage.

## Entrada em vigor e simplicidade

Publicar o PDF e o aviso antes de restringir o acesso. Manter o histórico existente consultável e exportável durante **35 dias de transição**.

Registrar uma única data de ativação no banco, consultada pela aplicação e pela rotina de limpeza. Ao chegar essa data:

1. Aplicar as janelas de 35 e 90 dias.
2. Iniciar a limpeza dos registros existentes em lotes.
3. Conferir conclusão e falhas pelo histórico do agendador.

Antes da primeira exclusão, executar consulta de simulação com contagens por tabela.

A exclusão abrange o ambiente operacional. Backups seguem sua retenção própria; após restauração, reaplicar a política antes de liberar acesso. PDFs baixados ficam sob guarda do cliente.

Não criar configurações por cliente, filas, microserviços, armazenamento de relatórios, envio por e-mail ou painel novo de monitoramento. Usar Next.js, PostgreSQL, Supabase Cron e os mecanismos existentes de autorização e auditoria.

Adicionar esta spec ao índice e atualizar as referências à preservação indefinida nas specs anteriores.

## Critérios de aceite e validação

- [x] Cliente consulta e exporta somente o período autorizado, inclusive por chamadas diretas.
- [x] Master consulta os registros retidos até o vencimento.
- [x] PDF reproduz os dados e filtros do portal, sem vazamento entre clientes ou truncamento.
- [x] Datas vencidas são diferenciadas de datas sem registros.
- [x] Importações antigas e mistas respeitam o prazo sem duplicar dados.
- [x] Limpeza remove o histórico vencido e preserva cadastros e registros recentes.
- [x] Reprocessamento e limpeza concorrentes não quebram referências nem recriam dados excluídos.
- [x] A transição mantém acesso e exportação por 35 dias antes da ativação.
- [x] Falhas da limpeza ficam visíveis e permitem nova execução segura.

Cobrir limites de 35/90 dias, fusos diferentes, virada de mês, aplicações atravessando o corte, dependências de potência, isolamento entre dois clientes, repetição da limpeza e PDF multipágina.

Executar testes SQL e da aplicação pertinentes, typecheck, lint e build. Conferir o PDF renderizado e o portal em desktop e celular.

Antes de alterar código Next.js, ler os guias locais pertinentes em `node_modules/next/dist/docs/`, conforme `AGENTS.md`.

## Implementação e publicação

A migration é `supabase/migrations/20261019185805_history_retention_pdf.sql`. O PDF usa `pdf-lib` na rota autenticada `/portal/relatorio`, com as mesmas consultas e filtros do portal, paginação completa das RPCs e resposta `private, no-store`.

A data única fica em `private.history_retention_policy.activates_at`. A migration a deixa **nula**: instalar o banco antes de publicar o portal não inicia a transição nem restringe o histórico. Funções de manutenção são privadas e executáveis somente pelo proprietário do banco, não pelos papéis de cliente, Master ou `service_role`.

Ordem de publicação:

1. Aplicar as migrations pendentes, incluindo as specs 14 e 15, das quais as definições atuais dependem.
2. Publicar a aplicação e conferir o aviso e o download autenticado.
3. Configurar no Vault `retention_storage_url` com a URL base do projeto e `retention_storage_service_key` com uma chave de servidor autorizada a excluir objetos. Não incluir a chave em SQL versionado, variáveis `NEXT_PUBLIC_*` ou logs.
4. Iniciar o aviso com a chamada abaixo, usando uma conexão administrativa. A chamada é idempotente e não adia uma data já registrada.
5. Durante a transição, executar e registrar a simulação abaixo. Conferir os jobs após a ativação.

```sql
select private.start_history_retention_notice();
```

Simulação antes da primeira exclusão, sem alterar a ativação visível às outras conexões:

```sql
begin;
update private.history_retention_policy set activates_at = now();
select * from private.history_retention_counts();
rollback;
```

As contagens mostram os candidatos por tabela na data da simulação; dependências, correções e lotes compartilhados são conferidos novamente durante a remoção. Repetir a consulta perto da ativação para atualizar a estimativa.

O job `history-retention-daily` roda às **06:15 UTC**. Cada passagem exclui até 5.000 eventos e 5.000 leituras, além dos derivados e referências associados, sob o mesmo bloqueio por gerador usado nas importações. A rotina confirma cada passagem e libera o bloqueio antes da seguinte. Resumos de reprocessamentos que perderam evidências são descartados; cadastros e vigências permanecem. As contagens ficam na auditoria com a ação `history_retention_purge`.

O job `abandoned-import-uploads-daily` roda às **06:45 UTC** e remove arquivos com mais de 24 horas em grupos de 100, exclusivamente pela API de Storage. A falta dos segredos gera erro quando houver arquivos vencidos para remover.

Consultar conclusão e erros, sem painel adicional:

```sql
select j.jobname, d.start_time, d.end_time, d.status, d.return_message
from cron.job_run_details d
join cron.job j on j.jobid = d.jobid
where j.jobname in ('history-retention-daily', 'abandoned-import-uploads-daily')
order by d.start_time desc
limit 50;
```

Após corrigir uma falha, o próximo agendamento retoma a limpeza. Para antecipar a execução, usar `call private.purge_history()` fora de um bloco `BEGIN` — a procedure faz seus próprios commits. A limpeza de Storage pode ser repetida com `select private.purge_abandoned_import_uploads()`.

Após restaurar um backup, manter o acesso fechado, reaplicar a migration quando necessário, recuperar a data de ativação já publicada e executar a política antes de liberar o portal. Não reiniciar os 35 dias de transição por causa da restauração.

## Evidências de validação local

- Suíte completa: 23 arquivos SQL e 198 testes da aplicação aprovados. Inclui chamadas atuais/legadas, RLS, dois clientes, limites de dias e fusos, virada de mês, aplicação atravessando o corte, evidência de potência vencida, arquivos mistos, prévia desatualizada e consulta com 1.001 aplicações.
- Migração integral reexecutada sobre as definições anteriores dentro de uma transação de teste, desfeita ao final. Lint SQL sem erros.
- Duas conexões confirmaram o bloqueio por gerador e a repetição após timeout. A procedure completa foi executada duas vezes com fixtures, conferindo commits, idempotência e remoção de conteúdo operacional da auditoria.
- Storage local: arquivo sintético com mais de 24 horas removido pela API; arquivo recente preservado. Fixtures e segredos temporários removidos após o teste.
- PDF de 150 aplicações e 17 páginas renderizado e conferido, inclusive última página. Download real autenticado testado; mês vencido retorna 404 sem PDF e sem cache compartilhado.
- Portal conferido em 1440 px e 390 px, sem rolagem horizontal. Datas vencidas e limites do seletor de meses verificados no navegador.
- Typecheck, ESLint e build com `next build --webpack` aprovados. O build padrão com Turbopack encontrou uma restrição de criação de processo/porta no ambiente de execução.

O advisor do Supabase sinaliza `search_path` mutável na procedure de limpeza. A exceção é intencional: PostgreSQL proíbe `COMMIT` em procedures com cláusula `SET`. A rotina define `search_path` vazio por transação, qualifica os objetos e só pode ser chamada pelo proprietário do banco. As demais funções usam `SET search_path = ''`.
