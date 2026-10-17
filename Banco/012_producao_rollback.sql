/* ============================================================
   ERP 2026 - 012_producao_rollback.sql
   ------------------------------------------------------------
   Desfaz o 012_producao.sql (Módulo 3 - Produção).

   ATENÇÃO: apaga os dados de produção. Use somente para
   desfazer a migração em ambiente de teste/desenvolvimento.

   Aplicar com:
     isql -u SYSDBA -p masterkey Banco\DADOS.FDB -i Banco\012_producao_rollback.sql
   ============================================================ */

DROP TABLE TALAO_BIPAGEM;
DROP TABLE TALAO;
DROP TABLE CONSUMO_MATERIAL_ITEM;
DROP TABLE CONSUMO_MATERIAL;
DROP TABLE MAPA_PRODUCAO_ITEM;
DROP TABLE MAPA_PRODUCAO;
DROP TABLE FICHA_TECNICA_ITEM;
DROP TABLE FICHA_TECNICA;

DROP GENERATOR GEN_TALAO_BIPAGEM_ID;
DROP GENERATOR GEN_TALAO_ID;
DROP GENERATOR GEN_CONSUMO_MATERIAL_ITEM_ID;
DROP GENERATOR GEN_CONSUMO_MATERIAL_ID;
DROP GENERATOR GEN_MAPA_PRODUCAO_ITEM_ID;
DROP GENERATOR GEN_MAPA_PRODUCAO_ID;
DROP GENERATOR GEN_FICHA_TECNICA_ITEM_ID;
DROP GENERATOR GEN_FICHA_TECNICA_ID;

DELETE FROM CONFIGURACAO WHERE CHAVE STARTING WITH 'PRODUCAO_';
DELETE FROM PERMISSAO WHERE MODULO = 'PRODUCAO';

COMMIT;

/* Fim. */
