# Spec 12 — Potência nominal e alerta de redução operacional

**Status:** implementada e validada localmente em 15/09/2026. Publicação remota não realizada.

**Tipo:** evolução da configuração do gerador, da avaliação de telemetria e da
apresentação sanitizada ao cliente.

**Dependências:** specs 02, 03, 04, 06, 07, 08, 09, 10 e 11.

## Plano de execução incremental

Esta spec deve ser implementada em tarefas pequenas e na ordem abaixo. Cada
tarefa depende da conclusão das anteriores e só deve ser iniciada por comando
explícito, por exemplo: `execute a tarefa 12.1`.

Regras para a execução:

- executar somente a tarefa solicitada, sem antecipar entregas funcionais das
  tarefas seguintes;
- admitir apenas infraestrutura de compatibilidade estritamente necessária
  para manter a aplicação funcional entre duas tarefas;
- começar conferindo se todas as predecessoras estão concluídas;
- manter migrations aditivas e contratos antigos durante as transições
  indicadas neste plano;
- incluir na própria tarefa os testes automatizados correspondentes;
- encerrar cada tarefa com tipos, lint e testes afetados aprovados;
- atualizar o marcador e a data da tarefa na própria spec somente depois da
  verificação;
- não considerar a spec concluída enquanto a tarefa 12.10 não estiver
  aprovada.

### Acompanhamento

- [x] **12.1 — Fundação dos perfis nominais** — concluída em 04/09/2026.
- [x] **12.2 — Avaliação operacional determinística** — concluída em 04/09/2026.
- [x] **12.3 — Reprocessamento e inconsistência de potência baixa** — concluída
  em 04/09/2026; revisada e validada em 09/09/2026.
- [x] **12.4 — Contratos administrativos de servidor** — concluída em 09/09/2026.
- [x] **12.5 — Experiência administrativa do gerador** — concluída em 09/09/2026.
- [x] **12.6 — Integração com a importação conjunta** — concluída em 14/09/2026.
- [x] **12.7 — Diagnóstico técnico do Master** — concluída em 14/09/2026.
- [x] **12.8 — Contrato sanitizado do cliente** — concluída em 14/09/2026.
- [x] **12.9 — Experiência do portal e retirada do contrato antigo** — concluída
  em 14/09/2026.
- [x] **12.10 — Auditoria final, documentação e aceite integrado** — concluída
  em 15/09/2026.

### Tarefa 12.1 — Fundação dos perfis nominais

**Objetivo:** criar o modelo histórico de potência nominal sem alterar ainda o
cadastro nem o processamento das aplicações.

**Escopo:**

- criar `generator_power_profiles` por migration gerada pelo Supabase CLI;
- usar decimal exato, validar potência positiva e até três casas decimais;
- fixar `reduction_limit_percent` em `15.000` e calcular no banco o mínimo de
  85%, sem aceitar um mínimo informado externamente;
- implementar vigência semiaberta e impedir sobreposição por gerador;
- registrar `created_by` e `created_at`, com chave estrangeira e índices
  necessários;
- habilitar RLS e definir `GRANT`, `REVOKE` e políticas explícitas para que
  somente o Master consulte ou mantenha os perfis;
- manter geradores existentes sem perfil e sem qualquer inferência de valor.

**Concluída quando:** constraints, cálculo `72 → 61,2`, limites de vigência,
sobreposição, auditoria básica e acesso de Master, cliente e `anon` estiverem
cobertos por testes SQL. Nenhuma tela ou ação de cadastro muda nesta tarefa.

### Tarefa 12.2 — Avaliação operacional determinística

**Objetivo:** representar e calcular os quatro estados operacionais sem ainda
ligar o cálculo automaticamente a todos os gatilhos de reprocessamento.

**Escopo:**

- estender `application_power_verifications` com estado operacional, perfil,
  leitura de referência, snapshots e motivo técnico;
- garantir uma única avaliação operacional por aplicação;
- implementar uma função privada e determinística que selecione o perfil pela
  data do evento `Ligar` e use somente `power_on_reading_id`;
- produzir `within_expected`, `below_expected`, `not_evaluable` e
  `not_configured` sem alterar o estado principal da aplicação;
- preservar no snapshot os valores efetivamente usados pelo processamento;
- manter a avaliação de correlação da spec 10 independente da nova avaliação.

**Concluída quando:** testes SQL cobrirem igualdade em `61,2 W`, valor
`61,199 W`, ausência de leitura ligada, ausência de perfil, fronteira exata de
vigência, leitura de desligamento ignorada e reconstrução determinística. A
função pode ser exercitada diretamente pelos testes nesta etapa.

### Tarefa 12.3 — Reprocessamento e inconsistência de potência baixa

**Objetivo:** incorporar a avaliação operacional ao processamento real e
manter o ciclo de vida da inconsistência `power_below_expected`.

**Escopo:**

- integrar a avaliação à reconstrução e correlação transacional da spec 10;
- criar ou manter uma única inconsistência ativa de potência baixa por
  aplicação, leitura e perfil efetivo;
- resolver automaticamente a inconsistência quando o resultado deixar de ser
  baixo, sem apagar reconhecimento ou comentário administrativo histórico;
- reprocessar após mudanças relevantes de perfil, controlador, vigência,
  tolerância, limites ou dados correlacionados;
- limitar mudanças de perfil ao intervalo temporal afetado;
- registrar a versão da regra de cálculo e as contagens por estado sem guardar
  conteúdo bruto de arquivos;
- assegurar atomicidade e idempotência em falhas e repetições.

**Concluída quando:** testes SQL demonstrarem criação única, repetição sem
duplicidade, preservação após reconhecimento, resolução automática, escopo
temporal do reprocessamento e ausência de resultado parcial.

**Revisão de fechamento — 09/09/2026:** implementação mantida, com ampliação
dos testes SQL para reconstrução completa, perda e recuperação da leitura após
mudança do limite elétrico e encerramento da vigência do controlador. Os casos
confirmam resolução automática, ausência de duplicidade e preservação do
reconhecimento e comentário histórico. Suíte SQL completa aprovada (13 arquivos),
novos casos da tarefa aprovados, typecheck e lint aprovados e 14 testes de
aplicação aprovados. Tipos públicos conferidos contra o banco local, sem
diferenças de contrato. A revisão não antecipa as tarefas 12.4 a 12.10.

### Tarefa 12.4 — Contratos administrativos de servidor

**Objetivo:** disponibilizar primitivas seguras para cadastro e versionamento
antes de trocar a interface existente.

**Escopo:**

- criar RPC administrativa para registrar gerador e primeiro perfil na mesma
  transação;
- criar RPC administrativa para encerrar o perfil vigente e criar uma nova
  vigência, sem sobrescrever o histórico;
- validar identidade e papel dentro das funções, fixar `search_path` e limitar
  permissões;
- derivar autor da sessão e dados confiáveis do banco, sem aceitar autor ou
  mínimo calculado do navegador;
- adicionar validação decimal no servidor para vazio, não numérico, não finito,
  não positivo e mais de três casas;
- adicionar Server Actions e queries tipadas para situação atual, histórico e
  geradores pendentes;
