@echo off
REM ============================================================
REM FIREBIRD - Alias do banco ERP 2026 no databases.conf
REM Execute como ADMINISTRADOR (botao direito -> Executar como admin)
REM
REM O que faz:
REM   - Faz backup de databases.conf
REM   - Adiciona o alias "erp2026" apontando para o DADOS.FDB
REM   - Depois disso e possivel conectar usando so "erp2026"
REM     como nome do banco (HostName=IP, Database=erp2026)
REM
REM O banco de SEGURANCA (usuarios/senhas do Firebird) ja esta
REM configurado de fabrica neste arquivo:
REM     security.db = $(dir_secDb)/security5.fdb
REM     { RemoteAccess = false }   <- ninguem acessa remotamente
REM Nao e preciso (nem recomendado) mexer nele.
REM ============================================================
net session >nul 2>&1
if errorlevel 1 (
  echo ERRO: execute este arquivo como Administrador.
  pause
  exit /b 1
)

set CONF=C:\Program Files\Firebird\Firebird_5_0\databases.conf
if not exist "%CONF%" (
  echo ERRO: databases.conf nao encontrado em %CONF%
  pause
  exit /b 1
)

REM >>> Ajuste este caminho se o banco estiver em outro lugar <<<
set BANCO=C:\Users\Charles\Documents\ProjetoERP_1\Banco\dados.fdb

findstr /c:"erp2026 =" "%CONF%" >nul
if not errorlevel 1 (
  echo Alias "erp2026" ja existe em databases.conf - nada a fazer.
  pause
  exit /b 0
)

if not exist "%BANCO%" (
  echo AVISO: o arquivo %BANCO% nao existe ainda.
  echo O alias sera criado mesmo assim - crie o banco depois
  echo ou ajuste a variavel BANCO neste script.
)

copy /y "%CONF%" "%CONF%.bak_erp" >nul
echo Backup criado: %CONF%.bak_erp

(
echo.
echo # ERP 2026 - alias do banco de dados
echo erp2026 = %BANCO%
) >> "%CONF%"

echo Alias adicionado:
echo   erp2026 = %BANCO%
echo.
echo Para usar: no erp2026.ini deixe banco_caminho=erp2026
echo e banco_host=IP_DA_MAQUINA_ONDE_O_FIREBIRD_RODA
echo.
echo O servico Firebird NAO precisa reiniciar - databases.conf
echo e relido a cada conexao.
pause
