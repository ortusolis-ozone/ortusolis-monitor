# Spec 11 — Importação conjunta de estado e potência

**Status:** concluída em 03/09/2026.

**Aprovação do produto:** 03/09/2026.

**Tipo:** evolução da experiência administrativa posterior à spec 10.

**Dependências:** specs 05, 07, 09 e 10.

> **Evolução posterior:** a potência nominal do gerador, o mínimo automático de
> 85% e o alerta qualitativo de redução são definidos pela
> [spec 12](./12-potencia-nominal-e-alerta-de-reducao-operacional.md).

## Regra de precedência

Esta spec substitui, somente na experiência administrativa de importação, o
fluxo de arquivo único descrito nas specs 05 e 10.

Continuam válidos:

- os dois formatos de XLSX e suas validações individuais;
- os papéis independentes `state` e `power_telemetry`;
- a preservação de eventos e leituras como fontes brutas;
- a correlação temporal e os estados de evidência definidos pela spec 10;
- a idempotência por hash, contexto e fingerprint;
- o acesso exclusivo do Master aos dados técnicos;
- a publicação sanitizada para o cliente.

Esta spec não altera a definição de aplicação nem transforma potência elétrica
em medição direta de produção ou concentração de ozônio.

## Problema

O fluxo atual mantém um único seletor de controlador, um único campo de arquivo
e uma única prévia. Embora o backend reconheça os dois formatos, o Master precisa
executar duas importações separadas e lembrar qual fonte ainda falta.

Essa experiência permite:

- concluir uma atualização operacional com apenas uma das fontes;
- selecionar o papel de controlador incorreto antes da validação;
- perder a referência visual de qual arquivo já foi confirmado;
- visualizar os dois lotes como registros independentes no histórico;
- publicar temporariamente um resultado sem que a atualização complementar
  tenha sido concluída.

## Objetivo

Tratar os arquivos de estado e potência como duas partes visíveis de uma mesma
atualização administrativa, mantendo sua persistência técnica separada.

O Master deverá conseguir, em uma única tela:

1. selecionar uma vez a hierarquia até o gerador;
2. identificar os dois controladores por papel;
3. selecionar um XLSX de estado e um XLSX de potência em campos distintos;
4. reconhecer imediatamente o estado de cada arquivo;
5. validar a compatibilidade individual e conjunta;
6. confirmar a atualização uma única vez;
7. consultar posteriormente os dois lotes como uma única sessão de importação.

## Resultado esperado

- O Master não precisa memorizar qual fonte já foi enviada.
- Cada arquivo possui campo, controlador, prévia e estado próprios.
- A ausência de uma fonte fica explícita antes da confirmação.
- Uma atualização nova não publica estado parcial entre as duas confirmações.
- O histórico mostra a atualização conjunta e permite abrir os detalhes de cada
  lote técnico.
- Reimportações e arquivos parcialmente sobrepostos continuam idempotentes.

## Vocabulário

### Sessão de importação

Unidade administrativa que reúne exatamente um lote de eventos de estado e um
lote de leituras de potência para o mesmo contexto operacional.

A sessão organiza o fluxo, a auditoria e o histórico. Ela não cria vínculo
direto entre linhas dos dois arquivos e não substitui a correlação temporal da
spec 10.

### Campo de estado

Área destinada exclusivamente ao formato `state_events`, com os cabeçalhos
`Tempo`, `Operação` e `Acionado por`.

### Campo de potência

Área destinada exclusivamente ao formato `power_readings`, com o conjunto de
cabeçalhos técnicos definido pela spec 10.

### Arquivo complementar

O outro arquivo obrigatório da mesma sessão. Estado e potência são
complementares, mas permanecem fontes independentes.

## Experiência administrativa

### Seleção do contexto

O início do fluxo mantém a seleção dependente:

```text
Cliente → Unidade → Câmara → Gerador
```

Não haverá um único seletor global de controlador. Após a escolha do gerador, a
interface apresentará os controladores separadamente dentro de cada campo:

- controlador de `Estado liga/desliga` no campo de estado;
- controlador de `Telemetria de potência` no campo de potência.