- manter temporariamente o contrato antigo de cadastro utilizável até a troca
  atômica da interface na tarefa 12.5.

**Concluída quando:** testes de servidor e banco cobrirem autorização,
validação, mínimo adulterado, criação atômica, nova vigência, conflito e
mensagens sanitizadas, sem regressão no cadastro existente.

**Entrega — 09/09/2026:** migration
`20260909171707_nominal_power_admin_contracts.sql`, aplicada e validada no banco
local. Os contratos novos são:

- `register_generator_with_power_profile`: registra gerador, alocação, dois
  controladores e primeiro perfil em uma transação. Deriva cliente e local da
  câmara, início do perfil da alocação no fuso do local e autor da sessão.
- `version_generator_power_profile`: encerra o último perfil aberto e insere
  outro; exige início posterior e confere `p_expected_profile_id` sob bloqueio
  transacional. Identificador ausente/nulo permite configurar um legado sem
  perfil aberto; versão desatualizada exige releitura do histórico.
- `list_admin_generator_power_configuration` e
  `list_admin_generator_power_history`: consultam situação em um instante,
  geradores pendentes e histórico, com autorização de Master e RLS.

As Server Actions e queries tipadas ficam em
`lib/operations/power-profiles/`. A potência nominal trafega como texto decimal
exato, aceita vírgula ou ponto e até três casas, sem conversão para `Number`.
Autor, percentual e mínimo enviados pelo navegador não entram no comando.
O versionamento recebe data/hora ISO com fuso explícito; a consulta de situação
usa o relógio do banco quando nenhum instante é informado. As consultas
administrativas preservam os valores decimais como texto.

Validação: 14 arquivos SQL aprovados, incluindo falha tardia com rollback de
cadastro, encerramento, auditoria e reprocessamento; 70 testes de aplicação
aprovados; typecheck, lint, lint SQL e build de produção aprovados. Tipos públicos
regenerados. O cadastro antigo continua utilizável até a troca da interface na
tarefa 12.5.

### Tarefa 12.5 — Experiência administrativa do gerador

**Objetivo:** tornar a configuração nominal obrigatória para novos geradores e
gerenciável pelo Master.

**Escopo:**

- adicionar `Potência nominal (W)` ao cadastro do gerador;
- mostrar a prévia de `Potência mínima calculada` em 85% como somente leitura;
- explicar a diferença entre potência do gerador e limites elétricos do
  controlador;
- trocar o cadastro para o novo contrato transacional e desativar o caminho
  legado para novos geradores;
- adicionar edição com potência nova e início de vigência;
- mostrar nominal vigente, mínimo, situação e histórico na lista/detalhe;
- identificar e filtrar geradores legados com configuração pendente;
- cobrir vazio, inválido, válido, salvando e erro com rótulos, foco, teclado e
  mensagens acessíveis em desktop e smartphone.

**Concluída quando:** um novo gerador não puder ser salvo sem potência nominal
positiva no navegador, no servidor ou no banco; uma edição criar nova vigência;
e testes de componente/servidor cobrirem a prévia e os estados do formulário.

**Entrega — 09/09/2026:** cadastro individual e cadastro de estrutura completa
exigem potência nominal positiva, com prévia exata de 85% somente para leitura.
O formulário explica a diferença entre potência do gerador e limites do
controlador. A lista apresenta nominal vigente, mínimo e situação, oferece o
filtro `Configuração pendente` e liga ao detalhe em `/admin/geradores/[id]`.
O detalhe permite configurar legados e registrar nova vigência em horário de
Fortaleza, preservando valores e períodos anteriores no histórico.

A migration `20260909174038_require_nominal_power_for_new_generators.sql`
acrescenta uma constraint trigger diferida que exige perfil para todo gerador
novo ao concluir a transação. INSERT direto e RPCs legadas não conseguem
concluir um cadastro sem potência; os contratos antigos permanecem como
primitivas de composição dos novos cadastros. Geradores anteriores à migration
não são preenchidos nem revalidados automaticamente. O cadastro completo passa
a usar `register_complete_client_structure_with_power_profile`.

Validação: 83 testes de aplicação, 15 arquivos SQL, typecheck, lint, lint SQL e
build de produção aprovados. Testes de componente cobrem vazio, inválido,
prévia exata, salvando, erro com foco e anúncio acessível, reset e fuso da nova
vigência. No navegador, foram verificados cadastro de 72 W com mínimo de
61,2 W, rejeição de data conflitante, nova vigência de 100 W com mínimo de 85 W,
preservação do histórico e filtro de pendentes. Desktop e viewport de 390 px
sem transbordamento da página ou erro de renderização. Tipos regenerados;
migration aplicada somente no banco local; dados sintéticos removidos após a
verificação. A tarefa 12.6 permanece não iniciada.

O `npm audit` também identificou alertas preexistentes em `next` (crítico),
`sharp` e `js-yaml` (altos), presentes antes das novas dependências de teste.
A atualização dessas dependências não faz parte desta entrega.

### Tarefa 12.6 — Integração com a importação conjunta

**Objetivo:** aplicar a regra nominal à prévia e confirmação da spec 11 sem
duplicar lógica de domínio.

**Escopo:**

- bloquear antes da confirmação uma nova sessão que precise avaliar potência
  em período sem perfil nominal válido;
- orientar o Master a completar o cadastro, sem classificar o caso como
  potência baixa;
- projetar na prévia nominal e mínimo vigentes e quantidades
  `within_expected`, `below_expected` e `not_evaluable`, agrupadas por motivo;
- usar na prévia e na confirmação a mesma função canônica de correlação e
  avaliação;
- manter confirmação transacional, revalidação dos dois arquivos e
  idempotência da spec 11;
- impedir que fluxos legados criem silenciosamente avaliações sem perfil.

**Concluída quando:** testes SQL, de servidor e da interface cobrirem bloqueio
sem perfil, perfis que mudam no período, contagens projetadas iguais às
confirmadas, falha atômica e reimportação idempotente.

**Entrega — 14/09/2026:** migration
`20260914135727_nominal_power_joint_import_preview.sql`, aplicada somente no
banco local. A RPC `preview_import_session` executa a confirmação canônica em
uma subtransação revertida antes do retorno: lotes, fontes, aplicações,
inconsistências e auditoria não são persistidos pela prévia. A confirmação
continua transacional e idempotente, com bloqueio por gerador. Como em outras
transações revertidas do PostgreSQL, sequências podem avançar sem criar linhas.

O resumo considera as aplicações alcançadas pelos períodos dos lotes, inclusive
pares nas fronteiras e a tolerância de correlação da potência. Ele apresenta
perfis efetivamente usados, vigências, nominal e mínimo como decimais em texto,
contagens operacionais e agrupamentos por motivo. Prévia e confirmação rejeitam
aplicações sem perfil no instante de início; a revalidação também protege a
confirmação contra configuração alterada após a prévia. O processamento dos
contratos individuais legados aplica a mesma proteção às aplicações afetadas,
sem preencher automaticamente o histórico.

