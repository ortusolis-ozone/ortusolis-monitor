# PRD — Ortusolis Monitor MVP

## 1. Visão do produto

O **Ortusolis Monitor** é um webapp B2B para clientes da Ortusolis acompanharem os registros das aplicações de ozônio realizadas em suas câmaras frias.

O sistema transforma registros técnicos exportados do eWeLink em informações simples sobre a realização das aplicações, preservando a metodologia operacional da Ortusolis.

O MVP **não controla os geradores** e **não possui dados em tempo real**.

---

## 2. Objetivos do MVP

- Centralizar os registros dos geradores instalados nos clientes.
- Permitir que a Ortusolis importe e acompanhe os registros operacionais.
- Permitir que cada cliente consulte exclusivamente suas próprias instalações.
- Informar a realização das aplicações sem revelar ciclos, horários ou duração.
- Identificar inconsistências nos registros.
- Diferenciar aplicações programadas de acionamentos realizados para testes.
- Reforçar a presença da marca Ortusolis junto ao cliente.

---

## 3. Perfis de usuário

### Administrador Master — Ortusolis

Pode:

- acessar todos os clientes;
- cadastrar e editar clientes;
- cadastrar locais/unidades;
- cadastrar câmaras frias;
- cadastrar geradores;
- cadastrar e substituir controladores;
- importar registros XLSX;
- consultar registros operacionais;
- visualizar e revisar inconsistências.

### Administrador do Cliente

Pode consultar todas as unidades, câmaras e informações disponibilizadas para sua empresa.

### Operador

Pode consultar as instalações e informações autorizadas da própria empresa.

### Visualizador

Possui acesso somente para consulta.

No MVP, os três perfis de cliente podem compartilhar inicialmente a mesma experiência de consulta, mantendo a estrutura de permissões preparada para diferenciação futura.

---

## 4. Estrutura funcional

```text
Cliente
└── Local / Unidade
    └── Câmara fria
        └── Gerador
            └── Controlador
```

### Cliente

Dados mínimos:

- razão social/nome;
- CNPJ;
- status ativo/inativo.

### Local / Unidade

- nome;
- cliente;
- identificação/localização;
- status.

### Câmara fria

- nome/identificação;
- local;
- categoria de produto armazenado;
- status.

Categorias iniciais:

- FLV;
- bovinos;
- suínos;
- aves;
- pescados;
- outros.

### Gerador

- identificação;
- câmara;
- status;
- controlador atual.

O histórico deverá ser preservado caso o gerador seja desativado ou realocado.

### Controlador

- identificação;
- gerador;
- data de ativação;
- data de desativação;
- status.

A substituição do controlador não cria um novo gerador.

---

## 5. Autenticação

O sistema deverá oferecer:

- login por e-mail;
- senha;
- OTP por e-mail para ativação/autenticação quando aplicável;
- recuperação de senha;
- gerenciamento seguro da sessão.

O CNPJ identifica a empresa à qual os usuários pertencem, mas cada usuário possui autenticação individual.

Nenhum usuário de cliente poderá acessar dados pertencentes a outro cliente.

---

## 6. Importação dos registros

A importação será realizada exclusivamente pelo Administrador Master.

Fluxo:

```text
Selecionar cliente
→ local
→ câmara
→ gerador
→ selecionar XLSX
→ validar
→ visualizar resultado
→ confirmar importação
```

O arquivo esperado contém:

```text
Tempo | Operação | Acionado por
```

O sistema deverá:

- validar estrutura do arquivo;
- normalizar data e hora;
- reconhecer `Ligar` e `Desligar`;
- preservar a origem indicada em `Acionado por`;
- evitar eventos duplicados;
- processar sequências;
- identificar inconsistências;
- informar o resultado da importação.

---

## 7. Classificação dos eventos

Os eventos serão classificados internamente como:

- `programado`;
- `teste`;
- `desconhecido`.

O valor original de **Acionado por** deverá ser preservado.

O mapeamento dos valores do eWeLink para essas categorias deverá ser configurável pela Ortusolis.

### Regra principal

**Eventos classificados como teste não contam como aplicação.**

Eles podem permanecer disponíveis internamente para auditoria, mas não podem:

- contribuir para conclusão da aplicação;
- alterar indicadores do cliente;
- completar ciclos da rotina programada.

Origem desconhecida deverá ser tratada como pendência quando não puder ser classificada com segurança.

---

## 8. Processamento dos registros

O sistema trabalhará conceitualmente com:

```text
raw_events
open_event
consolidated_cycles
client_daily_status
```

### raw_events

Eventos normalizados provenientes das importações.

### open_event

Mantém temporariamente um `Ligar` programado ainda sem `Desligar` correspondente.

### consolidated_cycles

Representa sequências reconciliadas e inconsistências operacionais.

### client_daily_status

Contém exclusivamente a informação sanitizada que pode ser acessada pelo cliente.

---

## 9. Continuidade e inconsistências

As importações sucessivas deverão ser tratadas como uma sequência contínua por gerador.

Exemplo:

```text
Importação A
Ligar

Importação B
Desligar
```

O sistema deverá conseguir reconciliar esses eventos.

