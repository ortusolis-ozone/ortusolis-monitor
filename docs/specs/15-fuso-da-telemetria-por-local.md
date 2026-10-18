# Spec 15 — Fuso da telemetria por local

**Status:** implementada e validada localmente em 17/10/2026; migration e publicação em produção pendentes.

**Tipo:** evolução do cadastro operacional e da importação conjunta de estado e potência.

**Dependências:** specs 02, 04, 05, 10, 11 e 13.

## Problema

A importação de potência exige selecionar o fuso do XLSX a cada validação, mesmo quando os arquivos de uma unidade seguem sempre a mesma referência temporal. Essa repetição aumenta o trabalho operacional e a possibilidade de interpretar incorretamente os horários.

O cadastro de local já possui `time_zone`, usado nas datas operacionais e na interpretação do arquivo de liga/desliga. Esse valor não determina, sozinho, o fuso da telemetria: uma unidade em Fortaleza pode receber arquivos exportados em UTC.

## Objetivo

Cadastrar previamente, por local do cliente, a referência temporal dos arquivos de telemetria e aplicá-la automaticamente na importação. Permitir exceção para um arquivo específico, mantendo a normalização em UTC, a correção auditável por reimportação e a preservação do histórico.

## Regra de precedência

Esta spec substitui a exigência da spec 13 de iniciar toda importação de potência com o seletor vazio. A escolha explícita pode ocorrer previamente no cadastro do local, com autoria auditável, e ser herdada na importação.

Permanecem as regras da spec 13 para preservação do horário bruto, normalização, idempotência, substituição auditável de leituras, reprocessamento e bloqueio de interpretações já corrigidas. A spec 14 e as classificações de origem dos comandos não são alteradas.

O sistema não deduz o fuso pelo nome do arquivo, pelo navegador, pelo servidor, pelo último lote ou pela diferença observada entre as fontes.

## Conceitos e escopo

| Conceito | Configuração | Uso |
| --- | --- | --- |
| Fuso da unidade | `locations.time_zone` | Referência operacional do local e interpretação de liga/desliga |
| Referência temporal da telemetria | `locations.telemetry_time_basis` | Define se os horários do arquivo estão em UTC ou no horário da unidade |
| Fuso efetivo do arquivo | `import_batches.source_timezone` | Registra o fuso concreto utilizado para interpretar aquele lote |

A configuração pertence ao local, e não diretamente ao cliente: um cliente pode possuir unidades com referências temporais diferentes.

Estão fora desta entrega: configuração por controlador, inferência automática, ajuste arbitrário de relógio em minutos/horas, reprocessamento histórico provocado apenas pela alteração do cadastro e reversão de correções históricas. Uma configuração por controlador poderá ser uma evolução caso equipamentos do mesmo local exijam padrões diferentes.

## Cadastro operacional

Adicionar `telemetry_time_basis` ao local, com os valores:

- `utc`: os valores de `Event Time` são horários UTC.
- `location`: os valores de `Event Time` estão no fuso cadastrado em `time_zone`.
- `null`: referência ainda não configurada, permitida para compatibilidade com locais existentes.

Não atribuir um padrão silencioso. Novos locais devem exigir uma escolha explícita nos fluxos de criação, inclusive no cadastro completo de cliente. Locais existentes podem continuar sendo consultados e editados sem configuração, mas a importação de potência deve orientar o Master a configurá-la antes de validar o arquivo.

Apresentar no cadastro:

```text
Fuso horário da unidade
[ America/Fortaleza ]

Horário dos arquivos de telemetria
[ UTC / Horário da unidade ]

Escolha UTC se 23:00 no arquivo corresponder a 20:00 em Fortaleza.
Escolha Horário da unidade se o arquivo já apresentar o horário local.
```

O exemplo acima é específico para Fortaleza. Em locais com outro fuso, usar uma explicação coerente com a configuração, sem apresentar uma diferença fixa de três horas como regra geral.

Somente o Master ativo pode configurar ou alterar essa preferência. Registrar valor anterior, novo valor, local, responsável e instante da alteração. Salvar o mesmo valor não deve produzir uma mudança ou auditoria duplicada.

