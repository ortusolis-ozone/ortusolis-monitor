# Spec 00 — Regras e escopo do MVP

**Status:** concluída.

## Objetivo

Fixar as decisões que todas as demais specs devem respeitar.

## Regra de aplicação

Uma aplicação é concluída quando existe um evento `Ligar` programado seguido por um evento `Desligar` programado para o mesmo gerador, em ordem cronológica.

- Eventos de teste são preservados para auditoria, mas ignorados no cálculo.
- Eventos de origem desconhecida geram uma inconsistência.
- O pareamento continua entre importações diferentes.
- O sistema não avalia programação esperada, quantidade de ciclos ou duração.
- `Concluído` significa apenas: **há registro completo de aplicação**.
- O sistema nunca inventa evento, horário ou duração.

## Estados públicos diários

Precedência para cada gerador e data:

1. `Verificação necessária`: existe inconsistência pendente.
2. `Concluído`: existe ao menos uma aplicação completa e nenhuma inconsistência pendente.
3. `Sem dados`: o período já foi alcançado pelas importações, mas não existe aplicação completa.
4. `Aguardando atualização`: a data é posterior à última data importada para o gerador.

Uma inconsistência revisada deixa de prevalecer sobre uma aplicação válida, mas a revisão não cria nem completa uma aplicação.

## Escopo do MVP

- Cadastros de clientes, unidades, câmaras, geradores e controladores.
- Autenticação individual e isolamento por cliente.
- Importação administrativa de XLSX.
- Classificação de eventos como programado, teste ou desconhecido.
- Consolidação de aplicações e inconsistências.
- Revisão administrativa.
- Dashboard e histórico sanitizados para o cliente.

## Fora do escopo

- Controle ou programação dos equipamentos.
- Dados em tempo real.
- Validação de duração ou cumprimento de uma agenda esperada.
- API pública para terceiros.
- Gestão de usuários pelo próprio cliente.
- Permissões diferentes entre os três perfis de cliente.
- Correção manual ou criação de eventos operacionais.

## Critérios de aceite

- As definições desta spec aparecem sem contradição nas demais specs.
- Nenhuma tela do cliente promete validar uma programação que o sistema não conhece.
- A comunicação pública diferencia registro concluído de garantia de funcionamento do equipamento.
