/* ============================================================
   ERP 2026 - 016 - GRADE (Fase 2)
   ------------------------------------------------------------
   Decisao do usuario:
     - tela de cadastro de grade com tabela principal + sub-tabela
       de tamanhos (numero de tamanhos variavel por tipo:
       calcado / confeccao / grupo);
     - a grade pode ser inserida no ITEM DO PEDIDO;
     - no MAPA o subgrid da grade e EDITAVEL;
     - preferencia USA_GRADE: desmarcada, a grade NAO aparece
       nem no mapa nem no pedido.

   Estrutura:
     GRADE                - principal (nome + tipo)
     GRADE_TAMANHO        - tamanhos da grade (ordem + ativo)
     PRODUTO.GRADE_ID     - grade padrao do produto (aditiva, nullable)
     ITEM_PEDIDO_GRADE    - grade efetiva do item do pedido
     MAPA_PRODUCAO_ITEM_GRADE - grade efetiva do item do mapa
     CONFIGURACAO.USA_GRADE   - 'S'/'N' (uma por empresa; seed 'N')

   Convencao do banco (igual 014/015): SEM chaves estrangeiras;
   integridade garantida pelo Service. Execucao unica.

   Aplicar com:
     isql -u SYSDBA -p masterkey -charset UTF8 Banco\DADOS.FDB -i Banco\016_grade.sql
   Reverter com:
     Banco\016_grade_rollback.sql
   ============================================================ */

SET NAMES UTF8;
SET ECHO ON;

CREATE GENERATOR GEN_GRADE_ID;
CREATE GENERATOR GEN_GRADE_TAMANHO_ID;
CREATE GENERATOR GEN_ITEM_PEDIDO_GRADE_ID;
CREATE GENERATOR GEN_MAPA_ITEM_GRADE_ID;
COMMIT;

CREATE TABLE GRADE (
  ID                BIGINT NOT NULL PRIMARY KEY,
  EMPRESA_ID        BIGINT NOT NULL,
  NOME              VARCHAR(60) NOT NULL,
  TIPO              VARCHAR(15) DEFAULT 'OUTRO' NOT NULL,
  ATIVO             CHAR(1) DEFAULT 'A',
  OBSERVACAO        VARCHAR(255),
  DATA_CADASTRO     TIMESTAMP,
  DATA_ATUALIZACAO  TIMESTAMP,
  CONSTRAINT CKB_GRADE_TIPO CHECK (TIPO IN ('CALCADO', 'CONFECCAO', 'GRUPO', 'OUTRO')),
  CONSTRAINT CKB_GRADE_ATIVO CHECK (ATIVO IN ('A', 'I')),
  CONSTRAINT UQ_GRADE_NOME UNIQUE (EMPRESA_ID, NOME)
);

CREATE TABLE GRADE_TAMANHO (
  ID                BIGINT NOT NULL PRIMARY KEY,
  GRADE_ID          BIGINT NOT NULL,
  TAMANHO           VARCHAR(10) NOT NULL,
  ORDEM             INTEGER DEFAULT 0,
  ATIVO             CHAR(1) DEFAULT 'A',
  CONSTRAINT CKB_GRADE_TAM_ATIVO CHECK (ATIVO IN ('A', 'I')),
  CONSTRAINT UQ_GRADE_TAM UNIQUE (GRADE_ID, TAMANHO)
);

/* grade efetiva do item do pedido (snapshot; o total do item e a soma) */
CREATE TABLE ITEM_PEDIDO_GRADE (
  ID                BIGINT NOT NULL PRIMARY KEY,
  ITEM_PEDIDO_ID    BIGINT NOT NULL,
  TAMANHO           VARCHAR(10) NOT NULL,
  QUANTIDADE        NUMERIC(15,4) DEFAULT 0 NOT NULL,
  ORDEM             INTEGER DEFAULT 0,
  CONSTRAINT CKB_IPGRADE_QTD CHECK (QUANTIDADE >= 0),
  CONSTRAINT UQ_IPGRADE_TAM UNIQUE (ITEM_PEDIDO_ID, TAMANHO)
);

