# Testes Executados — 17/10/2026

Bateria completa de testes do ERP 2026: **Desktop (16 telas)**, **API REST (transações)** e
**App Android (8 telas + transação real)**.

Tudo rodou contra o mesmo banco Firebird `Banco/DADOS.FDB`, com o Desktop e a API ativos.

---

## 1. Ambiente

| Componente | Detalhe | Processo |
|---|---|---|
| Firebird | 5.0 (SYSDBA/masterkey), banco `Banco/DADOS.FDB` (UTF8) | serviço |
| API REST | `API/bin/ERP2026API.exe`, `http://localhost:9000` | PID 5696 |
| Desktop | `Desktop/bin/ERP2026.exe` (login `admin` / `admin123`) | PID 12344 |
| Android | Emulador `Pixel_9` (`emulator-5554`), APK `app-debug.apk` | PID 21636 |

---

## 2. Desktop — 16 telas (100% OK)

Todas as telas do menu principal foram abertas por automação Win32 (`WM_COMMAND`), fotografadas
e verificadas quanto a diálogos de erro, e fechadas com `WM_CLOSE`.

| # | Menu | Tela aberta | Resultado |
|---|---|---|---|
| 1 | Cadastros > Clientes | Clientes | OK |
| 2 | Cadastros > Fornecedores | Fornecedores | OK |
| 3 | Cadastros > Produtos | Produtos | OK |
| 4 | Cadastros > Categorias | Categorias | OK |
| 5 | Cadastros > Usuários | Usuários | OK |
| 6 | Estoque > Movimentação | Movimentação de Estoque | OK |
| 7 | Estoque > Inventário | Inventário de Estoque | OK |
| 8 | Estoque > Kardex | Kardex do Produto | OK |
| 9 | Vendas > Novo Pedido | Pedido de Venda | OK |
| 10 | Vendas > Novo Orçamento | Orçamento | OK |
| 11 | Vendas > Lista de Pedidos | Pedidos de Venda | OK |
| 12 | PDV > Abrir PDV | PDV - Ponto de Venda | OK |
| 13 | Financeiro > Contas a Receber | Contas a Receber | OK |
| 14 | Financeiro > Contas a Pagar | Contas a Pagar | OK |
| 15 | Fiscal > NF-e / NFC-e | NF-e / NFC-e - Notas Fiscais Eletrônicas | OK |
| 16 | IA Copiloto > Abrir Copiloto | Copiloto ERP - Assistente Inteligente | OK |

**PDV — abertura de caixa (fluxo completo):** com o caixa fechado, o PDV exibe o diálogo
"Abertura de Caixa"; informando um valor inicial e confirmando, o registro é gravado:

```
CAIXA  ID=2  USUARIO_ID=1  STATUS=A  VALOR_ABERTURA=150.0000  DATA_ABERTURA=2026-10-17
```

---

## 3. API REST — transações

| Requisição | Resultado |
|---|---|
| `POST /api/login` (admin/admin123) | **200** — devolve `token`, `usuario_id=1`, `nome=Administrador` |
| `GET /api/clientes` **sem** token | **401** (middleware JWT correto) |
| `GET /api/clientes` | 200 |
| `GET /api/produtos` | 200 |
| `GET /api/estoque` | 200 |
| `GET /api/vendas` | 200 |
| `GET /api/financeiro` | 200 |
| `GET /api/financeiro/receber` | 200 |
| `GET /api/financeiro/pagar` | 200 |
| `POST /api/clientes` | **201** — cliente `João API éTeste` (São Paulo/SP) gravado |
| `POST /api/produtos` | **201** — produto `APITEST1` gravado, ID **999** |
| `POST /api/estoque/movimento` (tipo `E`, 25) | **201** — `NF-API-1` |
| `POST /api/estoque/movimento` (tipo `S`, 5) | **201** — `NF-API-2` |
| `GET /api/estoque` | saldo do produto 999 = **20,00** (25 − 5) ✔ trigger acumulando |

