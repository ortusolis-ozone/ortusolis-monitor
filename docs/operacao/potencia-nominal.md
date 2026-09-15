# Operação da potência nominal

A Ortusolis configura e investiga a potência no painel Master. O cliente acompanha
aplicações registradas e, quando necessário, um aviso qualitativo de atenção.

## O que a avaliação significa

- **Energização:** a correlação encontra uma leitura elétrica compatível com o
  evento programado de ligar. Os limites de liga/desliga do controlador e a
  tolerância temporal servem a essa correlação.
- **Consumo abaixo do esperado:** a leitura ligada correlacionada fica abaixo
  de 85% da potência nominal válida no início da aplicação. É uma observação
  pontual, não uma medição de permanência durante toda a aplicação.
- **Geração de ozônio:** não é medida por essa leitura. Potência baixa não prova
  defeito nem ausência de ozônio; potência dentro do esperado não comprova
  concentração, vazão, massa ou eficácia do tratamento.

O percentual de redução é fixo em 15%. Um nominal de 72 W produz mínimo exato
de 61,2 W: 61,200 W está dentro do esperado; 61,199 W está abaixo. O banco usa
aritmética decimal e sempre deriva o mínimo, sem confiar na prévia do navegador.
A leitura de desligamento, inclusive zero watt, não participa dessa comparação.

## Cadastro e vigência

1. Em **Geradores**, informe a potência nominal positiva, com até três casas
   decimais. A prévia de potência mínima é somente para leitura.
2. Configure separadamente os controladores de estado e potência, os limites
   elétricos e a tolerância. Esses limites não substituem a potência nominal.
3. Para mudar o nominal, abra o detalhe do gerador e registre a nova potência e
   seu início de vigência. A interface usa o horário de Fortaleza.
4. Confira o histórico: a vigência anterior termina exatamente quando começa a
   nova. O início é inclusivo; o fim é exclusivo. Períodos não podem se sobrepor.
5. Em caso de conflito ou edição concorrente, atualize o histórico antes de
   tentar novamente. Não sobrescreva valores de perfis usados.

Geradores legados aparecem no filtro **Configuração pendente**. Cadastre um
perfil com início conhecido e justificável antes de importar o período. Não
estime o nominal pela média, máximo ou moda das leituras. Configurar somente a
partir de hoje não dá cobertura retroativa a uma importação antiga.

## Importação conjunta

1. Selecione o contexto e os dois arquivos: eventos de estado e telemetria.
2. Valide os arquivos e solicite **Projetar avaliação operacional**.
3. Confira perfis e vigências utilizados, nominal, mínimo e totais por estado.
   Ausência de perfil no início de uma aplicação bloqueia a confirmação e pede
   completar a configuração. Não significa potência baixa.
4. Quando aplicável, registre ciência da cobertura parcial.
5. Confirme. Os arquivos, hashes e a configuração são revalidados. A prévia e a
   confirmação usam o processamento canônico; a prévia reverte suas alterações.
6. Confira o resumo confirmado. Repetir a mesma importação não duplica lotes,
   aplicações ou inconsistências. Falha não mantém apenas um dos dois lotes.

Uma prévia pode avançar sequências do PostgreSQL sem persistir registros. Lacunas
em identificadores não demonstram perda de dados.

## Investigação de uma aplicação

Em **Geradores → detalhe → aplicação**, consulte correlação e avaliação
operacional separadamente, além dos snapshots, leitura, controladores, arquivos,
lotes, perfil, inconsistências e histórico de reprocessamentos.

| Estado administrativo | Interpretação e próxima ação | Atenção por redução no portal |
| --- | --- | --- |
| Dentro do esperado (`within_expected`) | A leitura ligada atende ao mínimo; não extrapolar para toda a aplicação. | Não |
| Abaixo do esperado (`below_expected`) | Conferir equipamento, nominal, vigências, coleta e correlação. | Sim |
| Não avaliável (`not_evaluable`) | Existe perfil, mas falta leitura ligada válida; conferir cobertura, limites, horário e coleta. | Não |
| Não configurado (`not_configured`) | Falta perfil válido no início; corrigir a configuração histórica com evidência. | Não |