O controlador ativo do papel será selecionado por padrão. Controladores
históricos permanecerão disponíveis para importações retroativas e deverão
mostrar claramente sua vigência.

Alterar cliente, unidade, câmara ou gerador invalida as duas prévias. Alterar o
controlador de um papel invalida somente a prévia e o arquivo validado daquele
papel.

### Estrutura visual obrigatória

A tela deverá apresentar dois blocos simultaneamente visíveis:

```text
1. Horários programados — Liga/desliga
   Controlador de estado
   [ Selecionar XLSX de horários ]
   Estado do arquivo · período · linhas · última confirmação

2. Potência consumida
   Controlador de telemetria
   [ Selecionar XLSX de potência ]
   Estado do arquivo · período · linhas · última confirmação
```

Os dois blocos devem permanecer distinguíveis por título, descrição, ícone ou
outro recurso que não dependa exclusivamente de cor.

Em smartphone, os blocos podem ser empilhados, mas ambos devem aparecer antes
da ação principal de validação ou confirmação.

### Informações persistidas exibidas

Antes de selecionar novos arquivos, cada bloco deverá informar, quando houver:

- data e responsável pela última confirmação;
- nome do último arquivo confirmado;
- período coberto pelo lote mais recente;
- estado da fonte no contexto selecionado.

Essas informações vêm do banco. O valor visual de um `<input type="file">` não
pode ser usado para afirmar que um arquivo foi importado.

Após calcular o hash do arquivo selecionado, a interface deverá distinguir uma
seleção nova de um lote idêntico já confirmado no mesmo contexto e controlador.

### Estados de cada campo

Cada campo deverá possuir um estado textual e acessível:

- `empty`: nenhum arquivo selecionado;
- `selected`: arquivo selecionado e ainda não validado;
- `validating`: validação em andamento;
- `valid`: arquivo válido e pronto para compor a confirmação;
- `already_imported`: o mesmo hash já foi confirmado no contexto;
- `invalid`: arquivo incompatível ou com erro de validação;
- `confirmed`: lote associado a uma sessão confirmada.

Os rótulos apresentados ao usuário deverão ser, respectivamente, equivalentes
a:

- `Não selecionado`;
- `Pronto para validar`;
- `Validando`;
- `Validado`;
- `Já importado`;
- `Arquivo incompatível`;
- `Importado com sucesso`.

Erros de um arquivo devem aparecer dentro de seu próprio bloco. Um erro no
arquivo de potência não pode apagar uma prévia válida do arquivo de estado, e
vice-versa.

### Estado conjunto

A sessão deverá informar um estado agregado:

- `incomplete`: falta arquivo ou controlador em pelo menos um papel;
- `validating`: ao menos um arquivo está sendo validado;
- `ready`: os dois arquivos são válidos ou já foram importados;
- `ready_with_warning`: os dois arquivos são válidos, mas há diferença de
  cobertura que exige ciência do Master;
- `confirming`: a persistência conjunta está em andamento;
- `confirmed`: os dois lotes estão associados e o reprocessamento terminou;
- `failed`: a confirmação conjunta falhou.

Enquanto a sessão estiver incompleta, a interface deverá indicar qual fonte
falta, por exemplo:

> Falta o arquivo de potência para concluir esta atualização.

O botão de confirmação permanecerá indisponível até que os dois campos estejam
em `valid` ou `already_imported`.

## Validação

### Validação individual

Cada arquivo continua obedecendo aos limites e contratos existentes:

- extensão `.xlsx`;
- até 5 MB por arquivo;
- até 25.000 registros por arquivo;
- primeira aba não vazia compatível;
- controlador e formato do mesmo papel;
- todas as linhas dentro da vigência do controlador;
- hash e parsing recalculados na confirmação;
- Device ID único e compatível para potência;
- datas interpretadas no fuso da unidade.

O campo de estado deve rejeitar um arquivo de potência com uma mensagem que
indique o campo correto. O campo de potência deve fazer o equivalente para um
arquivo de estado.

### Validação conjunta

Depois das validações individuais, o servidor deverá verificar:

