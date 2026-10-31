/* ============================================================
   ERP 2026 - 013 - Permissoes das telas de administracao
   ------------------------------------------------------------
   Telas novas no menu principal (30/10/2026):
     - Sistema > Configuracoes    (SISTEMA/CONFIGURACOES)
     - Sistema > Permissoes       (SISTEMA/PERMISSOES)
     - Financeiro > Caixa         (FINANCEIRO/CAIXA)
     - Relatorios > Central       (RELATORIOS/CENTRAL_RELATORIOS)

   Grupo 1 = Administradores, tudo liberado (mesmo padrao do 012).
   Idempotente: NOT EXISTS - pode rodar mais de uma vez.
   Bancos novos ja recebem estas linhas pelo 007_initial_data.sql;
   este script e para bancos existentes (ex.: DADOS.FDB de dev).
   ============================================================ */

SET ECHO ON;

INSERT INTO PERMISSAO (GRUPO_ID, MODULO, TELA, PODE_VISUALIZAR, PODE_INSERIR,
                       PODE_EDITAR, PODE_EXCLUIR, PODE_IMPRIMIR)
SELECT 1, 'SISTEMA', 'CONFIGURACOES', 'S', 'S', 'S', 'S', 'S' FROM RDB$DATABASE
WHERE NOT EXISTS (SELECT 1 FROM PERMISSAO
                  WHERE GRUPO_ID = 1 AND MODULO = 'SISTEMA'
                    AND TELA = 'CONFIGURACOES');

INSERT INTO PERMISSAO (GRUPO_ID, MODULO, TELA, PODE_VISUALIZAR, PODE_INSERIR,
                       PODE_EDITAR, PODE_EXCLUIR, PODE_IMPRIMIR)
SELECT 1, 'SISTEMA', 'PERMISSOES', 'S', 'S', 'S', 'S', 'S' FROM RDB$DATABASE
WHERE NOT EXISTS (SELECT 1 FROM PERMISSAO
                  WHERE GRUPO_ID = 1 AND MODULO = 'SISTEMA'
                    AND TELA = 'PERMISSOES');

INSERT INTO PERMISSAO (GRUPO_ID, MODULO, TELA, PODE_VISUALIZAR, PODE_INSERIR,
                       PODE_EDITAR, PODE_EXCLUIR, PODE_IMPRIMIR)
SELECT 1, 'FINANCEIRO', 'CAIXA', 'S', 'S', 'S', 'S', 'S' FROM RDB$DATABASE
WHERE NOT EXISTS (SELECT 1 FROM PERMISSAO
                  WHERE GRUPO_ID = 1 AND MODULO = 'FINANCEIRO'
                    AND TELA = 'CAIXA');

INSERT INTO PERMISSAO (GRUPO_ID, MODULO, TELA, PODE_VISUALIZAR, PODE_INSERIR,
                       PODE_EDITAR, PODE_EXCLUIR, PODE_IMPRIMIR)
SELECT 1, 'RELATORIOS', 'CENTRAL_RELATORIOS', 'S', 'S', 'S', 'S', 'S' FROM RDB$DATABASE
WHERE NOT EXISTS (SELECT 1 FROM PERMISSAO
                  WHERE GRUPO_ID = 1 AND MODULO = 'RELATORIOS'
                    AND TELA = 'CENTRAL_RELATORIOS');

COMMIT;

SET ECHO OFF;
