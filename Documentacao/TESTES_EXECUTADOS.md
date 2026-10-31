# Testes Executados - 17/10/2026 (atualizado em 30/10/2026 - Modelos I/II dos relatórios e pool de conexões da API)

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

Roda completa (login → tela → menu ▼ → preview → PDFs → editor), script
`Scripts\testes\fase6_01.ps1` (autônomo — não depende do `%TEMP%`; evidências em
`Documentacao\evidencias\fase6_*.png`):

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

## 8. Pendência — senhas em SHA-256 (19/10/2026)

A senha de usuário deixa de ser guardada em texto puro: Desktop, API e semente
passaram a guardar **SHA-256** (hex de 64 chars).

- **Unit nova**: `Desktop\src\Utils\uSenhaHash.pas` — SHA-256 em Pascal puro
  (FIPS 180-4). A instalação do FPC 3.2.2 usada pelo projeto não traz a unit
  `sha256` do pacote hash (só md5/sha1), e a regra é não instalar pacotes
  novos. É a mesma unit para o Desktop e para a API (o build da API ganhou o
  caminho `-Fu Desktop\src\Utils`).
- **Login (Desktop e API)**: a senha não entra mais no `WHERE`; a busca é por
  `LOGIN` + `ATIVO='A'` e a comparação é feita em código via `SenhaConfere`.
  **Migração progressiva**: senha antiga em texto puro ainda autentica e é
  regravada como hash no próprio login (bem-sucedido).
- **Cadastro de usuários** (`uFrmUsuarios`): INSERT/UPDATE gravam `HashSenha`.
- **Sementes** (`007_initial_data.sql`, `banco_simplificado.sql`,
  `script_simplificado.sql`): `admin` com o hash de `admin123`
  (`240be518...720a9`).
- **Banco real**: `UPDATE` do `admin` para o hash já aplicado em `DADOS.FDB`.

Verificações desta rodada:

| Verificação | Resultado |
|---|---|
| `Scripts\build_desktop.bat` | compila |
| `Scripts\build_api.bat` | compila |
| `Scripts\run_tests.bat` | **53/53** (49 + 4 novos de SHA-256: vetores `admin123`/`abc`, `EhHashSHA256`, migração legada→hash) |
| API `POST /api/login` admin/admin123 | HTTP **200** com token |
| API senha errada / usuário inexistente | HTTP **401** |
| Migração via API (senha voltada a texto puro → login → reconsulta) | regravada como hash ✓ |
| `Scripts\testes\fase6_01.ps1` (login admin/admin123 pela UI) | **FASE6-01 CONCLUIDO** |

---

## Parametrização do `uClienteService` e JWT com HS256 real (19/10/2026)

Duas pendências de segurança fechadas nesta rodada.

**1. Queries parametrizadas no Desktop.** `uRepositoryBase` ganhou `InserirParam`,
`AtualizarParam`, `BuscarTodosParam` e `ContarParam` (valores aplicados por
`ParamByName`). No `uClienteService`, `CpfCnpjExiste`, `Inserir`, `Atualizar`,
`Pesquisar` e `BuscarTodos` deixaram de montar SQL com `Format`. O caso mais grave
era o `Pesquisar`, que interpolava o termo **três vezes** em `CONTAINING '%s'` —
um apóstrofo no nome já quebrava a consulta. `BuscarTodos` filtrava por
`Connection.Tag` (sempre 0, resultando em lista vazia) e passou a usar a empresa
da sessão (`TSessao.GetInstance.EmpresaId`).

- **Teste novo**: `TestServiceClienteApostrofo` — insere o nome `D'Ávila` e percorre
  Inserir → BuscarPorId → Pesquisar → Atualizar → Excluir, limpando a própria
  auditoria no fim (transação explícita).

**2. HS256 de verdade.** `uMiddlewareJWT.pas` anunciava o algoritmo `HS256`, mas usava
um HMAC caseiro. Nova unit `Desktop\src\Utils\uHMAC.pas` implementa HMAC-SHA256
conforme a **RFC 2104**, construído sobre o `SHA256Raw` de `uSenhaHash.pas`;
`Assinar` passou a assinar com ela e a comparação da assinatura é feita em
**tempo constante** (`AssinaturaIgual`), evitando timing attack na validação do token.

- **Testes novos**: `TestHMACSha256VetorRfc4231` (vetor oficial RFC 4231, caso 1) e
  `TestHMACSha256RawEAoTamanhoChave` (chave maior e menor que o bloco de 64 bytes).

| Verificação | Resultado |
|---|---|
| `Scripts\build_desktop.bat` | compila |
| `Scripts\build_api.bat` | compila |
| `Scripts\run_tests.bat` | **56/56** (53 + 3 novos) |
| API `POST /api/login` admin/admin123 | HTTP **200** com token |
| API rota protegida sem token / token forjado | HTTP **401** |

---

## Consolidação dos SQLs e do build do banco (19/10/2026)

