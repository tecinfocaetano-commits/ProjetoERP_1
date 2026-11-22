/* ============================================================
   ERP 2026 - Rollback da migracao 024 (marco 3.92)
   Remove somente a tabela e o generator da nota de servico.
   ============================================================ */

SET NAMES UTF8;
SET ECHO ON;

DROP TABLE NOTA_SAIDA_SERVICO;
COMMIT;

DROP GENERATOR GEN_NOTA_SAIDA_SERVICO_ID;
COMMIT;
