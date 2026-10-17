@echo off
REM ============================================================
REM ERP 2026 - Build do APK Android (debug)
REM Gera Android\android\app\build\outputs\apk\debug\app-debug.apk
REM ============================================================
setlocal
cd /d "%~dp0..\Android\android"

call gradlew.bat assembleDebug
if errorlevel 1 goto :erro

echo.
echo === APK gerado ===
echo Android\android\app\build\outputs\apk\debug\app-debug.apk
goto :fim

:erro
echo.
echo !!! ERRO ao compilar o APK !!!
exit /b 1

:fim
endlocal
