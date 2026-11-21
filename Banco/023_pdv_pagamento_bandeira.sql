/* ============================================================
   ERP 2026 - Migracao 023
   PDV Pagamentos - bandeira do cartao (VISA/MASTERCARD/ELO/...

   Metadado para conciliacao/relatorio. O PAN nunca e armazenado
   (PCI-DSS): a bandeira vem do provedor/adquirente ou da escolha
   do operador quando a forma e CARTAO.

   Execucao unica:
     isql -u SYSDBA -p masterkey -charset UTF8 Banco\DADOS.FDB -i Banco\023_pdv_pagamento_bandeira.sql
   Reverter:
     ALTER TABLE PAGAMENTO DROP BANDEIRA; (manual)
   ============================================================ */

SET NAMES UTF8;
SET ECHO ON;

ALTER TABLE PAGAMENTO ADD BANDEIRA VARCHAR(20);
COMMIT;
