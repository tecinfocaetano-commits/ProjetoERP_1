/* ============================================================
   ERP 2026 - 021 - ROLLBACK dos indices unicos (D9)
   ------------------------------------------------------------
   Remove apenas os tres indices. As duplicatas de PESSOA
   eliminadas pela migration NAO sao restauradas: use o backup
   gbak feito antes da aplicacao se precisar delas.
   ============================================================ */

SET NAMES UTF8;
SET ECHO ON;

DROP INDEX UQ_PESSOA_EMPRESA_TIPO_CPF;
DROP INDEX UQ_PEDIDO_VENDA_EMPRESA_NUMERO;
DROP INDEX UQ_USUARIO_EMPRESA_LOGIN;

COMMIT;
