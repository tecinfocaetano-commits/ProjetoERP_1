# ERP 2026 Bipe — app de bipagem de talões

App Android para o chão de fábrica: o operador bipa o código de barras
do talão (`TALAO.CODIGO_BARRAS`) e o sistema dá baixa na produção —
a mesma máquina de estados do `uFrmBipagem` do desktop.

## Como funciona

- **Login:** mesmas credenciais do ERP (`POST /api/login`). A URL do
  servidor é configurada na tela de login (ex.:
  `http://192.168.0.10:9000`). Se o mesmo login existir em mais de uma
  empresa, o campo opcional **Empresa (ID)** é enviado como
  `empresa_id` — exigência da API.
- **Isolamento do histórico:** o `empresa_id` do login fica salvo; se o
  aparelho trocar de empresa, o histórico SQLite é zerado para não
  misturar bipagens de empresas diferentes.
- **Bipagem:** quatro caminhos para o mesmo código:
  - leitor USB/Bluetooth — funciona como teclado; `Enter`, `Tab` ou
    `DPAD_CENTER` disparam a bipagem (a maioria usa Enter; alguns usam Tab);
  - digitação manual + Enter/botão BIPAR;
  - câmera (botão "Ler pela câmera", ZXing).
- **Erros HTTP:** respostas `{"error": "..."}` da API (400/401/500) são
  exibidas com a mensagem real — ex.: "login existe em mais de uma
  empresa, informe empresa_id".
- **Resposta da API** `POST /api/producao/bipar`:
  `OK` (talão avança GERADO/IMPRESSO→EM_PRODUCAO→CONCLUIDO),
  `DUPLICADO` (já concluído) e `INVALIDO` (não encontrado/cancelado),
  cada um com bipe sonoro diferente.
- **Modo offline:** sem rede, a bipagem entra numa fila local
  (`pendente` no `erp2026_bipe.db`, DB v2) com a hora do bipe — o
  operador não para. Ao voltar a rede (ou pelo botão "Enviar fila"),
  os códigos sobem em ordem FIFO para `POST /api/producao/bipar` com
  `origem=APP_BIPE_OFFLINE`; o resultado real do servidor entra no
  histórico com a hora original. Se a rede cair no meio, o restante
  continua na fila. "Zerar turno" limpa só o histórico — a fila de
  pendentes nunca é apagada (são bipagens de produção reais).
- **Histórico do servidor:** `GET /api/producao/bipagens?limite=N`
  lista as últimas bipagens da empresa (isolamento via
  `USUARIO.EMPRESA_ID`, pois `TALAO_BIPAGEM` não tem `EMPRESA_ID`).
- **Turno:** contadores OK/Duplicados/Inválidos/Fila + histórico das
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
