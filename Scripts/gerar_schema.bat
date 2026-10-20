@echo off
REM ============================================================
REM ERP 2026 - Gera Banco\schema_canonico.sql a partir do DADOS.FDB
REM Compila Desktop\src\Tools\GerarSchema.lpr e executa.
REM Uso: Scripts\gerar_schema.bat [caminho\de\saida.sql]
REM ============================================================
setlocal

set ROOT=%~dp0..
set FPC=C:\lazarus\fpc\3.2.2\bin\i386-win32\fpc.exe

if not exist "%ROOT%\Desktop\bin" mkdir "%ROOT%\Desktop\bin"
if not exist "%ROOT%\Desktop\bin\gsunits" mkdir "%ROOT%\Desktop\bin\gsunits"

"%FPC%" -Mobjfpc -Sh ^
  -Fu"%ROOT%\Desktop\src\Config" ^
  -FU"%ROOT%\Desktop\bin\gsunits" ^
  -FE"%ROOT%\Desktop\bin" ^
  "%ROOT%\Desktop\src\Tools\GerarSchema.lpr"
if errorlevel 1 goto :erro

if "%~1"=="" (
  "%ROOT%\Desktop\bin\GerarSchema.exe" "%ROOT%\Banco\schema_canonico.sql"
) else (
  "%ROOT%\Desktop\bin\GerarSchema.exe" "%~1"
)
if errorlevel 1 goto :erro

echo.
echo === Schema canonico gerado ===
goto :fim

:erro
echo.
echo !!! ERRO ao gerar schema canonico !!!
exit /b 1

:fim
endlocal
