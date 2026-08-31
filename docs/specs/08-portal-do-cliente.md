# Spec 08 — Portal do cliente

**Status do MVP original:** concluída.

**Evolução Spec 10:** pendente de implementação.

> **Evolução:** a comunicação qualitativa da evidência de potência, sem exposição de dados técnicos, é definida pela [spec 10](./10-duplo-controlador-e-telemetria-de-potencia.md).

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

## Resultado da implementação

- O portal abre diretamente na empresa vinculada ao perfil autenticado e apresenta uma visão consolidada expansível por unidade, câmara e gerador.
- A consolidação usa a precedência pública definida, destaca imediatamente itens com verificação necessária e oferece atalhos para o histórico já filtrado no nível selecionado.
- O cabeçalho converte imediatamente o maior `updated_at` sanitizado em uma data pública, sem serializar horários, e o histórico diário combina filtros de período, unidade, câmara e gerador por navegação server-rendered.
- Toda leitura da página usa apenas `clients`, `locations`, `cold_rooms`, `generators` e `client_daily_status`, com seleção explícita de campos sanitizados. Não foi criado endpoint JSON para o portal.
- A interface diferencia estados publicados, ausência de registros e períodos ainda não alcançados, sem afirmar quantidade, duração, programação ou funcionamento do equipamento.
- O layout possui tabela responsiva convertida em cartões no smartphone, grade intermediária no tablet e hierarquia expansível no desktop, além de estados de carregamento e erro recuperável.
- Testes transacionais cobrem os três papéis de cliente, isolamento entre duas empresas, filtros combinados, precedência, data do cabeçalho, schema sanitizado e bloqueio de dados operacionais.
