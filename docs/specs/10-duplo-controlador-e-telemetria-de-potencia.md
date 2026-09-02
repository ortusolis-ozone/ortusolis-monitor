# Spec 10 — Duplo controlador e telemetria de potência

**Status:** concluída em 31/08/2026.

**Aprovação do produto:** 31/08/2026.

**Adendo operacional aprovado:** 01/09/2026 — importação retroativa em controlador substituído, limitada à sua vigência.

**Tipo:** evolução funcional posterior ao MVP original.

**Dependências:** specs 00, 02, 03, 04, 05, 06, 07, 08 e 09.

## Regra de precedência

Esta spec substitui, somente no domínio de controladores e telemetria de potência, as premissas anteriores de que um gerador possui um único controlador e de que apenas eventos `Ligar`/`Desligar` são importados.

Continuam válidas as demais regras das specs anteriores, especialmente:

- o banco é a fonte de verdade;
- dados brutos são preservados e os resultados são reconstruíveis;
- somente o Master importa dados e altera cadastros operacionais;
- o cliente recebe apenas informações sanitizadas;
- o sistema não controla o equipamento e não apresenta dados em tempo real;
- o sistema não afirma geração ou concentração de ozônio sem uma medição específica para isso.

Leitura de potência é telemetria. Ela não significa controle de potência, acionamento remoto ou programação do equipamento.

## Objetivo

Representar e acompanhar os dois sinais complementares de cada gerador:

1. o controlador de estado registra a rotina programada por eventos `Ligar` e `Desligar`;
2. o controlador de potência registra a potência elétrica em watts enquanto o gerador está energizado.

O sistema deverá correlacionar essas fontes para oferecer evidência adicional de que uma aplicação registrada também apresentou consumo elétrico, sem tratar esse consumo como prova direta de produção de ozônio.

## Resultado esperado para o usuário

- A Ortusolis configura dois controladores por gerador e acompanha ambos separadamente.
- A Ortusolis importa os dois formatos de XLSX, identifica divergências e consulta os dados técnicos.
- O cliente vê uma confirmação qualitativa de potência associada ao registro da aplicação, sem acessar horários, duração, valores brutos ou parâmetros internos.
- Geradores antigos sem telemetria continuam consultáveis e são identificados como sem cobertura de potência, não como defeituosos.

## Fora do escopo

- leitura direta ou em tempo real dos dispositivos;
- comando remoto, programação ou controle de potência;
- cálculo de energia em Wh ou kWh com base em duas leituras pontuais;
- medição de concentração, vazão ou produção de ozônio;
- inferência de cumprimento de uma agenda que não esteja representada pelos eventos programados;
- exposição ao cliente de eventos, horários, duração, watts, limites de classificação ou identificadores técnicos;
- correção manual ou criação artificial de leituras.

## Vocabulário

### Controlador de estado

Controlador com papel `state`. Seus eventos programados `Ligar` e `Desligar` continuam sendo a fonte de verdade para formar uma aplicação.

### Controlador de potência

Controlador com papel `power_telemetry`. Suas leituras em watts são uma fonte independente de evidência elétrica e nunca formam uma aplicação sozinhas.

### Aplicação

Permanece definida pela spec 00: evento programado `Ligar` seguido de evento programado `Desligar`, no mesmo gerador e no mesmo controlador de estado.

### Evidência de potência

Correlação entre uma aplicação e observações compatíveis de potência ligada e desligada. É evidência indireta de energização do gerador, não prova direta de geração de ozônio.

### Cobertura de telemetria

Intervalo temporal coberto por um lote confirmado do controlador de potência. Ausência de cobertura é diferente de ausência de consumo.

## Regras de domínio

### Estrutura esperada

- Cada gerador operacional deve possuir dois papéis de controlador: um `state` e um `power_telemetry`.
- Cada papel tem identificação, vigência, substituição e histórico independentes.
- Pode existir no máximo um controlador ativo de cada papel no mesmo gerador e instante.
- Controladores de papéis diferentes podem e devem ter vigências simultâneas.
- Um controlador de estado nunca recebe arquivo de potência e um controlador de potência nunca recebe arquivo de estado.
- A substituição de um papel não encerra nem modifica o controlador do outro papel.
- A substituição encerra a vigência do controlador antigo e inicia a do novo no mesmo instante, de forma atômica, sem apagar o controlador ou seus dados.
- Um controlador substituído continua disponível para importações retroativas, desde que todas as linhas estejam em sua vigência `[activated_at, deactivated_at)`.
- O instante exato do corte pertence ao controlador novo; o antigo aceita somente instantes anteriores ao corte.

