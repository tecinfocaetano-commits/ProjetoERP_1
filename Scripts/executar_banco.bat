@echo off
REM ============================================================
REM ERP 2026 - Script de Criação do Banco
REM Executar via isql do Firebird
REM ============================================================

SET ISQL="C:\Program Files\Firebird\Firebird_5_0\isql.exe"
SET DB="C:\Users\Charles\Documents\ProjetoERP_1\Banco\dados.fdb"
SET USER=SYSDBA
SET PASS=masterkey
SET BANCO_DIR=C:\Users\Charles\Documents\ProjetoERP_1\Banco

echo === ERP 2026 - Criando estrutura do banco ===
echo.

echo [1/6] Criando dominios...
%ISQL% %DB% -user %USER% -password %PASS% -input "%BANCO_DIR%\002_domains.sql"
if errorlevel 1 goto :erro

echo [2/6] Criando generators...
%ISQL% %DB% -user %USER% -password %PASS% -input "%BANCO_DIR%\003_generators.sql"
if errorlevel 1 goto :erro

echo [3/6] Criando tabelas...
%ISQL% %DB% -user %USER% -password %PASS% -input "%BANCO_DIR%\004_tables.sql"
if errorlevel 1 goto :erro

echo [4/6] Criando triggers...
%ISQL% %DB% -user %USER% -password %PASS% -input "%BANCO_DIR%\005_triggers.sql"
if errorlevel 1 goto :erro

echo [5/6] Criando indices...
%ISQL% %DB% -user %USER% -password %PASS% -input "%BANCO_DIR%\006_indexes.sql"
if errorlevel 1 goto :erro

echo [6/6] Inserindo dados iniciais...
%ISQL% %DB% -user %USER% -password %PASS% -input "%BANCO_DIR%\007_initial_data.sql"
if errorlevel 1 goto :erro

echo.
echo === Banco criado com sucesso! ===
echo.
echo Usuario admin: admin / admin123
echo.
pause
goto :fim

:erro
echo.
echo !!! ERRO na execucao. Verifique o log acima. !!!
echo.
pause

:fim
