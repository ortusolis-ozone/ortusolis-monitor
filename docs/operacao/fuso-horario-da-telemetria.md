# Fuso horário da telemetria

No cadastro **Locais e unidades**, configure uma vez o **Horário dos arquivos de
telemetria** de cada local:

- **UTC**: por exemplo, `23:00` no arquivo corresponde a `20:00` em Fortaleza.
- **Horário da unidade**: o arquivo já mostra o horário local correto, interpretado
  no **Fuso IANA** cadastrado para a unidade.

Confira um evento conhecido nas duas fontes. O sistema não detecta o fuso
automaticamente. Locais antigos começam sem essa preferência: configure-a antes
de validar potência. Novas unidades exigem a escolha no cadastro.

Na tela **Importações**, o bloco **Potência consumida** aplica a configuração do
local e mostra o fuso utilizado. O arquivo de liga/desliga continua usando o fuso
da unidade. A correlação compara instantes normalizados, sem aplicar uma segunda
correção fixa de horas.

## Exceção para um arquivo

Selecione o XLSX e use **Alterar para este arquivo** quando uma exportação tiver
outra referência temporal. Escolha UTC, o fuso da unidade ou America/Fortaleza
para arquivos históricos. A exceção não altera o cadastro. **Usar configuração
do local** remove a exceção.

Trocar o arquivo de potência, controlador ou hierarquia elimina a exceção.
Falhas ao validar o mesmo arquivo a preservam. Uma nova importação após a
confirmação volta à preferência do local.

Após validar, confira os períodos original e convertido e a origem da escolha.
Clique em **Projetar avaliação operacional** e depois confirme a atualização.
Alterar a escolha temporal exige validar novamente potência e recalcular a
projeção. Se o fuso da unidade mudar, valide também liga/desliga. Uma mudança no
cadastro após a prévia bloqueia a confirmação; atualize a tela e valide novamente.

## Correção de importações anteriores

Alterar o cadastro afeta as próximas importações; não corrige lotes antigos
sozinho. Para corrigir uma importação, selecione novamente os arquivos e use o
fuso correto da potência, herdado ou como exceção. O sistema reaproveita o lote de
liga/desliga quando já existe.

As leituras corrigidas passam a participar da correlação. As interpretações e
sessões anteriores continuam guardadas para auditoria. O histórico mostra o fuso
e se a sessão utilizou o cadastro ou uma alteração para aquele arquivo. Registros
antigos sem essa informação são identificados como legados.

Repetir o arquivo com o mesmo fuso não duplica leituras, mesmo alternando entre
cadastro e exceção. Uma interpretação substituída não pode ser reativada pela
repetição do arquivo antigo: use o fuso registrado na correção. Reverter uma
correção exige um fluxo próprio, fora desta entrega.

Sem interseção entre os períodos convertidos, confira a origem temporal e os
arquivos escolhidos. A potência nominal também precisa estar configurada na
vigência das aplicações; escolher UTC não corrige ausência de perfil nominal.