Alterar a referência da telemetria não altera `time_zone`. Alterar `time_zone` deve explicitar que, quando a preferência for `location`, as próximas importações herdarão o novo fuso. Esta entrega não redefine os efeitos operacionais já existentes da alteração de `time_zone`.

## Resolução do fuso no servidor

A resolução deve ocorrer depois de validar a hierarquia operacional e consultar o cadastro autorizado do local:

1. Sem referência configurada, bloquear a validação de potência e orientar o cadastro; a exceção por arquivo não substitui essa configuração inicial.
2. Se houver uma exceção explícita para o arquivo, utilizar o fuso validado dessa exceção.
3. Caso contrário, `utc` resolve para `UTC` e `location` resolve para o `time_zone` atual do local.
4. Entregar ao parser o fuso concreto resolvido e preservar essa informação na prévia e na confirmação.

O pedido do navegador deve distinguir **usar configuração do local** de **alterar para este arquivo**. Não confiar em um `sourceTimezone` arbitrário como evidência de que o valor veio do cadastro. O servidor resolve e verifica a procedência da escolha.

Para a exceção, oferecer `UTC` e o fuso atual da unidade, sem duplicar opções quando forem equivalentes. Preservar também `America/Fortaleza` como opção de compatibilidade para corrigir arquivos históricos. Outros fusos avulsos não são necessários nesta entrega.

O modo `location` deve aceitar os fusos IANA suportados pelo cadastro e pela cadeia de normalização. A implementação deve harmonizar validações da aplicação e do banco; não basta ampliar o seletor enquanto a restrição atual da potência aceita somente `UTC` e `America/Fortaleza`. Recusar configurações não suportadas com erro explícito, sem substituir por UTC.

## Experiência de importação

Ao selecionar o local, carregar sua preferência. No bloco de potência, substituir a escolha obrigatória recorrente por um resumo e uma ação de exceção:

```text
Horários da telemetria: UTC
Configuração do local: Unidade Fortaleza

[Alterar para este arquivo]
```

Após a leitura do XLSX, a prévia deve mostrar o período bruto, o período convertido no fuso da unidade e a origem da escolha. Exemplos devem usar datas completas quando a conversão cruzar a meia-noite.

Ao acionar a exceção, mostrar o seletor com o fuso efetivo atual e indicar **Alteração somente para este arquivo**. Oferecer **Usar configuração do local** para remover a exceção. Essa ação não altera o cadastro e não deve oferecer uma gravação implícita da preferência.

- Alterar o fuso efetivo invalida a prévia de potência e a projeção conjunta, preservando o arquivo e a prévia de liga/desliga quando seu contexto continuar válido.
- Alterar somente a origem da escolha, mesmo mantendo o fuso, exige atualizar a prévia antes da confirmação para manter a procedência coerente.
- Trocar o arquivo de potência, controlador ou hierarquia elimina a exceção anterior e aplica novamente o padrão do local. Preservar as invalidações de contexto já existentes no fluxo.
- A confirmação bem-sucedida encerra a exceção; uma nova importação começa com a preferência cadastrada.
- Sem configuração, apresentar **Configure o horário dos arquivos de telemetria no cadastro do local** e um caminho administrativo para o cadastro.
- Falhas e novas tentativas de validação do mesmo arquivo não devem apagar silenciosamente a exceção escolhida.

## Normalização e correção UTC

Não implementar uma operação separada de somar ou subtrair três horas. A correção ocorre pela interpretação do horário bruto no fuso efetivo, uma única vez.

| Horário bruto em 16/10/2026 | Fuso efetivo | Instante normalizado | Exibição em Fortaleza |
| --- | --- | --- | --- |
| `23:00` | `UTC` | `2026-10-16T23:00:00Z` | `16/10/2026 20:00` |
| `20:00` | `America/Fortaleza` | `2026-10-16T23:00:00Z` | `16/10/2026 20:00` |

Preservar `occurred_at_raw` exatamente como recebido e os milissegundos. Armazenar o instante normalizado em `occurred_at` e comparar potência e liga/desliga por instantes absolutos.

