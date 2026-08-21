# Spec 06 — Processamento e estados

## Objetivo

Transformar eventos confirmados em aplicações, inconsistências e estados públicos sem revelar a metodologia.

## Preparação

Para um gerador:

1. Carregar eventos confirmados.
2. Ordenar por horário e, em caso de empate, por identificador estável.
3. Aplicar o mapeamento de origem.
4. Ignorar duplicatas e eventos classificados como teste.
5. Recriar aplicações e inconsistências derivadas.

Reprocessar todo o gerador é a estratégia inicial. Processamento incremental só será considerado se medições mostrarem necessidade.

## Pareamento

- `Ligar` sem evento aberto: abre uma aplicação.
- `Desligar` com evento aberto compatível: conclui a aplicação.
- `Desligar` sem `Ligar`: cria inconsistência.
- Novo `Ligar` com outro aberto: cria inconsistência para o anterior e passa a considerar o mais recente como aberto.
- `Ligar` restante ao final: cria inconsistência aberta.
- Eventos de origem desconhecida: criam inconsistência e não participam do pareamento.
- Troca de controlador entre `Ligar` e `Desligar`: cria inconsistência; eventos de controladores diferentes não formam aplicação.

Um `Desligar` recebido em importação posterior pode concluir um `Ligar` anterior. Nesse caso, a inconsistência aberta correspondente é resolvida automaticamente durante o reprocessamento.

## Data pública

- A aplicação pertence à data local do evento `Ligar`.
- A inconsistência pertence à data local do evento que a originou.
- A última atualização do gerador é o maior horário de evento confirmado.

## Cálculo do estado diário

Para cada gerador e data:

```text
inconsistência pendente?        → Verificação necessária
senão, aplicação concluída?    → Concluído
senão, data já importada?      → Sem dados
senão                           → Aguardando atualização
```

Revisar uma inconsistência remove sua precedência, mas não cria uma aplicação. Se não houver aplicação válida, o resultado passa a `Sem dados`.

## Publicação sanitizada

`client_daily_status` pode conter somente:

- identificadores da hierarquia autorizada;
- data;
- estado público;
- instante da última atualização.

Não pode conter quantidade de aplicações, eventos, horários, duração, origem ou parâmetros internos.

## Critérios de aceite

- Pares completos, incompletos, invertidos, duplicados e intercalados com testes possuem testes automatizados.
- Importações em ordens diferentes produzem o mesmo resultado final.
- Reprocessar sem novos eventos é idempotente.
- Nenhum dado técnico é copiado para a tabela pública.
- Uma inconsistência resolvida por evento posterior deixa de aparecer como pendente.