Reconhecer uma inconsistência, escrever uma nota ou reabri-la é acompanhamento
administrativo. Essas ações não normalizam uma leitura baixa. O alerta só deixa
de existir quando dados ou configuração válidos, reprocessados, produzem outro
resultado. Mudanças de perfil reprocessam seu intervalo afetado; mudanças de
controlador e de parâmetros de correlação também reavaliam os dados alcançados.

Quando o resultado muda, a inconsistência é resolvida automaticamente sem apagar
reconhecimento ou comentário. Se a mesma combinação de aplicação, leitura e
perfil voltar a ficar baixa, a inconsistência é reativada, preservando a revisão.

## Auditoria e investigação técnica

As trilhas se complementam e não armazenam cópias das planilhas:

- `audit_logs` registra autor, instante, ação e identificador da entidade.
  Criação/edição de perfis referencia `generator_power_profiles`, onde nominal,
  mínimo, gerador, autor de criação e vigências ficam preservados. O encerramento
  aparece como `updated`; o novo perfil como `created`.
- As transições derivadas geram `power_below_expected_created`,
  `power_below_expected_resolved` e `power_below_expected_reactivated`, apontando
  para a inconsistência e, por ela, para aplicação, leitura e perfil. Revisão e
  reabertura administrativa mantêm seus eventos próprios.
- `private.operational_power_reprocessing_runs` registra intervalo, motivo,
  versão `nominal-power-v1`, data e contagens nos quatro estados. O Master consulta
  as execuções pertinentes pelo diagnóstico; a tabela não é pública.
- Os logs de falha das ações auditadas registram operação e SQLSTATE, sem mensagem
  livre, detalhes de linha, arquivo, token, comentário ou stack. Falhas sem código
  válido usam `unexpected`. Conflitos comuns incluem `23P01` (sobreposição) e
  `40001` (edição concorrente).

Auditoria e reprocessamento participam da mesma transação. Uma falha revertida
não deixa eventos de sucesso nem resultados parciais. Para investigar tentativas
malsucedidas, use os logs de servidor e os registros administrativos de falha de
importação, cuja mensagem é sanitizada. Não envie diagnósticos a analytics do
cliente. Execuções técnicas sem sessão podem registrar autor nulo; não atribua
essas execuções a um usuário por inferência.

## Comunicação ao cliente

Sem redução: **Aplicação registrada**.

Com redução: **Aplicação registrada — atenção necessária**.

> O consumo elétrico registrado ficou abaixo do esperado. A Ortusolis deve
> verificar o equipamento.

Vários resultados baixos do mesmo gerador e dia produzem um sinal qualitativo,
sem contagem. Os demais estados públicos de qualidade/disponibilidade continuam
separados. O cabeçalho indica o último dia publicado, não o horário do último
reprocessamento. O cliente não deve alterar o equipamento em resposta ao aviso.

O portal usa apenas `list_client_application_status`. Perfis, watts, percentuais,
limites, motivos internos e identificadores técnicos não entram em seu contrato.
O caminho antigo `client_daily_status` é restrito ao Master por RLS. Um rollback
de interface não autoriza restaurar o acesso cliente à evidência elétrica.

## Validação e publicação

Use Node.js 22 ou superior. Para validar migrations, use exclusivamente um banco
local descartável e confira as URLs de ambiente: `.env.development.local` tem
precedência sobre `.env.local` em desenvolvimento.

```sh
supabase db reset --local --no-seed
supabase test db
supabase db lint --local --schema public,private
supabase gen types typescript --local --schema public > /tmp/ortusolis-types.ts
diff -u lib/supabase/database.types.ts /tmp/ortusolis-types.ts
npm test
npm run typecheck
npm run lint
npm run build
```

A migração do banco e a versão do portal devem ser publicadas de forma
coordenada. A validação local não significa publicação no Supabase remoto nem
no Vercel. Faça backup do destino antes de aplicar migrations. Nunca execute
`db reset` em um banco de produção.
