# Spec 13 — Normalização do fuso horário da telemetria

**Status:** concluída e validada localmente em 15/09/2026. Migration aplicada em produção na mesma data; deploy da aplicação pendente.

**Tipo:** evolução da importação conjunta de estado e potência.

**Dependências:** specs 05, 10, 11 e 12.

## Problema

Foi observada uma diferença de três horas entre as fontes. Quando o horário do arquivo de potência está três horas à frente do mesmo evento em Fortaleza, a interpretação UTC representa o instante esperado. A diferença isolada não identifica automaticamente o fuso: o Master deve conferir o sentido do deslocamento e selecionar a origem. Sem normalização, leituras que representam o mesmo instante não são correlacionadas corretamente.

O nome do arquivo não define o fuso. O fuso pertence aos valores da coluna `Event Time`.

## Objetivo

Permitir que o Master informe o fuso dos horários no arquivo de potência e garantir que toda correlação use instantes absolutos, preservando o valor bruto para auditoria.

## Regra de precedência

Esta spec altera somente a interpretação temporal do arquivo de potência. Ela não altera a definição da aplicação, os limites dos controladores, a potência nominal, os estados operacionais ou o contrato sanitizado do cliente.

Depois da conversão, a aplicação e a telemetria devem ser comparadas por timestamp absoluto em UTC. As telas administrativas continuam exibindo os horários em `America/Fortaleza`.

## Fuso do arquivo

O campo será obrigatório para uma nova validação de potência e terá inicialmente as opções:

- `UTC` — para os arquivos atuais do controlador;
- `America/Fortaleza` — para arquivos já exportados no horário local.

O valor selecionado é armazenado no lote de potência, referenciado pela sessão e exibido em seu histórico. O seletor começa vazio: não há inferência automática baseada na diferença observada.

## Conversão e preservação

Para cada leitura de potência:

1. `occurred_at_raw` permanece exatamente como veio do XLSX;
2. o valor é interpretado no fuso selecionado;
3. `occurred_at` é gravado como `timestamptz`, representando o instante UTC;
4. a correlação com liga/desliga e a avaliação operacional usam `occurred_at`;
5. a interface pode mostrar o horário convertido e indicar o fuso de origem.

Horários sem fuso nunca podem ser tratados como UTC por padrão silencioso. Datas inválidas, fusos não suportados e horários inexistentes ou ambíguos por transição de horário de verão devem bloquear a prévia com erro por linha.

## Modelo de dados e idempotência

O lote de potência deve registrar `source_timezone` e uma versão da regra de normalização. O fingerprint e a chave de idempotência devem incluir o fuso selecionado, pois o mesmo texto bruto pode representar instantes diferentes em fusos distintos.

Lotes já confirmados não serão reescritos. A migration preenche somente os novos metadados dos lotes antigos com o fuso da unidade e versão `0`, identificando a interpretação anterior. Novos lotes com escolha explícita usam versão `1`.

Arquivos antigos devem ser reimportados com o fuso correto. A chave de lote inclui `source_timezone`; o fingerprint das novas leituras inclui o fuso e a versão. Uma repetição de lote legado no mesmo fuso continua reutilizando o lote existente.

A correção registra vínculos em `private.power_reading_replacements`. Leituras do mesmo controlador e gerador, com horário bruto, potência, Device ID e tipo/nome de evento correspondentes, são substituídas na correlação por sua nova interpretação. As linhas originais e as sessões antigas permanecem preservadas. Isso também cobre arquivos parcialmente sobrepostos. Repetir uma interpretação já substituída é bloqueado com orientação para usar o fuso da correção; desfazer uma correção histórica exige um fluxo futuro próprio.

## Experiência administrativa

No bloco **Potência consumida**, antes da validação, mostrar:

```text
Fuso horário do arquivo
[ UTC v ]
Os horários do XLSX serão convertidos para America/Fortaleza na tela.
```

Trocar o fuso invalida somente a prévia de potência e exige nova validação. A prévia deve mostrar o período convertido, o período bruto de referência e uma indicação clara de que a conversão foi aplicada.

Se o período convertido não intersectar o período de estado, a sessão deve continuar bloqueada com diagnóstico explícito de fuso ou de cobertura temporal.

## Reprocessamento

Uma importação corrigida reavalia o gerador selecionado usando somente as leituras efetivas. A cobertura temporal também é recalculada com essas leituras, impedindo que lotes substituídos ofereçam cobertura artificial. Os vínculos de substituição, novos lotes, sessões, resultados derivados e auditoria pertencem à mesma transação; a prévia executa o mesmo caminho e desfaz suas gravações.