/* grade efetiva do item do mapa (editavel na tela do mapa) */
CREATE TABLE MAPA_PRODUCAO_ITEM_GRADE (
  ID                BIGINT NOT NULL PRIMARY KEY,
  MAPA_PRODUCAO_ITEM_ID BIGINT NOT NULL,
  TAMANHO           VARCHAR(10) NOT NULL,
  QUANTIDADE        NUMERIC(15,4) DEFAULT 0 NOT NULL,
  ORDEM             INTEGER DEFAULT 0,
  CONSTRAINT CKB_MPGRADE_QTD CHECK (QUANTIDADE >= 0),
  CONSTRAINT UQ_MPGRADE_TAM UNIQUE (MAPA_PRODUCAO_ITEM_ID, TAMANHO)
);
COMMIT;

SET TERM ^ ;
CREATE TRIGGER TRG_GRADE_BI FOR GRADE ACTIVE BEFORE INSERT POSITION 0
AS BEGIN
  IF (NEW.ID IS NULL OR NEW.ID = 0) THEN NEW.ID = GEN_ID(GEN_GRADE_ID, 1);
  IF (NEW.DATA_CADASTRO IS NULL) THEN NEW.DATA_CADASTRO = CURRENT_TIMESTAMP;
END^
CREATE TRIGGER TRG_GRADE_BU FOR GRADE ACTIVE BEFORE UPDATE POSITION 0
AS BEGIN
  NEW.DATA_ATUALIZACAO = CURRENT_TIMESTAMP;
END^
CREATE TRIGGER TRG_GRADE_TAMANHO_BI FOR GRADE_TAMANHO ACTIVE BEFORE INSERT POSITION 0
AS BEGIN
  IF (NEW.ID IS NULL OR NEW.ID = 0) THEN NEW.ID = GEN_ID(GEN_GRADE_TAMANHO_ID, 1);
END^
CREATE TRIGGER TRG_ITEM_PEDIDO_GRADE_BI FOR ITEM_PEDIDO_GRADE ACTIVE BEFORE INSERT POSITION 0
AS BEGIN
  IF (NEW.ID IS NULL OR NEW.ID = 0) THEN NEW.ID = GEN_ID(GEN_ITEM_PEDIDO_GRADE_ID, 1);
END^
CREATE TRIGGER TRG_MAPA_ITEM_GRADE_BI FOR MAPA_PRODUCAO_ITEM_GRADE ACTIVE BEFORE INSERT POSITION 0
AS BEGIN
  IF (NEW.ID IS NULL OR NEW.ID = 0) THEN NEW.ID = GEN_ID(GEN_MAPA_ITEM_GRADE_ID, 1);
END^
SET TERM ; ^
COMMIT;

/* coluna aditiva: grade padrao do produto (nullable = produto sem grade) */
ALTER TABLE PRODUTO ADD GRADE_ID BIGINT;
COMMIT;

CREATE INDEX IDX_GRADE_EMPRESA ON GRADE (EMPRESA_ID);
CREATE INDEX IDX_GRADE_TAMANHO_GRADE ON GRADE_TAMANHO (GRADE_ID);
CREATE INDEX IDX_IPGRADE_ITEM ON ITEM_PEDIDO_GRADE (ITEM_PEDIDO_ID);
CREATE INDEX IDX_MPGRADE_ITEM ON MAPA_PRODUCAO_ITEM_GRADE (MAPA_PRODUCAO_ITEM_ID);
CREATE INDEX IDX_PRODUTO_GRADE ON PRODUTO (GRADE_ID);
COMMIT;

/* preferencia por empresa: desligada por padrao */
INSERT INTO CONFIGURACAO (EMPRESA_ID, CHAVE, VALOR, DESCRICAO)
SELECT E.ID, 'USA_GRADE', 'N', 'Usa grade de tamanhos no pedido e no mapa'
FROM EMPRESA E
WHERE NOT EXISTS (
  SELECT 1 FROM CONFIGURACAO C
  WHERE C.EMPRESA_ID = E.ID AND C.CHAVE = 'USA_GRADE');
COMMIT;

/* ------------------------------------------------------------
   Fim.
   ------------------------------------------------------------ */
