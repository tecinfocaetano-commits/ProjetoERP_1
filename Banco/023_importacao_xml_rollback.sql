/* ============================================================
   ERP 2026 - Rollback da migracao 023
   Reverte a tabela IMPORTACAO_XML_ITEM e seu generator.

   ATENCAO: apaga o historico de mapeamento de produtos das notas
   importadas. Os vinculos ja aplicados em NOTA_ENTRADA_ITEM
   (PRODUTO_ID) NAO sao desfeitos.

   Aplicar com:
     isql -u SYSDBA -p masterkey -charset UTF8 Banco\DADOS.FDB -i Banco\023_importacao_xml_rollback.sql
   ============================================================ */

SET NAMES UTF8;
SET ECHO ON;

DROP TRIGGER TRG_IMPORTACAO_XML_ITEM_BI;
COMMIT;

DROP TABLE IMPORTACAO_XML_ITEM;
COMMIT;

DROP GENERATOR GEN_IMPORTACAO_XML_ITEM_ID;
COMMIT;