Na interface, após validar os dois arquivos, o Master aciona `Projetar avaliação
operacional`. A confirmação fica bloqueada até a projeção válida e mudanças de
arquivo, controlador ou contexto invalidam o resultado. Falta de perfil orienta
a completar a configuração do gerador, sem comunicar potência baixa. Os dois
arquivos são novamente lidos, validados e comparados por hash tanto na projeção
quanto na confirmação; o resumo confirmado vem do processamento real.

Validação: 96 testes de aplicação, 16 arquivos SQL, typecheck, lint, lint SQL dos
schemas `public` e `private` e build de produção aprovados. Cobertura inclui
bloqueio sem perfil e com cobertura nominal incompleta, fronteira de vigência,
igualdade em 61,2 W, três estados projetados iguais aos confirmados, rollback da
prévia e de falha na segunda fonte, reimportação idempotente, acesso de Master,
rejeição de cliente/anon, revalidação dos dois arquivos, mensagens sanitizadas
e invalidação da projeção na interface. Tipos públicos regenerados. As tarefas
12.7 a 12.10 permanecem não iniciadas.

### Tarefa 12.7 — Diagnóstico técnico do Master

**Objetivo:** oferecer ao Master evidência suficiente para investigar cada
aplicação sem alterar o cálculo por ações administrativas.

**Escopo:**

- exibir lado a lado o estado de correlação e o estado operacional;
- mostrar nominal, mínimo, observado, diferença absoluta e percentual;
- mostrar leitura, controlador, lote, arquivo e perfil de origem;
- mostrar motivo técnico para `not_evaluable` e `not_configured`;
- integrar a inconsistência e o histórico disponível de reprocessamento;
- manter reconhecimento e comentários como acompanhamento, sem normalizar uma
  leitura baixa;
- usar texto que recomende verificar equipamento e coleta sem concluir defeito
  ou ausência de ozônio.

**Concluída quando:** queries retornarem o diagnóstico completo somente ao
Master, a interface distinguir todos os estados e testes assegurarem que ações
administrativas não alteram `below_expected`.

**Entrega — 14/09/2026:** migration
`20260914141526_admin_application_power_diagnostics.sql`, aplicada somente no
banco local. Três contratos administrativos retornam, com validação de papel no
banco, o diagnóstico de cada aplicação, as inconsistências vinculadas e o
histórico de reprocessamentos cujo intervalo alcança o início da aplicação.
Clientes e `anon` não conseguem executar as consultas; a tabela privada de
execuções permanece sem acesso direto.

O detalhe do gerador agora lista as aplicações com o estado de correlação e o
estado operacional lado a lado e liga ao diagnóstico em
`/admin/aplicacoes/[id]`. O detalhe mostra os snapshots de nominal, mínimo e
observado, diferença absoluta e percentual em relação ao nominal, leitura de
referência, controladores, lotes, arquivos, eventos e perfil de origem. Os
estados `not_evaluable` e `not_configured` recebem motivos e orientações
próprios, sem serem apresentados como redução de potência.

Inconsistências pendentes, reconhecidas e resolvidas ficam associadas ao
diagnóstico com nota, responsável e datas disponíveis. Reconhecimento,
comentário e reabertura continuam sendo acompanhamento administrativo: não
alteram os snapshots nem transformam `below_expected` em resultado normal. A
orientação da tela recomenda verificar equipamento e coleta e esclarece que a
leitura pontual não comprova defeito nem ausência de geração de ozônio.

Validação: 116 testes de aplicação e 17 arquivos SQL aprovados, incluindo os
quatro estados operacionais, valores decimais exatos, origem completa,
paginação, autorização, preservação de `below_expected` após reconhecimento e
reabertura e histórico após resolução automática. Typecheck, lint e lint SQL
dos schemas `public` e `private` aprovados. O layout sintético foi inspecionado
em desktop e em 390 px, sem transbordamento horizontal e com as quatro seções
acessíveis. Tipos públicos regenerados. As tarefas 12.8 a 12.10 permanecem não
iniciadas.

### Tarefa 12.8 — Contrato sanitizado do cliente

**Objetivo:** criar uma superfície pública nova e mínima, em paralelo ao
contrato atual, para permitir migração segura do portal.

**Escopo:**

- criar view com `security_invoker` ou RPC sanitizada que retorne somente o
  contexto público necessário, `application_status` e `attention_status`;
- agregar o dia como `attention` quando ao menos uma aplicação visível estiver
  `below_expected`, sem retornar contagem;
- mapear `within_expected`, `not_evaluable` e `not_configured` para ausência de
  alerta de redução;
- excluir nominal, mínimo, observado, percentual, perfis, leituras, estados
  internos, razões, tolerâncias e limites do tipo de retorno;
- aplicar isolamento por conta, RLS, `GRANT` e `REVOKE` explícitos;
- manter o contrato antigo somente como ponte interna até a tarefa 12.9, sem
  ampliar suas permissões.

**Concluída quando:** testes de catálogo e execução provarem ausência de
colunas técnicas, bloqueio de `anon`, isolamento entre dois clientes e acesso
correto do Master e do cliente ao novo contrato.

**Resultado:** a RPC `list_client_application_status` publica somente cliente,
unidade, câmara, gerador, data, estado público da aplicação e sinal qualitativo
de atenção. O estado diário `completed` é apresentado como `registered`; os
demais estados públicos existentes continuam disponíveis para preservar a
migração do portal. Duas ou mais aplicações `below_expected` do mesmo gerador
e dia produzem uma única linha `attention`, enquanto `within_expected`,
`not_evaluable` e `not_configured` produzem `none`.

A implementação protegida valida usuário ativo e limita usuários de cliente à
própria conta. A função exposta usa `security invoker`, `search_path` fixo e
permissões explícitas somente para `authenticated`; `anon` não possui execução.
O contrato anterior foi mantido sem mudança de privilégios como ponte para a
tarefa 12.9.

Validação: 116 testes de aplicação e 18 arquivos SQL aprovados. O teste novo
cobre catálogo com exatamente sete colunas públicas, bloqueio real de `anon`,
isolamento entre duas contas, acesso do Master, filtros, agregação sem contagem
e os quatro estados operacionais. Reset completo do banco, typecheck, lint,
build, lint SQL de `public` e `private` e conferência dos tipos públicos também
foram aprovados.

### Tarefa 12.9 — Experiência do portal e retirada do contrato antigo

**Objetivo:** migrar o portal para o contrato sanitizado e remover a exposição
normal de “potência confirmada”.

**Escopo:**

- trocar queries e tipos do portal para consumir somente o contrato da tarefa
  12.8;
- mostrar `Aplicação registrada` sem selo ou detalhe elétrico quando não houver
  redução;
- mostrar `Aplicação registrada — atenção necessária` e o texto qualitativo
  aprovado quando houver redução;
- apresentar um único sinal de atenção por dia, mesmo com várias aplicações
  baixas;
- não gerar falso alerta para `not_evaluable`, `not_configured`, falta de
  cobertura ou leitura de desligamento;
- garantir que o alerta tenha texto e semântica acessível, sem depender apenas
  de cor;