A restrição estrutural do banco garantirá **no máximo um controlador vigente por papel**. A exigência de **dois papéis presentes** será garantida pelas operações atômicas de cadastro e por uma validação explícita de prontidão do gerador, pois uma restrição multirregistro não pode impedir com segurança os estados transitórios de uma substituição.

### Cadastro e legado

- O cadastro guiado de uma nova estrutura exige os dois controladores e persiste cliente, unidade, câmara, gerador, alocação e controladores na mesma transação.
- O cadastro individual de gerador também exige os dois papéis antes de marcá-lo como pronto para importação.
- Todos os controladores existentes antes desta evolução serão classificados como `state` durante a migração.
- Geradores existentes sem controlador de potência serão marcados como `telemetry_pending`.
- Um gerador legado `telemetry_pending` continua aceitando importações de estado e preserva seus resultados atuais.
- Depois que a telemetria for cadastrada e houver cobertura, as novas regras de correlação passam a valer para o período coberto, sem inventar resultados históricos.

### Configuração do controlador de potência

O controlador `power_telemetry` possui:

- identificação legível;
- identificador externo do dispositivo, obrigatório;
- início e fim de vigência;
- limite de ligado em watts;
- limite de desligado em watts;
- tolerância de correlação em segundos;
- status ativo/inativo.

Valores iniciais propostos, editáveis pelo Master:

- ligado: leitura maior ou igual a `5 W`;
- desligado: leitura menor ou igual a `1 W`;
- tolerância entre evento e telemetria: `120 segundos` para cada extremidade.

O limite de desligado deve ser menor que o limite de ligado. Leituras entre os dois limites formam uma zona de histerese e mantêm o último estado elétrico conhecido.

O identificador externo não pode estar associado simultaneamente a mais de um controlador de potência vigente. Seu valor original e sua forma normalizada devem ser preservados.

## Modelo conceitual de dados

Os nomes abaixo definem o contrato esperado. A migration poderá ajustar detalhes técnicos, desde que preserve as responsabilidades e os critérios desta spec.

### Alterações em `controllers`

- `role`: `state` ou `power_telemetry`, obrigatório;
- `external_device_id`: obrigatório para potência e opcional para estado;
- limites e tolerância: obrigatórios para potência e nulos para estado.

A regra antiga que proíbe a sobreposição de quaisquer controladores do mesmo gerador será substituída por uma regra de não sobreposição para `(generator_id, role)`.

### Alterações em `import_batches`

Cada lote registra um `data_kind` imutável:

- `state_events` para o formato `Tempo | Operação | Acionado por`;
- `power_readings` para o formato de telemetria.

O lote mantém contexto, hash, arquivo, autor, totais, intervalo temporal e estado. O contexto deve indicar o controlador selecionado e ser compatível com seu papel.

### Nova entidade `power_readings`

Cada leitura confirmada preserva, no mínimo:

- lote, cliente, unidade, câmara, gerador e controlador coerentes;
- instante com fuso;
- potência normalizada em watts;
- nome e identificador do dispositivo presentes no arquivo;
- tipo, nome e detalhe original do evento;
- valores originais relevantes da linha;
- fingerprint determinístico;
- instante de persistência.

Leituras são imutáveis. Reprocessamento não as remove nem altera.

Chaves estrangeiras compostas ou validações equivalentes devem impedir qualquer vínculo cruzado entre clientes, geradores, controladores, lotes e leituras.

### Nova entidade `application_power_verifications`

Resultado reconstruível da correlação entre uma aplicação e a telemetria:

- aplicação e gerador;
- controlador de potência aplicável;
- observações de potência ligada e desligada, quando existirem;
- estado da verificação;
- motivo técnico;
- instante da fonte mais recente que alterou o resultado.

Estados internos:

- `verified`: observações compatíveis de ligado e desligado foram encontradas;
- `missing_power_on`: existe cobertura, mas falta observação compatível de ligado;
- `missing_power_off`: existe cobertura, mas falta observação compatível de desligado;
- `missing_power_both`: existe cobertura, mas faltam as duas observações;
- `no_coverage`: a aplicação não está coberta por telemetria confirmada.

### Inconsistência `unexpected_power`

Uma transição para ligado que não possa ser associada a uma aplicação de estado dentro da tolerância cria uma inconsistência administrativa `unexpected_power`.

