/* ============================================================
   ERP 2026 - Rollback da migracao 022 (PAGAMENTO - PDV)

   ATENCAO: remove a tabela PAGAMENTO e o gerador. Cobrancas
   pendentes nao finalizadas serao perdidas. Aplicar somente
   com autorizacao do usuario.
   ============================================================ */

SET NAMES UTF8;
SET ECHO ON;

DROP TRIGGER TRG_PAGAMENTO_BU;
DROP TRIGGER TRG_PAGAMENTO_BI;
DROP TABLE PAGAMENTO;
DROP GENERATOR GEN_PAGAMENTO_ID;
COMMIT;
