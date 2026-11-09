/* ============================================================
   ERP 2026 - 019 - ROLLBACK (TELEFONE em USUARIO)
   Remove a coluna TELEFONE adicionada por 019_usuario_telefone.sql.
   ATENCAO: apaga os telefones cadastrados — so use antes de
   colocar a tela de usuarios em producao.
   ============================================================ */

SET NAMES UTF8;
SET ECHO ON;

ALTER TABLE USUARIO DROP TELEFONE;

COMMIT;
