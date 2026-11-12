@echo off
REM ============================================================
REM ERP 2026 - Backup do banco Firebird (gbak)
REM
REM Uso:
REM   Scripts\backup_banco.bat
REM   Scripts\backup_banco.bat D:\Backups
REM
REM Variaveis opcionais (se nao definidas, usa o padrao de dev):
REM   ERP_DB_USER     (padrao SYSDBA)
REM   ERP_DB_PASSWORD (padrao masterkey)
REM   ERP_FB_BIN      (padrao C:\Program Files\Firebird\Firebird_5_0)
REM
REM Gera um arquivo DADOS_AAAAMMDD_HHMMSS.fbk na pasta de destino.
REM Nao apaga backups antigos; a retencao fica a cargo do operador.
REM ============================================================

setlocal

set "ROOT=%~dp0.."
set "ORIGEM=%ROOT%\Banco\DADOS.FDB"

if "%ERP_FB_BIN%"=="" set "ERP_FB_BIN=C:\Program Files\Firebird\Firebird_5_0"
set "GBAK=%ERP_FB_BIN%\gbak.exe"

if not exist "%GBAK%" (
  echo ERRO: gbak.exe nao encontrado em "%ERP_FB_BIN%".
  echo Defina ERP_FB_BIN com a pasta bin do Firebird.
  exit /b 2
)

if not exist "%ORIGEM%" (
  echo ERRO: banco nao encontrado: "%ORIGEM%"
  exit /b 2
)

set "DESTINO=%~1"
if "%DESTINO%"=="" set "DESTINO=%ROOT%\Backups"
if not exist "%DESTINO%" mkdir "%DESTINO%" >nul 2>&1
if not exist "%DESTINO%" (
  echo ERRO: nao foi possivel criar a pasta "%DESTINO%".
  exit /b 2
)

set "USUARIO=%ERP_DB_USER%"
if "%USUARIO%"=="" set "USUARIO=SYSDBA"
set "SENHA=%ERP_DB_PASSWORD%"
if "%SENHA%"=="" set "SENHA=masterkey"

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "STAMP=%%I"
if "%STAMP%"=="" set "STAMP=manual"

set "ARQUIVO=%DESTINO%\DADOS_%STAMP%.fbk"

echo.
echo Backup do banco ERP 2026
echo   Origem : %ORIGEM%
echo   Destino: %ARQUIVO%
echo.

"%GBAK%" -b -g -user "%USUARIO%" -password "%SENHA%" "%ORIGEM%" "%ARQUIVO%"
if errorlevel 1 (
  echo.
  echo ERRO: o gbak falhou. Backup NAO concluido.
  exit /b 1
)

if not exist "%ARQUIVO%" (
  echo.
  echo ERRO: arquivo de backup nao foi criado.
  exit /b 1
)

echo.
for %%A in ("%ARQUIVO%") do echo Backup concluido: %%~fA (%%~zA bytes)
exit /b 0
