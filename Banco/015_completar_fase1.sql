/* ============================================================
   ERP 2026 - 015 - Completar o banco da fase 1
   ------------------------------------------------------------
   Fecha as lacunas de banco da fase 1 do redesenho
   (Documentacao/DESENHO_NOVAS_ABAS.md + CHECKPOINT.md), incluindo
   duas fusoes decididas pelo usuario:

   1) STATUS_PRODUCAO: CHECK com os 3 valores canonicos
      (ABERTO / PARCIALMENTE_CONCLUIDO / CONCLUIDO) - pendencia 1.
      Valores SEM acento (gravacao do Service).

   2) FUSAO Fiscal+Financeiro (usuario: "produto fiscal e financeiro
      e o mesmo"): PRODUTO_FISCAL absorve TIPO (S=servico/O=outros) e
      VALOR; PRODUTO_FINANCEIRO (vazia) e removida. Uma tabela so.

   3) Itens de nota ganham o vinculo ao PRODUTO_FISCAL (ponto B2):
      NOTA_ENTRADA_ITEM  + MATERIAL_ID, PRODUTO_FISCAL_ID
      NOTA_SAIDA_ITEM    + PRODUTO_FISCAL_ID
      (as colunas fiscais ja existentes - NCM/CFOP/CST/aliq - continuam;
       o Service passa a preenche-las a partir do PRODUTO_FISCAL.)

   4) Rename MOVIMENTO_FINANCEIRO.CONTAPRODUCAO_ID -> CONTA_ID
      (pendencia 7; Firebird nao renomeia coluna: ADD + copia + DROP).

   5) Cadastros geograficos (usuario: "cria o cadastro de pais, estado
      e cidades"): PAIS -> ESTADO -> CIDADE. Globais (sem EMPRESA_ID;
      dado geografico e universal). Seed: Brasil + 27 UFs (IBGE).
      CIDADE fica vazia (preenchimento por cadastro/importacao).

   NAO inclui a fusao CLIENTE+FORNECEDOR (etapa separada, alto risco:
   49 refs de FK + estruturas diferentes + caminho de NF-e).

   Convencao do banco (igual ao 014): SEM chaves estrangeiras;
   integridade garantida pelo Service. Execucao unica (sem IF NOT
   EXISTS, como o 014).

   Aplicar com:
     isql -u SYSDBA -p masterkey -charset UTF8 Banco\DADOS.FDB -i Banco\015_completar_fase1.sql
   Reverter com:
     Banco\015_completar_fase1_rollback.sql
   ============================================================ */

SET NAMES UTF8;
SET ECHO ON;

/* ------------------------------------------------------------
   1) STATUS_PRODUCAO - CHECK dos valores de andamento (pend. 1)
   ------------------------------------------------------------ */
UPDATE CONSUMO_MATERIAL_ITEM
   SET STATUS_PRODUCAO = 'ABERTO'
 WHERE STATUS_PRODUCAO IS NULL
    OR STATUS_PRODUCAO NOT IN ('ABERTO','PARCIALMENTE_CONCLUIDO','CONCLUIDO');
COMMIT;

ALTER TABLE CONSUMO_MATERIAL_ITEM
  ADD CONSTRAINT CKB_CMITEM_STATUSPROD
  CHECK (STATUS_PRODUCAO IN ('ABERTO','PARCIALMENTE_CONCLUIDO','CONCLUIDO'));

COMMIT;

/* ------------------------------------------------------------
   2) FUSAO Fiscal+Financeiro: PRODUTO_FISCAL absorve TIPO e VALOR
   ------------------------------------------------------------ */
ALTER TABLE PRODUTO_FISCAL ADD TIPO CHAR(1);     /* S=servico, O=outros; NULL = classificacao pura */
ALTER TABLE PRODUTO_FISCAL ADD VALOR NUMERIC(15,4) DEFAULT 0;
COMMIT;

ALTER TABLE PRODUTO_FISCAL
  ADD CONSTRAINT CKB_PFISCAL_TIPO CHECK (TIPO IN ('S', 'O'));
COMMIT;

/* PRODUTO_FINANCEIRO esta vazia (0 linhas) - fusao sem dados a migrar.
   Remove em ordem de dependencia: indices -> triggers -> tabela -> generator. */
DROP INDEX IDX_PRODFIN_EMPRESA;
DROP INDEX IDX_PRODFIN_FISCAL;
DROP TRIGGER TRG_PRODUTO_FINANCEIRO_BI;
DROP TRIGGER TRG_PRODUTO_FINANCEIRO_BU;
DROP TABLE PRODUTO_FINANCEIRO;
DROP GENERATOR GEN_PRODUTO_FINANCEIRO_ID;
COMMIT;

/* permissao da tela que deixa de existir */
DELETE FROM PERMISSAO WHERE MODULO = 'FINANCEIRO' AND TELA = 'PRODUTOS_FINANCEIROS';
COMMIT;

/* ------------------------------------------------------------
   3) Itens de nota ganham vinculo ao PRODUTO_FISCAL (B2)
   ------------------------------------------------------------ */
