# Spec 07 — Painel administrativo

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
