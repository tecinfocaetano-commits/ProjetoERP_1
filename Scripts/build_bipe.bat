@echo off
REM ============================================================
REM ERP 2026 - Build do APK do app de bipagem de talao (:bipe)
REM Gera Android\android\bipe\build\outputs\apk\debug\bipe-debug.apk
REM Nao altera codigo Java/XML; apenas compila o modulo ja fechado.
REM ============================================================
setlocal
cd /d "%~dp0..\Android\android"

call gradlew.bat :bipe:assembleDebug --console=plain
if errorlevel 1 goto :erro

echo.
echo === APK DO BIPE GERADO ===
echo Android\android\bipe\build\outputs\apk\debug\bipe-debug.apk
goto :fim

:erro
echo.
echo !!! ERRO ao compilar o APK do BIPE !!!
exit /b 1

:fim
endlocal
