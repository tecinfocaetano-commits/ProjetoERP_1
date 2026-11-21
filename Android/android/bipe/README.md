# ERP 2026 Bipe — app de bipagem de talões

App Android para o chão de fábrica: o operador bipa o código de barras
do talão (`TALAO.CODIGO_BARRAS`) e o sistema dá baixa na produção —
a mesma máquina de estados do `uFrmBipagem` do desktop.

## Como funciona

- **Login:** mesmas credenciais do ERP (`POST /api/login`). A URL do
  servidor é configurada na tela de login (ex.:
  `http://192.168.0.10:9000`).
- **Bipagem:** três caminhos para o mesmo código:
  - leitor USB/Bluetooth — funciona como teclado, o `Enter` dispara;
  - digitação manual + Enter/botão BIPAR;
  - câmera (botão "Ler pela câmera", ZXing).
- **Resposta da API** `POST /api/producao/bipar`:
  `OK` (talão avança GERADO/IMPRESSO→EM_PRODUCAO→CONCLUIDO),
  `DUPLICADO` (já concluído) e `INVALIDO` (não encontrado/cancelado),
  cada um com bipe sonoro diferente.
- **Turno:** contadores OK/Duplicados/Inválidos + histórico das
  últimas 50 bipagens no SQLite local (`bipe.db`), que sobrevive a
  queda do app.

## Build

```bat
cd Android\android
gradlew.bat :bipe:assembleDebug
```

APK gerado em `bipe\build\outputs\apk\debug\bipe-debug.apk`.

Para instalar num aparelho com depuração USB:

```bat
gradlew.bat :bipe:installDebug
```

## Estrutura

```
bipe/src/main/java/com/example/erp2026_bipe/
  LoginActivity.java    login + URL do servidor
  BipagemActivity.java  tela de bipagem (teclado/câmera/Enter)
  ApiClient.java        POST JSON mínimo + Bearer token
  Sessao.java           token/URL em SharedPreferences
  BipeDb.java           histórico SQLite do turno
```

## Backend

O endpoint `POST /api/producao/bipar` vive em
`API/src/Rotas/uRotasProducao.pas` e executa
`uProducaoBipagem.ExecutarBipagemTalao` — a mesma unit que o desktop
usa em `TProducaoService.BiparTalao` (regra única, sem duplicação).
EMPRESA_ID/USUARIO_ID vêm do JWT; toda bipagem grava auditoria em
`TALAO_BIPAGEM` + `LOG_SISTEMA`.