- após a troca, retirar `power_evidence_status` do contrato público antigo e
  revogar ou remover o caminho de compatibilidade correspondente;
- inspecionar HTML e payload para confirmar que nenhum valor ou identificador
  técnico foi enviado ao cliente.

**Concluída quando:** testes do portal e verificação no navegador cobrirem caso
normal, caso baixo, agregação diária, responsividade, acessibilidade, payload
sanitizado e isolamento entre contas.

**Entrega — 14/09/2026:** o portal consulta exclusivamente a RPC
`list_client_application_status` para histórico, visão geral e verificações.
Tipos e apresentação usam `registered` e `attention_status`; a evidência
elétrica antiga foi retirada da interface. Sem redução, aparece “Aplicação
registrada”. Com redução, o registro diário apresenta um único destaque com
“Aplicação registrada — atenção necessária” e a orientação para verificação
pela Ortusolis, com semântica `role="status"` e texto além da cor.

A migration `20260914190956_retire_client_power_evidence_contract.sql`, aplicada
somente no banco local, remove a política de consulta cliente da tabela antiga.
`client_daily_status`, incluindo `power_evidence_status`, permanece interna ao
processamento e ao diagnóstico do Master; usuários cliente não recebem linhas
desse caminho. O novo contrato mantém isolamento por conta. Nenhum dado
histórico é apagado pela migration. O cabeçalho passa a indicar o último dia
publicado, pois a RPC sanitizada não expõe `updated_at` do processamento.

Validação: 123 testes de aplicação, 18 arquivos SQL, typecheck e lint aprovados;
lint SQL de `public` e `private` sem erros. Build de produção aprovado com
Webpack e Node 24. O build padrão com Turbopack encontrou bloqueio do ambiente
ao abrir uma porta de subprocesso, inclusive após escalonamento de permissões.
No navegador, a versão compilada foi verificada com duas contas sintéticas no
Supabase local: caso normal, dois resultados baixos agregados em um alerta,
ausência de falso alerta nos demais estados, filtro com gerador de outra conta,
HTML e payload sem campos ou identificadores técnicos. Em 1440, 768 e 390 px,
os sete dias publicados mantiveram um único alerta e nenhum transbordamento
horizontal. Imagens em `output/playwright/spec129/`. Dados sintéticos removidos
ao fim da verificação. A tarefa 12.10 permanece não iniciada.

### Tarefa 12.10 — Auditoria final, documentação e aceite integrado

**Objetivo:** provar que a entrega completa satisfaz a spec e preparar sua
operação segura.

**Escopo:**

- revisar logs e auditoria de criação/encerramento de perfil, reprocessamento e
  ciclo da inconsistência, sem dados brutos ou exposição ao cliente;
- documentar a operação e a diferença entre energização, consumo abaixo do
  esperado e geração de ozônio;
- gerar novamente os tipos do banco e conferir o diff;
- executar reset/migrations em banco limpo e a suíte SQL completa;
- executar testes unitários, typecheck, lint e build de produção;
- verificar no navegador os fluxos críticos de Master e cliente em desktop e
  viewport móvel;
- revisar a matriz abaixo e registrar qualquer decisão editorial permitida;
- atualizar o status geral da spec somente após todos os critérios passarem.

**Concluída quando:** todas as tarefas 12.1 a 12.9 estiverem marcadas como
concluídas, a suíte completa estiver verde, não houver regressão das specs 02 a
11 e a Definition of Done desta spec estiver integralmente atendida.

**Entrega — 15/09/2026:** auditoria integrada concluída. O guia
[Operação da potência nominal](../operacao/potencia-nominal.md) documenta
cadastro e vigências, importação, diagnóstico, reprocessamento, auditoria e a
diferença entre energização, consumo abaixo do esperado e geração de ozônio.

A revisão identificou e corrigiu duas lacunas: eventos explícitos de criação,
resolução e reativação de `power_below_expected`, e logs que recebiam objetos de
erro completos. A migration `20260914203245_operational_power_lifecycle_audit.sql`
registra o ciclo derivado sem copiar conteúdo de arquivo ou comentários. Os
logs de servidor passam a guardar somente operação e SQLSTATE; registros de
falha enviados pelas ações de importação usam mensagens fixas sanitizadas.

A nova auditoria revelou que a reconstrução de estado resolvia temporariamente
um alerta de potência antes de a avaliação canônica reativá-lo. A migration
`20260915004544_preserve_operational_alert_during_state_reprocessing.sql`
separa esses ciclos: somente a avaliação operacional resolve o alerta nominal,
evita eventos artificiais na reimportação e preserva a idempotência. Os testes
verificam transições reais, ausência de duplicidade e acesso restrito. O teste
legado da spec 06 fixa o fuso de Fortaleza, alinhado ao calendário de publicação,
para não depender de uma coincidência entre a data UTC e a data local.

**Verificação final:** 21 migrations reaplicadas em banco local limpo; 18
arquivos SQL e 130 testes de aplicação aprovados; lint SQL de `public` e
`private`, typecheck e lint aprovados. Tipos públicos regenerados, sem mudança
de contrato (normalizada somente a linha vazia adicional no fim do arquivo).
Build de produção aprovado com Webpack e Node 24; a limitação de subprocesso do
Turbopack registrada na 12.9 permanece específica do ambiente. O primeiro reset
exigiu recuperação do Docker; a reaplicação final completou as 21 migrations e
retornou um 502 transitório ao reiniciar os serviços. Os testes e a aplicação
foram verificados depois da recuperação desses serviços.

**Navegador e banco:** nova vigência de 72 W com prévia de 61,2 W e preservação
do perfil anterior; validação de dois XLSX sintéticos, projeção, confirmação
conjunta e repetição sem duplicar sessão/lotes. A massa integrada produziu uma
aplicação baixa e outra não avaliável, conforme a correlação existente; igualdade
exata em 61,2 W e os quatro estados estão cobertos pela suíte SQL. O diagnóstico
mostrou 61,199 W contra 61,2 W. Reconhecimento com nota preservou `below_expected`,
com um único evento de criação e um de revisão. O cliente recebeu apenas o
alerta qualitativo, inclusive após reconhecimento. Conta B não recebeu o gerador
da conta A quando seu identificador foi usado no filtro. HTML e resposta do
portal foram inspecionados sem valores ou identificadores técnicos.

Importação, diagnóstico e portal foram inspecionados em 1440 e 390 px, sem
transbordamento horizontal; alerta com texto e `role="status"`. Evidências em
`output/playwright/spec1210/`. A confirmação de importação também foi exercitada
com aceitação programática restrita à mensagem esperada, pois o controle do
diálogo nativo pelo CLI foi instável. Essa instrumentação não altera o código
da aplicação. Dados e contas sintéticos removidos após a verificação.

**Decisões editoriais mantidas:** “Aplicação registrada” sem detalhe elétrico;
“Aplicação registrada — atenção necessária” com verificação atribuída à
Ortusolis; cabeçalho “Último dia publicado”; indisponibilidade e qualidade dos
registros continuam separadas da redução de potência. Não se infere defeito,
ausência de ozônio ou necessidade de o cliente alterar o equipamento.

