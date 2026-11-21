/* ============================================================
   ERP 2026 - Migracao 022
   PDV - Pagamentos eletronicos (esqueleto multi-provedor)

   Tabela PAGAMENTO: intencao de cobranca com maquina de estados
     PENDENTE -> PROCESSANDO -> APROVADO | RECUSADO | CANCELADO | EXPIRADO

   Regras:
     - nenhuma PEDIDO_VENDA/MOVIMENTO_CAIXA e criada enquanto o
       pagamento nao estiver APROVADO (PEDIDO_VENDA_ID preenchido
       somente apos a finalizacao);
     - IDEMPOTENCY_KEY unica por empresa: retry/webhook duplicado
       nunca gera cobranca duplicada;
     - DADOS_JSON guarda o carrinho normalizado (itens + desconto)
       para a finalizacao da venda apos a aprovacao;
     - QR_PAYLOAD guarda o BR Code/EMV para PIX quando o provedor
       devolve copia-e-cola;
     - PROVEDOR e resolvido por configuracao (PAG_PROVIDER), nunca
       fixo no codigo;
     - usa somente dominios presentes no banco real (DM_ID, DM_NOME,
       DM_DESCRICAO, DM_VALOR, DM_STATUS, DM_DATA); colunas
       anulaveis usam BIGINT/TIMESTAMP/VARCHAR diretos.

   Execucao unica. Aplicar com:
     isql -u SYSDBA -p masterkey -charset UTF8 Banco\DADOS.FDB -i Banco\022_pdv_pagamentos.sql
   Reverter com:
     Banco\022_pdv_pagamentos_rollback.sql
   ============================================================ */

SET NAMES UTF8;
SET ECHO ON;

CREATE GENERATOR GEN_PAGAMENTO_ID;
COMMIT;

CREATE TABLE PAGAMENTO (
  ID                 DM_ID NOT NULL,
  EMPRESA_ID         DM_ID NOT NULL,
  USUARIO_ID         BIGINT,
  CAIXA_ID           BIGINT,
  FORMA_PAGAMENTO_ID BIGINT,
  PROVEDOR           VARCHAR(30) NOT NULL,
  TIPO_COBRANCA      VARCHAR(10),
  STATUS             VARCHAR(15) NOT NULL
    CONSTRAINT CK_PAG_STATUS CHECK (STATUS IN
      ('PENDENTE', 'PROCESSANDO', 'APROVADO', 'RECUSADO',
       'CANCELADO', 'EXPIRADO')),
  VALOR              DM_VALOR NOT NULL,
  DESCONTO           DM_VALOR DEFAULT 0,
  DADOS_JSON         VARCHAR(8000),
  IDEMPOTENCY_KEY    VARCHAR(80),
  PROVEDOR_TXID      VARCHAR(120),
  QR_PAYLOAD         VARCHAR(4000),
  QR_IMAGEM_URL      VARCHAR(500),
  PEDIDO_VENDA_ID    BIGINT,
  MOTIVO             VARCHAR(255),
  EXPIRA_EM          TIMESTAMP,
  CONFIRMADO_EM      TIMESTAMP,
  DATA_CADASTRO      TIMESTAMP,
  DATA_ALTERACAO     TIMESTAMP,
  OBSERVACOES        VARCHAR(500),
  PRIMARY KEY (ID),
  CONSTRAINT UQ_PAG_IDEMPOTENCIA UNIQUE (EMPRESA_ID, IDEMPOTENCY_KEY)
);
COMMIT;

CREATE INDEX IDX_PAG_EMP_STATUS ON PAGAMENTO (EMPRESA_ID, STATUS);
CREATE INDEX IDX_PAG_PROVEDOR_TXID ON PAGAMENTO (PROVEDOR, PROVEDOR_TXID);
CREATE INDEX IDX_PAG_PEDIDO ON PAGAMENTO (PEDIDO_VENDA_ID);
COMMIT;

SET TERM ^ ;

CREATE TRIGGER TRG_PAGAMENTO_BI FOR PAGAMENTO
ACTIVE BEFORE INSERT POSITION 0
AS
BEGIN
  IF (NEW.ID IS NULL OR NEW.ID = 0) THEN
    NEW.ID = GEN_ID(GEN_PAGAMENTO_ID, 1);
  IF (NEW.DATA_CADASTRO IS NULL) THEN
    NEW.DATA_CADASTRO = CURRENT_TIMESTAMP;
  NEW.DATA_ALTERACAO = CURRENT_TIMESTAMP;
END^

CREATE TRIGGER TRG_PAGAMENTO_BU FOR PAGAMENTO
ACTIVE BEFORE UPDATE POSITION 0
AS
BEGIN
  NEW.DATA_ALTERACAO = CURRENT_TIMESTAMP;
END^

SET TERM ; ^

COMMIT;
