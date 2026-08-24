# Spec 04 — Cadastros operacionais

**Status:** concluída.

## Objetivo

Permitir que a Ortusolis configure a estrutura necessária para associar corretamente cada importação.

## Sequência dos cadastros

1. Cliente.
2. Local/unidade.
3. Câmara fria.
4. Gerador e sua alocação.
5. Controlador vinculado ao gerador.
6. Usuário vinculado ao cliente.

## Funcionalidades

- Listar, criar, editar e ativar/inativar cada cadastro.
- Navegar pela hierarquia do cliente.
- Buscar clientes por nome ou CNPJ.
- Filtrar cadastros por status.
- Realocar um gerador informando a data efetiva.
- Substituir um controlador informando a data de ativação do novo.
- Bloquear exclusões físicas e relações incompatíveis entre clientes.

## Validações

- Campos mínimos do PRD são obrigatórios.
- CNPJ é normalizado e validado antes de persistir.
- Categoria de câmara usa a lista definida no PRD, incluindo `outros`.
- Não pode haver duas alocações ativas do mesmo gerador.
- Não pode haver dois controladores ativos simultaneamente no mesmo gerador.
- Datas de vigência não podem gerar sobreposição.
- Um cadastro com histórico pode ser inativado, não excluído.

## Interface mínima

- Uma listagem por tipo de cadastro.
- Formulários simples em página ou diálogo.
- Página de detalhe do cliente exibindo sua hierarquia.
- Confirmação explícita para inativação, realocação e substituição.
- Mensagens de erro no campo correspondente.

## Critérios de aceite

- O Master consegue montar toda a hierarquia de um cliente.
- O sistema preserva onde o gerador estava e qual controlador utilizava em uma data anterior.
- Apenas combinações ativas e coerentes aparecem no fluxo de importação.
- Toda alteração relevante gera registro de auditoria.

## Resultado da implementação

- Foram criadas listagens com criação, edição, filtro por status e ativação/inativação para clientes, unidades, câmaras, geradores, controladores e usuários.
- A listagem de clientes permite busca por razão social ou CNPJ normalizado, e a página de detalhe apresenta a hierarquia atual com os históricos de alocação e controlador.
- CNPJ é normalizado e validado pelo algoritmo dos dígitos verificadores antes da persistência; categorias de câmara usam somente a lista do PRD.
- Geradores são criados junto da primeira alocação. Realocação fecha a vigência atual e abre a próxima de forma atômica no banco.
- Substituição de controlador encerra o anterior e cria o novo na mesma transação, com datas interpretadas no fuso da unidade.
- RLS permite mutações somente ao Master. Usuários de cliente continuam sem mutações e sem leitura das vigências técnicas.
- Triggers atualizam `updated_at`, auditam criação, edição e mudança de status e bloqueiam exclusões físicas inclusive quando o cadastro ainda não possui histórico.
- O convite de usuário usa a API administrativa exclusivamente no servidor; o perfil e o vínculo ao cliente são persistidos pelo contexto autenticado do Master.
- Testes transacionais cobrem isolamento, relações entre clientes, sobreposição, histórico, auditoria e bloqueio de exclusão.
