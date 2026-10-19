# Testes Executados — 17/10/2026 (atualizado em 18/10/2026 — Módulo de Produção, Fases 0–7)

Bateria completa de testes do ERP 2026: **Desktop (16 telas)**, **API REST (transações)**,
**App Android (8 telas + transação real)** e, desde 18/10, o **Módulo de Produção
(suíte de testes unitários 49/49 + automação de UI da tela do Mapa)** — ver seção 7.

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

---

## 7. Módulo de Produção — Fases 0 a 7 (18/10/2026)

### 7.1 Suíte de testes unitários — 49/49

`Scripts\build_tests.bat` compila `Desktop\Tests.lpi` e `Scripts\run_tests.bat` executa
`Desktop\bin\Tests.exe` (o `echo.` satisfaz o pause final, permitindo rodar sem interação):

```
Total: 49 | Passou: 49 | Falhou: 0
```

São 39 testes da base (Login/Clientes/Produtos/Categorias/Usuários) + **10 novos de Produção**
(`src\Tests\uProducaoTest.pas`):

| Teste | O que valida |
|---|---|
| `TestTabelasProducaoExistem` | as 8 tabelas do script 012 existem |
| `TestSeedPermissoesProducao` | seed de `PERMISSAO` das 4 telas do módulo |
| `TestPermissaoAdminBypass` | administrador ignora `PERMISSAO` (bypass) |
| `TestPermissaoPorAcaoSemAdmin` | ação inválida e grupo sem registro ⇒ **negado** (fail-closed) |
| `TestAuditoriaUsaUsuarioDaSessao` | `LOG_SISTEMA` grava `USUARIO_ID`/`EMPRESA_ID` da sessão |
| `TestLogOperacaoServiceParametrizado` | `TServiceBase.LogOperacao`: SQL parametrizado (aspas simples sobrevivem) e usuário da sessão (**não 0**) |
| `TestImportarXmlGravaAuditoria` | `TACBrHelper.ImportarXML` audita com as colunas corretas (antes: *Column unknown*) |
| `TestProximoNumeroDoMapa` | numeração `MAX+1` por empresa devolve ≥ 1 |
| `TestCopilotoFluxoCaixaTipado` | `CAST` tipa `RECEBER_30D`/`PAGAR_30D` (SQLDB lia 0 sem tipo) |
| `TestTaloesComCodigoBarras` | talões existem com código de barras preenchido |

Os testes limpam o próprio rastro (`DELETE` + commit das linhas de `LOG_SISTEMA` que criam;
verificado: 0 linhas remanescentes `TESTE_UNITARIO`/`TESTE_SERVICE_LOG`/`XML_FISCAL`).

### 7.2 Automação de UI — tela do Mapa de Produção e relatórios (Fase 6)

Roda completa (login → tela → menu ▼ → preview → PDFs → editor), script `fase6_01.ps1`
(em `%TEMP%\opencode`, evidências em `Documentacao\evidencias\fase6_*.png`):

| Passo | Resultado |
|---|---|
| Tela Mapa de Produção (cmd 21) | OK — abre com os controles |
| Menu "Relatório ▼" (MSAA) | OK — 8 itens, incluindo os 3 novos da Fase 6 |
| Preview do relatório do mapa | OK — layout correto, acentos e decimais (`2,00`), datas `dd/mm/aaaa` |
| Exportar talões em PDF | OK — `taloes_mapa_1.pdf` (%PDF, diálogo "PDF gerado com sucesso") |
| Exportar mapa em PDF | OK — `mapa_1.pdf` (%PDF) |
| "Editar relatório (abrir editor)" | OK — janela **Designer - talao.lrf**; fecha (WM_CLOSE) e reabre; `.lrf` intocado (hash igual) |

Estrutura dos PDFs verificada por inspeção binária: **fontes TrueType embutidas** (Bold e
Regular, com tabelas `cmap`/`glyf`) e glifos acentuados no fluxo de conteúdo — acentos não
dependem de fonte do sistema.

### 7.3 Commits

| Fase | Commit | Conteúdo |
|---|---|---|
| 0+1 | `fce74f7` | reconhecimento, tabelas, permissões e tela do mapa |
| 2 | `bdad0a8` | itens do mapa e pedidos de produção |
| 3 | `091b7f8` | talões com código de barras (LazReport/Code128) |
| 4 | `a3d5832` | bipagem + relatório configurável + diálogos em português |
| 5 | `2954420` | ficha técnica e consumo de materiais com auditoria |
| 6 | `2eeb642` | relatório do mapa (preview/PDF), talões em PDF e editor (`lr_desgn`) |
| 7 | `90fdd44` | auditoria parametrizada + CAST no copiloto + testes de Produção |