O arquivo de liga/desliga continua usando o fuso da unidade, independentemente da preferência ou da exceção da potência. Manter erros por linha para datas inválidas e horários locais inexistentes ou ambíguos. Ao ampliar os fusos suportados, validar também transições de horário de verão com deslocamento diferente de uma hora.

## Prévia, confirmação e concorrência

A prévia deve conter um retrato verificável da configuração utilizada: local, preferência temporal, fuso da unidade, fuso efetivo e origem da escolha. Uma revisão da configuração temporal deve permitir detectar alterações posteriores, inclusive uma alteração seguida de retorno ao valor anterior.

Na confirmação, revalidar arquivo, hierarquia, autorização, configuração e escolha. Se a configuração temporal relevante tiver mudado, recusar a confirmação e pedir nova validação; nunca recalcular silenciosamente com outro fuso após a aprovação da prévia.

Garantir essa verificação também no limite transacional da gravação, evitando que uma alteração concorrente do cadastro ocorra entre a última conferência e a confirmação do lote. A confirmação deve usar exatamente a configuração aprovada ou falhar sem gravação parcial.

Mudança somente em `telemetry_time_basis` invalida potência e projeção conjunta. Mudança em `time_zone` exige revalidar também liga/desliga, pois sua interpretação depende desse valor. A exceção por arquivo não elimina essa verificação do contexto temporal.

## Persistência, procedência e idempotência

Manter no lote o `source_timezone` concreto e `normalization_version`. Nunca persistir `location` como fuso: esse valor é uma preferência de resolução, não um identificador temporal.

Registrar também a procedência da escolha (`location_default` ou `file_override`) e o retrato da configuração usado na confirmação. A informação deve permitir distinguir a criação original do lote das importações posteriores que o reutilizem:

- O lote conserva os metadados de sua criação; uma reutilização não os sobrescreve.
- Cada sessão registra como seu fuso foi resolvido, mesmo quando reaproveita um lote existente. Persistir o retrato no registro da sessão ou no vínculo com seu lote de potência, conforme o modelo existente.
- O histórico administrativo apresenta o fuso efetivo e a procedência da sessão. Nos registros legados, indicar que essa procedência não foi registrada, sem inventar uma herança do cadastro atual.

O mesmo arquivo, contexto e fuso efetivo deve continuar reutilizando o mesmo lote, independentemente de o fuso ter vindo do cadastro ou de uma exceção. A procedência e a revisão do cadastro não entram no fingerprint das leituras nem na chave de idempotência do lote.

Não incrementar `normalization_version` apenas por adicionar a herança do cadastro: a interpretação temporal existente permanece a mesma. Se houver necessidade de alterar o algoritmo de normalização, documentar separadamente a compatibilidade e os impactos sobre fingerprints e correções antes de implementar.

## Histórico e reprocessamento

Alterar o cadastro não reinterpreta lotes antigos, não atualiza seus metadados e não inicia reprocessamento histórico da potência.

Para corrigir uma importação anterior, o Master reimporta os arquivos usando a configuração correta ou a exceção por arquivo. Reaproveitar o lote de liga/desliga quando aplicável e executar o fluxo canônico da spec 13:

- registrar a nova interpretação e os vínculos de substituição;
- preservar leituras e sessões anteriores;
- usar somente leituras efetivas na correlação e na cobertura temporal;
- recalcular os resultados do gerador afetado na mesma transação;
- manter o bloqueio de reutilização de interpretações já substituídas.

Se o padrão cadastrado apontar para uma interpretação histórica já corrigida, mostrar o fuso utilizado na correção e orientar a exceção ou a revisão do cadastro. Não alterar a preferência automaticamente e não reativar leituras substituídas.

## Compatibilidade e segurança

