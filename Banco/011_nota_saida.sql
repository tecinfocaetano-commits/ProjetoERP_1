/* ============================================================
   ERP 2026 - 011_nota_saida.sql
   ------------------------------------------------------------
   Módulo 2: NOTA DE SAÍDA (faturamento de venda)

   Cria:
     - NOTA_SAIDA        (documento de saída gerado a partir do
                          pedido de venda)
     - NOTA_SAIDA_ITEM   (itens, com dados fiscais)

   Fluxo:
     1) a nota é criada a partir de um PEDIDO_VENDA (status Aberta);
     2) ao Faturar, o service grava os MOVIMENTO_ESTOQUE de saída
        (TIPO = 'S'), gera as parcelas em CONTA_RECEBER e marca o
        pedido como Faturado;
     3) Cancelar/Estornar devolve o estoque (movimento inverso),
        cancela as parcelas em aberto e libera o pedido.

   Estrutura pronta para NF-e real: modelo/série/número, chave de
   acesso (44 dígitos com DV), protocolo e status SEFAZ.

   Observações:
     - O saldo de ESTOQUE é mantido pelo trigger TRG_MOVEST_AI;
     - Script ADITIVO e de uso único.

   Aplicar com:
     isql -u SYSDBA -p masterkey Banco\DADOS.FDB -i Banco\011_nota_saida.sql
   ============================================================ */

/* ------------------------------------------------------------
   1) GENERATORS
   ------------------------------------------------------------ */
CREATE GENERATOR GEN_NOTA_SAIDA_ID;
CREATE GENERATOR GEN_NOTA_SAIDA_ITEM_ID;

COMMIT;

/* ------------------------------------------------------------
   2) TABELAS
   ------------------------------------------------------------ */
CREATE TABLE NOTA_SAIDA (
  ID                     BIGINT NOT NULL PRIMARY KEY,
  EMPRESA_ID             BIGINT,
  CLIENTE_ID             BIGINT,
  PEDIDO_VENDA_ID        BIGINT,
  NUMERO                 VARCHAR(20),
  SERIE                  VARCHAR(5) DEFAULT '1',
  MODELO                 VARCHAR(3) DEFAULT '55',
  CHAVE_ACESSO           VARCHAR(44),
  PROTOCOLO              VARCHAR(20),
  NATUREZA_OPERACAO      VARCHAR(120) DEFAULT 'VENDA DE MERCADORIA',
  CFOP                   VARCHAR(4) DEFAULT '5102',
  DATA_EMISSAO           DATE,
  DATA_SAIDA             DATE,
  VALOR_PRODUTOS         NUMERIC(15,4) DEFAULT 0,
  VALOR_FRETE            NUMERIC(15,4) DEFAULT 0,
  VALOR_SEGURO           NUMERIC(15,4) DEFAULT 0,
  VALOR_OUTRAS           NUMERIC(15,4) DEFAULT 0,
  VALOR_DESCONTO         NUMERIC(15,4) DEFAULT 0,
  VALOR_ICMS             NUMERIC(15,4) DEFAULT 0,
  VALOR_TOTAL            NUMERIC(15,4) DEFAULT 0,
  STATUS                 VARCHAR(1) DEFAULT 'A',
  CONDICAO_PAGAMENTO_ID  BIGINT,
  FORMA_PAGAMENTO_ID     BIGINT,
  TRANSPORTADORA         VARCHAR(120),
  PESO_BRUTO             NUMERIC(15,3) DEFAULT 0,
  PESO_LIQUIDO           NUMERIC(15,3) DEFAULT 0,
  MODALIDADE_FRETE       VARCHAR(1) DEFAULT '9',
  XML_ARQUIVO            VARCHAR(255),
  OBSERVACOES            VARCHAR(255),
  MOTIVO_CANCELAMENTO    VARCHAR(255),
  USUARIO_ID             BIGINT,
  DATA_CADASTRO          TIMESTAMP,
  DATA_PROCESSAMENTO     TIMESTAMP,
  DATA_CANCELAMENTO      TIMESTAMP
);

/* STATUS: A = Aberta (aguardando faturamento)
           P = Processada (estoque baixado e contas a receber geradas)
           C = Cancelada                                    */

