/* ============================================================
   ERP 2026 - Cenario fiscal de teste (NF-e)
   ------------------------------------------------------------
   Cria (ou reutiliza) um cliente, um produto, um produto fiscal
   e um pedido COMPLETOS para validar o XML da NF-e sem SEFAZ.
   Nao altera dados legados nem o produto 1 usado pela suite.

   Marcadores fixos (rodar de novo nao duplica):
     PESSOA.CPF_CNPJ      = 529.982.247-25
     PRODUTO.CODIGO       = CEN-FISCAL-01
     PRODUTO_FISCAL.CODIGO= CEN-FISCAL
     PEDIDO_VENDA.NUMERO  = CEN-FISCAL-01

   O cliente e de MG e o produto fiscal usa CFOP 6102, para
   exercitar tambem a operacao interestadual (empresa em SP).

   Uso:
     isql -user SYSDBA -password masterkey Banco\DADOS.FDB ^
       -i Scripts\preparar_cenario_fiscal.sql
   ============================================================ */

SET NAMES UTF8;
SET ECHO OFF;
SET TERM ^ ;

EXECUTE BLOCK RETURNS (PEDIDO_ID BIGINT)
AS
  DECLARE V_EMP BIGINT;
  DECLARE V_PESSOA BIGINT;
  DECLARE V_PRODUTO BIGINT;
  DECLARE V_PF BIGINT;
  DECLARE V_PEDIDO BIGINT;
  DECLARE V_ITEM BIGINT;
  DECLARE V_CIDADE BIGINT;
  DECLARE V_UNIDADE BIGINT;
  DECLARE V_CATEGORIA BIGINT;
  DECLARE V_FORMA BIGINT;
