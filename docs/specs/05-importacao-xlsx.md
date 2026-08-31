# Spec 05 — Importação XLSX

**Status do MVP original:** concluída.

**Evolução Spec 10:** pendente de implementação.

> **Evolução:** o segundo contrato de XLSX e sua compatibilidade com o papel do controlador são definidos pela [spec 10](./10-duplo-controlador-e-telemetria-de-potencia.md).

## Objetivo

Receber um arquivo eWeLink, validar seu conteúdo, apresentar uma prévia e confirmar os eventos sem duplicidade.

## Fluxo

```text
Selecionar cliente → local → câmara → gerador → controlador
→ escolher XLSX → validar → exibir resumo → confirmar
```

Somente o Master pode executar o fluxo.

## Contrato inicial do arquivo

- Formato `.xlsx`.
- Leitura da primeira aba não vazia.
- Cabeçalhos obrigatórios: `Tempo`, `Operação`, `Acionado por`.
- Espaços e diferenças de maiúsculas/minúsculas dos cabeçalhos podem ser normalizados.
- Operações aceitas após normalização: `Ligar` e `Desligar`.
- Horários do arquivo são interpretados no fuso da unidade e armazenados com fuso.
- O valor original de cada célula relevante deve ser preservado.
- Limites iniciais: 5 MB e 25.000 linhas, configuráveis após validação com arquivos reais.

## Validação e prévia

Bloqueiam a confirmação:

- ausência de coluna obrigatória;
- data ou operação inválida;
- arquivo vazio ou acima dos limites;
- evento fora da vigência do controlador selecionado;
- seleção hierárquica inconsistente.

Origem não mapeada não bloqueia: o evento é classificado como desconhecido e seguirá para revisão.

A prévia informa:

- total de linhas válidas;
- duplicatas já existentes;
- origens desconhecidas;
- primeiro e último horários;
- amostra das primeiras linhas normalizadas.

A prévia é transitória. O navegador mantém o arquivo durante o fluxo; ao confirmar, envia-o novamente e o servidor repete a validação e confere seu hash. Recarregar ou abandonar a página descarta a prévia sem criar dados.

## Confirmação

- Cria um `import_batch` identificado pelo hash do arquivo e contexto.
- Insere os eventos em lotes, usando conflito de fingerprint para ignorar os já existentes.
- Fingerprint: controlador, gerador, instante, operação e origem normalizada.
- Parsing e validação terminam antes da transação no banco.
- A transação contém somente persistência, reprocessamento e atualização do lote.
- Uma falha não pode deixar metade do lote confirmado.

## Estados do lote

- `processing`: confirmação em andamento.
- `confirmed`: eventos persistidos e processados.
- `failed`: falha registrada com mensagem administrativa.

## Critérios de aceite

- O mesmo arquivo pode ser reapresentado sem duplicar eventos.
- Arquivos parcialmente sobrepostos inserem apenas os eventos novos.
- Um arquivo inválido nunca altera registros operacionais.
- A Ortusolis vê um resumo claro antes de confirmar.
- O lote registra autor, momento, contexto e resultado.

## Resultado da implementação

- Foi criada a página administrativa de importações com seleção dependente de cliente, unidade, câmara, gerador e controlador, mostrando apenas combinações ativas e atualmente coerentes.
- O navegador envia o XLSX para um bucket privado temporário. A prévia e a confirmação usam envios independentes, e cada objeto é removido após a leitura.
- O parser lê a primeira aba preenchida, normaliza os três cabeçalhos obrigatórios, aceita somente `Ligar` e `Desligar`, preserva os valores originais e interpreta as datas no fuso da unidade.
- Arquivos vazios, inválidos, maiores que 5 MB, com mais de 25.000 eventos ou com registros fora da vigência do controlador são rejeitados antes de qualquer persistência.
- A prévia exibe quantidade válida, eventos já existentes, repetições internas, origens desconhecidas, período e amostra normalizada. Alterar o arquivo ou qualquer item da hierarquia invalida a prévia.
- A confirmação repete toda a validação, confere o SHA-256 e executa a persistência em uma transação PostgreSQL. A restrição única de fingerprint ignora sobreposições sem duplicar eventos.
- O lote registra contexto, autor, status, totais e período. Confirmações e falhas administrativas geram auditoria, e uma falha transacional não deixa eventos parciais.
- RLS restringe lotes, eventos brutos, mapeamentos e o bucket temporário ao Master ativo. Os objetos de Storage ficam isolados pelo identificador do próprio usuário.
- Testes SQL transacionais cobrem confirmação, reimportação idempotente, sobreposição parcial, hierarquia e vigência inválidas, falha registrada, auditoria e isolamento de usuários de cliente.
