@echo off
REM ============================================================
REM ERP 2026 - Build da API REST (Horse + FPC)
REM Compila API\ERP2026API.lpr para API\bin\ERP2026API.exe
REM ============================================================
setlocal

set ROOT=%~dp0..
set FPC=C:\lazarus\fpc\3.2.2\bin\i386-win32\fpc.exe

if not exist "%ROOT%\API\bin" mkdir "%ROOT%\API\bin"
if not exist "%ROOT%\API\bin\units" mkdir "%ROOT%\API\bin\units"

"%FPC%" -Mobjfpc -Sh ^
  -Fu"%ROOT%\API\vendor\horse-src" ^
  -Fu"%ROOT%\API\src" ^
  -Fu"%ROOT%\API\src\Rotas" ^
  -Fu"%ROOT%\API\src\Middleware" ^
  -Fu"%ROOT%\API\src\Config" ^
  -Fu"%ROOT%\Desktop\src\Models" ^
  -FU"%ROOT%\API\bin\units" ^
  -FE"%ROOT%\API\bin" ^
  "%ROOT%\API\ERP2026API.lpr"

if errorlevel 1 goto :erro

echo.
echo === API compilada: API\bin\ERP2026API.exe ===
goto :fim

:erro
echo.
echo !!! ERRO ao compilar a API !!!
exit /b 1

:fim
endlocal
