@echo off
REM ============================================================
REM ERP 2026 - Restauracao do banco Firebird (gbak)
REM
REM Uso:
REM   Scripts\restaurar_banco.bat Backups\DADOS_AAAAMMDD_HHMMSS.fbk
REM   Scripts\restaurar_banco.bat arquivo.fbk D:\Banco\DADOS_NOVO.FDB
REM   Scripts\restaurar_banco.bat arquivo.fbk destino.fdb forcar
REM
REM Por seguranca, o destino padrao e Banco\DADOS_RESTAURADO.FDB e o
REM script NAO sobrescreve um arquivo existente sem o argumento "forcar".
REM Feche o ERP/API antes de restaurar sobre o banco em uso.
REM
REM Variaveis opcionais:
REM   ERP_DB_USER, ERP_DB_PASSWORD, ERP_FB_BIN
REM ============================================================

setlocal

set "ROOT=%~dp0.."

if "%~1"=="" (
  echo Uso: %~nx0 ^<arquivo.fbk^> [banco_destino.fdb] [forcar]
  exit /b 2
)

set "BACKUP=%~1"
if not exist "%BACKUP%" (
  echo ERRO: backup nao encontrado: "%BACKUP%"
  exit /b 2
)

if "%ERP_FB_BIN%"=="" set "ERP_FB_BIN=C:\Program Files\Firebird\Firebird_5_0"
set "GBAK=%ERP_FB_BIN%\gbak.exe"

if not exist "%GBAK%" (
  echo ERRO: gbak.exe nao encontrado em "%ERP_FB_BIN%".
  echo Defina ERP_FB_BIN com a pasta bin do Firebird.
  exit /b 2
)

set "DESTINO=%~2"
if "%DESTINO%"=="" set "DESTINO=%ROOT%\Banco\DADOS_RESTAURADO.FDB"

set "FORCAR="
if /I "%~3"=="forcar" set "FORCAR=1"

if exist "%DESTINO%" if not defined FORCAR (
  echo ERRO: o destino ja existe: "%DESTINO%"
  echo Use outro caminho ou informe "forcar" como terceiro argumento.
  exit /b 2
)

set "USUARIO=%ERP_DB_USER%"
if "%USUARIO%"=="" set "USUARIO=SYSDBA"
set "SENHA=%ERP_DB_PASSWORD%"
if "%SENHA%"=="" set "SENHA=masterkey"

echo.
echo Restauracao do banco ERP 2026
echo   Backup : %BACKUP%
echo   Destino: %DESTINO%
echo.

"%GBAK%" -c -user "%USUARIO%" -password "%SENHA%" "%BACKUP%" "%DESTINO%"
if errorlevel 1 (
  echo.
  echo ERRO: o gbak falhou. Banco NAO restaurado.
  exit /b 1
)

if not exist "%DESTINO%" (
  echo.
  echo ERRO: banco de destino nao foi criado.
  exit /b 1
)

echo.
echo Restauracao concluida: %DESTINO%
echo Feche o ERP/API, renomeie o banco antigo e aponte a configuracao
echo para o novo arquivo antes de reabrir o sistema.
exit /b 0
