@echo off
REM ============================================================
REM ERP 2026 - Instalador do pacote cliente
REM Descompacta o kit, pergunta o servidor e grava erp2026.ini.
REM O Firebird SERVER precisa estar instalado na maquina que
REM hospeda o banco; nas estacoes basta este pacote (fbclient
REM embarcado) + apontar o ini para o servidor.
REM ============================================================
setlocal EnableDelayedExpansion
cd /d "%~dp0"

echo.
echo === ERP 2026 - Instalacao do Cliente ===
echo.
set /p DIR="Pasta de destino [C:\ERP2026]: "
if "%DIR%"=="" set DIR=C:\ERP2026

if not exist "%DIR%" mkdir "%DIR%"
echo Descompactando em %DIR% ...
powershell -NoProfile -Command "Expand-Archive -Path '%~dp0ERP2026_Cliente.zip' -DestinationPath '%DIR%' -Force"
if errorlevel 1 (
  echo ERRO ao descompactar. Verifique se o zip esta na mesma pasta.
  pause
  exit /b 1
)

echo.
echo --- Configuracao do servidor ---
echo Deixe vazio se o banco estiver NESTE computador.
echo Se o banco estiver em outro PC da rede, informe o IP/nome.
set /p SRV="IP ou nome do servidor do banco (vazio = este PC): "
set /p APIURL="Endereco da API para os apps moveis [http://127.0.0.1:9000]: "
if "%APIURL%"=="" set APIURL=http://127.0.0.1:9000

REM erp2026.ini lido pelo uConexao/uApiSaude antes de conectar
(
echo [servidor]
echo banco_host=%SRV%
echo banco_porta=3050
echo banco_caminho=%DIR%\Banco\DADOS.FDB
echo api_url=%APIURL%
) > "%DIR%\ERP2026\erp2026.ini"

REM atalho da API na Inicializar do Windows (sobe no login)
powershell -NoProfile -Command "$s=[Environment]::GetFolderPath('Startup');$w=New-Object -ComObject WScript.Shell;$l=$w.CreateShortcut(\"$s\ERP2026 API.lnk\");$l.TargetPath='%DIR%\API\ERP2026API.exe';$l.WorkingDirectory='%DIR%';$l.WindowStyle=7;$l.Save()"

echo.
echo === Instalacao concluida ===
echo   Desktop: %DIR%\ERP2026\ERP2026.exe
echo   API:     %DIR%\API\ERP2026API.exe  (atalho criado no Inicializar)
echo   Banco:   %DIR%\Banco\DADOS.FDB
echo   Config:  %DIR%\ERP2026\erp2026.ini
echo.
echo NOTAS:
echo  - Se o banco ficar em OUTRO computador, ajuste banco_caminho
echo    no erp2026.ini para o caminho do .FDB NO SERVIDOR.
echo  - Para banco zerado, substitua DADOS.FDB antes de usar
echo    (ou rode Scripts\executar_banco.bat no projeto).
echo  - Senha do Firebird nesta instalacao: a do SYSDBA definida
echo    no ambiente (ERP_DB_USER/ERP_DB_PASSWORD).
echo.
pause
