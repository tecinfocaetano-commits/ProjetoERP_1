/* ============================================================
   ERP 2026 - Dados fiscais de homologacao da Empresa Demo (ID 1)
   ------------------------------------------------------------
   Preenche APENAS campos vazios (COALESCE/NULLIF): nao sobrescreve
   dados reais ja cadastrados. Serve para exercitar a validacao
   local do XML da NF-e (ERP2026.exe --validar-nfe=<pedido>).
   Uso:
     isql -user SYSDBA -password masterkey Banco\DADOS.FDB ^
       -i Scripts\preparar_dados_nfe.sql
   ============================================================ */

UPDATE EMPRESA SET
  IE          = COALESCE(NULLIF(TRIM(IE), ''), '111111111111'),
  IM          = COALESCE(NULLIF(TRIM(IM), ''), '123456'),
  ENDERECO    = COALESCE(NULLIF(TRIM(ENDERECO), ''), 'Rua Teste'),
  NUMERO      = COALESCE(NULLIF(TRIM(NUMERO), ''), '100'),
  COMPLEMENTO = COALESCE(NULLIF(TRIM(COMPLEMENTO), ''), 'Sala 1'),
  BAIRRO      = COALESCE(NULLIF(TRIM(BAIRRO), ''), 'Centro'),
  CIDADE      = COALESCE(NULLIF(TRIM(CIDADE), ''), 'São Paulo'),
  UF          = COALESCE(NULLIF(TRIM(UF), ''), 'SP'),
  CEP         = COALESCE(NULLIF(TRIM(CEP), ''), '01001000'),
  TELEFONE    = COALESCE(NULLIF(TRIM(TELEFONE), ''), '1130001000'),
  /* 3 = Regime Normal (combina com o CST 00 do produto fiscal de teste) */
  CRT         = COALESCE(CRT, 3)
WHERE ID = 1
  AND CNPJ = '00000000000191';  /* so a Empresa Demo de teste */

COMMIT;