### Acentuação (UTF-8) de ponta a ponta
Gravado pela API e lido de volta do banco:

```
CLIENTE ID=1237  NOME='João API éTeste'  CIDADE='São Paulo'
```

### Robustez (corrigido)
Corpo vazio ou JSON inválido devolvia **`{"error":"Access violation"}` (HTTP 500)** e derrubava o
parse. Agora as rotas de escrita validam o corpo e respondem **HTTP 400** com mensagem clara.

---

## 4. App Android — telas e transação

Fluxo executado por automação `adb` + `uiautomator`.

| Tela | Conteúdo exibido | Resultado |
|---|---|---|
| Login | campos `admin` / `admin123` + botão ENTRAR | OK |
| Dashboard | "Bem-vindo, Administrador!" + 6 módulos | OK |
| Clientes | 3 clientes do banco (inclui os criados via API) | OK |
| Inserir Cliente | formulário (Nome, CPF/CNPJ, Endereço, Cidade, UF, CEP, Telefone, E-mail) | OK |
| Consultar Clientes | `Total: 3 cliente(s)` com CPF, cidade, telefone e e-mail | OK |
| Estoque | `Produto via API` / `Cod: APITEST1` / `Qtd: 20.00` | OK |
| Vendas | `Pedido PED-001 - Maria Silva Teste / R$ 200.00 / Aprovado` | OK |
| Financeiro | Total a Receber / a Pagar + lista de contas | OK |

### Transação criada pelo app (app → API → banco)

Pela tela **Inserir Cliente**:

```
Cliente cadastrado com sucesso na API!
Nome: Cliente Mobile App
CPF: 111.222.333-44
```

Confirmado no banco:

```
CLIENTE ID=1238  NOME='Cliente Mobile App'  CIDADE='Curitiba'  UF='PR'
```

---

## 5. Correções aplicadas nesta rodada

| # | Arquivo | Problema | Correção |
|---|---|---|---|
| 1 | `Banco/009_completar_schema.sql` *(novo)* | 3 telas quebravam por tabelas/colunas/triggers ausentes e todo `INSERT` exigia ID manual (não havia triggers de auto-incremento) | Migração aditiva: +3 tabelas, ~70 colunas, 3 generators e 23 triggers (inclui `TRG_MOVEST_AI` acumulando estoque) |
| 2 | banco (009) | `FORMA_PAGAMENTO` e `CONDICAO_PAGAMENTO` foram criadas com `STATUS`, mas o código consulta `ATIVO` | Coluna `ATIVO CHAR(1) DEFAULT 'A'` (7 formas e 5 condições ativas) |
| 3 | `Desktop/.../uFrmPDV.pas` + `.lfm` | `edtCodigo.SetFocus` dentro do `FormCreate` → *"Can not focus"* | Foco movido para o novo `FormShow` (com guarda `CanFocus`) |
| 4 | `Desktop/.../uFrmPedidoVenda.pas` | `SELECT MAX(NUMERO)` com `NUMERO` textual (`'PED-001'`) → *"is an invalid integer"* | `ProximoNumero` percorre os números e ignora valores não numéricos |
| 5 | `API/src/Rotas/*.pas` (4 rotas) | corpo vazio/JSON inválido → *Access violation* (500) | Validação do corpo JSON com resposta **400** |

---

## 6. Evidências

- Desktop: `Documentacao/evidencias/desktop/` — 16 telas + diálogo de sucesso do caixa
- Android: `Documentacao/evidencias/android/` — 11 capturas (login → dashboard → módulos → cliente cadastrado)

Scripts de automação (fora do repositório, em `%TEMP%\opencode`): `test_telas.ps1`,
`test_pdv.ps1`, `test_api.ps1`, `android_lib.ps1`, `android_step1..3.ps1`.
