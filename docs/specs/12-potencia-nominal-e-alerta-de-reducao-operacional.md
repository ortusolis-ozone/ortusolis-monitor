# Spec 12 — Potência nominal e alerta de redução operacional

**Status:** proposta para aprovação.

**Tipo:** evolução da configuração do gerador, da avaliação de telemetria e da
apresentação sanitizada ao cliente.

**Dependências:** specs 02, 03, 04, 06, 07, 08, 09, 10 e 11.

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
