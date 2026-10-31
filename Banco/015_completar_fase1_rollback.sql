/* ============================================================
   ERP 2026 - 015 - Rollback (Completar o banco da fase 1)
   ------------------------------------------------------------
   Reverte o que o 015_completar_fase1.sql fez.
   Ordem inversa: geo -> rename -> colunas de nota -> fusao -> CHECK.

   NOTA: o DROP de PRODUTO_FINANCEIRO NAO e reversivel por aqui
   (tabela estava vazia; para recriar, refaca a 014 e reaplique).

   Aplicar com:
     isql -u SYSDBA -p masterkey -charset UTF8 Banco\DADOS.FDB -i Banco\015_completar_fase1_rollback.sql
   ============================================================ */

SET NAMES UTF8;
SET ECHO ON;

/* ------------------------------------------------------------
   1) Geografia (ordem inversa: dados -> tabelas -> generators)
   ------------------------------------------------------------ */
DROP TABLE CIDADE;
DROP TABLE ESTADO;
DROP TABLE PAIS;
DROP GENERATOR GEN_CIDADE_ID;
DROP GENERATOR GEN_ESTADO_ID;
DROP GENERATOR GEN_PAIS_ID;
COMMIT;

/* ------------------------------------------------------------
   2) Desfaz rename: ADD CONTAPRODUCAO_ID + copia + DROP CONTA_ID
   ------------------------------------------------------------ */
DROP INDEX IDX_MOVFIN_CONTA;
ALTER TABLE MOVIMENTO_FINANCEIRO ADD CONTAPRODUCAO_ID BIGINT;
UPDATE MOVIMENTO_FINANCEIRO
   SET CONTAPRODUCAO_ID = CONTA_ID
 WHERE CONTA_ID IS NOT NULL;
ALTER TABLE MOVIMENTO_FINANCEIRO DROP CONTA_ID;
COMMIT;

/* ------------------------------------------------------------
   3) Remove colunas de nota + indices
   ------------------------------------------------------------ */
DROP INDEX IDX_NEITEM_MATERIAL;
DROP INDEX IDX_NEITEM_PFISCAL;
DROP INDEX IDX_NSITEM_PFISCAL;
ALTER TABLE NOTA_ENTRADA_ITEM DROP MATERIAL_ID;
ALTER TABLE NOTA_ENTRADA_ITEM DROP PRODUTO_FISCAL_ID;
ALTER TABLE NOTA_SAIDA_ITEM DROP PRODUTO_FISCAL_ID;
COMMIT;

/* ------------------------------------------------------------
   4) Desfaz fusao (recria PRODUTO_FINANCEIRO vazia)
   ------------------------------------------------------------ */
ALTER TABLE PRODUTO_FISCAL DROP CONSTRAINT CKB_PFISCAL_TIPO;
ALTER TABLE PRODUTO_FISCAL DROP VALOR;
ALTER TABLE PRODUTO_FISCAL DROP TIPO;
COMMIT;

CREATE GENERATOR GEN_PRODUTO_FINANCEIRO_ID;
COMMIT;
CREATE TABLE PRODUTO_FINANCEIRO (
  ID                  BIGINT NOT NULL PRIMARY KEY,
  EMPRESA_ID          BIGINT NOT NULL,
  PRODUTO_FISCAL_ID   BIGINT,
  CODIGO              VARCHAR(30),
  DESCRICAO           VARCHAR(100) NOT NULL,
  TIPO                CHAR(1) DEFAULT 'S',
  VALOR               NUMERIC(15,4) DEFAULT 0,
  ATIVO               CHAR(1) DEFAULT 'A',
  OBSERVACOES         VARCHAR(500),
  DATA_CADASTRO       TIMESTAMP,
  DATA_ATUALIZACAO    TIMESTAMP,
  CONSTRAINT CKB_PRODFIN_TIPO CHECK (TIPO IN ('S', 'O')),
  CONSTRAINT CKB_PRODFIN_ATIVO CHECK (ATIVO IN ('A', 'I'))
);
COMMIT;

SET TERM ^ ;
CREATE TRIGGER TRG_PRODUTO_FINANCEIRO_BI FOR PRODUTO_FINANCEIRO
ACTIVE BEFORE INSERT POSITION 0
AS BEGIN
  IF (NEW.ID IS NULL OR NEW.ID = 0) THEN NEW.ID = GEN_ID(GEN_PRODUTO_FINANCEIRO_ID, 1);
  IF (NEW.DATA_CADASTRO IS NULL) THEN NEW.DATA_CADASTRO = CURRENT_TIMESTAMP;
END^
CREATE TRIGGER TRG_PRODUTO_FINANCEIRO_BU FOR PRODUTO_FINANCEIRO
ACTIVE BEFORE UPDATE POSITION 0
AS BEGIN
  NEW.DATA_ATUALIZACAO = CURRENT_TIMESTAMP;
END^
SET TERM ; ^
COMMIT;

CREATE INDEX IDX_PRODFIN_EMPRESA ON PRODUTO_FINANCEIRO (EMPRESA_ID);
CREATE INDEX IDX_PRODFIN_FISCAL ON PRODUTO_FINANCEIRO (PRODUTO_FISCAL_ID);
COMMIT;

INSERT INTO PERMISSAO (GRUPO_ID, MODULO, TELA, PODE_VISUALIZAR, PODE_INSERIR,
                       PODE_EDITAR, PODE_EXCLUIR, PODE_IMPRIMIR)
SELECT 1, 'FINANCEIRO', 'PRODUTOS_FINANCEIROS', 'S', 'S', 'S', 'S', 'S' FROM RDB$DATABASE
WHERE NOT EXISTS (SELECT 1 FROM PERMISSAO
                  WHERE GRUPO_ID = 1 AND MODULO = 'FINANCEIRO' AND TELA = 'PRODUTOS_FINANCEIROS');
COMMIT;

/* ------------------------------------------------------------
   5) Remove CHECK do STATUS_PRODUCAO
   ------------------------------------------------------------ */
ALTER TABLE CONSUMO_MATERIAL_ITEM DROP CONSTRAINT CKB_CMITEM_STATUSPROD;
COMMIT;

/* ------------------------------------------------------------
   Fim do rollback.
   ------------------------------------------------------------ */
