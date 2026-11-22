@echo off
REM ============================================================
REM ERP 2026 - Build do APK do app PDV mobile (:pdv)
REM Gera Android\android\pdv\build\outputs\apk\debug\pdv-debug.apk
REM Nao altera codigo Java/XML; apenas compila o modulo ja fechado.
REM ============================================================
setlocal
cd /d "%~dp0..\Android\android"

call gradlew.bat :pdv:assembleDebug --console=plain
if errorlevel 1 goto :erro

echo.
echo === APK DO PDV GERADO ===
echo Android\android\pdv\build\outputs\apk\debug\pdv-debug.apk
goto :fim

:erro
echo.
echo !!! ERRO ao compilar o APK DO PDV !!!
exit /b 1

:fim
endlocal
