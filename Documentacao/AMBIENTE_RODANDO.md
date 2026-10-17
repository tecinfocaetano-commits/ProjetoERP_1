# ERP 2026 — Ambiente rodando (17/10/2026)

Guia do que está funcionando, como subir cada parte e as correções aplicadas.

---

## Arquitetura

```
┌──────────────────────┐        ┌──────────────────────┐
│  Desktop (Lazarus)   │        │  Android (Java)      │
│  ERP2026.exe         │        │  app-debug.apk       │
└──────────┬───────────┘        └──────────┬───────────┘
           │ IBConnection                  │ HTTP/JSON
           │ (porta 3050)                  │ (porta 9000)
           ▼                               ▼
┌──────────────────────┐        ┌──────────────────────┐
│  Firebird 5          │◄───────│  API REST (Horse/FPC)│
│  Banco\dados.fdb     │        │  ERP2026API.exe      │
└──────────────────────┘        └──────────────────────┘
```

| Componente | Tecnologia | Porta / caminho |
|---|---|---|
| Banco | Firebird 5.0 | 3050 — `Banco\dados.fdb` |
| Desktop | Lazarus/FPC 3.2.2 (i386) | `Desktop\bin\ERP2026.exe` |
| API | Horse 3.3.14 + FPC | 9000 — `API\bin\ERP2026API.exe` |
| App | Android (Gradle 8.11 / JDK 17) | emulador `Pixel_9` |

---

## Credenciais

| O quê | Usuário | Senha |
|---|---|---|
| ERP (Desktop e App) | `admin` | `admin123` |
| Firebird (SYSDBA) | `SYSDBA` | `masterkey` |

---

## Como subir

```bat
REM 1) API (deixe a janela aberta)
Scripts\run_api.bat            REM ou: Scripts\build_api.bat  e depois API\bin\ERP2026API.exe

REM 2) Desktop
Desktop\bin\ERP2026.exe        REM login: admin / admin123

REM 3) Android
Scripts\build_android.bat      REM gera o APK
"C:\Users\Charles\AppData\Local\Android\Sdk\platform-tools\adb.exe" install -r ^
   Android\android\app\build\outputs\apk\debug\app-debug.apk
```

Scripts de build:

| Script | O que faz |
|---|---|
| `Scripts\build_desktop.bat` | Compila o Desktop (`lazbuild`) |
| `Scripts\build_api.bat` | Compila a API (fpc + Horse) |
| `Scripts\build_android.bat` | Gera o APK de debug |
| `Scripts\run_api.bat` | Sobe a API na porta 9000 |
| `Scripts\executar_banco.bat` | Recria a estrutura do banco |
| `Banco\fix_generators.sql` | Sincroniza os generators com o maior ID |
| `Banco\009_completar_schema.sql` | Migração aditiva: completa o schema (tabelas, colunas, generators e 23 triggers de auto-incremento) |

---

## Endpoints da API

Todas as rotas (exceto o login) exigem `Authorization: Bearer <token>`.

| Método | Rota | Descrição |
|---|---|---|
| POST | `/api/login` | Autentica e devolve `token` + dados do usuário |
| GET | `/api/clientes` | Lista clientes |
| GET | `/api/clientes/:id` | Detalha um cliente |
| POST | `/api/clientes` | Cadastra cliente |
| GET | `/api/produtos` | Lista produtos |
| GET | `/api/produtos/:id` | Detalha um produto |
| POST | `/api/produtos` | Cadastra produto |
| GET | `/api/estoque` | Posição de estoque |
| POST | `/api/estoque/movimento` | Registra movimento de estoque |
| GET | `/api/vendas` | Lista pedidos de venda |
| GET | `/api/vendas/:id` | Detalha pedido + itens |
| GET | `/api/financeiro` | Resumo (a receber / recebido / a pagar / pago) |
| GET | `/api/financeiro/receber` | Contas a receber |
| GET | `/api/financeiro/pagar` | Contas a pagar |

Teste rápido:

```bat
curl -X POST http://localhost:9000/api/login -H "Content-Type: application/json" ^
     -d "{\"login\":\"admin\",\"senha\":\"admin123\"}"
```

---

## O que foi corrigido nesta rodada