- Adicionar a preferência como nula aos locais existentes, sem copiar `time_zone`, presumir UTC ou inferir pelo último lote.
- Preservar lotes e metadados legados, inclusive `normalization_version = 0`.
- Atualizar os fluxos de criação de local e cadastro completo de cliente, edição, consultas, tipos e contratos de importação.
- Restringir alterações e confirmações ao Master ativo, com validação também no banco conforme os caminhos privilegiados existentes.
- Preservar RLS, permissões explícitas e restrições dos dados técnicos; a nova configuração e sua auditoria não ampliam o contrato sanitizado do portal do cliente.
- Requisições antigas sem o novo contrato de escolha devem receber orientação para atualizar a tela, sem conversão silenciosa de um fuso enviado em preferência herdada.

## Pontos de implementação

- Cadastro: `app/(admin)/admin/locais/page.tsx`, cadastro completo de cliente e `lib/operations/actions.ts`.
- Contexto e opções: `lib/imports/context.ts`, `lib/imports/queries.ts` e `lib/imports/types.ts`.
- Resolução e validação: `lib/imports/timezone.ts`, `lib/imports/actions.ts` e integração com o parser existente.
- Interface e histórico: `components/import-workflow.tsx` e `components/import-history.tsx`.
- Banco: migration para preferência, revisão temporal, procedência, restrições e contratos transacionais; atualizar os tipos gerados após a evolução do schema.
- Documentação operacional: atualizar `docs/operacao/fuso-horario-da-telemetria.md` para explicar cadastro, herança, exceção e correção histórica.

Antes de escrever código Next.js, ler os guias locais pertinentes em `node_modules/next/dist/docs/`, conforme `AGENTS.md`.

## Critérios de aceite

- [x] O Master configura a referência temporal por local, inclusive no cadastro completo de cliente.
- [x] Novos locais exigem escolha explícita; locais existentes não recebem um padrão inferido.
- [x] Local não configurado bloqueia a validação de potência com orientação para o cadastro.
- [x] A importação aplica o padrão automaticamente e mostra o fuso efetivo e sua procedência.
- [x] A exceção vale somente para o arquivo atual e não altera o cadastro.
- [x] Trocar arquivo, controlador ou hierarquia remove a exceção anterior.
- [x] UTC e horário da unidade produzem os instantes esperados, sem conversão duplicada.
- [x] Liga/desliga continua sendo interpretado no fuso da unidade.
- [x] Fusos suportados são coerentes entre cadastro, aplicação e banco; entradas inválidas e transições ambíguas ou inexistentes são recusadas.
- [x] Mudanças de escolha ou cadastro exigem nova prévia, com invalidação das fontes afetadas.
- [x] Uma alteração concorrente da configuração não permite confirmar uma prévia desatualizada.
- [x] Mesmo arquivo e fuso reutilizam o lote, inclusive alternando entre padrão e exceção.
- [x] Cada sessão conserva sua procedência sem sobrescrever a criação do lote reutilizado.
- [x] Alterar o cadastro não modifica lotes antigos nem reprocessa a potência histórica automaticamente.
- [x] A reimportação com outro fuso mantém substituição auditável, cobertura correta e reprocessamento transacional.
- [x] Interpretações já corrigidas permanecem bloqueadas e recebem orientação acionável.
- [x] Autorizações, auditoria e contrato sanitizado do cliente são preservados.
- [x] Cadastro, prévia, exceção e histórico funcionam em desktop e smartphone com controles acessíveis.

## Validação da implementação

Cobrir a resolução no servidor com preferência ausente, UTC, horário da unidade, exceção, entrada inválida e tentativa de falsificar a procedência. Cobrir datas que cruzam a meia-noite, precisão de milissegundos e transições temporais dos fusos suportados.

Testar a interface para herança automática, remoção de exceção, preservação do arquivo ao trocar o fuso, atualização do contexto e invalidação das prévias. Testar a confirmação com configuração alterada, inclusive alteração seguida de retorno ao valor anterior e concorrência na gravação.

No banco, validar autorização, auditoria, retratos históricos, reutilização do mesmo lote por sessões com procedências diferentes, compatibilidade legada, correção por reimportação e rollback em falhas. Reexecutar as regressões pertinentes das specs 11 e 13 e verificar o contrato sanitizado.