CREATE TABLE NOTA_SAIDA_ITEM (
  ID                  BIGINT NOT NULL PRIMARY KEY,
  NOTA_SAIDA_ID       BIGINT NOT NULL,
  PRODUTO_ID          BIGINT,
  CODIGO              VARCHAR(60),
  DESCRICAO           VARCHAR(120),
  UNIDADE             VARCHAR(6),
  NCM                 VARCHAR(8),
  CFOP                VARCHAR(4),
  CST_ICMS            VARCHAR(3),
  ALIQ_ICMS           NUMERIC(15,4) DEFAULT 0,
  VALOR_ICMS          NUMERIC(15,4) DEFAULT 0,
  QUANTIDADE          NUMERIC(15,4) DEFAULT 0,
  VALOR_UNITARIO      NUMERIC(15,4) DEFAULT 0,
  VALOR_TOTAL         NUMERIC(15,4) DEFAULT 0,
  DESCONTO            NUMERIC(15,4) DEFAULT 0,
  ATUALIZA_ESTOQUE    VARCHAR(1) DEFAULT 'S'
);

COMMIT;

/* ------------------------------------------------------------
   3) ÍNDICES
   ------------------------------------------------------------ */
CREATE INDEX IDX_NOTA_SAIDA_CLIENTE  ON NOTA_SAIDA (CLIENTE_ID);
CREATE INDEX IDX_NOTA_SAIDA_PEDIDO   ON NOTA_SAIDA (PEDIDO_VENDA_ID);
CREATE INDEX IDX_NOTA_SAIDA_DATA     ON NOTA_SAIDA (DATA_SAIDA);
CREATE INDEX IDX_NOTA_SAIDA_STATUS   ON NOTA_SAIDA (STATUS);
CREATE INDEX IDX_NOTA_SAIDA_ITEM_NOTA ON NOTA_SAIDA_ITEM (NOTA_SAIDA_ID);
CREATE INDEX IDX_NOTA_SAIDA_ITEM_PROD ON NOTA_SAIDA_ITEM (PRODUTO_ID);

COMMIT;

/* ------------------------------------------------------------
   4) TRIGGERS de auto-incremento
   ------------------------------------------------------------ */
SET TERM ^ ;

CREATE TRIGGER TRG_NOTA_SAIDA_BI FOR NOTA_SAIDA
ACTIVE BEFORE INSERT POSITION 0
AS
BEGIN
  IF (NEW.ID IS NULL OR NEW.ID = 0) THEN
    NEW.ID = GEN_ID(GEN_NOTA_SAIDA_ID, 1);
  IF (NEW.DATA_CADASTRO IS NULL) THEN
    NEW.DATA_CADASTRO = CURRENT_TIMESTAMP;
  IF (NEW.STATUS IS NULL) THEN
    NEW.STATUS = 'A';
END^

CREATE TRIGGER TRG_NOTA_SAIDA_ITEM_BI FOR NOTA_SAIDA_ITEM
ACTIVE BEFORE INSERT POSITION 0
AS
BEGIN
  IF (NEW.ID IS NULL OR NEW.ID = 0) THEN
    NEW.ID = GEN_ID(GEN_NOTA_SAIDA_ITEM_ID, 1);
END^

SET TERM ; ^

COMMIT;

/* ------------------------------------------------------------
   5) Vínculo com o financeiro
   A parcela gerada pelo faturamento guarda a nota de saída de
   origem, o que permite cancelar/estornar somente as parcelas
   daquele documento.
   ------------------------------------------------------------ */
ALTER TABLE CONTA_RECEBER ADD NOTA_SAIDA_ID BIGINT;

COMMIT;

CREATE INDEX IDX_CONTA_RECEBER_NOTA ON CONTA_RECEBER (NOTA_SAIDA_ID);

COMMIT;

/* Saldo do produto logo após a baixa (conferência do faturamento) */
ALTER TABLE NOTA_SAIDA_ITEM ADD SALDO_APOS NUMERIC(15,4);

COMMIT;

/* ------------------------------------------------------------
   Fim.
   ------------------------------------------------------------ */
