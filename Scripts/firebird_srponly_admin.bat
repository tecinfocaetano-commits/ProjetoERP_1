@echo off
REM ============================================================
REM ENDURECER FIREBIRD — desativa Legacy_Auth (Srp256 apenas)
REM Execute como ADMINISTRADOR (botao direito -> Executar como admin)
REM Motivo: ALTER USER mudou a senha do SYSDBA no SRP, mas o
REM protocolo legado continuava aceitando 'masterkey'.
REM ============================================================
net session >nul 2>&1
if errorlevel 1 (
  echo ERRO: execute este arquivo como Administrador.
  pause
  exit /b 1
)

set CONF="C:\Program Files\Firebird\Firebird_5_0\firebird.conf"
if not exist %CONF% (
  echo ERRO: firebird.conf nao encontrado em %CONF%
  pause
  exit /b 1
)

findstr /c:"AuthServer = Srp256" %CONF% | findstr /v Legacy >nul
if errorlevel 1 (
  powershell -Command "(Get-Content 'C:\Program Files\Firebird\Firebird_5_0\firebird.conf') -replace 'AuthServer = Srp256, Legacy_Auth','AuthServer = Srp256' | Set-Content 'C:\Program Files\Firebird\Firebird_5_0\firebird.conf'"
  echo firebird.conf atualizado: AuthServer = Srp256
) else (
  echo firebird.conf ja estava com AuthServer = Srp256
)

echo Reiniciando servico Firebird...
net stop FirebirdServerDefaultInstance
net start FirebirdServerDefaultInstance

echo.
echo Pronto. Verificacao:
echo   1) isql com a senha NOVA deve conectar
   2) isql com 'masterkey' deve FALHAR
echo.
pause