ALTER TABLE NOTA_ENTRADA_ITEM ADD MATERIAL_ID BIGINT;
ALTER TABLE NOTA_ENTRADA_ITEM ADD PRODUTO_FISCAL_ID BIGINT;
ALTER TABLE NOTA_SAIDA_ITEM   ADD PRODUTO_FISCAL_ID BIGINT;

COMMIT;

/* ------------------------------------------------------------
   4) Rename CONTAPRODUCAO_ID -> CONTA_ID (ADD + copia + DROP)
   ------------------------------------------------------------ */
ALTER TABLE MOVIMENTO_FINANCEIRO ADD CONTA_ID BIGINT;

UPDATE MOVIMENTO_FINANCEIRO
   SET CONTA_ID = CONTAPRODUCAO_ID
 WHERE CONTAPRODUCAO_ID IS NOT NULL;

ALTER TABLE MOVIMENTO_FINANCEIRO DROP CONTAPRODUCAO_ID;

COMMIT;

/* ------------------------------------------------------------
   5) Cadastros geograficos: PAIS -> ESTADO -> CIDADE
   ------------------------------------------------------------ */
CREATE GENERATOR GEN_PAIS_ID;
CREATE GENERATOR GEN_ESTADO_ID;
CREATE GENERATOR GEN_CIDADE_ID;
COMMIT;

CREATE TABLE PAIS (
  ID                BIGINT NOT NULL PRIMARY KEY,
  NOME              VARCHAR(60) NOT NULL,
  CODIGO            VARCHAR(5),            /* ex.: BRA (ISO 3166) */
  DDI               VARCHAR(5),            /* ex.: 55 */
  ATIVO             CHAR(1) DEFAULT 'A',
  DATA_CADASTRO     TIMESTAMP,
  DATA_ATUALIZACAO  TIMESTAMP,
  CONSTRAINT CKB_PAIS_ATIVO CHECK (ATIVO IN ('A', 'I')),
  CONSTRAINT UQ_PAIS_NOME UNIQUE (NOME)
);

CREATE TABLE ESTADO (
  ID                BIGINT NOT NULL PRIMARY KEY,
  PAIS_ID           BIGINT NOT NULL,
  NOME              VARCHAR(60) NOT NULL,
  UF                CHAR(2) NOT NULL,
  CODIGO_IBGE       VARCHAR(10),
  ATIVO             CHAR(1) DEFAULT 'A',
  DATA_CADASTRO     TIMESTAMP,
  DATA_ATUALIZACAO  TIMESTAMP,
  CONSTRAINT CKB_ESTADO_ATIVO CHECK (ATIVO IN ('A', 'I')),
  CONSTRAINT UQ_ESTADO_UF UNIQUE (PAIS_ID, UF)
);

CREATE TABLE CIDADE (
  ID                BIGINT NOT NULL PRIMARY KEY,
  ESTADO_ID         BIGINT NOT NULL,
  NOME              VARCHAR(80) NOT NULL,
  CODIGO_IBGE       VARCHAR(10),
  CEP_PADRAO        VARCHAR(9),
  ATIVO             CHAR(1) DEFAULT 'A',
  DATA_CADASTRO     TIMESTAMP,
  DATA_ATUALIZACAO  TIMESTAMP,
  CONSTRAINT CKB_CIDADE_ATIVO CHECK (ATIVO IN ('A', 'I')),
  CONSTRAINT UQ_CIDADE_NOME UNIQUE (ESTADO_ID, NOME)
);
COMMIT;

SET TERM ^ ;
CREATE TRIGGER TRG_PAIS_BI FOR PAIS ACTIVE BEFORE INSERT POSITION 0
AS BEGIN
  IF (NEW.ID IS NULL OR NEW.ID = 0) THEN NEW.ID = GEN_ID(GEN_PAIS_ID, 1);
  IF (NEW.DATA_CADASTRO IS NULL) THEN NEW.DATA_CADASTRO = CURRENT_TIMESTAMP;
END^
CREATE TRIGGER TRG_PAIS_BU FOR PAIS ACTIVE BEFORE UPDATE POSITION 0
AS BEGIN
  NEW.DATA_ATUALIZACAO = CURRENT_TIMESTAMP;
END^
CREATE TRIGGER TRG_ESTADO_BI FOR ESTADO ACTIVE BEFORE INSERT POSITION 0
AS BEGIN
  IF (NEW.ID IS NULL OR NEW.ID = 0) THEN NEW.ID = GEN_ID(GEN_ESTADO_ID, 1);
  IF (NEW.DATA_CADASTRO IS NULL) THEN NEW.DATA_CADASTRO = CURRENT_TIMESTAMP;
END^
CREATE TRIGGER TRG_ESTADO_BU FOR ESTADO ACTIVE BEFORE UPDATE POSITION 0
AS BEGIN
  NEW.DATA_ATUALIZACAO = CURRENT_TIMESTAMP;
