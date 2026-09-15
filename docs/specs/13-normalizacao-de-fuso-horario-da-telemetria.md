# Spec 13 — Normalização do fuso horário da telemetria

**Status:** proposta.

**Tipo:** evolução da importação conjunta de estado e potência.

**Dependências:** specs 05, 10, 11 e 12.

## Problema

Os arquivos de telemetria de potência são exportados em UTC, enquanto os horários das aplicações e dos eventos de liga/desliga são interpretados no contexto de `America/Fortaleza`. A diferença observada é de três horas. Sem normalização, leituras que representam o mesmo instante não são correlacionadas corretamente.

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

O valor selecionado deve ser armazenado na sessão/lote de importação. Não haverá inferência automática baseada na diferença observada.

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

Lotes já confirmados não serão reescritos. Arquivos antigos devem ser reimportados com `UTC` para gerar leituras corrigidas; a confirmação deve continuar transacional e idempotente.

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

Uma importação corrigida deve reprocessar apenas o intervalo afetado do gerador, preservando aplicações e leituras não relacionadas. A avaliação deve ser recalculável a partir dos timestamps normalizados e não pode duplicar inconsistências ou eventos de auditoria em uma repetição idêntica.

## Segurança e auditoria

- somente o Master escolhe o fuso e confirma o lote;
- o fuso de origem, a regra aplicada e o responsável ficam em auditoria;
- mensagens de erro não devem incluir conteúdo integral do arquivo;
- o portal do cliente não recebe o fuso, horários brutos, leituras ou IDs técnicos.

## Critérios de aceite

- [ ] Um arquivo UTC com evento `23:00` é persistido como o instante equivalente a `20:00` em Fortaleza.
- [ ] Um arquivo em `America/Fortaleza` não sofre deslocamento adicional.
- [ ] `occurred_at_raw` permanece inalterado e o lote registra o fuso escolhido.
- [ ] A prévia e a correlação usam os timestamps normalizados.
- [ ] A troca do fuso invalida a prévia anterior.
- [ ] O mesmo arquivo confirmado com o mesmo fuso é idempotente.
- [ ] O mesmo arquivo com fuso diferente não é tratado como o mesmo lote.
- [ ] A reimportação corrige aplicações afetadas sem duplicar auditoria.
- [ ] RLS continua isolando dados técnicos do cliente.
- [ ] Testes cobrem UTC, Fortaleza, erro de data, cobertura, fronteira e reprocessamento.
- [ ] A validação visual confirma a indicação do fuso em desktop e smartphone.

## Plano de rollout

1. adicionar a coluna de origem temporal e a versão da regra;
2. publicar o seletor na prévia conjunta;
3. manter compatibilidade de leitura dos lotes existentes;
4. reimportar os arquivos UTC afetados, selecionando `UTC`;
5. comparar uma aplicação conhecida com os eventos de liga/desliga;
6. somente depois remover qualquer tratamento temporário específico do arquivo.
