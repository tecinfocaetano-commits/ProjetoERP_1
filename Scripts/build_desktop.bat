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

REM Relatorios LazReport (.lrf) - o exe carrega de bin\relatorios
if not exist "%ROOT%\Desktop\bin\relatorios" mkdir "%ROOT%\Desktop\bin\relatorios"
copy /Y "%ROOT%\Desktop\relatorios\*.lrf" "%ROOT%\Desktop\bin\relatorios\" >nul

REM Traducao dos dialogos do LCL (Sim/Nao) - o exe carrega de bin\
copy /Y "%ROOT%\Desktop\locale\*.po" "%ROOT%\Desktop\bin\" >nul

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
