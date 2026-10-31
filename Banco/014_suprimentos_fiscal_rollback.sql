/* ============================================================
   ERP 2026 - 014 - Rollback (Suprimentos/Fiscal/Financeiro fase 1)
   ------------------------------------------------------------
   Reverte o que o 014_suprimentos_fiscal.sql criou.
   Ordem inversa: colunas aditivas e tabelas novas.

   Aplicar com:
     isql -u SYSDBA -p masterkey Banco\DADOS.FDB -i Banco\014_suprimentos_fiscal_rollback.sql
   ============================================================ */

SET ECHO ON;

/* ------------------------------------------------------------
   1) Remove indices que referenciam as colunas aditivas
      (Firebird recusa DROP de coluna com indice por cima)
   ------------------------------------------------------------ */
DROP INDEX IDX_PRODUTO_FISCAL;
DROP INDEX IDX_FICHA_BASE;
DROP INDEX IDX_CONSUMO_ITEM_STATUSPROD;

COMMIT;

/* ------------------------------------------------------------
   2) Remove colunas aditivas
   ------------------------------------------------------------ */
ALTER TABLE PRODUTO DROP PRODUTO_FISCAL_ID;
ALTER TABLE FICHA_TECNICA DROP TIPO_BASE;
ALTER TABLE FICHA_TECNICA DROP ID_BASE;
ALTER TABLE CONSUMO_MATERIAL_ITEM DROP STATUS_PRODUCAO;

COMMIT;

/* ------------------------------------------------------------
   3) Remove indices das tabelas novas (antes das tabelas)
   ------------------------------------------------------------ */
DROP INDEX IDX_PFISCAL_EMPRESA;
DROP INDEX IDX_MATERIAL_EMPRESA;
DROP INDEX IDX_MATERIAL_FISCAL;
DROP INDEX IDX_COR_PRODUTO;
DROP INDEX IDX_PRODFIN_EMPRESA;
DROP INDEX IDX_PRODFIN_FISCAL;
DROP INDEX IDX_PCOMPRA_FORNECEDOR;
DROP INDEX IDX_PCOMPRA_STATUS;
DROP INDEX IDX_PCOMPRA_ITEM_PC;
DROP INDEX IDX_PCOMPRA_ITEM_MAT;
DROP INDEX IDX_ESTQ_MAT_MAT;
DROP INDEX IDX_MOVESTMAT_MAT;
DROP INDEX IDX_MOVESTMAT_DATA;
DROP INDEX IDX_MOVFIN_DATA;

COMMIT;

/* ------------------------------------------------------------
   4) Remove triggers e tabelas novas
   ------------------------------------------------------------ */
DROP TRIGGER TRG_PRODUTO_FISCAL_BI;
DROP TRIGGER TRG_PRODUTO_FISCAL_BU;
DROP TRIGGER TRG_MATERIAL_BI;
DROP TRIGGER TRG_MATERIAL_BU;
DROP TRIGGER TRG_COR_BI;
DROP TRIGGER TRG_PRODUTO_FINANCEIRO_BI;
DROP TRIGGER TRG_PRODUTO_FINANCEIRO_BU;
DROP TRIGGER TRG_PEDIDO_COMPRA_BI;
DROP TRIGGER TRG_PEDIDO_COMPRA_BU;
DROP TRIGGER TRG_PEDIDO_COMPRA_ITEM_BI;
DROP TRIGGER TRG_ESTOQUE_MATERIAL_BI;
DROP TRIGGER TRG_MOVIMENTO_MATERIAL_BI;
DROP TRIGGER TRG_MOVIMENTO_FINANCEIRO_BI;

COMMIT;

DROP TABLE PEDIDO_COMPRA_ITEM;
DROP TABLE PEDIDO_COMPRA;
DROP TABLE MOVIMENTO_FINANCEIRO;
DROP TABLE MOVIMENTO_MATERIAL;
DROP TABLE ESTOQUE_MATERIAL;
DROP TABLE PRODUTO_FINANCEIRO;
DROP TABLE COR;
DROP TABLE MATERIAL;
DROP TABLE PRODUTO_FISCAL;

COMMIT;

/* ------------------------------------------------------------
   5) Remove permissões criadas (apenas as novas)
   ------------------------------------------------------------ */
DELETE FROM PERMISSAO WHERE MODULO = 'SUPRIMENTOS'
  AND TELA IN ('MATERIAIS', 'COMPRAS', 'CONSUMO');
DELETE FROM PERMISSAO WHERE MODULO = 'FINANCEIRO'
  AND TELA IN ('PRODUTOS_FINANCEIROS', 'PRODUTO_FISCAL', 'MOVIMENTACAO');

COMMIT;

/* ------------------------------------------------------------
   6) Remove generators
   ------------------------------------------------------------ */
DROP GENERATOR GEN_PRODUTO_FISCAL_ID;
DROP GENERATOR GEN_MATERIAL_ID;
DROP GENERATOR GEN_COR_ID;
DROP GENERATOR GEN_PRODUTO_FINANCEIRO_ID;
DROP GENERATOR GEN_PEDIDO_COMPRA_ID;
DROP GENERATOR GEN_PEDIDO_COMPRA_ITEM_ID;
DROP GENERATOR GEN_ESTOQUE_MATERIAL_ID;
DROP GENERATOR GEN_MOVIMENTO_MATERIAL_ID;
DROP GENERATOR GEN_MOVIMENTO_FINANCEIRO_ID;

COMMIT;

/* ------------------------------------------------------------
   Fim do rollback.
   ------------------------------------------------------------ */
