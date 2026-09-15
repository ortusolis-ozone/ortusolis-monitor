# Fuso horário da telemetria

Na tela **Importações**, escolha o fuso dos horários da coluna `Event Time` no
bloco **Potência consumida**, antes de validar o XLSX.

- Escolha **UTC** se, por exemplo, `23:00` no arquivo corresponder ao evento
  de `20:00` em Fortaleza.
- Escolha **America/Fortaleza** se o arquivo já mostrar o horário local correto.

Confira um evento conhecido nas duas fontes. A diferença de três horas precisa
ser interpretada no sentido correto; o sistema não detecta o fuso automaticamente.
O arquivo de liga/desliga continua usando o fuso da unidade.

Após validar, confira o período original e os horários convertidos na prévia.
Clique em **Projetar avaliação operacional** e depois confirme a atualização.
Alterar o fuso exige validar novamente a potência e recalcular a projeção.

Para corrigir uma importação antiga, selecione novamente os arquivos e informe
o fuso correto da potência. O sistema reaproveita o lote de liga/desliga quando
ele já existe. As leituras corrigidas passam a participar da correlação; as
interpretações anteriores continuam guardadas para auditoria. O histórico da
sessão mostra o fuso usado no lote de potência.

Repetir o mesmo arquivo com o mesmo fuso não duplica leituras. Uma interpretação
já substituída não pode ser reativada pela repetição do arquivo antigo; use o
fuso registrado na correção. Reverter uma correção requer tratamento específico.

Sem interseção entre os períodos convertidos, confira a origem temporal e os
arquivos escolhidos. A potência nominal também precisa estar configurada na
vigência das aplicações; escolher UTC não corrige ausência de perfil nominal.