### Build
1. **Caminhos fixos** apontavam para `ProjetoERP\` — ajustados para `ProjetoERP_1\` em 43 arquivos.
2. **`uFrmMovEstoque`, `uFrmKardex`, `uFrmContasPagar`, `uFrmContasReceber`, `uFrmListaPedidos`**: blocos `try/except` duplicados por uma edição interrompida — removidos.
3. **`edtInicio`/`edtFim` vs `edtDataInicio`/`edtDataFim`**: nomes divergentes entre `.pas` e `.lfm` em 3 forms — alinhados ao `.lfm`.
4. **Horse vendorizado** em `API\vendor\horse-src` (a API não dependia de pacote instalado no Lazarus).
5. **`-O1` removido** do build da API (provocava `Internal error 200510011` no FPC).
6. **JDBC/Jaybird removido** do app — inviável no Android 34; substituído por HTTP.

### Banco / API
7. **Login da API** usava MD5 e `ATIVO = 'S'`; o banco tem senha em texto e `ATIVO = 'A'` — alinhado (o Desktop já funcionava assim).
8. **Middleware JWT** bloqueava `/api/login` — agora libera a rota pública.
9. **Colunas inexistentes** nas consultas: `STATUS` → `ATIVO` (cliente), `VALOR_UNITARIO` → `PRECO_UNITARIO` (item do pedido).
10. **`NUMERO` do pedido** é texto (`PED-001`) e era lido como inteiro — corrigido.
11. **INSERTs sem chave primária**: não existem triggers no banco; os inserts passaram a usar `GEN_ID(GEN_*_ID, 1)` (cliente, produto, movimento de estoque).
12. **`CATEGORIA_ID`/`UNIDADE_ID`** em PRODUTO são `NOT NULL` (domínio `DM_ID`) — passaram a ser preenchidos.
13. **Generators zerados**: novos registros recebiam IDs 1, 2, 3... podendo colidir com os existentes. Sincronizados com o maior ID (`Banco\fix_generators.sql`).
14. **Transação SNAPSHOT**: a API mantinha uma transação aberta e devolvia dados obsoletos (um cliente criado por outro programa não aparecia). Agora usa `READ COMMITTED` — mesma correção aplicada ao Desktop.

### Codificação (acentuação)
15. A API devolvia bytes CP1252 (ex.: `E3` em vez de `C3 A3`) e o JSON era lido como UTF-8, exibindo `Jo?o`.
    - **API**: não define mais `CharSet = 'UTF8'` — recebe os bytes UTF-8 crus do Firebird.
    - **Desktop**: mantém `CharSet = 'UTF8'` (é o que faz o Windows renderizar os acentos corretamente).

### App Android
16. Login real contra a API (token JWT) em vez de credenciais fixas.
17. Telas de Clientes, Estoque, Vendas e Financeiro consomem a API de verdade; "Consultar" e "Diagnóstico" também.
18. Novo `ApiClient.java` (HttpURLConnection + `org.json`, sem dependências externas).
19. `DatabaseHelper.java` (JDBC) removido.

### Migração 009 — schema completo (rodada de 17/10/2026)
20. **Schema incompleto**: o banco em uso era o simplificado (`banco_simplificado.sql`), sem várias tabelas/colunas usadas pelas telas. Corrigido em `Banco\009_completar_schema.sql` (+3 tabelas, ~70 colunas, 3 generators).
21. **Nenhum trigger de auto-incremento existia** — todo `INSERT` precisava informar o ID. Foram criados 23 triggers `TRG_*_BI`, e o `TRG_MOVEST_AI` **soma** a quantidade ao saldo de `ESTOQUE` (versão corrigida; a de `005_triggers.sql` sobrescrevia o saldo).
22. **`FORMA_PAGAMENTO`/`CONDICAO_PAGAMENTO`** foram criadas com `STATUS`, mas o código consulta `ATIVO` — coluna `ATIVO CHAR(1) DEFAULT 'A'` adicionada (7 formas e 5 condições ativas).
23. **`uFrmPDV`**: `edtCodigo.SetFocus` dentro do `FormCreate` levantava *"Can not focus"* — movido para o novo `FormShow`.
24. **`uFrmPedidoVenda.ProximoNumero`**: `MAX(NUMERO)` sobre coluna de texto (`PED-001`) causava *"is an invalid integer"* — agora ignora valores não numéricos.
25. **Rotas de escrita da API** (login, clientes, produtos, estoque): corpo vazio/JSON inválido causava *Access violation* (HTTP 500) — agora validam o corpo e respondem **400**.

> O `009_completar_schema.sql` **não é idempotente** (`CREATE`/`ALTER` puros) e **já foi aplicado** em
> `Banco\DADOS.FDB`. Para reaplicar, restaure antes o backup `Banco\DADOS_backup_antes_009.fdb`.

---

## Verificação executada

| Teste | Resultado |
|---|---|
| Suíte de testes do Desktop (`Desktop\bin\Tests.exe`) | 39/39 passaram |
| **Desktop — 16 telas do menu** | **16/16 abrem sem erro** |
| **Desktop — PDV abertura de caixa** | grava `CAIXA` (ID 2, valor 150) |
| Endpoints GET da API | 200 em todos |
| Endpoints POST da API | 201 em todos |
| Rota protegida sem token | 401 |
| **API — movimento de estoque (E 25 / S 5)** | saldo final **20** |
| **API — corpo vazio/inválido** | **400** (antes: 500 / *Access violation*) |
| Acentuação (ida e volta, App e API) | correta |
| Desktop abrindo | janela "ERP 2026" exibida |
| **App no emulador — 8 telas** | **todas com dados reais do banco** |
| **App no emulador — cadastro de cliente** | grava `CLIENTE` ID 1238 |

Relatório detalhado com evidências: [`TESTES_EXECUTADOS.md`](TESTES_EXECUTADOS.md)

---

## Observações / pendências sugeridas

- **Senhas em texto puro** no banco. O ideal é migrar Desktop, API e semente para SHA-256 (as três pontas mudam juntas).
- **`uClienteService.pas`** monta SQL com `Format` (risco de injeção) — usar parâmetros, como já é feito na API.
- **`uMiddlewareJWT.pas`** rotula o token como HS256, mas usa um HMAC simplificado próprio. Trocar por uma implementação HS256 real (ou remover o rótulo).
- A API usa **uma única conexão** (servidor não threaded). Para produção, usar pool de conexões.
- `Banco\004_tables.sql` e `Banco\banco_simplificado.sql` divergem do banco real — vale consolidar num único script.