- mesmo cliente, unidade, câmara e gerador;
- exatamente um controlador de cada papel;
- compatibilidade das vigências com os períodos de seus arquivos;
- existência de interseção temporal entre os períodos importados;
- classificação da cobertura de potência em relação ao período de estado.

Os períodos não precisam possuir primeiro e último instantes idênticos. A
telemetria pode começar antes ou terminar depois dos eventos de estado.

Cobertura parcial gera `ready_with_warning` e mostra a parte do período sem
cobertura. Ausência total de interseção bloqueia a confirmação conjunta, pois os
arquivos não representam a mesma atualização operacional.

A confirmação de um aviso deve exigir uma ação explícita do Master. O aviso não
pode ser interpretado como falha do equipamento ou ausência de aplicação.

## Prévia

A prévia será dividida em três áreas:

1. resumo do arquivo de estado;
2. resumo do arquivo de potência;
3. compatibilidade da sessão.

O resumo de estado mantém:

- linhas válidas;
- duplicatas existentes e repetições internas;
- origens desconhecidas;
- primeiro e último eventos;
- amostra normalizada.

O resumo de potência mantém:

- dispositivo;
- linhas válidas, duplicadas e repetidas;
- primeiro e último horários;
- potência mínima e máxima;
- classificações ligada, desligada e histerese;
- amostra normalizada.

O resumo conjunto mostra:

- contexto selecionado;
- controladores de cada papel;
- períodos lado a lado;
- interseção e eventuais lacunas de cobertura;
- estado de prontidão da sessão;
- indicação de arquivo já confirmado e reutilizado, quando aplicável.

Nenhuma prévia persiste eventos, leituras, aplicações ou estados públicos.

## Confirmação conjunta

### Atomicidade

A ação `Confirmar atualização` deverá formar uma única transação de banco para
os dados ainda não confirmados.

Na mesma transação, o sistema deverá:

1. validar ator, contexto, papéis, hashes e vigências;
2. criar ou localizar o lote de estado idempotente;
3. criar ou localizar o lote de potência idempotente;
4. inserir somente eventos e leituras ainda inexistentes;
5. associar os dois lotes à sessão;
6. executar uma única reconstrução completa do gerador;
7. marcar a sessão como confirmada;
8. registrar auditoria.

Se qualquer dado novo falhar, nenhum lote novo, evento, leitura, associação ou
estado derivado dessa confirmação poderá permanecer parcialmente confirmado.

Um lote já confirmado antes da sessão não será removido nem revertido em caso
de falha; ele apenas não receberá a nova associação.

Depois do rollback, uma operação separada e validada para o Master deverá
registrar a tentativa malsucedida e sua auditoria, sem recriar os dados técnicos
que falharam e sem incluir conteúdo bruto dos arquivos.

### Reutilização de lotes existentes

Se um dos hashes já tiver sido confirmado no mesmo contexto e controlador, a
sessão poderá reutilizar esse lote e confirmar somente a fonte faltante.

Se os dois lotes já existirem separadamente, a confirmação poderá apenas criar
o agrupamento, validar sua compatibilidade e reprocessar de forma idempotente.

Reapresentar o mesmo par deverá retornar a sessão confirmada existente ou criar
um agrupamento equivalente sem duplicar dados técnicos.

### Ordem das fontes

Estado e potência podem ser selecionados ou validados em qualquer ordem. A
publicação da nova sessão ocorrerá somente depois da confirmação conjunta.

## Modelo conceitual de dados

### Nova entidade `import_sessions`

A sessão deverá preservar, no mínimo:

- identificador;
- cliente, unidade, câmara e gerador;
- lote de estado;
- lote de potência;
- estado da sessão;
- indicação de aviso de cobertura, quando aplicável;
- mensagem administrativa de falha;
- autor;
- criação e confirmação;
- período de estado, período de potência e interseção calculada.

Os lotes continuam sendo a fonte de verdade para arquivo, hash, controlador,
totais e período. A sessão não deve duplicar esses valores sem necessidade,
exceto quando um resumo imutável for indispensável para auditoria de falha.

Os campos de lote podem permanecer nulos enquanto uma falha está sendo
registrada. Uma sessão `confirmed` exige exatamente um lote `state_events` e um
lote `power_readings`, ambos confirmados e pertencentes ao mesmo contexto.

