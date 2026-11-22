@echo off
REM ============================================================
REM ERP 2026 - Prepara os schemas da NFS-e Nacional para o Desktop
REM Copia apenas os XSD oficiais v1.01 para bin\schemas\nfse.
REM Nao sobrescreve nem mistura com os schemas da NF-e/NFC-e.
REM ============================================================
setlocal
set ROOT=%~dp0..
set ORIG=%ROOT%\Schemas\NFSe\1.01
set DEST=%ROOT%\Desktop\bin\schemas\nfse

if not exist "%ORIG%\DPS_v1.01.xsd" (
  echo !!! Schemas da NFS-e nao encontrados em %ORIG% !!!
  exit /b 1
)

if not exist "%DEST%" mkdir "%DEST%"
xcopy /E /I /Y "%ORIG%\*.xsd" "%DEST%\" >nul
if errorlevel 1 goto :erro

echo.
echo === Schemas da NFS-e v1.01 copiados para %DEST% ===
goto :fim

:erro
echo.
echo !!! ERRO ao copiar schemas da NFS-e !!!
exit /b 1

:fim
endlocal
