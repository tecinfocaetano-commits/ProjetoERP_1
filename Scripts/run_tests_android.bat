@echo off
REM ============================================================
REM ERP 2026 - Testes unitarios do app Android (JVM + Robolectric)
REM Nao precisa de emulador: usa SQLite real via Robolectric e um
REM servidor HTTP falso local.
REM ============================================================
setlocal
cd /d "%~dp0..\Android\android"

call gradlew.bat testDebugUnitTest --console=plain
if errorlevel 1 goto :erro

echo.
echo === TESTES ANDROID OK ===
echo Relatorio: Android\android\app\build\reports\tests\testDebugUnitTest\index.html
goto :fim

:erro
echo.
echo !!! ERRO nos testes do Android !!!
exit /b 1

:fim
endlocal
