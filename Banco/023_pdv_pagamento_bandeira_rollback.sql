/* Rollback da migracao 023 - remove BANDEIRA de PAGAMENTO.
   Somente metadado: nenhuma venda e afetada. */
SET NAMES UTF8;
SET ECHO ON;
ALTER TABLE PAGAMENTO DROP BANDEIRA;
COMMIT;