Ela indica divergência entre as fontes. Não comprova acionamento indevido, falha do equipamento ou produção de ozônio.

### Publicação sanitizada

`client_daily_status` continuará sem dados técnicos e receberá somente um estado qualitativo de evidência de potência:

- `confirmed`: todas as aplicações publicáveis cobertas foram verificadas;
- `requires_review`: ao menos uma aplicação coberta possui evidência ausente ou existe potência inesperada;
- `partial`: há aplicações verificadas e outras sem cobertura;
- `unavailable`: nenhuma aplicação do dia possui cobertura de potência;
- `not_applicable`: não existe aplicação concluída no dia.

Esse campo não pode permitir deduzir quantidade de ciclos, watts, horários ou duração.

## Contrato do XLSX de potência

### Detecção do formato

O servidor identifica o tipo do arquivo pelos cabeçalhos, não apenas pelo nome da aba ou do arquivo.

Cabeçalhos observados e exigidos no formato inicial:

```text
Device Name
Device ID
Event Type
Event Name
Event Detail
Request From
Source Detail
Event Time
```

A primeira aba não vazia com esse conjunto de colunas será usada. Diferenças de espaços e maiúsculas/minúsculas podem ser normalizadas sem alterar os valores originais.

### Linhas aceitas

- `Event Type` deve representar `Report`.
- `Event Name` deve representar `Power`.
- `Event Detail` deve conter um número decimal seguido da unidade `W`.
- Separadores decimais `.` e `,` são aceitos quando o valor é inequívoco.
- Outras unidades são rejeitadas nesta versão; não haverá conversão implícita de `mW` ou `kW`.
- `Device ID` deve coincidir com o identificador externo do controlador selecionado.
- Todas as linhas do arquivo devem pertencer ao mesmo dispositivo.
- `Event Time` é interpretado no fuso IANA da unidade e persistido com fuso.
- Milissegundos no formato `YYYY-MM-DD HH:mm:ss:SSS` são preservados.
- A ordem física das linhas pode ser crescente ou decrescente; o processamento sempre ordena por instante e identificador estável.

O arquivo analisado como referência contém, por exemplo:

```text
2026-08-27 07:00:32:813 | 71.80W
2026-08-27 07:30:08:064 | 0.00W
```

Essas duas linhas representam leituras de potência em instantes distintos. Elas não representam `71,8 Wh`, não medem a energia total do período e não bastam para calcular consumo acumulado com precisão.

### Validação e prévia

Bloqueiam a confirmação:

- formato não reconhecido ou colunas obrigatórias ausentes;
- papel do controlador incompatível com o formato detectado;
- identificador externo diferente do dispositivo selecionado;
- arquivo com mais de um dispositivo;
- data, potência ou unidade inválida;
- leitura fora da vigência do controlador;
- contexto hierárquico inconsistente;
- arquivo vazio ou acima dos limites configurados.

A prévia de potência mostra ao Master:

- dispositivo identificado;
- linhas válidas, inválidas, repetidas e já importadas;
- primeiro e último horários;
- menor e maior potência;
- quantidade de observações classificadas como ligada, desligada ou na zona de histerese;
- amostra normalizada.

Nenhum dado é persistido durante a prévia. A confirmação repete parsing, validação e hash do arquivo.

### Idempotência

A fingerprint inclui, no mínimo, controlador de potência, instante, valor normalizado e identidade original do evento. O mesmo arquivo e arquivos parcialmente sobrepostos não duplicam leituras.

Uma confirmação é atômica: falha de validação, persistência ou reprocessamento não pode deixar lote parcialmente confirmado.

## Processamento da telemetria

### Normalização das observações

Para cada controlador de potência:

1. carregar somente leituras de lotes confirmados e dentro da vigência;
2. ordenar cronologicamente e usar a fingerprint como desempate estável;
3. classificar leitura maior ou igual ao limite de ligado como `on`;
4. classificar leitura menor ou igual ao limite de desligado como `off`;
5. manter o estado anterior para leituras na zona de histerese;
6. criar uma observação de transição somente quando o estado elétrico estável muda.

A primeira leitura válida estabelece o estado observado. Uma primeira leitura `on` pode servir como evidência de início. Uma primeira leitura `off`, sem estado `on` anterior no intervalo coberto, é preservada, mas não cria isoladamente uma transição de desligamento.

Zeros repetidos e outros valores repetidos são preservados como dados brutos, porém não criam ciclos adicionais.

### Cobertura

