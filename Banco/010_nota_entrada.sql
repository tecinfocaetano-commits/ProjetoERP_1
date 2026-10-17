/* ============================================================
   ERP 2026 - 010_nota_entrada.sql
   ------------------------------------------------------------
   Módulo 1: NOTA DE ENTRADA (compra de mercadoria)

   Cria:
     - NOTA_ENTRADA        (cabeçalho do documento de entrada)
     - NOTA_ENTRADA_ITEM   (itens, com dados fiscais e custo)

   Estrutura pronta para NF-e real: guarda modelo/série/número,
   chave de acesso (44 dígitos) e o caminho do XML importado.

   Observações:
     - O saldo de ESTOQUE é mantido pelo trigger TRG_MOVEST_AI a
       partir de MOVIMENTO_ESTOQUE; o processamento da nota
       apenas grava os movimentos de entrada (TIPO = 'E').
     - Script ADITIVO e de uso único.

   Aplicar com:
     isql -u SYSDBA -p masterkey Banco\DADOS.FDB -i Banco\010_nota_entrada.sql
   ============================================================ */

/* ------------------------------------------------------------
   1) GENERATORS
   ------------------------------------------------------------ */
CREATE GENERATOR GEN_NOTA_ENTRADA_ID;
CREATE GENERATOR GEN_NOTA_ENTRADA_ITEM_ID;

COMMIT;

/* ------------------------------------------------------------
   2) TABELAS
   ------------------------------------------------------------ */
CREATE TABLE NOTA_ENTRADA (
  ID                     BIGINT NOT NULL PRIMARY KEY,
  EMPRESA_ID             BIGINT,
  FORNECEDOR_ID          BIGINT,
  NUMERO                 VARCHAR(20),
  SERIE                  VARCHAR(5),
  MODELO                 VARCHAR(3) DEFAULT '55',
  CHAVE_ACESSO           VARCHAR(44),
  DATA_EMISSAO           DATE,
  DATA_ENTRADA           DATE,
  NATUREZA_OPERACAO      VARCHAR(120),
  CFOP                   VARCHAR(4),
  VALOR_PRODUTOS         NUMERIC(15,4) DEFAULT 0,
  VALOR_FRETE            NUMERIC(15,4) DEFAULT 0,
  VALOR_SEGURO           NUMERIC(15,4) DEFAULT 0,
  VALOR_DESCONTO         NUMERIC(15,4) DEFAULT 0,
  VALOR_OUTRAS           NUMERIC(15,4) DEFAULT 0,
  VALOR_ICMS             NUMERIC(15,4) DEFAULT 0,
  VALOR_IPI              NUMERIC(15,4) DEFAULT 0,
  VALOR_PIS              NUMERIC(15,4) DEFAULT 0,
  VALOR_COFINS           NUMERIC(15,4) DEFAULT 0,
  VALOR_TOTAL            NUMERIC(15,4) DEFAULT 0,
  STATUS                 VARCHAR(1) DEFAULT 'A',
  CONDICAO_PAGAMENTO_ID  BIGINT,
  FORMA_PAGAMENTO_ID     BIGINT,
  XML_ARQUIVO            VARCHAR(255),
  OBSERVACOES            VARCHAR(255),
  USUARIO_ID             BIGINT,
  DATA_CADASTRO          TIMESTAMP,
  DATA_PROCESSAMENTO     TIMESTAMP
);

/* STATUS: A = Aberta (aguardando processamento)
           P = Processada (estoque e contas a pagar gerados)
           C = Cancelada                                    */

CREATE TABLE NOTA_ENTRADA_ITEM (
  ID                  BIGINT NOT NULL PRIMARY KEY,
  NOTA_ENTRADA_ID     BIGINT NOT NULL,
  PRODUTO_ID          BIGINT,
  CODIGO_FORNECEDOR   VARCHAR(60),
  DESCRICAO           VARCHAR(120),
  NCM                 VARCHAR(8),
  CFOP                VARCHAR(4),
  CST_ICMS            VARCHAR(3),
  ALIQ_ICMS           NUMERIC(15,4) DEFAULT 0,
  VALOR_ICMS          NUMERIC(15,4) DEFAULT 0,
  QUANTIDADE          NUMERIC(15,4) DEFAULT 0,
  VALOR_UNITARIO      NUMERIC(15,4) DEFAULT 0,
  VALOR_TOTAL         NUMERIC(15,4) DEFAULT 0,
  DESCONTO            NUMERIC(15,4) DEFAULT 0,
  ATUALIZA_ESTOQUE    VARCHAR(1) DEFAULT 'S',
  ATUALIZA_CUSTO      VARCHAR(1) DEFAULT 'S'
);

COMMIT;

/* ------------------------------------------------------------
   3) ÍNDICES
   ------------------------------------------------------------ */
CREATE INDEX IDX_NOTA_ENTRADA_FORNECEDOR ON NOTA_ENTRADA (FORNECEDOR_ID);
CREATE INDEX IDX_NOTA_ENTRADA_DATA       ON NOTA_ENTRADA (DATA_ENTRADA);
CREATE INDEX IDX_NOTA_ENTRADA_DOC        ON NOTA_ENTRADA (FORNECEDOR_ID, MODELO, SERIE, NUMERO);
CREATE INDEX IDX_NOTA_ENTRADA_STATUS     ON NOTA_ENTRADA (STATUS);
CREATE INDEX IDX_NOTA_ENTRADA_ITEM_NOTA  ON NOTA_ENTRADA_ITEM (NOTA_ENTRADA_ID);
CREATE INDEX IDX_NOTA_ENTRADA_ITEM_PROD  ON NOTA_ENTRADA_ITEM (PRODUTO_ID);

COMMIT;

/* ------------------------------------------------------------
   4) TRIGGERS de auto-incremento
   ------------------------------------------------------------ */
SET TERM ^ ;

CREATE TRIGGER TRG_NOTA_ENTRADA_BI FOR NOTA_ENTRADA
ACTIVE BEFORE INSERT POSITION 0
AS
BEGIN
  IF (NEW.ID IS NULL OR NEW.ID = 0) THEN
    NEW.ID = GEN_ID(GEN_NOTA_ENTRADA_ID, 1);
  IF (NEW.DATA_CADASTRO IS NULL) THEN
    NEW.DATA_CADASTRO = CURRENT_TIMESTAMP;
  IF (NEW.STATUS IS NULL) THEN
    NEW.STATUS = 'A';
END^

CREATE TRIGGER TRG_NOTA_ENTRADA_ITEM_BI FOR NOTA_ENTRADA_ITEM
ACTIVE BEFORE INSERT POSITION 0
AS
BEGIN
  IF (NEW.ID IS NULL OR NEW.ID = 0) THEN
    NEW.ID = GEN_ID(GEN_NOTA_ENTRADA_ITEM_ID, 1);
END^

SET TERM ; ^

COMMIT;

/* ------------------------------------------------------------
   Fim.
   ------------------------------------------------------------ */