O DDL do banco estava espalhado em três fontes divergentes: o banco real
(`DADOS.FDB`, **34 tabelas**), `Banco\004_tables.sql` (**22**) e
`Banco\banco_simplificado.sql` (**19**). Produção e Notas tinham entrado por
scripts incrementais (008..012), então um banco montado pelo caminho antigo
ficava incompleto.

- **Fonte única**: `Banco\schema_canonico.sql`, **gerado do próprio banco real**
  pela nova ferramenta `Desktop\src\Tools\GerarSchema.lpr` (lê o metadata `RDB$*`
  via SQLDB — nada de interpretar a saída padronizada do `isql`):
  **34 tabelas, 34 generators, 6 domains, 111 constraints** (34 PK + 65 NOT NULL +
  12 CHECK), **34 índices** e **36 triggers**.
- **Validação round-trip**: `Scripts\testes\schema_roundtrip.ps1` cria um `.fdb`
  descartável com o script, compara coluna a coluna com o `DADOS.FDB` real pela
  ferramenta auxiliar `Desktop\src\Tools\DumpSchema.lpr` e exige diff vazio:
  **450 campos**.
- **`007_initial_data.sql` ajustado ao schema real**: `UNIDADE.NOME` é obrigatório
  (domínio `DM_NOME NOT NULL`) e `GRUPO`/`EMPRESA`/`USUARIO` usam `ATIVO`, não
  `STATUS`; acrescentadas as 4 permissões `PRODUCAO` que existem no banco real.
  Encoding preservado (UTF-8 **sem** BOM, fim de linha LF).
- **`Scripts\executar_banco.bat` reescrito**: roda `schema_canonico.sql` e depois
  `007_initial_data.sql` (antes parava no `007` e gerava só **22 das 34 tabelas**).
  Falha se o banco já existir; `/recriar` apaga e recria do zero.
- **`004_tables.sql`** e **`banco_simplificado.sql`** receberam cabeçalho
  `[SUPERADO]` apontando para o script canônico — **conteúdo intacto**
  (22 e 19 `CREATE TABLE` seguem lá, como histórico).

| Ferramenta | Função |
|---|---|
| `Desktop\src\Tools\GerarSchema.lpr` | Lê `RDB$*` e emite `schema_canonico.sql` |
| `Desktop\src\Tools\DumpSchema.lpr` | Dump `tabela\|campo\|tipo\|notnull\|default` |
| `Scripts\gerar_schema.bat` | Compila e roda o gerador |
| `Scripts\build_dump_schema.bat` | Compila o dump |
| `Scripts\testes\schema_roundtrip.ps1` | Banco descartável × real, exige diff vazio |
| `Scripts\testes\banco_fresco.ps1` | Reproduz o build novo + sementes e confere |

| Verificação | Resultado |
|---|---|
| `Scripts\testes\schema_roundtrip.ps1` | **450 campos, diff vazio** |
| `Scripts\testes\banco_fresco.ps1` | 450 campos, 34 tabelas, 34 generators, admin + permissões presentes |
| `Scripts\build_desktop.bat` | compila |
| `Scripts\build_api.bat` | compila |
| `Scripts\run_tests.bat` | **56/56** |

---

## Modelos I e II dos relatórios de Talão e de Mapa (30/10/2026)

Pedido: no "visualizar" dos relatórios, ter **Modelo I e Modelo II com os mesmos
links (mesmos datasets)**, para o usuário configurar como preferir. O Modelo II é
uma **cópia do Modelo I** que o usuário ajusta no designer do LazReport: os dois
usam o mesmo dataset — só o arquivo `.lrf` carregado muda.

| Relatório | Modelo I | Modelo II |
|---|---|---|
| Talão | `relatorios\talao.lrf` (caminho configurável, chave `PRODUCAO_TALAO_RELATORIO`) | `relatorios\talao_modelo2.lrf` (chave `PRODUCAO_TALAO_RELATORIO_M2`) |
| Mapa | `relatorios\mapa_producao.lrf` | `relatorios\mapa_producao_modelo2.lrf` |

- **Mesmos datasets nos dois modelos**: `frDBTalao` (talão) e `frDBMapa`/`qryMapaRel`
  (mapa), criados no `FormCreate` e compartilhados — trocar o `.lrf` não muda
  nenhuma ligação de dados.
- **Modelo ativo** fica na `CONFIGURACAO` (chaves `PRODUCAO_TALAO_MODELO` e
  `PRODUCAO_MAPA_MODELO`, `'1'`/`'2'`, ausente = Modelo I). Botão *Visualizar*,
  menu, impressão e exportação em PDF usam o modelo ativo.
- O menu `Relatório ▼` ganhou 4 itens **puramente aditivos** (`Modelo I/II -
  visualizar talões` e `Modelo I/II - visualizar mapa`). Nenhum item existente
  mudou de legenda nem virou submenu: a suíte de UI só enxerga itens de nível
  superior (MSAA no `HMENU`) e exige que `'(visualizar)'`, `'Exportar talões'`,
  `'mapa (exportar PDF)'` e `'abrir editor'` continuem **ações diretas** (clique
  que abre janela).
