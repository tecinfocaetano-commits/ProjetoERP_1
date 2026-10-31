@echo off
REM ============================================================
REM ERP 2026 - Build dos testes unitarios (Desktop)
REM Compila Desktop\Tests.lpi para Desktop\bin\Tests.exe
REM Executar com: Scripts\run_tests.bat
REM ============================================================
setlocal
set ROOT=%~dp0..
set LAZBUILD=C:\lazarus\lazbuild.exe

if not exist "%LAZBUILD%" (
  echo !!! lazbuild.exe nao encontrado em %LAZBUILD% !!!
  exit /b 1
)

"%LAZBUILD%" "%ROOT%\Desktop\Tests.lpi"
if errorlevel 1 goto :erro

REM Relatorios LazReport (.lrf): os testes de Modelo I/II conferem que os
REM 4 arquivos existem ao lado do Tests.exe (mesma copia do build_desktop).
if not exist "%ROOT%\Desktop\bin\relatorios" mkdir "%ROOT%\Desktop\bin\relatorios"
copy /Y "%ROOT%\Desktop\relatorios\*.lrf" "%ROOT%\Desktop\bin\relatorios\" >nul

echo.
echo === Testes compilados: Desktop\bin\Tests.exe ===
goto :fim

:erro
echo.
echo !!! ERRO ao compilar os testes !!!
exit /b 1

:fim
endlocal