END^
CREATE TRIGGER TRG_CIDADE_BI FOR CIDADE ACTIVE BEFORE INSERT POSITION 0
AS BEGIN
  IF (NEW.ID IS NULL OR NEW.ID = 0) THEN NEW.ID = GEN_ID(GEN_CIDADE_ID, 1);
  IF (NEW.DATA_CADASTRO IS NULL) THEN NEW.DATA_CADASTRO = CURRENT_TIMESTAMP;
END^
CREATE TRIGGER TRG_CIDADE_BU FOR CIDADE ACTIVE BEFORE UPDATE POSITION 0
AS BEGIN
  NEW.DATA_ATUALIZACAO = CURRENT_TIMESTAMP;
END^
SET TERM ; ^
COMMIT;

CREATE INDEX IDX_ESTADO_PAIS ON ESTADO (PAIS_ID);
CREATE INDEX IDX_CIDADE_ESTADO ON CIDADE (ESTADO_ID);
CREATE INDEX IDX_CIDADE_NOME ON CIDADE (NOME);
CREATE INDEX IDX_CIDADE_IBGE ON CIDADE (CODIGO_IBGE);
CREATE INDEX IDX_NEITEM_MATERIAL ON NOTA_ENTRADA_ITEM (MATERIAL_ID);
CREATE INDEX IDX_NEITEM_PFISCAL ON NOTA_ENTRADA_ITEM (PRODUTO_FISCAL_ID);
CREATE INDEX IDX_NSITEM_PFISCAL ON NOTA_SAIDA_ITEM (PRODUTO_FISCAL_ID);
CREATE INDEX IDX_MOVFIN_CONTA ON MOVIMENTO_FINANCEIRO (CONTA_ID);
COMMIT;

/* ---- seed: Brasil + 27 UFs (IBGE) ---- */
INSERT INTO PAIS (NOME, CODIGO, DDI, ATIVO) VALUES ('Brasil', 'BRA', '55', 'A');
COMMIT;

INSERT INTO ESTADO (PAIS_ID, NOME, UF, CODIGO_IBGE, ATIVO)
SELECT (SELECT ID FROM PAIS WHERE CODIGO = 'BRA'), v.NOME, v.UF, v.IBGE, 'A'
FROM (SELECT 'Rondônia' AS NOME, 'RO' AS UF, '11' AS IBGE FROM RDB$DATABASE
      UNION ALL SELECT 'Acre', 'AC', '12' FROM RDB$DATABASE
      UNION ALL SELECT 'Amazonas', 'AM', '13' FROM RDB$DATABASE
      UNION ALL SELECT 'Roraima', 'RR', '14' FROM RDB$DATABASE
      UNION ALL SELECT 'Pará', 'PA', '15' FROM RDB$DATABASE
      UNION ALL SELECT 'Amapá', 'AP', '16' FROM RDB$DATABASE
      UNION ALL SELECT 'Tocantins', 'TO', '17' FROM RDB$DATABASE
      UNION ALL SELECT 'Maranhão', 'MA', '21' FROM RDB$DATABASE
      UNION ALL SELECT 'Piauí', 'PI', '22' FROM RDB$DATABASE
      UNION ALL SELECT 'Ceará', 'CE', '23' FROM RDB$DATABASE
      UNION ALL SELECT 'Rio Grande do Norte', 'RN', '24' FROM RDB$DATABASE
      UNION ALL SELECT 'Paraíba', 'PB', '25' FROM RDB$DATABASE
      UNION ALL SELECT 'Pernambuco', 'PE', '26' FROM RDB$DATABASE
      UNION ALL SELECT 'Alagoas', 'AL', '27' FROM RDB$DATABASE
      UNION ALL SELECT 'Sergipe', 'SE', '28' FROM RDB$DATABASE
      UNION ALL SELECT 'Bahia', 'BA', '29' FROM RDB$DATABASE
      UNION ALL SELECT 'Minas Gerais', 'MG', '31' FROM RDB$DATABASE
      UNION ALL SELECT 'Espírito Santo', 'ES', '32' FROM RDB$DATABASE
      UNION ALL SELECT 'Rio de Janeiro', 'RJ', '33' FROM RDB$DATABASE
      UNION ALL SELECT 'São Paulo', 'SP', '35' FROM RDB$DATABASE
      UNION ALL SELECT 'Paraná', 'PR', '41' FROM RDB$DATABASE
      UNION ALL SELECT 'Santa Catarina', 'SC', '42' FROM RDB$DATABASE
      UNION ALL SELECT 'Rio Grande do Sul', 'RS', '43' FROM RDB$DATABASE
      UNION ALL SELECT 'Mato Grosso do Sul', 'MS', '50' FROM RDB$DATABASE
      UNION ALL SELECT 'Mato Grosso', 'MT', '51' FROM RDB$DATABASE
      UNION ALL SELECT 'Goiás', 'GO', '52' FROM RDB$DATABASE
      UNION ALL SELECT 'Distrito Federal', 'DF', '53' FROM RDB$DATABASE
     ) v;
COMMIT;

/* ------------------------------------------------------------
   Fim.
   ------------------------------------------------------------ */
