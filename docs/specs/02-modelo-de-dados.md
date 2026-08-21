# Spec 02 — Modelo de dados

**Status:** concluída.

## Objetivo

Definir o schema mínimo para identidade, instalações, importação, processamento e publicação segura.

## Entidades principais

### Identidade e estrutura

- `profiles`: usuário do Auth, cliente opcional, nome, papel e status.
- `clients`: razão social, CNPJ, status.
- `locations`: cliente, nome, identificação/localização, fuso e status.
- `cold_rooms`: local, nome, categoria e status.
- `generators`: identificação e status.
- `generator_assignments`: gerador, câmara, início e fim da vigência.
- `controllers`: gerador, identificação, ativação, desativação e status.

`profiles.client_id` é nulo para o Master e obrigatório para usuários de cliente. Um usuário pertence a no máximo um cliente no MVP.

### Importação e processamento

- `source_mappings`: valor normalizado de origem e classificação (`programmed`, `test`).
- `import_batches`: contexto selecionado, nome e hash do arquivo, estado, totais, intervalo temporal e usuário responsável.
- `raw_events`: lote, gerador, controlador, instante, operação, origem original, origem normalizada, classificação e fingerprint.
- `applications`: gerador, evento de início, evento de fim e data pública da aplicação.
- `inconsistencies`: gerador, tipo, eventos relacionados, data pública, estado de revisão, observação e revisor.
- `client_daily_status`: cliente, local, câmara, gerador, data, estado público e data de atualização.
- `audit_logs`: ator, ação, entidade, identificador e instante.

## Regras estruturais

- Perfis usam o UUID correspondente ao Supabase Auth; entidades de domínio expostas usam UUID e tabelas internas de alto volume podem usar `bigint identity`.
- Datas técnicas são armazenadas com fuso; a data pública é calculada no fuso da unidade.
- CNPJ é único após normalização.
- Um gerador possui somente uma alocação ativa por vez.
- Um controlador possui somente um período ativo e períodos de controladores do mesmo gerador não devem se sobrepor.
- Eventos não são apagados por desativação de cadastros.
- `raw_events.fingerprint` é único e impede reimportação do mesmo evento.
- Aplicações e inconsistências referenciam os eventos que as originaram.
- `client_daily_status` não contém horários, duração, ciclos ou origem.

## Estratégia de alterações

- Cadastros usam status ativo/inativo em vez de exclusão física.
- Realocar gerador fecha uma alocação e cria outra.
- Substituir controlador encerra o atual e cria um novo.
- Registros derivados podem ser removidos e reconstruídos durante reprocessamento; eventos brutos não.

## Índices mínimos

- Todas as chaves estrangeiras usadas para navegação ou RLS são indexadas explicitamente.
- Eventos por `(generator_id, occurred_at)`.
- Fingerprint único dos eventos.
- Inconsistências pendentes por estado e data, preferencialmente com índice parcial.
- Estados públicos por `(client_id, date)` e por gerador/data.

## Critérios de aceite

- O histórico continua correto após realocação ou troca de controlador.
- Não é possível vincular registros entre clientes diferentes.
- É possível reconstruir aplicações, inconsistências e estados usando somente dados persistidos.
- A tabela sanitizada não permite deduzir horários ou duração.

## Resultado da implementação

- O schema foi versionado em uma única migração inicial do Supabase.
- Chaves estrangeiras compostas impedem vínculos entre hierarquias de clientes diferentes.
- Restrições de exclusão impedem períodos sobrepostos de alocação e de controladores.
- Todas as tabelas públicas têm RLS habilitada; `anon` e `authenticated` permanecem sem acesso até a definição das políticas na spec 03.
- A `service_role` possui permissões explícitas para as operações internas.
- Os tipos TypeScript do schema foram gerados e aplicados aos clientes Supabase do navegador e do servidor.
- O reset completo, o lint do schema e os testes transacionais locais foram executados com sucesso.

A aplicação da migração em um ambiente hospedado fica pendente até o provisionamento de um projeto Supabase exclusivo para o Ortusolis Monitor.