Cada lote confirmado define inicialmente uma cobertura entre sua primeira e última leitura. Coberturas sobrepostas do mesmo controlador podem ser unificadas.

Uma aplicação recebe `no_coverage` quando suas extremidades, consideradas as tolerâncias, não estão contidas em cobertura confirmada compatível. Ausência de cobertura nunca deve virar automaticamente `missing_power_on`, `missing_power_off` ou falha operacional.

### Correlação com aplicações

Para cada aplicação de estado:

1. selecionar o controlador de potência vigente no período;
2. verificar se há cobertura compatível;
3. localizar a observação `on` mais próxima do evento `Ligar`, dentro da tolerância;
4. localizar a observação `off` mais próxima do evento `Desligar`, dentro da tolerância;
5. exigir que a observação `on` preceda a observação `off`;
6. persistir o resultado derivado e determinístico.

Uma mesma observação de transição não pode confirmar duas aplicações diferentes. Em caso de empate, vence a aplicação com menor diferença temporal e depois o identificador estável.

O reprocessamento inicial continuará sendo completo por gerador. Ele deverá reconstruir aplicações, verificações de potência, inconsistências e estado público na mesma transação e sob o mesmo lock do gerador.

### Idempotência temporal

Reprocessar sem novas fontes ou mudanças de configuração deve produzir os mesmos registros, estados e datas de atualização.

- `updated_at` público representa o instante mais recente de uma fonte confirmada que efetivamente participa do resultado publicado.
- O horário atual da transação não pode substituir esse valor.
- Um eventual `processed_at` é técnico, separado e inacessível ao cliente.

## Regras do estado diário

O estado principal continua obedecendo à spec 00, acrescido das divergências de potência:

```text
inconsistência de estado ou potência pendente?       → Verificação necessária
senão, aplicação concluída?                          → Concluído
senão, data já importada?                            → Sem dados
senão                                                → Aguardando atualização
```

Regras adicionais:

- `verified` contribui para evidência diária `confirmed`.
- `missing_power_on`, `missing_power_off` ou `missing_power_both` geram inconsistência pendente e evidência `requires_review`.
- `unexpected_power` gera inconsistência pendente e evidência `requires_review`.
- `no_coverage` resulta em `unavailable` ou `partial`, sem transformar sozinho o estado principal em `Verificação necessária`.
- Revisar uma inconsistência remove sua precedência, mas não cria leitura, transição, aplicação ou verificação.
- A atualização posterior da cobertura pode resolver automaticamente inconsistências derivadas, preservando o histórico de auditoria.

## Experiência administrativa

### Cadastros

- A hierarquia do gerador exibe separadamente `Estado liga/desliga` e `Telemetria de potência`.
- Cada papel mostra identificação, vigência e status.
- Potência mostra também Device ID e limites configurados.
- A substituição pode ser iniciada tanto na lista de controladores quanto em `Clientes e instalações → Ver estrutura → Gerenciar geradores`.
- Ações de substituição pedem explicitamente qual papel será substituído.
- Gerador sem um dos papéis exibe o estado de prontidão e a ação necessária.

### Importações

- O fluxo seleciona primeiro o gerador e depois um dos controladores compatíveis.
- Controladores ativos aparecem primeiro; controladores históricos permanecem selecionáveis com sua vigência identificada.
- O formato é detectado automaticamente após o upload.
- Incompatibilidade entre formato e papel bloqueia a prévia.
- Linha fora da vigência do controlador selecionado bloqueia a prévia e a confirmação.
- O histórico diferencia claramente lotes de estado e lotes de potência.

### Diagnóstico

O Master pode consultar leituras, watts, horários, transições, cobertura, correlações e motivos das inconsistências. A interface deve deixar claro o que foi observado e o que foi inferido.

## Experiência do cliente

O portal pode comunicar apenas resultados qualitativos, por exemplo:

- `Aplicação registrada — potência confirmada`;
- `Aplicação registrada — telemetria indisponível no período`;
- `Verificação necessária nos registros`.

Não serão exibidos ao cliente:

- potência em watts ou energia;
- gráficos de telemetria;
- horários, duração ou quantidade de ciclos;
- Device ID, limites, tolerâncias ou cobertura técnica;
- afirmação de que houve uma quantidade específica de ozônio.

Texto obrigatório próximo da evidência:

> A potência registrada é uma evidência indireta de energização do gerador e não mede a concentração ou a produção de ozônio.

## Segurança e autorização

