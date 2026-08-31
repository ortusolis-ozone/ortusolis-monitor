# Spec 09 — Qualidade e entrega

**Status do MVP original:** pendente de conclusão.

**Evolução Spec 10:** pendente de implementação.

> **Evolução:** os testes adicionais obrigatórios para duplo controlador e telemetria são definidos pela [spec 10](./10-duplo-controlador-e-telemetria-de-potencia.md).

## Objetivo

Definir a verificação mínima para liberar o MVP com segurança.

## Estratégia de testes

### Unitários

- Normalização de colunas, datas, operações e origens.
- Fingerprint e detecção de duplicidade.
- Máquina de pareamento dos eventos.
- Cálculo dos estados e precedência.
- Conversão para a data local da unidade.

### Integração

- Confirmação atômica de importação.
- Reprocessamento e reconstrução dos derivados.
- Troca de controlador e realocação de gerador.
- Políticas RLS com Master e pelo menos dois clientes.
- Revisão e reabertura de inconsistência.

### Ponta a ponta

1. Master cria a hierarquia.
2. Master importa e confirma um XLSX.
3. O processamento cria aplicação e estado sanitizado.
4. Cliente correto consulta o resultado.
5. Outro cliente não consegue acessar o resultado.

## Casos obrigatórios do processamento

- Par `Ligar → Desligar` no mesmo arquivo.
- Par dividido entre dois arquivos.
- Arquivos sobrepostos.
- Apenas eventos de teste.
- Origem desconhecida.
- `Ligar` sem `Desligar`.
- `Desligar` sem `Ligar`.
- Dois `Ligar` consecutivos.
- Eventos fora de ordem no XLSX.
- Aplicação atravessando meia-noite.

## Requisitos operacionais mínimos

- Logs de falhas de autenticação, importação e processamento sem conteúdo sensível desnecessário.
- Backup gerenciado do banco conforme o plano contratado antes da produção.
- Ambientes separados para desenvolvimento e produção.
- Runtime Node.js 22 ou superior, compatível com os SDKs atuais utilizados.
- Variáveis secretas fora do repositório.
- Migrações versionadas e aplicadas antes da aplicação.
- Página de erro recuperável para falhas operacionais.

## Checklist de liberação

- Todos os critérios das specs anteriores atendidos.
- Build, lint e suíte de testes aprovados.
- Testes negativos de RLS aprovados.
- Arquivos reais de exemplo validados pela Ortusolis.
- Textos dos estados aprovados pela área responsável.
- Usuário Master inicial criado por procedimento seguro.
- Política de backup e retenção registrada.
- Smoke test realizado no ambiente de produção.

## Não bloqueiam o MVP

- API pública.
- Dashboards analíticos avançados.
- Filas e processamento assíncrono distribuído.
- Cache de aplicação.
- Permissões distintas entre perfis do cliente.
- Exportação de relatórios.