Devem ser identificados casos como:

- `Ligar` sem `Desligar`;
- `Desligar` sem `Ligar`;
- sequência inválida;
- evento aberto além do limite permitido;
- origem não reconhecida.

O sistema nunca deverá criar horários ou durações inexistentes.

Uma inconsistência de registro **não significa automaticamente falha do gerador ou ausência de aplicação**.

---

## 10. Revisão administrativa

Inconsistências deverão aparecer no painel administrativo.

Estados:

```text
Pendente de revisão
Revisado
```

O administrador poderá:

- consultar a ocorrência;
- visualizar os dados técnicos relacionados;
- adicionar observação interna;
- marcar como revisada.

O dashboard administrativo deverá indicar a quantidade de pendências existentes.

---

## 11. Dashboard do cliente

O cliente poderá navegar por:

```text
Empresa
→ Local
→ Câmara
→ Gerador
```

A visão deverá apresentar:

- situação das aplicações;
- histórico diário;
- última atualização dos registros;
- visão consolidada das unidades;
- visão individual por local/câmara;
- estados públicos das aplicações.

Exemplo de comunicação:

> **Ortusolis cuidando da sua câmara fria**
>
> Acompanhe os registros das aplicações de ozônio realizadas na sua instalação.

---

## 12. Estados públicos

Estados mínimos:

### Concluído

Os registros processados são compatíveis com a aplicação esperada.

### Verificação necessária

Foi identificada uma inconsistência nos registros.

A interface deverá deixar claro que isso não significa necessariamente falha do equipamento.

### Sem dados

Não existem registros suficientes para determinar a situação.

### Aguardando atualização

O período ainda não está contemplado pela última importação.

Como a importação ocorre aproximadamente a cada três dias, o dashboard deverá exibir:

> **Registros atualizados até DD/MM/AAAA**

---

## 13. Proteção da metodologia

Usuários dos clientes não poderão acessar:

- quantidade de ciclos;
- horários;
- duração;
- tempo total de funcionamento;
- programação;
- eventos ON/OFF;
- parâmetros internos da aplicação.

Esses dados não deverão ser apenas escondidos na interface.

O acesso do cliente será feito por uma estrutura sanitizada, como `client_daily_status`, sem os campos sensíveis.

As políticas de acesso deverão impedir consultas às tabelas operacionais.

---

## 14. Histórico

O cliente deverá conseguir consultar o histórico de aplicações já processadas.

Filtros mínimos:

- período;
- local;
- câmara;
- gerador.

O histórico exibirá somente os estados públicos.

A Ortusolis poderá acessar informações operacionais mais detalhadas.

---

## 15. API

O sistema deverá ser arquitetado para disponibilizar API REST autenticada para integrações autorizadas.

O MVP deverá preservar separação entre:

- dados públicos do cliente;
- dados operacionais da Ortusolis.

A API deverá respeitar essas mesmas permissões.

Integrações de BI e documentação pública/privada completa da API podem ser implementadas após as funcionalidades principais do MVP.

---

## 16. Segurança e privacidade

O sistema deverá utilizar:

- HTTPS;
- autenticação segura;
- autorização por perfil;
- RLS para isolamento entre clientes;
- proteção dos dados operacionais;
- registro das principais ações administrativas;
- políticas adequadas de backup e retenção.

Dados pessoais deverão ser limitados ao necessário para funcionamento do serviço e tratados de acordo com os requisitos aplicáveis da LGPD.

---

## 17. Interface

A aplicação deverá ser responsiva para:

- desktop;
- tablet;
- smartphone.

Prioridades de UX:

- leitura rápida da situação das câmaras;
- navegação simples entre unidades;
- clareza sobre a última atualização;
- distinção clara entre situação normal, ausência de dados e registros em verificação;
- presença consistente da identidade Ortusolis.

---

## 18. Stack

```text
Next.js + TypeScript
Tailwind CSS
shadcn/ui

Supabase
PostgreSQL
Supabase Auth
RLS

Vercel
GitHub
Codex
```

---

## 19. Fora do escopo

O MVP não realizará:

- acionamento remoto;
- desligamento remoto;
- programação de Sonoff;
- controle de potência;
- controle da geração de ozônio;
- monitoramento em tempo real;
- substituição do eWeLink;
- automação dos equipamentos.

---

## 20. Critérios de sucesso do MVP

O MVP estará funcional quando:

1. A Ortusolis conseguir cadastrar a estrutura de um cliente até seus geradores/controladores.
2. Um XLSX válido do eWeLink puder ser importado e processado.
3. Importações sobrepostas não gerarem duplicidade.
4. Acionamentos de teste forem identificados e excluídos das aplicações.
5. Sequências incompletas puderem ser reconciliadas entre importações ou sinalizadas para revisão.
6. A Ortusolis conseguir consultar e revisar inconsistências.
7. O cliente conseguir acessar suas unidades e visualizar o histórico sanitizado.
8. Nenhum cliente conseguir acessar dados de outra empresa.
9. Nenhum cliente conseguir obter os parâmetros protegidos da metodologia.
10. A interface deixar claro que os dados não são apresentados em tempo real.
