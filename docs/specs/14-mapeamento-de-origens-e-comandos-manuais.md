# Spec 14 — Mapeamento de origens e comandos manuais

**Status:** implementada e validada localmente em 08/10/2026; migration e deploy em produção pendentes.

**Tipo:** evolução da classificação de origens e da experiência administrativa.

**Dependências:** specs 00, 02, 05, 06, 07 e 10.

## Problema

O Mapeamento de origens mostra valores técnicos e as classificações Programada, Teste e Desconhecida, sem explicar o comando representado por cada origem. Cronômetros regressivos e Dispositivo-Inching aparecem igualmente como Programada, embora representem etapas diferentes. O usuário `ortusolis@ortusolis.com.br` aparece como Teste, confundindo a origem manual com uma finalidade habitual.

## Objetivo

Explicar a origem dos comandos, diferenciar acionamento e desacionamento programados e classificar a origem do usuário Ortusolis como Manual. Teste deve ser apresentado como possível finalidade do comando manual, sem afirmar que todo comando desse usuário é um teste.

## Regra de precedência

Esta spec evolui o vocabulário das specs 00, 05, 06 e 07. A aplicação continua exigindo um `Ligar` programado seguido por um `Desligar` programado do mesmo gerador. Comandos manuais são preservados para auditoria e consulta administrativa, mas não comprovam uma aplicação programada.

Não há cadastro de agenda esperada no escopo atual. A referência a comandos fora do horário agendado descreve o uso informado da origem Ortusolis; o sistema não deve deduzir cumprimento de agenda comparando horários.

## Mapeamentos esperados

| Valor encontrado | Valor normalizado atual | Classificação | Descrição administrativa |
| --- | --- | --- | --- |
| Cronômetros regressivos | `cronômetros regressivos` | Programada | Acionamento automático pela agenda programada. |
| Dispositivo-Inching | `dispositivo-inching` | Programada | Desacionamento automático programado. |
| ortusolis@ortusolis.com.br | `ortusolis@ortusolis.com.br` | Manual | Comando manual do usuário Ortusolis, utilizado fora do horário agendado, geralmente para testes. |

A normalização existente deve ser preservada, sem alterar fingerprints ou criar uma segunda chave para a mesma origem. Não classificar outros e-mails automaticamente como Manual e não inferir origens por correspondência parcial.

## Origem, operação e finalidade

- **Origem:** como o comando foi emitido — Programada, Manual ou Desconhecida.
- **Operação:** o que o evento registrou — acionamento (`turn_on`) ou desacionamento (`turn_off`).
- **Finalidade:** teste é um uso possível de um comando manual; não será criado um campo de finalidade nesta entrega.

As descrições dos mapeamentos expressam o comportamento esperado das origens conhecidas. A operação efetiva continua vindo do evento importado. Nunca converter um `Desligar` em `Ligar`, ou vice-versa, com base na origem. Se uma origem conhecida apresentar uma operação diferente da descrita, a consulta do evento deve mostrar a operação real; esta entrega não cria uma nova inconsistência para essa divergência.

## Experiência administrativa

A tela principal é `/admin/mapeamentos`, implementada em `app/(admin)/admin/mapeamentos/page.tsx`.

1. Atualizar o texto introdutório para explicar comandos programados e manuais.
2. Mostrar a descrição legível junto ao valor encontrado, preservando o valor original e o normalizado para conferência.
3. Renomear a coluna Uso para Eventos registrados, evitando confundir contagem de eventos com finalidade.
4. Manter contagem, última ocorrência e classificação atual.
5. Oferecer Programada, Manual e Desconhecida para novos mapeamentos.
6. Manter Salvar e reprocessar, confirmação do impacto, indicação de processamento e mensagem de resultado.
7. Explicar que comandos manuais ficam fora do cálculo de aplicações programadas.

Para origens sem descrição conhecida, mostrar uma explicação neutra baseada na classificação atual, sem atribuir agenda, usuário ou intenção de teste. Uma descrição fixa de origem conhecida não pode ocultar a classificação atual caso o Master altere o mapeamento.

