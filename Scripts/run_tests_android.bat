@echo off
REM ============================================================
REM ERP 2026 - Testes unitarios dos apps Android (JVM + Robolectric)
REM Abrange :app, :bipe e :pdv. Nao precisa de emulador: usa SQLite
REM real via Robolectric e um servidor HTTP falso local.
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
