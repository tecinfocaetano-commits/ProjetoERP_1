@echo off
REM ============================================================
REM ERP 2026 - Script de Criacao do Banco
REM
REM CONSOLIDADO: a estrutura vem toda de Banco\schema_canonico.sql
REM (gerado do banco real por Scripts\gerar_schema.bat), que recria
REM as 34 tabelas + 34 generators + 111 constraints + 36 triggers.
REM
REM O caminho antigo (002 -> 003 -> 004 -> 005 -> 006) ficava com
REM 22 das 34 tabelas e precisava dos remendos 008..012; ele nao e
REM mais executado aqui. 004_tables.sql e banco_simplificado.sql
REM continuam no repositorio apenas como historico.
REM
REM Uso:
REM   executar_banco.bat            cria banco novo (falha se ja existir)
REM   executar_banco.bat /recriar   apaga e recria dados.fdb
REM ============================================================

SET ISQL="C:\Program Files\Firebird\Firebird_5_0\isql.exe"
SET DBPATH=C:\Users\Charles\Documents\ProjetoERP_1\Banco\dados.fdb
SET USER=SYSDBA
SET PASS=masterkey
SET BANCO_DIR=C:\Users\Charles\Documents\ProjetoERP_1\Banco

echo === ERP 2026 - Criando estrutura do banco ===
echo.

if /I "%~1"=="/recriar" goto :recriar

if exist "%DBPATH%" (
  echo O banco "%DBPATH%" ja existe.
  echo.
  echo Para recriar do zero:  executar_banco.bat /recriar
  echo Estrutura existente ja esta completa (ver Banco\schema_canonico.sql).
  goto :fim
)

echo [1/3] Criando banco e estrutura completa...
%ISQL% -user %USER% -password %PASS% -i "%BANCO_DIR%\schema_canonico.sql" -q
if errorlevel 1 goto :erro

goto :sementes

:recriar
echo [0/3] Removendo banco anterior...
if exist "%DBPATH%" del "%DBPATH%"
if exist "%DBPATH%.SL" del "%DBPATH%.SL"
if exist "%DBPATH%.FL" del "%DBPATH%.FL"
if exist "%DBPATH%.FDB" del "%DBPATH%.FDB"

echo [1/3] Criando banco e estrutura completa...
%ISQL% -user %USER% -password %PASS% -i "%BANCO_DIR%\schema_canonico.sql" -q
if errorlevel 1 goto :erro

:sementes
echo [2/3] Inserindo dados iniciais...
%ISQL% "%DBPATH%" -user %USER% -password %PASS% -i "%BANCO_DIR%\007_initial_data.sql"
if errorlevel 1 goto :erro

echo [3/3] Verificando estrutura...
SET CONTA=%TEMP%\erp_conta_tabelas.sql
echo SELECT COUNT(*) AS TABELAS FROM RDB$RELATIONS WHERE COALESCE(RDB$SYSTEM_FLAG,0)=0 AND RDB$VIEW_BLR IS NULL ;> "%CONTA%"
echo COMMIT ;>> "%CONTA%"
%ISQL% "%DBPATH%" -user %USER% -password %PASS% -i "%CONTA%" -q
del "%CONTA%"

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
exit /b 1

:fim
