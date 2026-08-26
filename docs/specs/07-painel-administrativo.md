# Spec 07 — Painel administrativo

**Status:** concluída.

## Objetivo

Reunir as operações necessárias para a Ortusolis administrar clientes, importar registros e revisar problemas.

## Navegação mínima

- Visão geral.
- Clientes e instalações.
- Importações.
- Inconsistências.
- Usuários.
- Mapeamento de origens.

## Visão geral

Exibir somente indicadores úteis à operação:

- clientes ativos;
- geradores ativos;
- inconsistências pendentes;
- últimas importações e seus resultados.

Não são necessários gráficos analíticos no MVP.

## Importações

- Iniciar o fluxo definido na spec 05.
- Consultar histórico de lotes.
- Ver autor, arquivo, contexto, intervalo, totais e resultado.
- Abrir mensagens de erro de lotes com falha.

## Inconsistências

- Listar pendentes por padrão.
- Filtrar por cliente, local, gerador, tipo, período e estado.
- Consultar eventos técnicos relacionados.
- Adicionar observação interna.
- Marcar como revisada, registrando autor e horário.
- Reabrir uma revisão realizada por engano.

## Mapeamento de origem

- Listar valores encontrados em `Acionado por`.
- Classificar como programado ou teste.
- Valores não cadastrados permanecem desconhecidos.
- Alterar um mapeamento solicita confirmação e reprocessa geradores afetados.

## Critérios de aceite

- O Master completa o fluxo operacional sem acessar diretamente o banco.
- A quantidade de pendências corresponde às inconsistências não revisadas.
- A interface deixa claro quando uma alteração provoca reprocessamento.
- Ações administrativas importantes são auditadas.
- Estados de carregamento, vazio, sucesso e erro estão previstos nas telas.

## Resultado da implementação

- A navegação administrativa foi reorganizada nos seis fluxos do MVP, mantendo atalhos para unidades, câmaras, geradores, alocações e controladores na visão geral.
- A visão geral passou a exibir clientes e geradores ativos, a contagem exata de inconsistências pendentes e as cinco importações mais recentes, sem gráficos analíticos.
- O histórico de importações agora apresenta autor, arquivo, cliente, unidade, câmara, gerador, controlador, intervalo, totais, origens desconhecidas, resultado e mensagem de falha.
- A tela de inconsistências abre nas pendências e permite combinar filtros por estado, tipo, cliente, unidade, gerador e período. Cada registro mostra os eventos técnicos principal e relacionado.
- Revisar registra nota interna opcional, autor e horário. Reabrir remove os dados da revisão; as duas ações solicitam confirmação, são auditadas e reprocessam os estados afetados.
- O mapeamento reúne os valores confirmados de `Acionado por`, quantidade de eventos, última ocorrência e classificação atual. Programar, marcar como teste ou voltar a desconhecido solicita confirmação e reprocessa todos os geradores afetados.
- As consultas administrativas usam funções `security invoker`, permissões mínimas e RLS exclusiva para Master ativo. Usuários de cliente recebem listas vazias e não conseguem executar mutações administrativas.
- Foram adicionados estados globais de carregamento e erro, vazios específicos e retornos de sucesso/erro nos formulários. A interface foi validada em navegador real nas larguras desktop e móvel.
- Testes SQL transacionais cobrem RLS, filtros, contagem de pendências, revisão, reabertura, autoria, auditoria, remapeamento e reprocessamento. TypeScript, ESLint, lint do banco e build de produção também foram validados.