BEGIN
  V_EMP = 1;

  SELECT FIRST 1 C.ID
    FROM CIDADE C
    JOIN ESTADO E ON E.ID = C.ESTADO_ID
   WHERE C.NOME = 'Belo Horizonte' AND E.UF = 'MG'
    INTO :V_CIDADE;

  SELECT FIRST 1 ID FROM UNIDADE ORDER BY ID INTO :V_UNIDADE;
  SELECT FIRST 1 ID FROM CATEGORIA ORDER BY ID INTO :V_CATEGORIA;
  SELECT FIRST 1 ID FROM FORMA_PAGAMENTO WHERE TIPO = 'DI'
    INTO :V_FORMA;

  /* ---------------- Cliente completo ---------------- */
  SELECT ID FROM PESSOA
   WHERE EMPRESA_ID = :V_EMP AND CPF_CNPJ = '529.982.247-25'
    INTO :V_PESSOA;

  IF (V_PESSOA IS NULL) THEN
  BEGIN
    V_PESSOA = NEXT VALUE FOR GEN_PESSOA_ID;
    INSERT INTO PESSOA (
      ID, EMPRESA_ID, TIPO, TIPO_PESSOA, NOME, CPF_CNPJ, RG_IE,
      ENDERECO, NUMERO, COMPLEMENTO, BAIRRO, CIDADE, CIDADE_ID,
      UF, CEP, TELEFONE, EMAIL, ATIVO, DATA_CADASTRO)
    VALUES (
      :V_PESSOA, :V_EMP, 'C', 'F', 'Cliente Cenario Fiscal',
      '529.982.247-25', 'ISENTO', 'Rua da Bahia', '1000', 'Sala 2',
      'Centro', 'Belo Horizonte', :V_CIDADE, 'MG', '30110000',
      '3130001000', 'cenario.fiscal@teste.com', 'A', CURRENT_TIMESTAMP);
  END

  /* ---------------- Produto fiscal ---------------- */
  SELECT ID FROM PRODUTO_FISCAL
   WHERE EMPRESA_ID = :V_EMP AND CODIGO = 'CEN-FISCAL'
    INTO :V_PF;

  IF (V_PF IS NULL) THEN
  BEGIN
    V_PF = NEXT VALUE FOR GEN_PRODUTO_FISCAL_ID;
    INSERT INTO PRODUTO_FISCAL (
      ID, EMPRESA_ID, CODIGO, DESCRICAO, NCM, CEST, CFOP,
      CFOP_VENDA, CFOP_COMPRA, CST_ICMS, CST_PIS, CST_COFINS,
      ALIQ_ICMS, ALIQ_PIS, ALIQ_COFINS, PESO_LIQUIDO, PESO_BRUTO,
      ATIVO, DATA_CADASTRO)
    VALUES (
      :V_PF, :V_EMP, 'CEN-FISCAL', 'Mercadoria cenario fiscal',
      '61091000', '2806300', '6102', '6102', '2102',
      '00', '01', '01', 12.0000, 1.6500, 7.6000,
      0.3000, 0.3500, 'A', CURRENT_TIMESTAMP);
  END

  /* ---------------- Produto ---------------- */
  SELECT ID FROM PRODUTO
   WHERE EMPRESA_ID = :V_EMP AND CODIGO = 'CEN-FISCAL-01'
    INTO :V_PRODUTO;

  IF (V_PRODUTO IS NULL) THEN
  BEGIN
    V_PRODUTO = NEXT VALUE FOR GEN_PRODUTO_ID;
    INSERT INTO PRODUTO (
      ID, EMPRESA_ID, CATEGORIA_ID, UNIDADE_ID, CODIGO, DESCRICAO,
      PRECO_CUSTO, PRECO_VENDA, MARGEM_LUCRO, ESTOQUE_MINIMO,
      ESTOQUE_MAXIMO, CONTROLA_ESTOQUE, PRODUTO_FISCAL_ID, ATIVO,
      DATA_CADASTRO)
    VALUES (
      :V_PRODUTO, :V_EMP, :V_CATEGORIA, :V_UNIDADE, 'CEN-FISCAL-01',
      'Produto cenario fiscal', 25.0000, 50.0000, 100.0000,
      0.0000, 0.0000, 'N', :V_PF, 'A', CURRENT_TIMESTAMP);
  END

  /* ---------------- Pedido ---------------- */
  SELECT ID FROM PEDIDO_VENDA
   WHERE EMPRESA_ID = :V_EMP AND NUMERO = 'CEN-FISCAL-01'
    INTO :V_PEDIDO;

  IF (V_PEDIDO IS NULL) THEN
  BEGIN
    V_PEDIDO = NEXT VALUE FOR GEN_PEDIDO_VENDA_ID;
    INSERT INTO PEDIDO_VENDA (
      ID, EMPRESA_ID, CLIENTE_ID, USUARIO_ID, NUMERO, DATA_EMISSAO,
      STATUS, SUBTOTAL, DESCONTO, TOTAL, OBSERVACOES,
      FORMA_PAGAMENTO_ID)
    VALUES (
      :V_PEDIDO, :V_EMP, :V_PESSOA, 1, 'CEN-FISCAL-01',
      CURRENT_DATE, 'A', 100.0000, 0.0000, 100.0000,
      'Cenario fiscal de teste', :V_FORMA);
  END

  /* ---------------- Item ---------------- */
  SELECT ID FROM ITEM_PEDIDO
   WHERE PEDIDO_VENDA_ID = :V_PEDIDO AND PRODUTO_ID = :V_PRODUTO
    INTO :V_ITEM;

  IF (V_ITEM IS NULL) THEN
  BEGIN
    V_ITEM = NEXT VALUE FOR GEN_ITEM_PEDIDO_ID;
    INSERT INTO ITEM_PEDIDO (
      ID, PEDIDO_VENDA_ID, PRODUTO_ID, QUANTIDADE, PRECO_UNITARIO,
      VALOR_TOTAL, DESCONTO, VALOR_UNITARIO)
    VALUES (
      :V_ITEM, :V_PEDIDO, :V_PRODUTO, 2.0000, 50.0000,
      100.0000, 0.0000, 50.0000);
  END

  PEDIDO_ID = V_PEDIDO;
  SUSPEND;
END ^

SET TERM ; ^

COMMIT;
