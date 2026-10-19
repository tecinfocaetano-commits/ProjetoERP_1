@echo off
REM ============================================================
REM ERP 2026 - Compila e executa a suíte de testes unitários
REM O "echo." fornece o ENTER do pause final (modo não interativo).
REM ============================================================
setlocal
call "%~dp0build_tests.bat"
if errorlevel 1 exit /b 1

echo.
echo ============================================================
echo  EXECUTANDO SUITE DE TESTES
echo ============================================================
echo.| "%~dp0..\Desktop\bin\Tests.exe"
exit /b %ERRORLEVEL%