Nas prévias de importação e demais consultas administrativas que já exibem classificação, apresentar Manual de maneira consistente. Nas consultas de eventos que já exibem operação, utilizar Acionamento e Desacionamento como rótulos legíveis, mantendo os valores técnicos existentes.

## Contrato de classificação e compatibilidade

Adicionar `manual` como classificação real em toda a cadeia: validação do servidor, tipos, parser, persistência, consultas e processamento. Não implementar somente uma troca do rótulo visual de `test`.

O parser atual converte qualquer mapeamento diferente de `programmed` em `test`; essa conversão deve ser substituída por tratamento explícito dos valores suportados.

Manter `test` como valor legado para registros e mapeamentos históricos de outras origens. Exibi-lo como Teste (legado), preservando sua exclusão do cálculo. Ele não deve ser uma opção para novos mapeamentos; se for o valor atual, a tela precisa representá-lo sem salvar silenciosamente outra classificação.

A evolução do banco deve ajustar as restrições de `source_mappings` e `raw_events` e a validação de `set_source_mapping`. Preservar a regra atual de Desconhecida como ausência de mapeamento ativo.

## Processamento e reprocessamento

- Somente eventos Programada participam do pareamento de aplicações.
- Eventos Manual e Teste (legado) não iniciam, encerram ou interrompem um par programado e não geram inconsistência de origem desconhecida.
- Eventos Desconhecida continuam seguindo o tratamento atual de pendências.
- Uma mudança de mapeamento reclassifica os eventos confirmados da origem e recalcula aplicações, inconsistências, verificações de potência e estados derivados dos geradores afetados pelo fluxo canônico existente.
- Preservar continuidade entre importações, idempotência e regras de correlação da telemetria.
- Preservar conteúdo bruto, timestamps, fingerprints, vínculos dos lotes e trilha de auditoria; a classificação é derivada e pode mudar.
- Falha no reprocessamento deve desfazer a mudança e seus resultados derivados na mesma transação.

## Atualização dos dados existentes

Preparar a transição do mapeamento exato `ortusolis@ortusolis.com.br` de Teste para Manual. Os dois mapeamentos automáticos conhecidos permanecem Programada.

A atualização deve passar pelo fluxo autorizado e auditável de remapeamento e reprocessamento. Não executar uma conversão global de todas as origens Teste. Não sobrescrever silenciosamente um mapeamento conhecido que esteja diferente do cenário aprovado: registrar a divergência para revisão do Master.

Novas importações devem utilizar o mapeamento ativo. Reimportar um arquivo já confirmado não pode duplicar eventos devido à nova classificação. A prévia e a confirmação devem usar o mesmo contrato de classificação, respeitando a revalidação atual do servidor.

## Segurança e privacidade

Somente o Master ativo pode alterar os mapeamentos. Preservar RLS, permissões explícitas e auditoria, registrando classificação anterior, nova classificação, responsável e origens/geradores afetados conforme o mecanismo existente.

O portal do cliente continua recebendo somente o resultado sanitizado. Não expor e-mail de origem, operação, finalidade, horários técnicos ou classificação interna nos contratos públicos.

## Critérios de aceite

- [x] As três origens conhecidas exibem as descrições e classificações definidas nesta spec.
- [x] Cronômetros regressivos e Dispositivo-Inching são distinguíveis como acionamento e desacionamento programados.
- [x] O usuário Ortusolis aparece como Manual, com teste apresentado somente como uso habitual.
- [x] O texto não afirma que o sistema verifica o horário da agenda.
- [x] A operação bruta prevalece quando diverge da descrição da origem.
- [x] Manual é persistido como `manual` e exibido consistentemente na prévia e nas consultas administrativas existentes.
- [x] Valores Teste de outras origens permanecem legados e não são convertidos automaticamente.
- [x] Um par programado com eventos manuais intercalados continua produzindo a mesma aplicação.
- [x] Eventos exclusivamente manuais não criam aplicação programada nem pendência de origem desconhecida.
- [x] Remapear entre Programada, Manual e Desconhecida recalcula os resultados afetados, com rollback em caso de falha.
- [x] O histórico Ortusolis é reclassificado sem duplicar eventos ou alterar os dados brutos.
- [x] Outros e-mails e origens sem mapeamento não recebem classificação automática.
- [x] Somente o Master consegue alterar os mapeamentos e a auditoria registra a mudança.
- [x] O portal do cliente mantém seu contrato sanitizado.
- [x] A tela é legível em desktop e smartphone, com descrição, seletor e ação acessíveis.

