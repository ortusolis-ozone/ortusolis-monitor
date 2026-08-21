# Spec 05 — Importação XLSX

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
