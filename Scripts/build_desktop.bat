@echo off
REM ============================================================
REM ERP 2026 - Build do Desktop (Lazarus)
REM Compila Desktop\ERP2026.lpi para Desktop\bin\ERP2026.exe
REM ============================================================
setlocal
set ROOT=%~dp0..
set LAZBUILD=C:\lazarus\lazbuild.exe

if not exist "%LAZBUILD%" (
  echo !!! lazbuild.exe nao encontrado em %LAZBUILD% !!!
  exit /b 1
)

"%LAZBUILD%" "%ROOT%\Desktop\ERP2026.lpi"
if errorlevel 1 goto :erro

echo.
echo === Desktop compilado: Desktop\bin\ERP2026.exe ===
echo (login: admin / admin123)
goto :fim

:erro
echo.
echo !!! ERRO ao compilar o Desktop !!!
exit /b 1

:fim
endlocal