### Relacionamento com `import_batches`

Um lote existente poderá participar de mais de uma tentativa idempotente ou
agrupamento posterior. A modelagem não deve exigir a duplicação de um lote para
associá-lo a uma sessão.

A implementação pode usar referências `state_batch_id` e `power_batch_id` em
`import_sessions` ou uma tabela de associação equivalente, desde que garanta:

- no máximo um lote por papel em cada sessão;
- compatibilidade imutável entre lote, papel e contexto;
- preservação dos lotes legados;
- consulta eficiente do histórico conjunto.

### Reprocessamento

Uma confirmação conjunta deve reprocessar o gerador apenas depois que as duas
fontes novas estiverem persistidas. Triggers ou funções existentes não devem
publicar um estado intermediário entre a confirmação do primeiro e do segundo
lote.

O resultado final continua reconstruível a partir de `raw_events`,
`power_readings`, controladores, configurações e mapeamentos.

## Histórico administrativo

O histórico principal deverá exibir uma linha por sessão, com:

- data e responsável;
- contexto até o gerador;
- estado conjunto;
- arquivo e período de estado;
- arquivo e período de potência;
- indicação de cobertura completa, parcial ou incompatível;
- resultado agregado.

Ao abrir a sessão, o Master poderá consultar separadamente os detalhes técnicos
dos dois lotes.

Lotes anteriores a esta evolução permanecem no histórico. Eles poderão aparecer
em uma seção `Importações individuais anteriores` ou com o rótulo `Sem sessão
conjunta`. A migração não deverá inferir pares históricos automaticamente apenas
por proximidade de datas.

## Portal do cliente

A interface do cliente não exibirá sessões, nomes de arquivos, controladores,
períodos técnicos ou estado de cada campo.

Para sessões novas:

- nenhuma publicação parcial deve ocorrer durante a confirmação;
- após o sucesso, o reprocessamento atualiza somente os estados sanitizados;
- em caso de falha, o último estado confirmado permanece disponível;
- a linguagem de evidência continua obedecendo à spec 10.

## Segurança e autorização

- Somente Master ativo pode validar, confirmar ou consultar sessões.
- `anon` e usuários de cliente não recebem acesso a `import_sessions`.
- Toda tabela criada em schema exposto deve possuir RLS e privilégios explícitos.
- Funções privilegiadas devem permanecer em schema não exposto; funções públicas
  indispensáveis devem validar o ator e usar o menor privilégio necessário.
- Os dois objetos temporários no Storage permanecem privados e isolados pelo
  identificador do Master.
- Prévia, sucesso, erro ou abandono do fluxo devem remover os objetos temporários.
- Conteúdo bruto dos arquivos não deve ser incluído em logs ou auditoria.
- A auditoria registra sessão, lotes, hashes, contexto, autor e resultado, sem
  armazenar o binário do XLSX.

## Compatibilidade e evolução

- `import_batches`, `raw_events` e `power_readings` mantêm seus contratos atuais.
- As funções individuais existentes não serão removidas na mesma migration que
  introduzir a confirmação conjunta.
- O novo fluxo administrativo passa a usar a operação conjunta depois que os
  testes de compatibilidade forem aprovados.
- Dados legados não serão reescritos, apagados ou pareados automaticamente.
- Reprocessar sessões antigas ou novas deve produzir o mesmo resultado derivado
  para as mesmas fontes e configurações.

## Fora do escopo

- alterar os formatos dos dois XLSX;
- mesclar fisicamente os arquivos;
- persistir permanentemente o binário enviado;
- criar correspondência linha a linha entre as duas planilhas;
- alterar a definição de aplicação da spec 10;
- determinar concentração, vazão ou quantidade produzida de ozônio;
- medir permanência dentro de uma faixa durante toda a aplicação;
- definir limite máximo de potência;
- permitir importação por usuários de cliente;
- importar mais de um gerador na mesma sessão.

A avaliação pontual da potência mínima e a linguagem qualitativa do portal são
definidas pela spec 12. Limite máximo, permanência dentro de uma faixa e
percentual aceitável ao longo da aplicação permanecem fora do escopo.