## Validação da implementação

Cobrir parser e prévia com `manual`, `test` legado e `unknown`; testar no banco o pareamento com comandos manuais intercalados, remapeamento histórico, idempotência, rollback e autorização. Verificar o contrato sanitizado e regressões na correlação de potência. Executar typecheck, lint, build e os testes pertinentes, além de conferir visualmente a tela em desktop e smartphone.

Antes de escrever código Next.js, ler os guias locais pertinentes em `node_modules/next/dist/docs/`, conforme `AGENTS.md`.

## Sequência de entrega

1. Evoluir o contrato de classificação e a compatibilidade com Teste legado.
2. Ajustar parser, processamento, consultas e ações de remapeamento.
3. Atualizar a interface e as descrições das origens conhecidas.
4. Validar o fluxo completo e o isolamento do cliente.
5. Publicar a evolução e executar o remapeamento auditável da origem Ortusolis.
6. Conferir eventos históricos, um par programado conhecido e os estados derivados após o reprocessamento.

## Entrega e evidências

- Migration: `20261008193758_manual_source_classification.sql`, aplicada e validada no Supabase local.
- Contrato: `manual` nas restrições, parser, prévia, tipos e RPC; `test` preservado para leitura histórica e recusado como novo mapeamento pela ação e pelo RPC.
- Processamento: Manual e Teste legado são ignorados no pareamento; remapeamento usa o fluxo canônico que recalcula estado, telemetria e avaliação operacional na mesma transação.
- Auditoria: metadados mínimos com origem normalizada, classificação anterior/nova e geradores afetados, sem ampliar os grants ou a leitura direta de auditoria. Salvar uma classificação idêntica não duplica auditoria.
- Interface: descrições das três origens, Eventos registrados, Manual, Teste (legado), orientação de atualização histórica e rótulos Acionamento/Desacionamento nas consultas existentes. Os seletores têm nomes acessíveis por origem; o rótulo usa `aria-label` para evitar overflow externo no celular.
- 155 testes da aplicação em 18 arquivos e 20 arquivos SQL aprovados, incluindo pareamento com comandos intercalados, importação manual, remapeamento histórico, idempotência, falha tardia com rollback e isolamento do cliente.
- TypeScript, ESLint, build de produção com Node 24/Webpack, lint SQL e advisors locais de segurança aprovados.
- Fluxo de navegador validado também no build de produção local: Teste → Manual, confirmação, mensagem de sucesso, quatro eventos reclassificados e autoria do Master na auditoria.
- As 26 migrations foram reaplicadas do zero no banco local. O teste da Spec 14 passou novamente via PostgreSQL/pgTAP após o reset; o executor Docker do CLI permaneceu aguardando nessa repetição e foi encerrado. Os dados sintéticos e a sessão de validação foram removidos.
- Evidências locais em `output/playwright/spec14/`: `mapeamentos-1440.png`, `mapeamentos-390.png` e `mapeamentos-390-acoes.png`. Em 390 px, a página tem largura de 390 px; a tabela mantém rolagem própria e acesso aos controles.

## Publicação e atualização histórica pendentes

A implementação não foi publicada e a migration não foi aplicada ao banco de produção nesta etapa. Os critérios acima foram verificados com dados sintéticos locais; não representam uma atualização dos registros reais.

Após publicar a migration e a aplicação, o Master deve abrir `/admin/mapeamentos`, conferir a origem exata `ortusolis@ortusolis.com.br`, selecionar Manual e usar **Salvar e reprocessar**. Esse caminho registra o responsável real e reclassifica o histórico automaticamente. Conferir as contagens, uma aplicação programada conhecida e o resultado sanitizado após a operação. Não converter globalmente outras origens Teste nem sobrescrever divergências sem revisão.
