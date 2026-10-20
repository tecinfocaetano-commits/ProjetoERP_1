@echo off
REM ============================================================
REM ERP 2026 - Compila DumpSchema.exe (validacao de schema)
REM ============================================================
setlocal
set ROOT=%~dp0..
set FPC=C:\lazarus\fpc\3.2.2\bin\i386-win32\fpc.exe

"%FPC%" -Mobjfpc -Sh ^
  -Fu"%ROOT%\Desktop\src\Config" ^
  -FU"%ROOT%\Desktop\bin\gsunits" ^
  -FE"%ROOT%\Desktop\bin" ^
  "%ROOT%\Desktop\src\Tools\DumpSchema.lpr"
if errorlevel 1 goto :erro
echo === DumpSchema compilado ===
goto :fim
:erro
echo !!! ERRO ao compilar DumpSchema !!!
exit /b 1
:fim
endlocal