O aceite é local. Nenhuma migration foi aplicada ao projeto remoto e nenhum
deploy foi realizado. O fechamento da spec 12 não substitui a liberação de
produção da spec 09.

### Matriz de rastreabilidade

| Área da spec | Tarefas responsáveis | Evidência de aceite |
| --- | --- | --- |
| Perfil, cálculo de 85%, vigência e legado | 12.1, 12.4 e 12.5 | Perfis, contratos administrativos e obrigatoriedade: testes SQL e formulários; vigência conferida no navegador. |
| Quatro estados e snapshots | 12.2 | Teste SQL de avaliação, incluindo igualdade, fronteira de vigência, ausência de leitura/perfil e desligamento. |
| Reprocessamento e `power_below_expected` | 12.3 | Teste SQL de reprocessamento e auditoria; revisão preserva resultado; repetição sem eventos extras. |
| Cadastro, edição, listagem e pendência | 12.4 e 12.5 | Contratos, validação decimal, componentes e histórico administrativo. |
| Prévia e confirmação conjunta | 12.6 | Teste SQL nominal da importação, ações, componentes e dois XLSX no navegador. |
| Diagnóstico administrativo | 12.7 | SQL e componentes de diagnóstico; origem, snapshots e nota conferidos no navegador. |
| Segurança e contrato sanitizado | 12.8 e 12.9 | Catálogo, RLS, anon, duas contas, queries e inspeção de HTML/payload. |
| Portal, atenção diária e acessibilidade | 12.9 | Testes de página, agregação SQL e navegador em desktop/smartphone. |
| Observabilidade, documentação e aceite final | 12.10 | Guia operacional, eventos de ciclo, logs sanitizados, reset, suíte completa, tipos, lint e build. |

## Regra de precedência

Esta spec acrescenta uma avaliação de suficiência operacional à evidência de
potência definida pela spec 10. Também substitui a apresentação normal de
“potência confirmada” ao cliente por uma comunicação centrada na aplicação.

Continuam válidos:

- a aplicação formada pelos eventos programados `Ligar` e `Desligar`;
- os papéis independentes dos controladores `state` e `power_telemetry`;
- os limites elétricos de liga e desliga configurados no controlador de
  potência;
- a preservação das leituras brutas e a correlação temporal da spec 10;
- a importação conjunta, os dois campos visíveis e a confirmação da spec 11;
- a distinção entre dado bruto, resultado derivado e visão sanitizada;
- o acesso do Master aos diagnósticos técnicos;
- o isolamento entre clientes e o princípio do menor privilégio.

Os limites de liga e desliga do controlador respondem se uma leitura é
compatível com equipamento energizado ou desenergizado. A potência nominal do
gerador responde se uma leitura já correlacionada ao início da aplicação está
dentro da faixa operacional esperada. São configurações distintas e não devem
ser reutilizadas uma no lugar da outra.

Potência elétrica permanece uma evidência indireta. Nem uma leitura dentro da
faixa, nem uma leitura abaixo dela medem concentração, vazão ou quantidade de
ozônio produzida.

## Problema

A correlação da spec 10 identifica se existe evidência elétrica compatível com
o início e o fim de uma aplicação, mas não compara o consumo observado com a
potência esperada para o modelo de gerador instalado.

Sem essa referência, uma leitura pode comprovar energização e ainda assim
representar consumo significativamente inferior ao nominal. O Master precisa
identificar essa condição para verificar o equipamento, enquanto o cliente
precisa receber um alerta simples, sem ter acesso a watts ou parâmetros
técnicos.

Pedir ao Master que informe também o mínimo aceitável criaria uma configuração
redundante e sujeita a critérios diferentes entre equipamentos. A regra do
produto será única: admite-se redução de até 15% em relação à potência nominal.

## Objetivo

Permitir que o Master informe a potência nominal do gerador e fazer o sistema:

1. calcular automaticamente o mínimo aceitável como 85% da potência nominal;
2. avaliar a leitura de potência associada ao início de cada aplicação;
3. distinguir potência dentro do esperado, potência abaixo do esperado e
   impossibilidade de avaliação;
4. oferecer ao Master os dados técnicos necessários para investigação;
5. mostrar ao cliente apenas que houve aplicação e, quando necessário, um
   alerta qualitativo de atenção;
6. preservar a classificação histórica quando a potência nominal for alterada.

## Resultado esperado

- No cadastro do gerador, o Master informa somente a potência nominal em watts.
- O sistema apresenta o mínimo calculado, mas não permite editá-lo.
- Uma aplicação com leitura de início igual ou superior ao mínimo permanece sem
  alerta de potência no portal do cliente.
- Uma aplicação com leitura de início inferior ao mínimo permanece registrada,
  mas recebe um alerta de atenção.
- Ausência de telemetria, falha de correlação e potência baixa são condições
  diferentes.
- O cliente não consegue consultar potência nominal, potência observada,
  percentual, limite calculado ou evidências técnicas.
- Alterações futuras na potência nominal não mudam silenciosamente o resultado
  de aplicações anteriores.

## Vocabulário

### Potência nominal

Potência elétrica, em watts, esperada para o gerador segundo sua configuração
operacional. É informada pelo Master e pertence ao gerador, não ao controlador.

### Redução máxima admitida

Percentual fixo de 15% abaixo da potência nominal. É uma regra do produto e não
é editável no cadastro.

### Potência mínima aceitável

Valor calculado pelo sistema:

```text
potencia_minima_aceitavel_w = potencia_nominal_w × 0,85
```

Uma leitura exatamente igual ao mínimo é aceita. Somente valor estritamente
inferior é classificado como abaixo do esperado.

### Leitura de referência

Leitura já correlacionada pela spec 10 ao início da aplicação, identificada por
`power_on_reading_id`. É o ponto avaliado nesta spec.

A leitura correlacionada ao `Desligar`, identificada por
`power_off_reading_id`, comprova desenergização e nunca deve ser comparada com o
mínimo operacional.

### Atenção operacional

Sinal qualitativo de que a leitura de referência ficou abaixo do mínimo
aceitável. Orienta uma verificação do equipamento, sem afirmar defeito ou falta
de produção de ozônio.

## Regras de domínio

### Configuração no cadastro do gerador

- `potência nominal (W)` é obrigatória para novos geradores.
- O valor deve ser numérico, finito e estritamente maior que zero.
- A persistência aceita até três casas decimais.
- A unidade é sempre watt; não haverá seletor de unidade.
- O Master não informa redução máxima nem potência mínima.
- A tela calcula e mostra o mínimo de 85% como valor somente leitura.
- O cálculo exibido pela interface é uma prévia; o servidor e o banco são a
  fonte de verdade.
- O servidor ignora qualquer mínimo enviado pelo cliente e o recalcula a partir
  da potência nominal válida.
- Não será definido limite máximo arbitrário nesta spec.

Exemplo:

```text
potência nominal: 72 W
potência mínima aceitável: 61,2 W
```

Os campos dos controladores devem continuar separados. A interface deve deixar
claro que:

- potência nominal descreve o gerador;
- `power_on_threshold_w` e `power_off_threshold_w` classificam o sinal do
  controlador;
