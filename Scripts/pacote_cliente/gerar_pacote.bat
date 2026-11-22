@echo off
REM ============================================================
REM ERP 2026 - Gerador de pacote para o cliente
REM Monta Deploy\ERP2026_Cliente\ + ERP2026_Cliente.zip +
REM INSTALADOR.exe (auto-extraivel via IExpress, nativo do Windows)
REM
REM Uso:   gerar_pacote.bat            (usa os exes ja compilados)
REM        gerar_pacote.bat rebuild   (recompila desktop+API antes)
REM ============================================================
setlocal EnableDelayedExpansion
cd /d "%~dp0..\.."
set ROOT=%CD%
set KIT=%ROOT%\Deploy\ERP2026_Cliente
set ZIP=%ROOT%\Deploy\ERP2026_Cliente.zip
set SRC=%ROOT%\Scripts\pacote_cliente

if /i "%~1"=="rebuild" (
  echo === Recompilando Desktop ===
  call Scripts\build_desktop.bat || goto :erro
  echo === Recompilando API ===
  call Scripts\build_api.bat || goto :erro
)

if not exist "Desktop\bin\ERP2026.exe" ( echo ERRO: Desktop\bin\ERP2026.exe nao existe & goto :erro )
if not exist "API\bin\ERP2026API.exe"   ( echo ERRO: API\bin\ERP2026API.exe nao existe   & goto :erro )
if not exist "Banco\DADOS.FDB"          ( echo ERRO: Banco\DADOS.FDB nao existe         & goto :erro )

echo === Montando kit em %KIT% ===
if exist "%KIT%" rmdir /s /q "%KIT%"
mkdir "%KIT%\ERP2026" "%KIT%\API" "%KIT%\Banco"

REM ---------- Desktop ----------
echo Copiando ERP2026.exe + runtime...
xcopy /E /I /Y /Q "Desktop\bin\ERP2026.exe" "%KIT%\ERP2026\" >nul
for %%D in (libcrypto-3.dll libssl-3.dll libexslt.dll libiconv.dll libxml2.dll libxslt.dll) do (
  if exist "Desktop\bin\%%D" copy /Y "Desktop\bin\%%D" "%KIT%\ERP2026\" >nul
)
REM cliente Firebird embarcado (maquinas sem Firebird instalado)
for %%D in (fbclient.dll ib_util.dll icudt63.dll icudt63l.dat icuin63.dll icuuc63.dll msvcp140.dll msvcp140_1.dll vcruntime140.dll vcruntime140_1.dll zlib1.dll) do (
  if exist "C:\Program Files\Firebird\Firebird_5_0\%%D" copy /Y "C:\Program Files\Firebird\Firebird_5_0\%%D" "%KIT%\ERP2026\" >nul
)
for %%F in (nfe relatorios schemas xml gsunits) do (
  if exist "Desktop\bin\%%F" xcopy /E /I /Y /Q "Desktop\bin\%%F" "%KIT%\ERP2026\%%F\" >nul
)
if exist "Desktop\bin\lclstrconsts.pt_BR.po" copy /Y "Desktop\bin\lclstrconsts.pt_BR.po" "%KIT%\ERP2026\" >nul

REM ---------- API ----------
echo Copiando API...
copy /Y "API\bin\ERP2026API.exe" "%KIT%\API\" >nul
for %%D in (libcrypto-3.dll libssl-3.dll) do (
  if exist "API\bin\%%D" copy /Y "API\bin\%%D" "%KIT%\API\" >nul
)
for %%D in (fbclient.dll ib_util.dll icudt63.dll icudt63l.dat icuin63.dll icuuc63.dll msvcp140.dll msvcp140_1.dll vcruntime140.dll vcruntime140_1.dll zlib1.dll) do (
  if exist "C:\Program Files\Firebird\Firebird_5_0\%%D" copy /Y "C:\Program Files\Firebird\Firebird_5_0\%%D" "%KIT%\API\" >nul
)

REM ---------- Banco ----------
echo Copiando banco...
copy /Y "Banco\DADOS.FDB" "%KIT%\Banco\" >nul

REM ---------- Instalador ----------
echo Copiando instalador...
copy /Y "%SRC%\INSTALAR_CLIENTE.bat" "%KIT%\..\INSTALAR_CLIENTE.bat" >nul 2>&1
if not exist "%ROOT%\Deploy\INSTALAR_CLIENTE.bat" copy /Y "%SRC%\INSTALAR_CLIENTE.bat" "%ROOT%\Deploy\INSTALAR_CLIENTE.bat" >nul
copy /Y "%SRC%\LEIA-ME.txt" "%ROOT%\Deploy\LEIA-ME.txt" >nul

REM ---------- Zip ----------
echo Compactando...
powershell -NoProfile -Command "Compress-Archive -Path '%KIT%' -DestinationPath '%ZIP%' -Force"
if not exist "%ZIP%" ( echo ERRO ao gerar zip & goto :erro )

REM ---------- IExpress (instalador auto-extraivel) ----------
echo Gerando INSTALADOR.exe...
set SED=%ROOT%\Deploy\erp2026_cliente.sed
(
echo [Version]
echo Class=IEXPRESS
echo SEDVersion=3
echo [Options]
echo PackagePurpose=InstallApp
echo ShowInstallProgramWindow=0
echo HideExtractAnimation=1
echo UseLongFileName=1
echo InsideCompressed=0
echo CAB_Fixed_Root=1
echo RebootMode=N
echo InstallPrompt=Instalar ERP 2026 no cliente? ^(requer Windows^)
echo DisplayLicense=
echo FinishMessage=Instalacao concluida. Leia o LEIA-ME.txt.
echo TargetName=%ROOT%\Deploy\INSTALADOR.exe
echo FriendlyName=ERP 2026 - Pacote Cliente
echo AppLaunched=INSTALAR_CLIENTE.bat
echo PostInstallCmd=^<None^>
echo AdminQuietInstCmd=
echo UserQuietInstCmd=
echo SourceFiles=SourceFiles
echo [SourceFiles]
echo SourceFiles0=%ROOT%\Deploy\
echo [SourceFiles0]
echo %%FILE0%%=ERP2026_Cliente.zip
echo %%FILE1%%=INSTALAR_CLIENTE.bat
echo %%FILE2%%=LEIA-ME.txt
) > "%SED%"

i"%SystemRoot%\System32\iexpress.exe" /N /Q "%SED%"
if exist "%ROOT%\Deploy\INSTALADOR.exe" (
  echo.
  echo === PACOTE PRONTO ===
  echo   Kit:    %ZIP%
  echo   Setup:  %ROOT%\Deploy\INSTALADOR.exe
) else (
  echo AVISO: IExpress falhou - o ZIP esta pronto em %ZIP%
)
goto :fim
:erro
echo.
echo !!! FALHOU - veja erros acima !!!
exit /b 1
:fim
endlocal