- Todas as novas tabelas do schema exposto terão RLS habilitada e privilégios explícitos.
- `anon` não recebe acesso aos dados de domínio.
- Somente Master ativo pode cadastrar controladores, importar arquivos e consultar leituras ou verificações técnicas.
- Usuários de cliente não acessam `controllers`, `import_batches`, `raw_events`, `power_readings`, `applications`, verificações técnicas ou detalhes de inconsistências.
- Cliente consulta somente a hierarquia autorizada e a publicação sanitizada do próprio `client_id`.
- Funções `security definer`, quando indispensáveis, fixam `search_path`, validam o ator dentro da função e não são executáveis por `public`.
- Storage temporário permanece privado e isolado pelo usuário responsável pelo upload.
- Toda confirmação, troca de controlador, alteração de limites e revisão gera auditoria sem registrar segredos ou conteúdo desnecessário do arquivo.

## Compatibilidade e estratégia de evolução

A implementação deverá ser aditiva e dividida em etapas verificáveis:

1. adicionar os novos tipos, campos, tabelas, índices e políticas;
2. classificar controladores existentes como `state` e marcar geradores legados sem telemetria;
3. preservar contratos existentes de funções e testes durante a transição;
4. adicionar contratos versionados para o cadastro e a substituição por papel;
5. migrar a aplicação e os testes para os novos contratos;
6. adicionar parser, prévia e confirmação de potência;
7. adicionar correlação e publicação sanitizada;
8. habilitar a experiência após reset, lint, testes e validação com arquivo real.

Uma migration não deverá remover uma assinatura de função já usada pela aplicação ou pelos testes no mesmo passo em que introduz o substituto. O contrato anterior só poderá ser retirado em uma migration posterior, depois que não houver consumidores.

Nenhum dado bruto existente será reescrito ou apagado. A desativação da funcionalidade deve impedir novas importações de potência sem comprometer o fluxo anterior de estado.

## Critérios de aceite funcionais

### Cadastro

- Um gerador novo só fica pronto após a criação atômica dos dois papéis.
- Não é possível manter vigências sobrepostas de dois controladores do mesmo papel.
- É possível manter simultaneamente um controlador de estado e um de potência.
- Substituir potência não encerra estado, e vice-versa.
- A substituição preserva o controlador antigo e todos os dados já vinculados a ele.
- Controladores legados são migrados para `state` sem perda de histórico.

### Importação

- O formato de estado continua funcionando sem regressão.
- O formato de potência é detectado pelos cabeçalhos e exige papel compatível.
- Device ID divergente, múltiplos dispositivos, unidade inválida ou vigência incompatível bloqueiam a confirmação.
- Arquivo em ordem decrescente produz o mesmo resultado que o mesmo arquivo em ordem crescente.
- Milissegundos e fuso da unidade são preservados.
- Um controlador histórico aceita importação retroativa dentro de sua vigência e rejeita registros no ou após o corte.
- O controlador novo aceita registros a partir do instante exato do corte.
- Reimportação e sobreposição não duplicam leituras.
- Falha não deixa lote parcial.

### Processamento

- O exemplo `71.80 W` próximo ao `Ligar` e `0.00 W` próximo ao `Desligar` produz `verified` quando está dentro da tolerância.
- Zeros repetidos e zeros órfãos são preservados, mas não criam transições ou aplicações falsas.
- Limites e bordas exatas de tolerância possuem comportamento determinístico.
- Ausência de uma ou das duas observações gera o motivo correto quando existe cobertura.
- Falta de cobertura gera `no_coverage`, não falha do equipamento.
- Potência ligada sem aplicação compatível gera `unexpected_power` para revisão.
- Reprocessamento sem alteração é idempotente, inclusive em `updated_at`.

### Portal e segurança

- Cliente vê somente o estado qualitativo do próprio cliente.
- Cliente não consegue consultar watts, horários, Device ID, limites, leituras ou correlações técnicas nem por API direta.
- Master consegue diagnosticar a origem de uma divergência.
- A comunicação nunca afirma medição direta de ozônio.

## Estratégia obrigatória de testes

### Banco e migrations

- `supabase db reset` em banco limpo;
- lint do banco sem novos erros relevantes;
- toda a suíte SQL existente aprovada antes dos casos novos;
- testes de sobreposição por papel e integridade hierárquica;
- testes de backfill e compatibilidade dos contratos anteriores;
- testes de RLS com Master, dois clientes e `anon`;
- teste transacional dedicado, previsto como `supabase/tests/09_dual_controller_power_telemetry.sql`.

### Parser e processamento