**Decisão de implementação:** a correlação canônica consulta a sequência completa do gerador para preservar continuidade de estado, histerese e disputa por leituras nas bordas. A gravação das verificações e avaliações usa comparação de diferenças, preservando resultados não alterados. Não há um recorte rígido da consulta pelo intervalo do arquivo, pois ele poderia excluir a transição anterior necessária à correlação. Outros geradores não são reprocessados.

## Segurança e auditoria

- somente o Master escolhe o fuso e confirma o lote;
- o fuso de origem, a regra aplicada e o responsável ficam em auditoria;
- mensagens de erro não devem incluir conteúdo integral do arquivo;
- o portal do cliente não recebe o fuso, horários brutos, leituras ou IDs técnicos.

## Critérios de aceite

- [x] Um arquivo UTC com evento `23:00` é persistido como o instante equivalente a `20:00` em Fortaleza.
- [x] Um arquivo em `America/Fortaleza` não sofre deslocamento adicional.
- [x] `occurred_at_raw` permanece inalterado e o lote registra o fuso escolhido.
- [x] A prévia e a correlação usam os timestamps normalizados.
- [x] A troca do fuso invalida a prévia anterior.
- [x] O mesmo arquivo confirmado com o mesmo fuso é idempotente.
- [x] O mesmo arquivo com fuso diferente não é tratado como o mesmo lote.
- [x] A reimportação corrige aplicações afetadas sem duplicar auditoria.
- [x] RLS continua isolando dados técnicos do cliente.
- [x] Testes cobrem UTC, Fortaleza, erro de data, cobertura, fronteira e reprocessamento.
- [x] A validação visual confirma a indicação do fuso em desktop e smartphone.

## Plano de rollout

1. adicionar a coluna de origem temporal e a versão da regra;
2. publicar o seletor na prévia conjunta;
3. manter compatibilidade de leitura dos lotes existentes;
4. reimportar os arquivos UTC afetados, selecionando `UTC`;
5. comparar uma aplicação conhecida com os eventos de liga/desliga;
6. verificar o histórico com o fuso registrado e os resultados operacionais recalculados.

## Entrega

- Migration: `20260915173810_telemetry_source_timezone.sql`.
- Parser: escolha explícita da origem, precisão de milissegundos, recusa de datas inválidas e de horas históricas ambíguas/inexistentes.
- Servidor: revalidação do arquivo e da escolha do fuso na prévia e confirmação; bloqueio quando o fuso diverge da prévia.
- Interface: seletor no bloco de potência, períodos original e convertido, invalidação da prévia de potência e da projeção conjunta, histórico com fuso e indicação de interpretação legada.
- Banco: metadados, idempotência por fuso, substituição auditável de leituras e processamento de fontes efetivas; funções privilegiadas e vínculos técnicos restritos ao schema privado.
- Validação visual local em 1440 e 390 px: arquivo UTC `10:00–12:30` exibido em Fortaleza como `07:00–09:30`, uma aplicação `within_expected`, uma `below_expected`, confirmação persistida e histórico com UTC. Trocar o fuso preservou a prévia de estado e bloqueou a confirmação até revalidar potência. Sem overflow horizontal da página.
- Evidências locais: `output/playwright/spec13/preview-1440.png` e `preview-390.png`.

A migration foi aplicada ao banco de produção em 15/09/2026. A correção de arquivos reais acontece após o deploy da aplicação e a reimportação explícita pelo Master.

## Validação concluída

- 143 testes da aplicação em 15 arquivos aprovados; teste de actions repetido após refinamento da cobertura de fuso ausente/inválido.
- Typecheck, ESLint e build de produção com Node 24 e Webpack aprovados.
- As 22 migrations foram aplicadas do zero com `supabase db reset --local --no-seed --yes`; a nova migration consta no histórico local.
- 19 arquivos SQL aprovados, incluindo correção após importação legada, deduplicação de arquivo sobreposto, bloqueio de interpretação obsoleta, falha tardia com rollback, privacidade e autorização. Antes do reset, os 18 existentes e o novo teste passaram pelo CLI; após o reset, o executor Docker ficou parado e a suíte completa foi executada diretamente com `psql`, `ON_ERROR_STOP`, verificação das saídas TAP e rollback por arquivo.
- `supabase db lint --local --schema public,private` sem erros e tipos públicos atualizados.
- Dados sintéticos da validação visual removidos pela recriação local.

## Aplicação em produção

- Em 15/09/2026, o dry-run identificou somente `20260915173810_telemetry_source_timezone.sql` como pendente no projeto `wvaeojbuarhfizdpxldi`.
- Migration aplicada com `supabase db push --linked --yes` após o commit de implementação `eca985a`.
- Histórico remoto conferido: as 22 migrations locais e remotas estão alinhadas.
- `supabase db lint --linked --schema public,private` concluído sem erros.
- Deploy da aplicação e reimportação de arquivos reais não foram executados nesta etapa.