## Critérios de aceite funcionais

### Interface

- Após selecionar um gerador, os dois campos aparecem simultaneamente.
- Cada campo identifica seu papel e seu controlador sem depender de cor.
- O Master consegue reconhecer qual fonte falta sem abrir outra tela.
- A última confirmação de cada fonte vem de dados persistidos.
- Alterar um arquivo invalida somente a prévia correspondente.
- Erros permanecem associados ao campo que os originou.
- O botão de confirmação não é habilitado com uma fonte ausente ou inválida.
- Desktop, tablet e smartphone preservam a distinção entre os dois campos.

### Validação

- Arquivo no campo incorreto é rejeitado com orientação específica.
- Os dois parsers atuais continuam funcionando sem regressão.
- Controladores ativos e históricos respeitam papel e vigência.
- Períodos sobrepostos são aceitos mesmo sem bordas idênticas.
- Cobertura parcial exige ciência explícita do Master.
- Períodos sem interseção não podem compor a mesma sessão.
- Hash já confirmado é exibido como `Já importado`.

### Confirmação e dados

- Uma confirmação nova cria uma sessão com exatamente dois lotes compatíveis.
- Falha na segunda fonte não deixa a primeira fonte nova confirmada isoladamente.
- Um lote existente pode ser reutilizado sem duplicação.
- O reprocessamento ocorre com as duas fontes disponíveis e sem publicação
  intermediária.
- O mesmo par pode ser reapresentado sem duplicar sessão, lote, evento ou leitura.
- Arquivos parcialmente sobrepostos inserem somente fingerprints novas.
- O histórico agrupa os dois arquivos e preserva acesso aos detalhes individuais.
- Lotes legados continuam consultáveis sem associação inventada.

### Segurança

- Master ativo completa o fluxo.
- Usuários de cliente e `anon` não consultam sessões ou lotes.
- O cliente recebe somente `client_daily_status` sanitizado.
- Objetos temporários dos dois arquivos são removidos.
- Falha e sucesso produzem auditoria sem conteúdo bruto.

## Estratégia obrigatória de testes

### Unidade e componentes

- estados individuais e agregado da sessão;
- invalidação independente das prévias;
- arquivo de estado no campo de potência e vice-versa;
- apresentação de ativo, histórico e vigência;
- responsividade e acessibilidade dos dois campos;
- mensagens de arquivo faltante, inválido e já importado.

### Parser e servidor

- validação independente em qualquer ordem;
- comparação de períodos e classificação da cobertura;
- hash alterado entre prévia e confirmação;
- um arquivo válido e outro inválido;
- um arquivo novo e outro já confirmado;
- dois arquivos já confirmados;
- remoção dos dois objetos temporários em sucesso e falha.

### Banco

- atomicidade com falha em cada etapa da confirmação;
- integridade entre sessão, lotes, papéis e contexto;
- idempotência do mesmo par e de sobreposições parciais;
- reprocessamento único depois das duas fontes;
- ausência de estado público intermediário;
- RLS e privilégios com Master, `anon` e dois clientes;
- auditoria de sucesso e falha;
- preservação de lotes sem sessão.

### Ponta a ponta

1. Master seleciona o contexto e visualiza os dois campos.
2. Master envia os arquivos em qualquer ordem.
3. O sistema mostra as duas prévias e a compatibilidade temporal.
4. Master confirma uma única atualização.
5. O histórico exibe uma sessão com dois lotes.
6. O cliente correto consulta o resultado sanitizado.
7. Outro cliente não acessa sessão, lotes ou dados técnicos.
8. Repetir o par não duplica dados nem altera o resultado final.

## Definição de pronto para desenvolvimento

O desenvolvimento pode começar quando:

- esta spec for aprovada;
- os rótulos dos dois campos e estados forem aprovados;
- a regra de cobertura parcial como aviso for confirmada;
- os arquivos reais de estado e potência forem incluídos nos testes locais;
- a estratégia de associação entre sessão e lotes for escolhida;
- a operação conjunta preservar todos os contratos e testes da spec 10.