- Escolher um modelo grava a chave e **só se realmente gravou** recarrega a tela
  (o `COMMIT` da `CONFIGURACAO` invalida os cursores SQLDB).

**Testes novos** (`Desktop\src\Tests\uProducaoTest.pas`)

- `TestModelosRelatorioApontamArquivosDiferentes` — nomes esperados dos 4 arquivos,
  caminhos distintos entre os modelos e existência ao lado do exe (o
  `Scripts\build_tests.bat` passou a copiar os `.lrf` para `bin\relatorios`, o
  mesmo que já fazia o `build_desktop.bat`).
- `TestEscolhaDoModeloFicaNaConfiguracao` — round-trip `1 → 2 → 1` nas duas chaves
  (`DefinirModeloAtivo` devolve `False` quando a escolha não muda, evitando COMMIT
  à toa), `CaminhoRelatorioTalao` seguindo o modelo ativo e **restauração do
  estado original**. Um rodar limpo não deixa rastro: nem `CONFIGURACAO` nem
  `LOG_SISTEMA` — o `finally` apaga as chaves e as linhas de auditoria acima do
  topo capturado no início.

| Verificação | Resultado |
|---|---|
| `Scripts\build_desktop.bat` | compila, **0 warning / 0 erro** |
| `Scripts\run_tests.bat` | **58/58** (56 + 2 novos), inclusive a partir de banco limpo |
| `Scripts\testes\fase6_01.ps1` | **FASE6-01 CONCLUIDO** (menu com os 4 itens novos, preview, `taloes_mapa_1.pdf`, `mapa_1.pdf`, `Designer - talao.lrf`, `.lrf` intocado) |
| Rastro da suíte de unit e da suíte de UI nas chaves de modelo | `RESTOS = 0` e auditoria estável após cada run |

## Pool de conexões da API (30/10/2026)

Pendência do CHECKPOINT: *"API usa conexão única → pool de conexões (produção)"*.

**O problema.** O Horse (provider `FPC.HTTPApplication`) atende cada requisição em
**thread própria** (`THTTPApplication.Threaded := True`, `TFPHTTPConnectionThread`,
com keep-alive). Com uma `TIBConnection` única para todo o servidor, duas
requisições simultâneas disputariam a **mesma** conexão e a **mesma** transação.

**Solução** (`API\src\Config\uConexao.pas`, reescrito):

- **Pool com afinidade por thread**: cada thread de requisição recebe a **sua**
  `TConexao` (conexão + transação) — nunca há duas threads no mesmo objeto.
- `TConexao.GetInstance` **manteve a assinatura**, então as 6 unidades de rota
  (**15 pontos** de chamada) **não mudaram**.
- Toda conexão retirada já sai **conectada** (reconecta sozinha se o Firebird
  reiniciar) e, ao ser devolvida, faz `Rollback` antes de fechar.
- **Reciclagem de vagas** por detecção de thread morta (Windows: `OpenThread` +
  `GetExitCodeThread` = `STILL_ACTIVE`): quando a thread keep-alive morre, a vaga
  volta ao pool e a conexão do Firebird é fechada — nada envelhece.
- Se todas as conexões estiverem em uso por threads vivas, `Obter` **espera ~5 s**
  (250 × 20 ms) e só então falha com mensagem clara — **nunca compartilha conexão
  em silêncio**.
- Tamanho via variável de ambiente **`ERP_API_POOL`** (padrão 8, limitada a 2..64);
  `initialization` cria o pool e `finalization` o libera.
- `TConexao.PoolDescricao` (ex.: `pool=3 conexoes, 1 em uso`) impresso no startup.
- Fora do Windows, `ThreadViva` assume a thread viva: o pool continua limitado,
  perde só a reciclagem.

**Teste de concorrência** (`Scripts\testes\pool_api.ps1`) — API subida com
**`ERP_API_POOL=3`** (pool pequeno de propósito, para forçar o caminho de espera):

1. `POST /api/login` (`admin`/`admin123`) → token.
2. **Fase 1 (keep-alive)**: 40 requisições / 20 simultâneas em `GET /api/clientes`.
3. **Fase 2 (TCP nova por requisição)**: cada request do servidor roda numa
   **thread nova** — com apenas 3 conexões no pool, as 40 requisições só passam se
   a reciclagem das vagas das threads mortas funcionar.
4. `GET /api/clientes` sem token.

| Verificação | Resultado |
|---|---|
| `Scripts\build_api.bat` | compila, **0 warning / 0 erro** |
| Linha de startup | `Pool de conexoes: pool=3 conexoes, 1 em uso` |
| Fase 1 — keep-alive, 40 req / 20 simultâneas | **200=40, 401=0, outros=0, exceções=0** |
| Fase 2 — TCP nova por req (thread nova), 40 req / 20 simultâneas | **200=40, 401=0, outros=0, exceções=0** |
| `GET /api/clientes` sem token | **401** (o pool não quebra a segurança) |