- alterar um desses valores não altera automaticamente os demais.

### Histórico da potência nominal

A potência nominal deve ser versionada por vigência. Sobrescrever um único
campo no gerador faria uma alteração atual reclassificar aplicações antigas e
prejudicaria a auditoria.

- Cada gerador possui no máximo um perfil de potência válido em cada instante.
- A vigência usa intervalo semiaberto: `valid_from <= instante < valid_until`.
- `valid_until = null` identifica o perfil vigente.
- O primeiro perfil começa no início operacional do gerador.
- A aplicação seleciona o perfil válido no instante do evento `Ligar`.
- Intervalos do mesmo gerador não podem se sobrepor.
- Uma alteração exige potência nominal nova e data/hora de vigência.
- A alteração encerra o perfil anterior e cria outro; não edita o histórico
  anterior no lugar.
- Trocar fisicamente o equipamento por outro gerador deve criar um novo
  gerador, especialmente quando número de série, identidade ou modelo mudar.
- Toda criação ou alteração registra autor e data para auditoria.

### Geradores já existentes

- Valores nominais não serão inferidos de leituras importadas.
- A migração não inventará potência para geradores existentes.
- Esses geradores ficam com configuração de potência pendente até o Master
  criar o primeiro perfil.
- Aplicações e dados históricos existentes permanecem consultáveis.
- Uma aplicação sem perfil válido recebe resultado técnico `not_configured` e
  não é classificada como potência baixa.
- Uma nova confirmação conjunta que pretenda avaliar potência para um gerador
  sem perfil deve ser bloqueada antes da confirmação, com orientação para
  completar o cadastro.
- Fluxos legados preservados exclusivamente para compatibilidade não podem
  criar silenciosamente uma avaliação de potência sem perfil.

### Cálculo do mínimo

O cálculo canônico é:

```text
minimum_acceptable_power_w = nominal_power_w × (1 - 0,15)
minimum_acceptable_power_w = nominal_power_w × 0,85
```

- O cálculo usa tipo decimal exato, nunca ponto flutuante binário.
- O valor persistido ou retornado mantém precisão suficiente para comparação.
- A formatação visual pode remover zeros finais, sem alterar o valor canônico.
- Não se arredonda o mínimo antes da comparação.
- Uma leitura `observed_power_w >= minimum_acceptable_power_w` está dentro do
  esperado.
- Uma leitura `observed_power_w < minimum_acceptable_power_w` está abaixo do
  esperado.

Exemplo de borda para um gerador nominal de 72 W:

| Leitura de referência | Resultado |
| --- | --- |
| 61,200 W | Dentro do esperado |
| 61,199 W | Abaixo do esperado |
| 72,000 W | Dentro do esperado |

### Leitura que pode ser avaliada

A avaliação usa exclusivamente a `power_on_reading_id` escolhida pela
correlação temporal da spec 10.

- A leitura precisa pertencer ao controlador de potência compatível com a
  aplicação e sua vigência.
- A leitura precisa ter passado pelas validações técnicas da importação.
- Uma leitura abaixo de `power_on_threshold_w` não se torna leitura de início
  apenas para permitir esta comparação.
- Se a spec 10 não encontrar leitura de início compatível, o resultado é não
  avaliável, e não potência baixa.
- Leituras próximas do evento `Desligar`, inclusive zero watt, são excluídas da
  avaliação do mínimo.
- Linhas não correlacionadas não geram alertas isoladamente.

Os arquivos atualmente representam observações pontuais. Portanto, esta spec
avalia o ponto de início disponível; ela não afirma permanência acima do mínimo
durante toda a aplicação.

### Estados da avaliação operacional

A avaliação deve ter um estado próprio, sem sobrecarregar o `status` de
correlação definido na spec 10:

| Estado técnico | Condição | Alerta de redução |
| --- | --- | --- |
| `within_expected` | leitura de referência maior ou igual ao mínimo | Não |
| `below_expected` | leitura de referência menor que o mínimo | Sim |
| `not_evaluable` | perfil existe, mas falta leitura de referência válida | Não |
| `not_configured` | não existe perfil válido para o início da aplicação | Não |

`not_evaluable` deve preservar um motivo técnico compatível com os estados da
spec 10, como ausência de leitura ligada ou falta de cobertura. Ele não pode ser
convertido em `below_expected` apenas por falta de dados.

A avaliação de correlação e a avaliação operacional são ortogonais. Por
exemplo, uma aplicação pode possuir leitura ligada válida, receber
`below_expected` e ainda ter leitura desligada ausente na correlação.

### Resultado da aplicação

- Uma leitura baixa não apaga, invalida nem reabre a aplicação formada pelos
  eventos de estado.
- O estado principal continua sendo “Aplicação registrada”.
- `below_expected` acrescenta atenção operacional ao resultado.
- O alerta não declara que o equipamento está defeituoso.
- O alerta não declara que não houve geração de ozônio.
- Revisar ou reconhecer uma inconsistência administrativa não transforma a
  leitura em normal.
- O alerta permanece enquanto o resultado derivado continuar
  `below_expected`.
- Ele desaparece somente quando dados ou configuração válidos forem corrigidos
  e o reprocessamento produzir outro resultado.

## Modelo de dados proposto

Os nomes abaixo definem o contrato conceitual. A migration pode adequar nomes
técnicos ao padrão do schema, desde que preserve os significados.

### `generator_power_profiles`

| Campo | Regra |
| --- | --- |
| `id` | UUID, chave primária |
| `generator_id` | gerador ao qual a configuração pertence |
| `nominal_power_w` | decimal positivo com até três casas |
| `reduction_limit_percent` | decimal fixado em `15.000` nesta versão |
| `minimum_acceptable_power_w` | decimal derivado da potência nominal |
| `valid_from` | início inclusivo da vigência |
| `valid_until` | fim exclusivo ou `null` |
| `created_by` | Master responsável |
| `created_at` | auditoria |

Requisitos de integridade:

- `nominal_power_w > 0`;
- `reduction_limit_percent = 15.000`;
- mínimo derivado de forma canônica, preferencialmente por coluna gerada ou
  função controlada pelo banco;
- `valid_until > valid_from` quando houver fim;
- exclusão de intervalos sobrepostos para o mesmo gerador;
- imutabilidade dos perfis já usados, exceto correção administrativa auditada
  com reprocessamento explícito.

### Extensão de `application_power_verifications`

A verificação de uma aplicação deve guardar ou expor:

| Campo conceitual | Finalidade |
| --- | --- |
| `operational_power_status` | um dos quatro estados desta spec |
| `power_profile_id` | perfil selecionado pela vigência |
| `reference_power_reading_id` | leitura de início avaliada |
| `nominal_power_w_snapshot` | valor usado no processamento |
| `minimum_acceptable_power_w_snapshot` | mínimo usado na comparação |
| `observed_power_w_snapshot` | valor observado avaliado |
| `operational_reason` | motivo técnico quando não avaliável |

Os snapshots garantem auditabilidade. Eles não autorizam exposição desses
valores ao cliente.

