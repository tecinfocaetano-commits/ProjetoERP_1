@echo off
REM ============================================================
REM ERP 2026 - Prepara os recursos do ACBr para o Desktop
REM Copia schemas da NF-e e DLLs (OpenSSL/LibXml2) para bin
REM ============================================================
setlocal
set ROOT=%~dp0..
set ACBR=C:\ACBr
set DEST=%ROOT%\Desktop\bin

if not exist "%DEST%" mkdir "%DEST%"
if not exist "%DEST%\schemas" mkdir "%DEST%\schemas"
if not exist "%DEST%\nfe" mkdir "%DEST%\nfe"

if not exist "%ACBR%\Exemplos\ACBrDFe\Schemas\NFe" (
  echo !!! Schemas da NF-e nao encontrados em %ACBR% !!!
  exit /b 1
)

echo Copiando schemas da NF-e...
xcopy /E /I /Y "%ACBR%\Exemplos\ACBrDFe\Schemas\NFe\*.*" "%DEST%\schemas\" >nul
if errorlevel 1 goto :erro

echo Copiando OpenSSL (x86)...
if exist "%ACBR%\DLLs\OpenSSL\3.1.3\x86\*.dll" (
  copy /Y "%ACBR%\DLLs\OpenSSL\3.1.3\x86\*.dll" "%DEST%\" >nul
)

echo Copiando LibXml2 (x86)...
if exist "%ACBR%\DLLs\LibXml2\x86\*.dll" (
  copy /Y "%ACBR%\DLLs\LibXml2\x86\*.dll" "%DEST%\" >nul
)

echo.
echo === Recursos do ACBr copiados para Desktop\bin ===
goto :fim

:erro
echo.
echo !!! ERRO ao copiar os recursos do ACBr !!!
exit /b 1

:fim
endlocal