- arquivo real de referência;
- cabeçalhos normalizados;
- `.` e `,` como separadores decimais;
- ordem crescente e decrescente;
- mudança de data e fuso;
- duplicatas internas e entre arquivos;
- Device ID incorreto e arquivo com dispositivos mistos;
- leituras positiva, zero, repetida, intermediária e inválida;
- `verified`, ausências, `no_coverage` e `unexpected_power`;
- idempotência por comparação dos registros antes e depois do reprocessamento.

### Aplicação

- build e verificação de tipos;
- cadastro guiado dos dois controladores;
- substituição independente por papel;
- prévia e confirmação dos dois formatos;
- portal sanitizado em desktop e smartphone;
- fluxo ponta a ponta Master → duas importações → correlação → cliente correto → bloqueio de outro cliente.

## Definição de pronto para desenvolvimento

O desenvolvimento só pode começar quando:

- esta spec estiver aprovada pelo responsável do produto;
- os valores iniciais de limites e tolerância estiverem aceitos;
- a comunicação qualitativa do portal estiver aceita;
- o arquivo real de referência permanecer disponível como fixture anonimizada;
- as alterações necessárias nas specs anteriores estiverem identificadas por esta regra de precedência;
- a árvore de trabalho não contiver migration experimental desta funcionalidade.

## Definição de concluído

- migrations aplicam do zero e sobre a versão anterior;
- schema, RLS, funções e índices atendem esta spec;
- contratos antigos permanecem compatíveis durante a transição;
- parser e importação validam arquivos reais sem persistência parcial;
- correlação é determinística, reconstruível e idempotente;
- dados legados permanecem corretos;
- suíte anterior e testes novos estão aprovados;
- cliente não recebe dados técnicos;
- textos deixam explícito o caráter indireto da evidência;
- documentação e tipos gerados refletem o resultado implementado.

## Evidências de conclusão

- A migration `20260831174610_dual_controller_power_telemetry.sql` adiciona os papéis `state` e `power_telemetry`, vigências independentes, prontidão do gerador, leituras de potência, correlações, inconsistências, RLS, auditoria e contratos versionados sem remover os contratos anteriores.
- A migration `20260901141902_allow_historical_controller_imports.sql` permite confirmar importações retroativas em controladores substituídos sem relaxar a validação linha a linha do intervalo de vigência.
- O cadastro guiado e o cadastro individual de gerador criam os dois controladores na mesma transação. Cadastro, edição, substituição e histórico tratam cada papel de forma independente.
- O importador detecta o formato pelos cabeçalhos, valida o papel e o Device ID, preserva milissegundos e fuso, aceita watts com ponto ou vírgula e mantém prévia, confirmação e idempotência para os dois formatos.
- O arquivo real de potência fornecido foi validado com 57 leituras, incluindo `71,8 W` às `07:00:32.813` e `0 W` às `07:30:08.064`; a repetição do mesmo arquivo não duplicou registros.
- O fluxo real de estado foi validado com 30 eventos programados. A correlação controlada do conjunto de referência produziu 27 aplicações e 27 verificações `verified`, sem resultado não verificado.
- O portal publica apenas `Potência confirmada`, `Verificação necessária`, `Sem cobertura` ou `Sem aplicação concluída`, além do aviso de que a potência é evidência indireta. Watts, horários, Device ID, limites e vínculos técnicos permanecem restritos ao Master por RLS.
- O cenário ponta a ponta foi verificado em navegador nas visões Master e cliente, em desktop e smartphone: cadastro dos dois controladores, prévia e confirmação dos dois XLSX, idempotência, correlação e publicação qualitativa.
- A suíte final inclui `supabase db reset`, `supabase test db`, `supabase db lint`, testes unitários do parser, lint da aplicação, verificação de tipos e build de produção.
- O teste `10_controller_replacement_imports.sql` cobre estado e potência antes, no instante e depois do corte, além de confirmar a preservação dos vínculos históricos.
- Os tipos TypeScript gerados em `lib/supabase/database.types.ts` refletem o schema concluído.

## Decisões aprovadas

A aprovação desta spec inclui estas três decisões:

1. limites iniciais de `5 W` para ligado e `1 W` para desligado, com histerese e edição pelo Master;
2. tolerância inicial de `120 segundos` em cada extremidade da aplicação;
3. exibição qualitativa no portal, mantendo valores, horários e gráficos restritos à Ortusolis.

Qualquer alteração nesses pontos deve atualizar esta spec antes do início do desenvolvimento.