Uma alternativa normalizada é permitida se mantiver relação única por
aplicação, reconstrução determinística e o mesmo isolamento de acesso.

### Inconsistência administrativa

`below_expected` cria ou mantém uma inconsistência do tipo
`power_below_expected`, vinculada à aplicação, à leitura de referência e ao
perfil utilizado.

- Reprocessamentos idempotentes não duplicam a inconsistência.
- Se o resultado deixar de ser baixo, a inconsistência é resolvida
  automaticamente com motivo de reprocessamento.
- Reconhecimento ou comentário do Master permanece como informação de
  acompanhamento e não muda o cálculo.
- `not_evaluable` e `not_configured` seguem tipos próprios de configuração ou
  qualidade de dados; não reutilizam `power_below_expected`.

## Processamento e reprocessamento

### Gatilhos

A avaliação deve ser executada quando houver:

- confirmação conjunta de novos arquivos;
- reconstrução de aplicações ou correlação da spec 10;
- criação ou alteração de perfil nominal com efeito no período;
- alteração relevante de controlador, vigência, tolerância ou limites de
  detecção;
- correção auditada de dados que altere a leitura correlacionada.

### Propriedades obrigatórias

- O processamento é transacional quando fizer parte da confirmação conjunta.
- Para as mesmas fontes e configurações efetivas, o resultado é determinístico.
- Repetir o processamento não duplica verificações nem inconsistências.
- A data funcional do resultado não depende do relógio da reexecução.
- A aplicação seleciona o perfil pelo instante de início, não pelo instante da
  importação.
- Mudanças de perfil reprocessam somente o intervalo afetado.
- Falha no reprocessamento não deve publicar parte do novo resultado.

### Prévia da importação conjunta

Depois que ambos os arquivos forem válidos, a prévia administrativa pode
mostrar:

- potência nominal vigente;
- mínimo calculado;
- quantidade projetada de aplicações dentro do esperado;
- quantidade projetada abaixo do esperado;
- quantidade não avaliável e seus motivos.

Esses números são exclusivos do Master. A projeção deve usar a mesma correlação
e a mesma função de cálculo da confirmação; não pode simplesmente contar todas
as linhas com watts abaixo do mínimo.

## Experiência administrativa

### Cadastro e edição

- O campo `Potência nominal (W)` fica no cadastro do gerador.
- O texto de apoio informa que o sistema admite redução de até 15%.
- O valor `Potência mínima calculada` aparece como somente leitura.
- Erros indicam claramente valor obrigatório, inválido ou não positivo.
- A edição solicita a data/hora a partir da qual a nova potência vale.
- A lista e o detalhe do gerador mostram potência nominal vigente, mínimo
  calculado e situação da configuração.
- Geradores legados pendentes devem ser identificáveis e filtráveis.

### Diagnóstico de aplicações

Para uma aplicação, o Master pode consultar:

- estado da correlação da spec 10;
- estado da avaliação operacional;
- potência nominal e mínimo utilizados;
- leitura observada de referência;
- diferença absoluta e percentual em relação ao nominal;
- leitura, controlador, lote e arquivo de origem;
- inconsistência e histórico de reprocessamento.

A interface não deve sugerir que o valor baixo, isoladamente, comprova ausência
de ozônio. A orientação operacional é verificar o equipamento e a coleta.

## Experiência do cliente

### Aplicação sem redução detectada

O cliente vê somente o estado principal da aplicação, por exemplo:

> Aplicação registrada

Não deve ser exibido selo “Potência confirmada”, watt, percentual, limite ou
explicação técnica quando a avaliação estiver dentro do esperado.

### Aplicação com redução detectada

Quando o estado for `below_expected`, a aplicação recebe destaque qualitativo:

> Aplicação registrada — atenção necessária

Texto de apoio recomendado:

> O consumo elétrico registrado ficou abaixo do esperado. A Ortusolis deve
> verificar o equipamento.

O texto pode ser ajustado editorialmente sem mudar estas restrições:

- não revelar nenhum valor numérico;
- não usar “falha”, “sem ozônio” ou outra conclusão não demonstrada;
- não pedir ao cliente que altere o equipamento;
- deixar claro que a verificação cabe à Ortusolis.

### Agregação diária

- Se qualquer aplicação visível do dia estiver `below_expected`, o dia recebe
  atenção.
- Várias aplicações baixas no mesmo dia continuam produzindo um único sinal
  qualitativo, sem contagem para o cliente.
- Aplicações dentro do esperado não mostram evidência técnica adicional.
- `not_evaluable` e `not_configured` não podem ser apresentados como redução de
  potência.
- Regras existentes de indisponibilidade ou qualidade de dados podem continuar
  sendo tratadas separadamente, sem revelar o diagnóstico técnico.

### Contrato sanitizado

A superfície consumida pelo portal deve oferecer somente o mínimo necessário,
por exemplo:

```text
application_status = "registered"
attention_status = "none" | "attention"
```

O cliente não deve conseguir consultar, nem mesmo ocultos na interface:

- potência nominal;
- potência mínima aceitável;
- potência observada;
- percentual fixo de redução;
- `power_profile_id` ou identificadores de leituras;
- estados internos de correlação e avaliação;
- tolerâncias, limites ou razões técnicas;
- contagens de ocorrências abaixo do esperado.

O `power_evidence_status` da spec 10 deixa de fazer parte do contrato público do
portal. Pode permanecer internamente para processamento e diagnóstico.

Ocultar colunas no componente React não é uma barreira de segurança. O banco
deve oferecer uma view segura ou função RPC sanitizada, com RLS e permissões
explícitas. As tabelas técnicas não recebem `SELECT` do papel de cliente. Caso
uma view seja usada, ela deve respeitar o usuário chamador e não contornar RLS.

## Segurança e autorização

- Somente Master cria ou altera perfis de potência nominal.
- Operações administrativas são validadas no servidor e no banco.
- Clientes acessam apenas aplicações e agregados pertencentes à própria conta.
- RLS é obrigatória nas novas tabelas.
- `GRANT` e `REVOKE` são explícitos; criar tabela no schema `public` não implica
  exposição pela Data API.
- Papéis `anon` e cliente não acessam perfis, snapshots, leituras ou
  inconsistências técnicas.
- O papel administrativo recebe somente as permissões necessárias às operações
  previstas.
- Funções com privilégio elevado validam identidade, papel e escopo antes de
  consultar ou alterar dados.
- Auditoria não armazena conteúdo bruto dos arquivos nem expõe valores ao
  cliente.

## Compatibilidade e migração

- Nenhum evento, leitura, aplicação ou lote existente é apagado.
- O estado de correlação da spec 10 permanece independente do novo estado
  operacional.
- Perfis nominais começam vazios para geradores legados.
- O Master recebe uma lista objetiva dos geradores que precisam de
  configuração.
- Resultados históricos só são calculados onde houver perfil explicitamente
  vigente e leitura de referência válida.
- Não haverá preenchimento automático pela média, máximo ou moda das leituras.
- A publicação do novo contrato sanitizado deve ser coordenada com a atualização
  do portal para não expor nem depender do antigo selo de potência.
