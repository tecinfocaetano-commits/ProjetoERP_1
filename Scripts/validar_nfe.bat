@echo off
REM ============================================================
REM ERP 2026 - Validacao local do XML da NF-e (sem SEFAZ)
REM
REM Uso:
REM   Scripts\validar_nfe.bat 1003
REM   Scripts\validar_nfe.bat 1003 C:\certificados\teste.pfx teste123
REM
REM Sem argumentos de certificado, usa ERP_NFE_CERT/ERP_NFE_SENHA
REM ou C:\certificados\teste.pfx com a senha teste123.
REM Gere o certificado de teste com:
REM   powershell -ExecutionPolicy Bypass -File Scripts\gerar_certificado_teste.ps1
REM ============================================================

setlocal
set EXE=%~dp0..\Desktop\bin\ERP2026.exe
set RESULTADO=%~dp0..\Desktop\bin\nfe\validacao_%~1.txt

if "%~1"=="" (
  echo Uso: %~nx0 ^<id do pedido^> [certificado.pfx] [senha]
  exit /b 2
)

set CERT=%~2
if "%CERT%"=="" set CERT=%ERP_NFE_CERT%
if "%CERT%"=="" set CERT=C:\certificados\teste.pfx

set SENHA=%~3
if "%SENHA%"=="" set SENHA=%ERP_NFE_SENHA%
if "%SENHA%"=="" set SENHA=teste123

if not exist "%EXE%" (
  echo Execute Scripts\build_desktop.bat antes.
  exit /b 2
)
if not exist "%CERT%" (
  echo Certificado nao encontrado: %CERT%
  echo Gere um de teste com Scripts\gerar_certificado_teste.ps1
  exit /b 2
)

"%EXE%" --validar-nfe=%~1 --cert="%CERT%" --senha="%SENHA%"

if exist "%RESULTADO%" (
  echo.
  type "%RESULTADO%"
)

endlocal