Executar typecheck, lint, build e testes pertinentes. Conferir visualmente o fluxo completo em desktop e smartphone. Os critérios de aceite foram verificados localmente; a publicação em produção é uma etapa separada.

## Sequência de entrega

1. Evoluir o modelo, a revisão temporal e os contratos de persistência, preservando dados existentes.
2. Adicionar a configuração aos cadastros e a auditoria de alterações.
3. Implementar a resolução no servidor e a verificação transacional da prévia.
4. Atualizar importação, exceção por arquivo, histórico e orientação operacional.
5. Validar o fluxo completo, concorrência, correção histórica e isolamento do cliente.
6. Publicar a evolução e configurar explicitamente os locais pelo Master antes das próximas importações de potência.
7. Conferir uma importação conhecida e, quando necessária, executar a correção histórica pelo fluxo de reimportação existente.


## Entrega e evidências

- Migration: `20261016185129_location_telemetry_timezone.sql`, aplicada no Supabase local. Locais existentes mantêm a preferência nula; novos locais exigem escolha explícita ao concluir a transação.
- Cadastro: criação de local e cadastro completo de cliente recebem a preferência; edição e auditoria distinguem o fuso da unidade da referência dos arquivos. O seletor acompanha o valor persistido após salvar.
- Resolução: o servidor determina o fuso e a procedência, e envia o retrato temporal com os dados revalidados. Requisições antigas sem esse contrato são recusadas.
- Concorrência: revisões separadas para o fuso operacional e a configuração da telemetria detectam mudanças, inclusive quando o valor é alterado e depois restaurado. A validação SQL mantém um bloqueio compartilhado do local até o fim da transação. Teste com duas conexões confirmou o bloqueio de uma edição concorrente, sem gravações persistidas pelo teste.
- Histórico: lotes conservam sua procedência original. A identidade da sessão inclui o retrato temporal, permitindo outra procedência com os mesmos lotes; repetir essa sessão continua idempotente. Sessões com falha preservam a possibilidade de registrar novas tentativas.
- Normalização: versão `1` preservada; a ampliação para fusos IANA inclui detecção de transições de meia hora, sem alterar os instantes já suportados de UTC/Fortaleza. A preferência e sua revisão não entram nos fingerprints das leituras.
- Interface: herança automática, exceção por arquivo, remoção da exceção, indicação da procedência na prévia e no histórico, atualização das opções quando o servidor encontra um cadastro mais recente e contagem de novas inserções que considera lotes reaproveitados.
- Validação: 184 testes da aplicação em 20 arquivos; 22 arquivos SQL aprovados, incluindo regressões das specs 11, 13 e 14. Os testes antigos usam um adaptador explícito de fixtures para o novo contrato, sem permitir requisições legadas na aplicação.
- TypeScript, ESLint, build de produção com Node 24/Webpack, lint SQL e diagnósticos locais de segurança aprovados. Todas as 28 migrations foram reaplicadas em banco temporário pelo `db diff`; nenhuma diferença nos schemas `public` e `private`.
- Fluxo real no navegador: cadastro completo sintético em UTC, edição da preferência com auditoria, importação de dois eventos e três leituras, projeção com uma aplicação dentro do esperado, confirmação e histórico. Uma segunda sessão com exceção UTC reutilizou os mesmos lotes: duas sessões e somente três leituras no banco.
- Evidências visuais locais em `output/playwright/spec15/`, com importação, cadastro e exceção em desktop e smartphone. Em 390 px, a largura da página permanece em 390 px; tabelas mantêm sua rolagem interna. Os XLSX desse diretório contêm exclusivamente dados sintéticos.

## Publicação pendente

A migration e a aplicação ainda não foram publicadas em produção. Publicar ambas de forma coordenada: o novo contrato temporal é exigido nas confirmações do banco, e telas abertas na versão anterior precisam ser atualizadas. Configurar explicitamente a referência temporal de cada local pelo Master antes de validar as próximas importações de potência.

A alteração do cadastro não corrige automaticamente os arquivos históricos. Quando necessário, usar a reimportação auditável descrita na spec 13 e conferir um evento conhecido nas duas fontes.