- Rollback da interface não autoriza reabrir acesso cliente às tabelas técnicas.

## Observabilidade e auditoria

Registrar, sem dados secretos ou conteúdo de planilha:

- criação e encerramento de perfil nominal;
- autor, gerador, valor e vigência da alteração;
- quantidade de avaliações por estado em cada processamento;
- criação e resolução de inconsistências `power_below_expected`;
- falhas de integridade, conflito de vigência e reprocessamento;
- versão da regra de cálculo usada.

Métricas e logs administrativos podem conter valores técnicos quando
necessários à operação, mas não devem ser enviados a analytics ou logs
acessíveis pelo cliente.

## Fora do escopo

- permitir que o Master escolha outro percentual de redução;
- configurar limite máximo de potência;
- medir permanência ou percentual de tempo dentro de uma faixa;
- calcular consumo de energia em Wh ou kWh;
- estimar concentração, vazão ou massa de ozônio;
- provar geração de ozônio apenas pela potência elétrica;
- inferir potência nominal a partir das leituras;
- criar alertas a partir de linhas não correlacionadas;
- enviar e-mail, SMS, push ou mensagem automática;
- permitir que o cliente veja ou exporte valores técnicos;
- controle remoto ou alteração automática do equipamento.

Uma evolução para telemetria contínua deverá definir frequência mínima,
tolerância a lacunas, agregação, permanência na faixa e tratamento de picos em
outra spec.

## Critérios de aceite funcionais

### Cadastro

- Novo gerador não pode ser salvo sem potência nominal positiva.
- O Master informa somente a potência nominal.
- O mínimo de 85% é mostrado como somente leitura.
- O backend recalcula o mínimo e não confia em valor enviado pela interface.
- Editar a potência cria nova vigência sem sobrescrever o histórico.
- Um intervalo sobreposto é rejeitado.
- Gerador legado sem perfil aparece como configuração pendente.

### Avaliação

- Nominal de 72 W produz mínimo exato de 61,2 W.
- Leitura de 61,2 W resulta em `within_expected`.
- Leitura de 61,199 W resulta em `below_expected`.
- Leitura de desligamento com 0 W não gera alerta de redução.
- Ausência da leitura de início resulta em `not_evaluable`.
- Ausência de perfil resulta em `not_configured`.
- Uma leitura não compatível com o limite de liga não é promovida artificialmente
  a leitura de referência.
- O perfil é escolhido pela data do `Ligar` da aplicação.
- Aplicação exatamente no início de uma nova vigência usa o perfil novo.
- Reprocessar as mesmas fontes e configurações mantém o mesmo resultado sem
  duplicidade.

### Administração

- O Master vê nominal, mínimo, observado, origem e motivo técnico.
- A prévia conjunta usa a correlação real para projetar os estados.
- Potência baixa cria uma única inconsistência ativa por aplicação.
- Reconhecer a inconsistência não remove o alerta enquanto o cálculo continuar
  baixo.
- Corrigir dados ou perfil e reprocessar resolve a inconsistência quando a
  leitura deixar de estar abaixo do mínimo.

### Portal do cliente

- Aplicação normal mostra “Aplicação registrada” sem selo ou valor de potência.
- Aplicação baixa mostra atenção qualitativa sem números.
- Um dia com ao menos uma aplicação baixa recebe um único sinal de atenção.
- `not_evaluable` e `not_configured` não são apresentados como potência baixa.
- O portal não inclui campos técnicos no HTML, payload ou exportação.
- A experiência continua compreensível em desktop, tablet e smartphone.
- O alerta não depende somente de cor e é anunciado corretamente por tecnologia
  assistiva.

## Critérios de aceite técnicos e de segurança

- Constraints rejeitam potência nominal nula, zero, negativa ou vigência
  inválida.
- Constraint de exclusão impede sobreposição de perfis do mesmo gerador.
- O cálculo usa decimal exato e possui teste de borda para igualdade.
- A avaliação possui chave única por aplicação ou garantia equivalente.
- RLS e permissões explícitas cobrem todas as tabelas, views e funções novas.
- `anon` não acessa dados operacionais.
- Um cliente não acessa dados de outro cliente.
- Cliente autenticado não consegue selecionar nominal, mínimo, observado,
  snapshots ou razões técnicas.
- Master consegue executar somente as operações administrativas previstas.
- A view ou RPC pública contém apenas o estado sanitizado.
- Funções privilegiadas validam papel e escopo e fixam um `search_path` seguro.
- Reprocessamento transacional não publica resultado parcial.
- Testes automatizados cobrem migração, domínio, RLS, contratos de servidor e
  interface.

## Estratégia de testes

### Banco de dados

- constraints de valores e vigência;
- exclusão de intervalos sobrepostos;
- cálculo de 85% com decimais e casos de fronteira;
- seleção do perfil nos limites do intervalo semiaberto;
- estados `within_expected`, `below_expected`, `not_evaluable` e
  `not_configured`;
- exclusão explícita da leitura de desligamento;
- idempotência da avaliação e da inconsistência;
- resolução automática após reprocessamento;
- RLS com Master, `anon` e dois clientes distintos;
- ausência de colunas técnicas no contrato sanitizado.

### Servidor

- validação da potência nominal;
- rejeição de mínimo calculado adulterado pelo cliente;
- criação versionada e conflito de vigência;
- bloqueio da confirmação conjunta sem perfil em gerador que requer avaliação;
- prévia e confirmação usando a mesma função de domínio;
- reprocessamento limitado ao período afetado;
- autorização administrativa e mensagens de erro sanitizadas.

### Interface administrativa

- cálculo visual enquanto o Master preenche o nominal;
- estados vazio, inválido, válido, salvando e erro;
- indicação de configuração pendente para legado;
- edição com início de vigência;
- diagnóstico de leitura baixa e não avaliável;
- responsividade, teclado, foco, rótulos e anúncio de erros.

### Portal do cliente

- aplicação normal sem detalhe de potência;
- aplicação baixa com texto de atenção e sem números;
- agregação de um ou vários casos no mesmo dia;
- ausência de falso alerta para desligamento, falta de cobertura ou falta de
  perfil;
- inspeção do payload para confirmar que dados técnicos não foram enviados;
- isolamento entre contas e acessibilidade do alerta.

## Definition of Done

A spec estará implementada quando:

- o cadastro do gerador exigir potência nominal e calcular o mínimo de 85%;
- perfis nominais forem históricos, auditáveis e sem sobreposição;
- aplicações forem avaliadas somente pela leitura de início correlacionada;
- os quatro estados operacionais forem persistidos ou derivados de modo
  determinístico;
- potência baixa produzir diagnóstico técnico para o Master e atenção
  qualitativa para o cliente;
- aplicações normais deixarem de expor a confirmação técnica de potência ao
  cliente;
- o contrato cliente não contiver valores nem estados internos;
- geradores legados forem tratados sem inferência de potência;
- reprocessamento for transacional e idempotente;
- testes de banco, servidor, interface, RLS e privacidade estiverem aprovados;
- a documentação operacional explicar a diferença entre energização, consumo
  abaixo do esperado e geração de ozônio.
