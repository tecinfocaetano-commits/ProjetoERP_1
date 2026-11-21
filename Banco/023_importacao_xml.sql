/* ============================================================
   ERP 2026 - Migracao 023
   Fiscal - rastreabilidade da importacao de XML na nota de entrada

   IMPORTACAO_XML_ITEM guarda, por item do documento importado:
     - CNPJ do fornecedor;
     - descricao original que veio no XML;
     - codigo do produto da nota (cProd);
     - classificacao fiscal que veio (NCM/CFOP/CST/CEST);
     - o produto do cadastro escolhido pelo usuario (PRODUTO_ID)
       e a situacao do mapeamento.

   Regras:
     - nenhum produto e criado automaticamente pela importacao;
       quando nao ha correspondencia, a tela de mapeamento deixa o
       usuario escolher um produto compativel ou cadastrar um novo;
     - SITUACAO: PENDENTE -> MAPEADO | NOVO | IGNORADO;
     - indice unico por empresa + chave + codigo do produto da nota
       permite reaproveitar o mapeamento numa reimportacao;
     - identificadores <= 31 caracteres, DEFAULT antes de NOT NULL,
       sem ALTER ... RENAME (convencao do projeto).

   Execucao unica. Aplicar com:
     isql -u SYSDBA -p masterkey -charset UTF8 Banco\DADOS.FDB -i Banco\023_importacao_xml.sql
   Reverter com:
     Banco\023_importacao_xml_rollback.sql
   ============================================================ */

SET NAMES UTF8;
SET ECHO ON;

CREATE GENERATOR GEN_IMPORTACAO_XML_ITEM_ID;
COMMIT;

CREATE TABLE IMPORTACAO_XML_ITEM (
  ID                  BIGINT NOT NULL,
  EMPRESA_ID          BIGINT NOT NULL,
  NOTA_ENTRADA_ID     BIGINT,
  NOTA_ITEM_ID        BIGINT,
  CHAVE               VARCHAR(44),
  TIPO_DOCUMENTO      VARCHAR(12) DEFAULT '55' NOT NULL,
  PROVEDOR            VARCHAR(20),
  FORNECEDOR_CNPJ     VARCHAR(14) NOT NULL,
  DESCRICAO_ORIGINAL  VARCHAR(250) NOT NULL,
  CODIGO_PRODUTO_NOTA VARCHAR(60) NOT NULL,
  CLASSIFICACAO_FISCAL VARCHAR(80),
  NCM                 VARCHAR(8),
  CFOP                VARCHAR(4),
  CST_ICMS            VARCHAR(3),
  CEST                VARCHAR(7),
  UNIDADE             VARCHAR(6),
  QUANTIDADE          NUMERIC(15,4) DEFAULT 0,
  VALOR_UNITARIO      NUMERIC(15,4) DEFAULT 0,
  PRODUTO_ID          BIGINT,
  SITUACAO            VARCHAR(12) DEFAULT 'PENDENTE' NOT NULL
    CONSTRAINT CK_IMPXML_SITUACAO CHECK (SITUACAO IN
      ('PENDENTE', 'MAPEADO', 'NOVO', 'IGNORADO')),
  USUARIO_ID          BIGINT,
  DATA_IMPORTACAO     TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
  PRIMARY KEY (ID)
);
COMMIT;

CREATE UNIQUE INDEX UQ_IMPXML_EMP_CHAVE_COD
  ON IMPORTACAO_XML_ITEM (EMPRESA_ID, CHAVE, CODIGO_PRODUTO_NOTA);
CREATE INDEX IX_IMPXML_PRODUTO ON IMPORTACAO_XML_ITEM (PRODUTO_ID);
CREATE INDEX IX_IMPXML_NOTA ON IMPORTACAO_XML_ITEM (NOTA_ENTRADA_ID);
COMMIT;

SET TERM ^ ;

CREATE TRIGGER TRG_IMPORTACAO_XML_ITEM_BI
  FOR IMPORTACAO_XML_ITEM ACTIVE BEFORE INSERT POSITION 0
AS
BEGIN
  IF (NEW.ID IS NULL OR NEW.ID = 0) THEN
    NEW.ID = GEN_ID(GEN_IMPORTACAO_XML_ITEM_ID, 1);
  IF (NEW.DATA_IMPORTACAO IS NULL) THEN
    NEW.DATA_IMPORTACAO = CURRENT_TIMESTAMP;
  IF (NEW.SITUACAO IS NULL) THEN
    NEW.SITUACAO = 'PENDENTE';
END
^

SET TERM ; ^
COMMIT;
