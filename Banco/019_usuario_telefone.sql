/* ============================================================
   ERP 2026 - 019 - TELEFONE em USUARIO
   ------------------------------------------------------------
   A tela de usuarios (uFrmUsuarios) ja exibia/grava o campo
   TELEFONE, mas a coluna nunca existiu em USUARIO — o INSERT/
   UPDATE da tela falhava com "column unknown". Coluna aditiva e
   nullable; nenhum dado existente e afetado.
   ============================================================ */

SET NAMES UTF8;
SET ECHO ON;

ALTER TABLE USUARIO ADD TELEFONE VARCHAR(20);

COMMIT;
