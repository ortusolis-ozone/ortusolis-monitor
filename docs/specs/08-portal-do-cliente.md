# Spec 08 — Portal do cliente

## Objetivo

Permitir consulta rápida dos registros de aplicação sem expor eventos ou parâmetros operacionais.

## Experiência

- Usuário entra diretamente no contexto de sua empresa.
- Navegação: empresa → local → câmara → gerador.
- Visão consolidada mostra o estado mais relevante de cada item.
- Histórico diário permite filtros por período, local, câmara e gerador.
- Cabeçalho informa `Registros atualizados até DD/MM/AAAA`.
- Interface responsiva para desktop, tablet e smartphone.

## Estados e linguagem

- `Concluído`: há registro completo de aplicação.
- `Verificação necessária`: existe uma inconsistência nos registros; isso não confirma falha do equipamento.
- `Sem dados`: não há registro completo disponível para o período já importado.
- `Aguardando atualização`: a importação ainda não alcançou o período.

Evitar textos que afirmem cumprimento de programação, quantidade de aplicações, duração ou funcionamento correto do gerador.

## Consolidação

Quando uma visão reúne vários geradores, usar a precedência:

1. Verificação necessária.
2. Aguardando atualização.
3. Sem dados.
4. Concluído.

A interface deve permitir abrir o nível inferior para identificar qual item determinou o estado consolidado.

## Segurança da resposta

- Consultas usam exclusivamente a hierarquia autorizada e `client_daily_status`.
- Nenhum endpoint do portal consulta ou serializa `raw_events`, `applications` ou detalhes de inconsistências.
- Horários e duração não aparecem em HTML, propriedades, respostas JSON, exportações ou metadados.
- Os três papéis de cliente têm a mesma permissão de consulta no MVP.

## Critérios de aceite

- Um usuário vê somente os dados do próprio cliente.
- É possível identificar rapidamente a última atualização e os itens que requerem verificação.
- Histórico e filtros funcionam sem revelar dados técnicos.
- Estados vazios explicam a diferença entre ausência de dados e espera por importação.
- As principais tarefas funcionam nos três tamanhos de tela previstos.
