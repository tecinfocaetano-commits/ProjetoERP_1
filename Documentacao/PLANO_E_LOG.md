# PLANO E LOG DE DESENVOLVIMENTO — ERP 2026

> Documento **vivo**: registra o planejamento, as decisões do usuário e o que já
> foi executado. Atualizar a cada etapa concluída.
> Última atualização: 09/11/2026

---

## 1. Decisões do usuário (não reabrir)

| # | Decisão | Data | Situação |
|---|---|---|---|
| D1 | Produto **fiscal e financeiro é o mesmo** → uma tabela só (`PRODUTO_FISCAL` absorve `TIPO`/`VALOR`; `PRODUTO_FINANCEIRO` removida) | 31/10 | ✅ executado (015) |
| D2 | Criar cadastro de **País → Estado → Cidade** (globais, sem empresa) | 31/10 | ✅ concluído (015 + telas + combos) |
| D3 | **Unificar CLIENTE + FORNECEDOR** com `TIPO` (C/F) | 31/10 | ⏸ adiado (alto risco, exige plano + aprovação) |
| D4 | Regra de negócio sempre em **Service**; SQL parametrizado; transações com auditoria | — | ✅ padrão do projeto |
| D5 | **GRADE**: tela própria com tabela principal + sub-tabela de tamanhos (nº de tamanhos variável por tipo: calçado/confecção/grupo) | 31/10 | ✅ concluído |
| D6 | GRADE no **item do pedido** (inserível) e subgrid **editável no mapa** | 31/10 | ✅ concluído |
| D7 | Preferência **`USA_GRADE`**: desmarcada → grade **não aparece nem no mapa nem no pedido** | 31/10 | ✅ concluído (gate nas duas telas) |
| D8 | LazReport apenas; testes de impressão só em PDF | — | ✅ padrão |
| D9 | **Android: configuração por empresa** — tela onde o usuário define o **caminho do servidor** (URL da API) e o **código de usuário**; cada empresa usada guarda a sua própria configuração de servidor + usuário | 02/11 | ✅ concluído (commit `67d26f4`) |

---

## 2. Backlog (o que falta)

| # | Item | Status | Observação |
|---|---|---|---|
| 1 | **Consertar telas geográficas** (País/Estado/Cidade) e voltar build/suíte ao verde | ✅ concluído | build 0/0 e suíte 62/62 |
| 2 | Migração `016` **GRADE**: `GRADE` + `GRADE_TAMANHO`, `PRODUTO.GRADE_ID`, `ITEM_PEDIDO_GRADE`, `MAPA_PRODUCAO_ITEM_GRADE`, config `USA_GRADE` | ✅ concluído (31/10) | aplicada no `DADOS.FDB` real (backup `DADOS_backup_antes_016.fdb`); testada em cópia (aplica→rollback) |
| 3 | Tela de cadastro de GRADE (master + tamanhos) | ✅ concluído (31/10) | D5 |
| 4 | GRADE no item do pedido + subgrid editável no mapa, sob `USA_GRADE` | ✅ concluído (31/10) | D6/D7 |
| 5 | Notas lerem `PRODUTO_FISCAL` (NCM/CFOP/CST/alíquotas no service) | ✅ concluído (01/11) | saída e entrada; ver §3.11 |
| 6 | Re-layout da tela de Consumo | ✅ concluído (01/11) | itens do mapa no topo + materiais no rodapé; §3.10 |
| 7 | Produto Produção com Cores (expor `COR`) | ✅ concluído (01/11) | diálogo `uFrmCoresProduto`; §3.8 |
| 8 | Compras → gerar Nota de Entrada na confirmação | ✅ concluído (01/11) | `CriarDoPedidoCompra`; §3.9 |
| 9 | Vínculo geo (país/estado/cidade) em CLIENTE/FORNECEDOR | ✅ concluído (01/11) | migração `017` (`CIDADE_ID`); §3.7 |
| 10 | Unificação CLIENTE+FORNECEDOR | ✅ concluído (02/11) | D3 — `PESSOA` (`TIPO` C/F), tela única **Pessoas**, API/consultas migradas; suíte 65/65 (§3.19) |
| 11 | Android: orçamentos + telas | ✅ concluído (02/11) | API `/api/orcamentos` (listar/detalhar/criar/converter) + telas Android + menu inferior Material; validado no emulador (§3.17) |
| 12 | **Android: tela de configuração por empresa** — caminho do servidor (URL da API) + código de usuário, salvos **separadamente por empresa** (cada empresa tem a sua configuração) | ✅ concluído (02/11) | D9 — commit `67d26f4`; validado no emulador (§3.13) |
| 13 | Regenerar `Banco\schema_canonico.sql` (está anterior à `015`: sem `PAIS`, `CIDADE_ID`, `GRADE`, `ESTOQUE_MATERIAL`) | ✅ concluído (02/11) | regenerado do banco real: **49 tabelas / 584 campos**; round-trip e banco novo verdes (§3.15 e §3.19) |
| 14 | **Encoding dos literais acentuados** — o fonte é UTF-8, mas o processo não declarava a codepage padrão: o SQLDB tratava os bytes como CP1252 e gravava `NF de saÃ­da` | ✅ concluído (02/11) | adotado `SetMultiByteConversionCodePage(CP_UTF8)` no início do app/testes, **sem** `-FcUTF8` (que gerava 213 warnings e corrompia concatenações); ver §3.16 |
| 15 | **Estoque: filtro de pesquisa** nas telas do módulo (movimentação/inventário/kardex) | ✅ concluído (02/11) | Movimentação e Kardex ganharam campo "Pesquisar" (produto/documento e documento/observação); Inventário já tinha (§3.20) |
| 16 | **Financeiro: filtro de pesquisa** nas telas (contas a pagar/receber e movimento) | ✅ concluído (02/11) | Contas a Pagar/Receber (fornecedor/cliente + descrição), Movimento Financeiro e Caixa (§3.20) |
| 17 | **Clientes: opção de incluir cliente** dentro da tela de clientes | ✅ concluído (02/11) | app Android: FAB "Incluir cliente" na lista de Clientes → `InserirClienteActivity` (POST `/api/clientes`), validado no emulador (§3.20) |

---

## 3. O que já foi executado

### 3.1 Banco de dados (fase 1 — PRONTO)

- `014_suprimentos_fiscal.sql`: 9 tabelas (suprimentos/fiscal/financeiro) + 4 colunas aditivas.
- `015_completar_fase1.sql`:
  - CHECK `STATUS_PRODUCAO` (`ABERTO`/`PARCIALMENTE_CONCLUIDO`/`CONCLUIDO`);
  - fusão Fiscal+Financeiro (D1);
  - itens de nota → `PRODUTO_FISCAL` (colunas);
  - rename `MOVIMENTO_FINANCEIRO.CONTAPRODUTO_ID` → `CONTA_ID`;
  - **`PAIS` / `ESTADO` / `CIDADE`** + seed Brasil + 27 UFs (D2).
- Aplicado no `DADOS.FDB` real (backup `DADOS_backup_antes_015.fdb`), testado antes em cópia.

### 3.2 Desktop — produzido e commitado

- Menu em **4 abas**: Suprimentos · Produção · Financeiro · Fiscal.
- Produção (8 fases), Modelos I/II de relatório, consumo automático (base planejada).
- **`STATUS_PRODUCAO`** recalculado na bipagem (início e conclusão de talão) — commit `78a7b8d`.
- Descrições de status centralizadas em `uMapaProducaoStatus`.
- Telas de administração; pool de conexões da API; SHA-256; JWT HS256; schema canônico.
- Android Material You.
- Última verificação verde: build **0/0**, suíte **62/62**.

### 3.3 Geográfico — CONCLUÍDO (commitado)

- [x] `uPais` — model com `NOME`, `CODIGO`, `DDI` (colunas reais; não existe `SIGLA`).
- [x] `uEstado` — model com `PAIS_ID`, `NOME`, `UF`, `CODIGO_IBGE`.
- [x] `uCidade` — model com `ESTADO_ID`, `NOME`, `CODIGO_IBGE`.
- [x] `uPaisService` — `InserirParam`/`AtualizarParam` com assinatura correta (4 args).
- [x] `uEstadoService` — idem + coluna `UF`.
- [x] `uCidadeService` — idem.
- [x] `uFrmPais`, `uFrmEstado`, `uFrmCidade` (.pas + .lfm) — CRUD completo no padrão
  `uFrmCadastroBase`/`uFrmMaterial`, com status e bloqueio de exclusão com vínculos.
- [x] Menu Principal → Cadastros (Países/Estados/Cidades).
- [x] `.lpi`/`.lpr` com as units novas.
- [x] Build **0 erros** e suíte **62/62**.
- [x] Commit.

### 3.13 D9 — Android: configuração por empresa (concluído 02/11)

- Commit `67d26f4`.
- Arquivos novos (em `Android\android\app\src\main\`):
  - `java\...\Configuracao.java` — persistência em `SharedPreferences`
    (`erp2026_config`): `empresaAtual`, `empresas`, `url_<empresa>`,
    `codigo_<empresa>`; `normalizarUrl`/`urlValida`; identidade da empresa sem
    diferenciar maiúsculas; `aplicarNoApi`.
  - `java\...\ConfiguracaoActivity.java` + `res\layout\activity_configuracao.xml`
    — spinner de empresas, campos empresa/URL/código, **Testar conexão**,
    **Salvar**, **Usar esta empresa** e **Excluir**.
- Alterados: `ApiClient` (`setBaseUrl`/`getBaseUrl`/`ping`), `App` (aplica a
  configuração no `onCreate`), `MainActivity` (empresa em uso no login +
  `codigoUsuario` no corpo do `POST /api/login`), `DashboardActivity` (botão de
  configuração e empresa no título) e `AndroidManifest.xml`.
- Regras:
  - cada empresa tem a **sua** URL e o **seu** código; trocar de empresa
    **encerra a sessão** (o token pertence ao servidor anterior);
  - sem configuração vale a URL padrão `http://10.0.2.2:9000` (emulador);
  - **Testar conexão** faz `GET <url>/` e considera **qualquer** resposta HTTP
    como servidor alcançável (a API não tem rota de health);
  - a API ignora campos extras, então `codigoUsuario` não quebra o login atual.

**Validação no emulador `Pixel_9` (Android 16), 02/11** — API local no ar:

| Verificação | Resultado |
|---|---|
| Abrir a tela pelo Dashboard e pela tela de login | OK |
| Testar conexão com `http://10.0.2.2:9000` | "Servidor alcançável (HTTP 404)" |
| Salvar `MATRIZ` / código `001` | `SharedPreferences` com as 4 chaves |
| URL digitada sem esquema (`10.0.2.2:9000`) | gravada normalizada com `http://` |
| Salvar `filial` com `FILIAL` já existente | não duplica; mantém `FILIAL` |
| "Usar esta empresa" | encerra a sessão; login mostra a empresa |
| Login após configurar | entra; título do menu vira `ERP 2026 - FILIAL` |
| Excluir empresa não-ativa | remove só ela; sessão continua |
| Excluir a empresa ativa | volta ao login ("Nenhuma empresa configurada") |
| Reiniciar o app (`force-stop` + abrir) | configuração persistida e aplicada |

- Verificação final: build desktop **0 erros / 0 warnings** (403 hints),
  suíte **62/62**; `gradlew :app:assembleDebug` → **BUILD SUCCESSFUL**.
- Uso documentado em `Android\CONFIGURACAO_POR_EMPRESA.md`.

### 3.14 CRUD geográfico — correção de services (concluído 02/11)

- Commit `5075a06`: `uEstadoService` e `uCidadeService` passaram a usar
  `BuscarTodos` simples (filtro por string), sem `BuscarTodosParam`.
- Telas `uFrmPais`/`uFrmEstado`/`uFrmCidade` já estavam prontas e ligadas em
  **Cadastros**.
- Verificação final: build **0 erros / 0 warnings**, suíte **62/62**.

### 3.15 Schema canônico regenerado — item 13 (concluído 02/11)

- `Banco\schema_canonico.sql` regenerado por `Scripts\gerar_schema.bat`
  (lê `RDB$*` do `DADOS.FDB` real): **49 tabelas, 49 generators, 201
  constraints, 64 índices, 58 triggers, 6 domains** (antes: 34/34/111/…).
- Entraram no script as 15 tabelas criadas depois da geração anterior:
  `PAIS`, `ESTADO`, `CIDADE`, `PRODUTO_FISCAL`, `MATERIAL`, `COR`,
  `ESTOQUE_MATERIAL`, `MOVIMENTO_MATERIAL`, `MOVIMENTO_FINANCEIRO`,
  `PEDIDO_COMPRA`, `PEDIDO_COMPRA_ITEM`, `GRADE`, `GRADE_TAMANHO`,
  `ITEM_PEDIDO_GRADE`, `MAPA_PRODUCAO_ITEM_GRADE` — além das colunas
  `CLIENTE.CIDADE_ID`/`FORNECEDOR.CIDADE_ID`, `PRODUTO.PRODUTO_FISCAL_ID`,
  `PRODUTO.GRADE_ID` etc.
- **Sementes consolidadas em `007_initial_data.sql`** (antes só existiam nas
  migrações, que não rodam num banco novo porque o schema canônico já traz as
  colunas):
  - `PAIS` Brasil (`BRA`/`55`) + **27 UFs** com código IBGE (migração `015`);
  - `CONFIGURACAO.USA_GRADE='N'` por empresa, idempotente (migração `016`).
- `Scripts\executar_banco.bat`: comentário atualizado (49 tabelas / 49
  generators / 201 constraints / 64 índices / 58 triggers).
- `Scripts\testes\banco_fresco.ps1`: contagens novas (49/49) e conferência das
  sementes novas (Brasil, 27 UFs, `USA_GRADE`).

**Validação (02/11):**

| Teste | Resultado |
|---|---|
| `Scripts\testes\schema_roundtrip.ps1` | **OK** — banco novo × real: 602 campos, diff vazio |
| `Scripts\testes\banco_fresco.ps1` | **OK** — 602 campos, diff vazio, 49 tabelas/49 generators, admin/permissoes, Brasil + 27 UFs e `USA_GRADE` |
| Build desktop | **0 erros / 0 warnings** |
| Suíte | **62/62** |

### 3.16 Encoding dos literais acentuados — item 14 (concluído 02/11)

**Problema:** o fonte é UTF-8, mas o processo nascia com
`DefaultSystemCodePage=1252`. O SQLDB então convertia os bytes UTF-8 dos
literais como se fossem CP1252, gravando `NF de saÃ­da` (20 bytes em vez de
12). O único contorno era local, na descrição do `CONTA_RECEBER`.

**Por que não adotar `-FcUTF8`:** a sonda mostrou que a flag resolve o caso
isolado, mas o projeto inteiro tem **213 avisos 4104/4105** — e eles são
reais: `'literal' + AnsiString` passa a ser convertido para CP1252 em tempo
de execução (ex.: `'pre ' + 'Ação'` virava 8 bytes CP1252), corrompendo
tanto textos de UI quanto valores gravados.

**Solução adotada:** manter a compilação sem `-FcUTF8` (convenção do LCL,
que trafega UTF-8 em `AnsiString`) e declarar a codepage do processo no
início de `ERP2026.lpr` e de `uTestRunner.pas`:

```pascal
SetMultiByteConversionCodePage(CP_UTF8);
```

Com isso o SQLDB enxerga os literais como UTF-8 e não reconverte. A sonda
empírica (gravação em `CONFIGURACAO`) passou de `octet_len=20` (duplo
encoding) para **12** — o UTF-8 correto — e o build continuou com
**0 warnings**.

- `Desktop\src\Services\uNotaSaidaService.pas`: removido o contorno
  (`RawByteString` + `SetCodePage` + `AsUTF8String`); a descrição voltou a
  ser `string` + `AsString`, igual aos demais textos.
- Nenhuma mudança em `ERP2026.lpi`/`Tests.lpi` (a flag `-FcUTF8` foi
  descartada).
- Varredura no banco real: **243 colunas de texto** (`CHAR`/`VARCHAR`)
  consultadas por `LIKE '%Ã%'` → **0 linhas** com mojibake.

**Validação (02/11):**

| Teste | Resultado |
|---|---|
| Build desktop (`--build-all`) | **0 erros / 0 warnings** |
| Build testes (`--build-all`) | **0 erros / 0 warnings** |
| Suíte | **62/62** |
| Sonda SQLDB (gravação acentuada) | **12 bytes** (UTF-8 correto) |
| Varredura de mojibake no banco | **0 linhas** em 243 colunas |
| Smoke do app | inicia e fica estável (login) |

**Parada de sessão:** o checkpoint detalhado está em `CHECKPOINT.md` →
"Estado atual da sessão".

### 3.17 Android — orçamentos + menu inferior (item 11, concluído 02/11)

**API (`API/src/Rotas/uRotasOrcamentos.pas`)**

- Orçamento é um `PEDIDO_VENDA` com `STATUS = 'O'`; a conversão muda para
  `'P'` (pedido), a mesma regra do desktop.
- `GET /api/orcamentos` — abertos, com número, cliente, total, emissão e
  contagem de itens (`ITEM_PEDIDO`).
- `GET /api/orcamentos/:id` — cabeçalho + itens (404 se não existe).
- `POST /api/orcamentos` — valida cliente e produtos ativos, **recalcula**
  subtotal/desconto/total no servidor e grava cabeçalho + itens na mesma
  transação; responde **201** com o id e o número.
- `POST /api/orcamentos/:id/converter` — 404 se não existe, **409** se já
  não está em aberto, 200 ao converter.
- Empresa/usuário saem das claims `empresa_id`/`sub` do JWT (nunca do
  corpo). Listagem, detalhe e conversão filtram pela empresa do token
  (orçamento de outra empresa responde 404); cliente/produto precisam ser
  da mesma empresa. A conversão usa `UPDATE ... WHERE STATUS = 'O'` e
  confere `RowsAffected` (duas conversões simultâneas: uma vence, a outra
  recebe 409). Numeração segue `ProximoNumero` do desktop: maior `NUMERO`
  numérico + 1, ignorando os não numéricos. O ID é obtido do generator
  **antes** do `INSERT`, sem depender do valor corrente do generator.
- Rotas registradas em `ERP2026API.lpr` (log de endpoints).

**Android**

- Menu inferior reutilizável (`include_bottom_nav.xml` +
  `menu_bottom_nav.xml`) com **Início, Clientes, Estoque, Vendas,
  Financeiro**; `Navegacao.java` reaproveita as Activities já abertas
  (`FLAG_ACTIVITY_REORDER_TO_FRONT`). Ícones vetoriais próprios em
  `res/drawable` (sem dependências novas).
- `BaseListaActivity` ganhou `itemMenuAtual()`, `aoSelecionarItem()` e
  `recarregar()`; as telas de lista passaram a marcar o item atual.
- `OrcamentosActivity`: lista os abertos, estado vazio explícito e
  conversão em pedido com confirmação (Toast + recarga).
- `InserirOrcamentoActivity`: spinners de cliente/produto carregados da
  API, quantidade/valor unitário/desconto por item, desconto geral,
  observações, totais recalculados a cada mudança e POST no servidor.
- Botão **Orçamentos** no Dashboard e na tela de Vendas; Activities
  registradas no Manifest.
- Corrigido de passagem: comentário mojibake em `Fmt.java` e z-order dos
  overlays de estado (cards com elevação cobriam mensagem/progresso).

**Validação (02/11, emulador `Pixel_9`)**

| Teste | Resultado |
|---|---|
| Build Android (`build_android.bat`) | **BUILD SUCCESSFUL** |
| API (`build_api.bat`) | 0 erros |
| Criar orçamento pela UI (2 × R$ 35, desconto R$ 5) | lista mostra **Orçamento 3**, total **R$ 65,00** |
| Converter pela UI | some da lista; banco fica `STATUS = 'P'` |
| Repetir conversão (API, `curl`) | **HTTP 409** |
| Criação via API (`curl`) | **HTTP 201**, id 1004, total 55 |
| Dados de teste | removidos do banco ao final |

**Arquivos:** `API/src/Rotas/uRotasOrcamentos.pas`, `API/ERP2026API.lpr`,
`Android/.../OrcamentosActivity.java`, `InserirOrcamentoActivity.java`,
`Navegacao.java`, `BaseListaActivity.java`, layouts `activity_orcamentos`,
`activity_inserir_orcamento`, `include_bottom_nav`, `res/menu/menu_bottom_nav`,
5 drawables `ic_nav_*` e `Android/README.md`.

### 3.18 Android — dashboard de vendas + menu de configurações (concluído 02/11)

**Tela inicial**

- `activity_dashboard.xml` foi reescrito: saíram os botões (`buttonClientes`,
  `buttonInserirCliente`, `buttonConsultarClientes`, `buttonEstoque`,
  `buttonVendas`, `buttonOrcamentos`, `buttonFinanceiro`,
  `buttonConfiguracao`, `buttonSair`) e entrou um dashboard com:
  faturamento do mês + vendas do mês, **A receber** / **A pagar**,
  **Orçamentos abertos**, **Clientes** e as **3 últimas vendas**.
- Cards clicáveis: orçamentos → `OrcamentosActivity`; clientes →
  `ClientesActivity`; últimas vendas → `VendasActivity`. O menu inferior
  (Início/Clientes/Estoque/Vendas/Financeiro) foi mantido.
- `DashboardActivity` carrega `/api/financeiro`, `/api/orcamentos`,
  `/api/clientes` e `/api/vendas` em segundo plano, cada chamada isolada
  (uma falha não apaga os outros números) e recarrega ao voltar para a tela.
- Menu **⋮** (`res/menu/menu_dashboard.xml`): **Atualizar resumo**,
  **Configuração (servidor e empresa)** e **Sair** (com confirmação). A
  configuração e a saída deixaram de ocupar botões na tela.

**Robustez do cliente HTTP**

- `ApiClient.get` repete a requisição até 3 vezes (120 ms/240 ms de espera)
  quando a conexão cai no meio da resposta. O servidor eventualmente fecha o
  corpo um byte antes do `Content-Length` (perde o último `}`), o que gerava
  `ProtocolException: unexpected end of stream` esporádico. Só GET é
  repetido, porque é idempotente; POST/PUT continuam com uma tentativa.
- Cada requisição envia `Connection: close`, evitando reutilizar sockets que
  o servidor já encerrou.

**Correção no resumo financeiro da API**

- `GET /api/financeiro` devolvia `a_receber`, `a_pagar` e `faturamento_mes`
  sempre **0**: o driver entrega `SUM(CASE ...)` (`NUMERIC(18,4)`) como BCD
  nulo, e `AsFloat` virava 0. As somas passaram a ser convertidas com
  `CAST(... AS DOUBLE PRECISION)` em `uRotasFinanceiro.pas`; o resumo do
  Android e a tela Financeiro passaram a mostrar os valores reais
  (A receber R$ 170,00 / A pagar R$ 1.595,00 / faturamento R$ 70,00 no banco
  de teste).

**Validação (02/11, emulador `Pixel_9`)**

| Teste | Resultado |
|---|---|
| Build Android (`build_android.bat`) | **BUILD SUCCESSFUL** |
| Dashboard com a API no ar | faturamento, contas, 0 orçamentos, 9 clientes e 3 últimas vendas |
| Menu ⋮ | 3 itens; **Atualizar resumo** recarregou 4× sem erro |
| Card Orçamentos / Clientes / Últimas vendas | abrem as telas certas; seta volta ao Dashboard |
| Configuração pelo menu | abre `ConfiguracaoActivity`; seta volta ao Dashboard |
| Sair | diálogo "Deseja encerrar a sessão?" (Cancelar mantém a sessão) |
| Financeiro (após o `CAST`) | A Receber R$ 170,00 / A Pagar R$ 1.595,00 |

**Arquivos:** `Android/.../DashboardActivity.java`, `ApiClient.java`,
`res/layout/activity_dashboard.xml`, `res/menu/menu_dashboard.xml`,
`API/src/Rotas/uRotasFinanceiro.pas`, `Android/README.md`.

### 3.4 Banco — migração `016` GRADE (concluído 31/10)

- `Banco\016_grade.sql` (+ `_rollback.sql`), testada em cópia (aplica →
  rollback limpo) e aplicada no `DADOS.FDB` real (backup
  `DADOS_backup_antes_016.fdb`).
- Tabelas: `GRADE` (nome + `TIPO` CALCADO/CONFECCAO/GRUPO/OUTRO),
  `GRADE_TAMANHO` (tamanhos variáveis + `ORDEM`), `ITEM_PEDIDO_GRADE`,
  `MAPA_PRODUCAO_ITEM_GRADE`; coluna `PRODUTO.GRADE_ID`; config
  `USA_GRADE='N'` por empresa; 4 generators, 5 triggers, 5 índices.
- Aprendizados do Firebird registrados: identificador máx. **31 caracteres**
  (gerador/trigger de `MAPA_PRODUCAO_ITEM_GRADE` encurtados) e **`DEFAULT`
  antes de `NOT NULL`** no `CREATE TABLE`.
- Próximo: service da grade + tela de cadastro.

### 3.5 GRADE — cadastro + preferência (concluído 31/10)

- `uGrade` — model com `TGradeTamanho.Quantidade` (usado nas grades efetivas),
  helpers de tipo e `SomarQuantidades`.
- `uGradeService` — CRUD com transação/auditoria, `Carregar` por empresa,
  `UsaGrade`/`DefinirUsaGrade` (fallback `EMPRESA_ID IS NULL`), grades
  efetivas do pedido e do mapa (salvar/copiar) e grade padrão do produto.
- `uFrmGrade` — master (nome/tipo/status/observação) + `TStringGrid` de
  tamanhos editável (adicionar/remover, ordem, ativo, validação de repetidos).
- Menu **Cadastros → Grades**; `.lpr`/`.lpi` atualizados.
- `uFrmConfiguracoes` — checkbox da preferência `USA_GRADE`.
- Build **0 erros / 0 warnings**; suíte **62/62**.

### 3.6 GRADE — pedido + mapa + produto (concluído 31/10)

- `uFrmGradeQuantidades` (`.pas`/`.lfm`) — diálogo reutilizável de
  quantidades: `TStringGrid` com `FixedCols=1` (tamanho não editável),
  coluna de quantidade, total no rodapé e validação opcional de total > 0.
- `uFrmPedidoVenda`:
  - coluna **Grade** no `sgItens` (largura 0 e sem título com
    `USA_GRADE='N'`) e botão **"Grade do item..."** (só visível com a
    preferência ligada);
  - ao adicionar produto com grade padrão, abre o diálogo já preenchido;
  - quantidade do item = soma das quantidades da grade; total recalculado;
  - no save, grava `ITEM_PEDIDO_GRADE` na **mesma transação** do pedido
    (`GEN_ID(GEN_ITEM_PEDIDO_ID, 0)` para o ID do item).
- `uFrmMapaProducao`:
  - painel **Grade do item** (à direita da lista de itens) com resumo/total,
    **Editar grade...** e **Copiar do pedido**; sem `USA_GRADE` o painel
    fica oculto e a grade ocupa a largura cheia;
  - `AtualizarInfoGrade` no `DataSourceItensMapa.OnDataChange`;
  - grava via `SalvarGradeMapaItem` e recarrega com `CarregarMapas`.
- `uFrmProdutos` — combo **Grade** gravando `PRODUTO.GRADE_ID` (grade padrão
  usada para montar o item no pedido).
- `uGradeService.GravarGradeEfetiva` — **transação composta**: só
  inicia/commita/rollback se `not Conexao.EmTransacao`; auditoria sempre.
- Build **0 erros / 0 warnings**; suíte **62/62**.
- Próximo: itens 5–10 do backlog e, depois, D9 (configuração por empresa no
  Android).

### 3.7 Item 9 — vínculo geográfico em CLIENTE/FORNECEDOR (concluído 01/11)

- `Banco\017_geo_cliente.sql` (+ `_rollback.sql`): coluna **`CIDADE_ID BIGINT`
  anulável** em `CLIENTE` e `FORNECEDOR` — sem `ESTADO_ID`, porque o estado já
  é derivado da cidade. As colunas texto `CIDADE`/`UF` **continuam existindo**
  (compatibilidade com telas, relatórios e legado); `0`/`NULL` = sem vínculo.
- Testada em cópia e aplicada no `DADOS.FDB` real (backup
  `Banco\DADOS_backup_antes_017.fdb`); 27 capitais gravadas com acentuação
  correta (`SET NAMES UTF8`).
- `Desktop\src\Views\uGeoCombos.pas` — unidade reutilizável com
  `CarregarPaises`, `CarregarEstados`, `CarregarCidades`, `SelecionarCidade`
  e `IdDoCombo`:
  - `cmbPais`/`cmbEstado` são `csDropDownList`; estado aparece como
    `"UF - Nome"`;
  - `cmbCidade` é editável: cidade antiga (sem `CIDADE_ID`) entra como item
    sem objeto, e o texto continua indo para `CIDADE`/`UF`.
- `uFrmClientes` grava `CIDADE_ID` via `uCliente`/`uClienteService`;
  `uFrmFornecedores` grava direto no `INSERT/UPDATE` do formulário (mesmo
  padrão anterior da tela).

### 3.8 Item 7 — Cores do produto (concluído 01/11)

- `uFrmCoresProduto` (`.pas`/`.lfm`) — diálogo aberto a partir de
  **Produtos → Cores...**, com CRUD de `COR` do produto (nome, `HEX`,
  ativo) e uma coluna **somente leitura** com a ficha técnica da cor
  (`FICHA_TECNICA.TIPO_BASE = 'COR'`).
- `uFrmProdutos` ganhou o botão e abre o diálogo para o produto selecionado;
  a exclusão de cor com ficha técnica é bloqueada com mensagem.

### 3.9 Item 8 — Compras → Nota de Entrada (concluído 01/11)

- `TNotaEntradaService.CriarDoPedidoCompra(APedidoCompraId)`:
  - cria `NOTA_ENTRADA` com `STATUS='A'` (aberta), `SERIE='1'`,
    `MODELO='55'`, `NATUREZA='Compra para comercialização'`, `CFOP='1102'`,
    `NUMERO` = número do pedido e
    `OBSERVACOES='Gerada do pedido de compra Nº <numero>'`;
  - copia os itens do pedido; item de **material** leva `MATERIAL_ID` e herda
    do `PRODUTO_FISCAL` do material `PRODUTO_FISCAL_ID`, NCM, CFOP, CST e
    alíquotas;
  - grava `PEDIDO_COMPRA.NOTA_ENTRADA_ID` e `STATUS='CONFIRMADO'`;
  - rejeita pedido cancelado ou que já tenha nota.
- `TNotaEntradaService.Processar` passou a aceitar item de material: dá
  entrada no estoque **sem trigger de saldo** — grava `MOVIMENTO_MATERIAL`
  (`TIPO='E'`, saldo anterior/posterior, `ORIGEM='NOTA_ENTRADA'`,
  `DOCUMENTO_ID` = nota), atualiza/insere `ESTOQUE_MATERIAL` e leva o último
  custo para `MATERIAL.PRECO_CUSTO`; gera as contas a pagar como antes.
- `uFrmCompras.btnConfirmarClick` salva o pedido, chama o service e mostra o
  número da nota gerada; `uFrmNotaEntrada.CarregarItens` exibe código e
  descrição do material (join com `MATERIAL`) e sinaliza item sem produto.

### 3.10 Item 6 — Consumo de materiais (concluído 01/11)

- `uFrmConsumoMaterial`: o topo agora tem o **combo de mapas + lista dos itens
  do mapa** (`sgMapaItens`: código, produto, quantidade, status —
  `CarregarItensMapa`/`MontarCabecalhoMapaItens`) e o rodapé mantém o **grid
  de materiais do consumo** (`sgItens`, `alClient` dentro de `pnlItens`).
- `.lfm` re-layout: formulário 700 px, `pnlMapaItens` (170 px) abaixo da
  seleção, `pnlAcoes` e `pnlItens` (cliente) e `pnlRodape` fixo.

### 3.11 Item 5 — Notas leem `PRODUTO_FISCAL` (concluído 01/11)

- `TNotaSaidaService.CriarDoPedido` passa a ler `PRODUTO_FISCAL` do produto e
  grava no item: `PRODUTO_FISCAL_ID`, `NCM`, `CFOP` (usa `CFOP_VENDA`),
  `CST_ICMS`, `CST_PIS`, `CST_COFINS`, `ALIQ_ICMS`, `ALIQ_PIS`, `ALIQ_COFINS`.
- `uFrmNotaEntrada.CarregarFiscalDoProduto` faz o mesmo para entrada
  (`CFOP_COMPRA`), reaproveitado pelo item de material.
- **Correção de encoding:** o fonte é UTF-8 mas o projeto compila sem
  `-FcUTF8`; o FPC etiqueta o literal como CP1252 e o SQLDB reconvertia os
  bytes, gravando `NF de saÃ­da` em `CONTA_RECEBER`. A descrição passou a ser
  montada em `RawByteString` com `SetCodePage(..., CP_UTF8, False)` e enviada
  por `AsUTF8String` (sem warnings). O problema geral está no backlog (item 14).

### 3.12 Teste de ponta a ponta dos fluxos (01/11)

- Harness **temporário** (`Desktop\Popular.lpr` + `.lpi`, removido depois)
  exercitando os services reais, com `TSessao.Logar(1,1,1,...)`, sem GUI:
  - **item 8:** `PEDIDO_COMPRA` → `CriarDoPedidoCompra` → `Processar`;
  - **item 5:** `PEDIDO_VENDA` → `CriarDoPedido` → `Faturar`.
- 38 verificações, todas OK: nota nasce `'A'` e vira `'P'`; item aponta para o
  material e herda NCM/CFOP do fiscal; pedido vira `CONFIRMADO` e fica ligado à
  nota; saldo do material `5 + 10 = 15` com `MOVIMENTO_MATERIAL`
  (5 → 15, `ORIGEM='NOTA_ENTRADA'`); `PRECO_CUSTO` atualizado; contas a pagar
  geradas; nota de saída herda CFOP de venda/CST/alíquota; estoque do produto
  `100 - 2 = 98`; contas a receber geradas; pedido de venda vira `'F'`.
- Banco deixado com **um exemplo completo de cada fluxo** (pedido de compra
  `PC-TESTE-8` → nota `8` processada; pedido de venda `PV-TESTE-5` → nota `4`
  faturada) e os cadastros de apoio (`FISC-TESTE`, fornecedor/cliente de teste,
  `MAT-TESTE8`, `PROD-TESTE8`, cor "Preto", saldos 15 e 98).
- Depois da remoção do harness: build **0 erros / 0 warnings** e suíte
  **62/62**.
- **Smoke das telas** (harness temporário, removido): `Create`/`Free` das 7
  telas mexidas nos itens 5–9 — `TfrmProdutos` (56 componentes),
  `TfrmCoresProduto` (15), `TfrmClientes` (59), `TfrmFornecedores` (59),
  `TfrmCompras` (39), `TfrmNotaEntrada` (78) e `TfrmConsumoMaterial` (21) —
  todas carregaram o `.lfm` sem erro. O build não valida `.lfm`; este smoke
  foi a garantia de que nenhum componente novo ficou fora do arquivo.

### 3.19 D3 — Unificação CLIENTE+FORNECEDOR em PESSOA (02/11, concluído)

- **Banco:** `Banco/018_unificar_pessoa.sql` aplicado no `DADOS.FDB` (backup
  `DADOS_backup_antes_018.fdb`). Tabela única `PESSOA` com `TIPO` `C`/`F`
  (`TIPO_PESSOA` F/J preservado); IDs de cliente mantidos e fornecedores
  remapeados para 1341/1342; `GEN_PESSOA_ID` acima do maior ID; zero órfãos;
  `CLIENTE` e `FORNECEDOR` removidas. Rollback em
  `018_unificar_pessoa_rollback.sql`.
- **Desktop:** `uPessoa`, `uPessoaService` e `uFrmPessoas` (menu Cadastros >
  **Pessoas**), com filtro Todos/Clientes/Fornecedores, tipo imutável após
  salvo e exclusão bloqueada quando referenciada em conta a receber/pagar,
  nota de entrada/saída, pedido de compra/venda, produto ou financeiro.
  Telas antigas de Clientes/Fornecedores removidas; consultas migradas para
  `PESSOA` em 18 units.
- **API:** `/api/clientes` continua com o mesmo contrato e filtra
  `TIPO = 'C'`; joins de financeiro, vendas e orçamentos apontam para
  `PESSOA`. Nenhuma dependência nova no Android.
- **Testes:** `uPessoaTest` substitui `uFrmClientesTest` (12 testes do D3);
  suíte **65/65**. Causa do `Invalid variant type cast`: o repositório
  genérico só aceita valores string e o SQLDB não converte `yyyy-mm-dd`
  para `ftDate`; o `TPessoaService` passou a montar o INSERT/UPDATE com
  `AsDateTime` (ou `NULL`) em `DATA_NASCIMENTO`.
- **Validação:** build desktop 0 erros/0 warnings; build API OK; Android
  `BUILD SUCCESSFUL`; `schema_canonico.sql` regenerado (49 tabelas /
  584 campos) com round-trip vazio; emulador `Pixel_9` com **9 clientes**,
  faturamento **R$ 70,00**, a receber **R$ 170,00** e a pagar
  **R$ 1.595,00**; smoke de runtime instanciou as 11 telas alteradas
  (0 falhas).

### 3.20 Filtros de pesquisa e inclusão de cliente (02/11, concluído)

- **Estoque (desktop):** `uFrmMovEstoque` ganhou `edtPesquisa` (descrição ou
  código do produto e documento) e `uFrmKardex` ganhou pesquisa em
  documento/observação, aplicada também ao resumo de entradas/saídas;
  `uFrmInventario` já tinha pesquisa (descrição/código) — nenhuma mudança.
- **Financeiro (desktop):** `uFrmContasPagar` (fornecedor + descrição),
  `uFrmContasReceber` (cliente + descrição) e `uFrmCaixa` (número/usuário
  nos caixas e descrição/tipo/usuário nos movimentos, via `TCaixaService`
  com filtro opcional). Em `uFrmMovimentoFinanceiro` a pesquisa herdada de
  `TfrmCadastroBase` foi corrigida: `DOCUMENTO_ID CONTAINING` (BIGINT)
  passou a `CAST(DOCUMENTO_ID AS VARCHAR(20))` e o `OR` foi parentizado.
- **Android:** FAB "Incluir cliente" em `ClientesActivity`
  (`activity_clientes.xml`, id `fabIncluirCliente`) abre
  `InserirClienteActivity` (POST `/api/clientes`); a lista recarrega no
  `onResume`. Nenhuma dependência nova e nenhum id existente alterado.
- **Validação:** build desktop **0 erros/0 warnings**, suíte **65/65**,
  Android `BUILD SUCCESSFUL`; SQLs dos filtros validados no Firebird e
  smoke de runtime (7 telas, com pesquisa aplicada, 0 falhas); emulador
  `Pixel_9` mostrou o FAB, abriu a tela e gravou "ClienteIncluidoApp"
  (removido depois — base de volta a **9 clientes**).

### 3.21 Checkpoint por marco: HEAD + estado do git (03/11, concluído)

- **`CHECKPOINT.md`:** o bloco "Estado atual" passou a trazer **HEAD com hash
  e mensagem** (`ba439bd`, commit de docs; código em `e4f4804`), o estado do
  git (árvore limpa/suja + arquivos não commitados), build/suíte e uma seção
  **Próximo passo (executável)**. Título e data da sessão em 03/11; "Em
  andamento" vazio porque a árvore está limpa. O bloco cita o commit de docs
  que o gravou; se `git log -1` divergir, vale o disco.
- **Números defasados:** o piso da suíte subiu de **62/62** para **65/65** no
  checkpoint, nas instruções e no "Para continuar". As menções a 62/62 em
  seções **históricas** (§3.2–§3.18, "Estado anterior", execuções antigas)
  ficam como registro da época — não são erro e não devem ser "corrigidas".
- **`INSTRUCOES_AGENTE.md`:** exemplos/comandos e o piso em 65/65; backlog
  atual declarado **sem itens abertos** (D3, filtros e "incluir cliente"
  concluídos em §3.19/§3.20).

### 3.22 Teste de UI em todas as telas do desktop (03/11, concluído)

- **Harness novo:** `Scripts\testes\telas_todas_ui.ps1` abre o app, lê o menu
  Win32 (sem IDs fixos), aciona cada item por `WM_COMMAND`, espera a janela,
  exige pelo menos um controle, tira evidência, fecha com `WM_CLOSE` e segue.
  Diálogos `#32770` são lidos e fechados; se o texto tiver `Access violation`,
  `SQL error`, `Token unknown` ou `invalid integer`, a tela é marcada **FALHA**
  (não basta a janela abrir). Aceita `-ApenasId 3,24` para repetir um recorte.
- **Saídas:** `Documentacao\TESTE_TELAS_DESKTOP.md` (tabela por tela) e
  `Documentacao\evidencias\telas_<id>_<slug>.png` (ignoradas pelo git).
- **Resultado final:** **33/33 telas OK**, 0 aviso, 0 falha.
- **Bugs encontrados e corrigidos:**
  1. **Geo** (`uPaisService`, `uEstadoService`, `uCidadeService`): passavam
     `'ORDER BY NOME'` como se fosse a condição do `BuscarTodos`, gerando
     `SELECT * FROM PAIS WHERE ORDER BY NOME` (**Token unknown - ORDER**).
     Combos de País/Estado/Cidade e a tela **Pessoas** falhavam na inicialização.
     Agora usam a assinatura certa: condição (`''` ou `PAIS_ID = ...`) + ordem `NOME`.
  2. **NF-e** (`uFrmNFe`): a classe declarava `edtInicio`/`edtFim`, mas o `.lfm`
     tem `edtDataInicio`/`edtDataFim` → campos `nil` e **Access violation** no
     `FormCreate`. Campos e usos renomeados para os nomes do `.lfm`.
  3. **Compras** (`uFrmCompras.ProximoNumero`): `SELECT MAX(NUMERO)` +
     `AsInteger` estourava com o registro de teste `PC-TESTE-8` (NUMERO é texto)
     e comparava texto (`'9' > '10'`). Agora lê os números com
     `StrToInt64Def` e escolhe o maior.
- **Limpeza:** campo morto `imgLogo` removido de `uFrmLogin` (não existe no `.lfm`).
- **Validação:** build 0/0, suíte **65/65**, UI **33/33**.

### 3.23 Android off-line: clientes e orçamentos com sincronização (03/11, concluído)

- **Banco local:** `ErpDbHelper` (`SQLiteOpenHelper`, schema **v2**) cria
  `erp2026.db` com `cliente_local`, `produto_local`, `orcamento_local`,
  `orcamento_item_local`, `outbox` e `meta` — todas as tabelas de negócio com a
  coluna `empresa`, porque a configuração é por empresa (D9). `onUpgrade` faz
  v1→v2 (`produto_local`, `desconto` no item, `qtd_itens` no cabeçalho) sem
  recriar o banco. Nenhuma dependência nova no Gradle (sem Room).
- **Modelo:** id local (`id`, auto-incremento) separado do id do servidor
  (`id_servidor`); `sincronizado` marca o que já existe na API. Caches usam
  **upsert por `id_servidor`** (nunca delete+insert), para não quebrar o id
  local referenciado por orçamentos pendentes.
- **Gravação sempre local primeiro:** `InserirClienteActivity` e
  `InserirOrcamentoActivity` gravam no SQLite e enfileiram na `outbox`; só
  então tentam `Sincronizacao.sincronizar` se `Conectividade.temRede`. Sem
  rede, o cadastro fica salvo e sobe na próxima sincronização.
- **Fila (`outbox`):** `BancoLocal.enfileirar` não duplica INSERT pendente do
  mesmo registro local (atualiza o payload). Falha vira `tentativas` +
  `ultimo_erro` e a linha **permanece** para a próxima rodada.
- **Ordem de envio:** clientes antes de orçamentos. `POST /api/clientes` não
  devolve id, então após o POST o app relê `GET /api/clientes` e localiza o
  cadastro por **nome + dígitos do CPF/CNPJ** (maior id), gravando
  `id_servidor`; se o cliente já existir (envio anterior confirmado), só
  vincula. O orçamento é montado **na hora do envio a partir do banco** (não do
  JSON da fila), com o `cliente_id` do servidor e `produto_id` de cada item;
  `POST /api/orcamentos` devolve `id`/`numero`, gravados no registro local.
- **Telas:** `ClientesActivity` e `OrcamentosActivity` listam do banco local,
  sincronizam em segundo plano na primeira exibição e têm
  `buttonSincronizar` ("Sincronizar (N pendente[s])"). Off-line mostram estado
  vazio com mensagem própria, sem erro de servidor. Orçamento ainda não enviado
  não pode ser convertido (o diálogo oferece **Sincronizar**).
- **Layouts:** `activity_clientes.xml` e `activity_orcamentos.xml` ganharam o
  `buttonSincronizar`; **nenhum `android:id` existente foi alterado**.
  `App.onCreate` abre o banco e loga tabelas/contagens na tag `ErpDb`.
- **Validação:** Android `BUILD SUCCESSFUL`; migração v1→v2 vista no logcat
  (`banco erp2026.db v2` + 6 tabelas). No emulador `Pixel_9`, em modo avião:
  cliente salvo local ("aguardando sincronização", 1 pendente) e orçamento
  #1 de 1 × R$ 35,00 (2 pendentes); religando a rede e sincronizando, a API
  recebeu cliente 1396 e orçamento 1007 (número 2, R$ 35,00, 1 item) e o app
  exibiu **Orçamento 2** com 0 pendentes. `force-stop` + relançamento em modo
  avião recarregou tudo do banco (`clientes=10 pendentes=0 produtos=4
  orcamentos=1 outbox=0`). Os registros de teste saíram do banco ao final
  (PESSOA 1396 + PEDIDO_VENDA 1007) e a suíte voltou a **65/65**.
- **Observação:** naquele momento `VendasActivity` continuava online-only; o
  §3.24 passou a lê-la do banco local. O botão **Orçamentos** dela já abre a
  tela off-line. Os registros criados para validar a sincronização (cliente
  "Cliente Offline Teste" / PESSOA 1396 e orçamento 1007) foram removidos do
  banco real depois do teste — a base voltou aos **9 clientes** e a suíte a
  **65/65** (o `TestIntegridade018` confere essa contagem fixa).

### 3.24 Sincronização total por empresa: vendas, estoque e financeiro (03/11, concluído)

- **Escopo (decidido com o usuário):** "sincronizar tudo" baixa **clientes,
  produtos, orçamentos, vendas, estoque e financeiro** da empresa do usuário
  logado. O vínculo **vendedor/fornecedor** fica documentado para quando existir
  no banco — hoje `USUARIO` só tem `EMPRESA_ID` (não há tabela `VENDEDOR`).
- **API — empresa do token em tudo:** `DadosDoToken` passou para
  `uMiddlewareJWT` (interface + implementação) e é usado por clientes, produtos,
  vendas, estoque e financeiro. Todas as consultas ganharam
  `EMPRESA_ID = :EMP`; os `POST /api/clientes`, `POST /api/produtos` e
  `POST /api/estoque/movimento` deixaram de gravar `EMPRESA_ID = 1` fixo e usam
  a empresa/usuário do JWT. `EMPRESA_ID <= 0` responde **401** com
  "Token sem empresa. Entre novamente.".
- **Banco local v3:** `ErpDbHelper.VERSAO = 3`; `criarTabelasConsulta(db)` cria
  `venda_local`, `estoque_local`, `conta_receber_local` e `conta_pagar_local`
  no `onCreate` e no `onUpgrade` (`versaoAntiga < 3`), com índice único por
  `(empresa, id_servidor)`. Modelos novos: `VendaLocal`, `EstoqueLocal` e
  `ContaLocal`. `BancoLocal` ganhou listar/substituir/contar para cada conjunto
  e `salvarResumoFinanceiro`/`lerResumoFinanceiro` (metas `fin_*`).
- **Snapshots:** vendas, estoque e contas são **delete+insert por empresa**
  (nada local os referencia); clientes, produtos e orçamentos continuam com
  **upsert por `id_servidor`** para não quebrar ids locais pendentes.
- **Sincronizacao:** novos `baixarVendas`, `baixarEstoque`,
  `baixarResumoFinanceiro`, `baixarContasReceber` e `baixarContasPagar`; cada
  conjunto grava a meta `sync_<conjunto>` e a tela mostra a última data. O
  `Resultado` passou a contar vendas/estoque/contas no resumo exibido.
- **Tela nova:** `SincronizacaoActivity` + `activity_sincronizacao.xml`, aberta
  por **⋮ › Sincronizar dados** (`action_sincronizar` em `menu_dashboard.xml`,
  registrada no `AndroidManifest.xml`). Mostra empresa/usuário, o que será
  baixado (contagem + última sincronização), pendências da `outbox` e o botão
  **Baixar tudo**; sem rede, avisa que os dados continuam no aparelho.
- **Telas de consulta:** `VendasActivity`, `EstoqueActivity` e
  `FinanceiroActivity` leem do banco local e sincronizam em segundo plano na
  primeira exibição (padrão `sincronizouNestaVisita` de `ClientesActivity`).
  `DashboardActivity` lê o resumo/contagens/últimas vendas do cache, publica
  imediatamente e atualiza em segundo plano; "Atualizar resumo" força a rodada.
- **Validação:** API recompilada e os 8 endpoints testados com token → **200**;
  Android `BUILD SUCCESSFUL`; logcat mostrou `banco erp2026.db v3` com as 10
  tabelas. No emulador `Pixel_9`, **Baixar tudo** salvou 9 clientes, 4 produtos,
  0 orçamentos, 4 vendas, 4 itens de estoque, 2 contas a receber e 3 a pagar; o
  Dashboard exibiu faturamento R$ 70,00, A receber R$ 170,00 e A pagar
  R$ 1.595,00. Em **modo avião**, após `force-stop`, Dashboard, Vendas, Estoque
  e Financeiro continuaram abrindo com os dados locais e o botão mostrou
  "Sem conexão. Os dados continuam salvos no aparelho.". Suíte desktop
  **65/65** e build desktop **0/0**; nenhum dado de teste foi gravado no banco
  real nesta etapa.

### 3.25 Testes unitários da sincronização Android (03/11, concluído)

- **Decisão:** JUnit 4 + Robolectric 4.13 como `testImplementation` (só teste;
  não entra no APK) para exercitar o SQLite real do Android e o `ApiClient`
  sem emulador. Nenhuma dependência de runtime foi adicionada.
- **Arquivo:** `Android\android\app\src\test\java\com\example\erp2026_mobile\SincronizacaoTest.java`,
  com `@RunWith(RobolectricTestRunner.class)` e `@Config(sdk = 34)`;
  `app\build.gradle` ganhou `testOptions { unitTests.includeAndroidResources = true }`.
- **Servidor falso:** `ServerSocket` em `127.0.0.1:0` (HTTP/1.1 mínimo) —
  `com.sun.net.httpserver` não existe no `android.jar` usado para compilar os
  testes. Cada teste configura status/corpo por rota; `POST /api/clientes`
  cria o cliente (id 77) e passa a devolvê-lo na lista.
- **Isolamento:** antes/depois de cada caso, o singleton `BancoLocal.instancia`
  é zerado por reflexão, o `helper` é fechado e `erp2026.db` é apagado; as
  preferências `erp2026`/`erp2026_config` são limpas e a empresa volta a "1".
- **Casos (5/5 verdes):**
  1. `sincronizarBaixaTodosOsConjuntos` — clientes, produtos, orçamentos,
     vendas, estoque, resumo financeiro e contas; contadores do `Resultado`,
     tabelas locais, metas `sync_*`/`ultima_sincronizacao` e resumo `fin_*`.
  2. `sincronizarEnviaClientePendenteEBaixaIdDoServidor` — INSERT na outbox,
     POST, recarga da lista, `id_servidor = 77` e fila zerada.
  3. `snapshotsSubstituemDadosEIsolamPorEmpresa` — empresa 1 com 2 vendas,
     empresa 2 com 1, volta à 1 com as 2 intactas e novo snapshot substitui.
  4. `resposta401MarcaSessaoExpiradaEInterrompeDownloads` — 401 no primeiro
     GET preenche `sessaoExpirada`, mostra a mensagem e não grava metadados.
  5. `resposta401NoEnvioInterrompeAntesDosDownloads` — 401 no POST mantém a
     operação na fila e não tenta os demais conjuntos.
- **Correção revelada pelo teste:** a rodada continuava baixando os outros
  conjuntos depois de um 401 (só `enviarOrcamentos` era interrompido).
  `Sincronizacao.sincronizar` agora guarda cada download com
  `r.sessaoExpirada == null`; falhas não-401 continuam isoladas por conjunto.
- **Comando:** `Scripts\run_tests_android.bat` (ou
  `Android\android\gradlew.bat testDebugUnitTest`). Resultado **5/5**;
  `assembleDebug` **BUILD SUCCESSFUL**. Relatório em
  `Android\android\app\build\reports\tests\testDebugUnitTest\index.html`.
  A primeira execução baixa Robolectric/android-all; depois roda em segundos.
- **Sem rastro:** os testes usam banco e preferências próprios do Robolectric;
  nada é gravado no `DADOS.FDB` nem no aparelho.

---

### 3.26 Testes unitários dos cadastros no desktop (04/11, concluído)

- **Escopo (decidido com o usuário):** "ambos, em etapas" — primeiro os
  cadastros, depois as notas fiscais de entrada/saída. Esta etapa cobre
  **País, Estado, Cidade, Cor, Material, Produto Fiscal e Grade**.
- **Arquivos novos:**
  - `Desktop\src\Tests\uGeograficoTest.pas` — **11 testes** de
    País/Estado/Cidade: ciclo completo (inserir, buscar, pesquisar, atualizar,
    excluir), campos obrigatórios, UF inválida, pai inexistente e busca por
    ID inexistente.
  - `Desktop\src\Tests\uCadastrosFase1Test.pas` — **23 testes** de Cor (4),
    Material (4), Produto Fiscal (4) e Grade (11): ciclo completo,
    duplicidade, campos vazios, limites de tamanho, vínculo grade×produto,
    `USA_GRADE`, soma de quantidades e tipos de grade.
  - Registrados em `Desktop\src\Tests\uTestRunner.pas` e `Desktop\Tests.lpi`.
- **Padrão dos testes:** dados com sufixo de timestamp, limpeza explícita no
  `finally` (`DELETE` por ID e remoção de `LOG_SISTEMA` acima do topo
  capturado), sem mock de banco — igual às suítes existentes.
- **Resultado:** suíte desktop **99/99** (`Scripts\run_tests.bat`), antes
  **65/65**; `Scripts\build_desktop.bat` linka com **0/0**. Banco real deixado
  limpo: zero registros `%TESTE%` em País/Estado/Cidade/Cor/Material/Produto
  Fiscal/Grade, `PRODUTO 1.GRADE_ID = NULL` e `USA_GRADE = 'N'`.
- **Bugs reais corrigidos pelos testes:**
  1. `BuscarPorId` de `uPaisService`, `uEstadoService`, `uCidadeService` e
     `uGradeService` liberava a query interna do repositório (`LQuery.Free`)
     e o destructor a liberava de novo — *double free*. Agora apenas faz
     `Close` quando ativa.
  2. `Pesquisar` de `uMaterialService` e `uProdutoFiscalService` usava
     `CONTAINING` direto em `CODIGO` (30), `CODIGO_BARRAS` (20) e `NCM` (10);
     termo maior que a coluna estourava `string right truncation`. Agora usa
     `UPPER(CAST(coluna AS VARCHAR(n))) CONTAINING UPPER(:T)`.
  3. `TGradeService.DefinirGradeDoProduto` validava o produto no repositório
     de `GRADE` (`ValidarId`), recusando qualquer produto existente. Agora
     consulta `PRODUTO` diretamente antes do `UPDATE`.
- **Limites reais confirmados no banco:** `PAIS.CODIGO` 5, `ESTADO.UF` 2,
  `MATERIAL.CODIGO` 30, `PRODUTO_FISCAL.NCM` 10 e `GRADE.NOME` 60 — os dados
  de teste passaram a respeitá-los.
- **Commit:** `6db1cb7` (testes + correções); a documentação deste marco vem
  no commit seguinte.

---

### 3.27 Testes unitários das notas fiscais no desktop (04/11, concluído)

- **Escopo:** segunda etapa de "ambos, em etapas" — **34 testes** em
  `Desktop\src\Tests\uNotasFiscaisTest.pas` (15 de entrada + 19 de saída),
  registrados em `uTestRunner.pas` e `Tests.lpi`.
- **Nota de entrada** (`TNotaEntradaService`):
  - `CriarDoPedidoCompra`: cabeçalho (fornecedor, número, série/modelo, CFOP,
    totais), itens copiados com classificação fiscal do `PRODUTO_FISCAL`
    (e fallback para material sem vínculo), pedido **Confirmado** e vinculado,
    auditoria `NOTA_ENTRADA/I`.
  - Recusas: pedido inexistente, cancelado, sem itens e pedido que já gerou
    nota.
  - `Processar` com produto: saldo 10 → 15, custo médio ponderado
    `(10*10 + 5*20)/15`, `PRODUTO.PRECO_CUSTO` atualizado, movimento `E`,
    conta a pagar e bloqueio de reprocessamento.
  - `Processar` com material: saldo 2 → 5, movimento com saldo
    anterior/posterior, último custo no cadastro e condição 3× com três
    vencimentos de 30 dias.
  - Erros: nota sem itens, item sem produto/material, nota inexistente;
    `Cancelar` de nota aberta e de nota já processada; `ExcluirItem` +
    `RecalcularTotais`; `PrimeiroItemSemProduto`; `CarregarFiscalDoProduto`
    (vínculo, fallback do cadastro e produto zero).
- **Nota de saída** (`TNotaSaidaService`):
  - `CriarDoPedido`: cabeçalho, itens, fiscal com fallback, totais,
    `NotaDoPedido`, `QuantidadeItens` e bloqueio de segunda nota ativa;
    recusas para pedido inexistente, faturado e cancelado; nota sem itens.
  - `VerificarSaldo`: saldo suficiente, insuficiente (devolve descrição,
    disponível e solicitado) e item que não movimenta estoque.
  - `AtualizarCabecalho`: campos do cabeçalho, frete/seguro/outras no total,
    bloqueio após faturar e cliente obrigatório.
  - `GerarChaveAcesso`: 44 dígitos, AAMM da emissão, modelo, série e número
    com zeros à esquerda e **DV módulo 11 conferido de forma independente**.
  - `Faturar`: status `P`, baixa de estoque 10 → 6, `SALDO_APOS` do item,
    movimento `S`, contas a receber, chave/protocolo de homologação, pedido
    `F` com número e chave da NF-e; recusas sem cliente, sem itens, com
    estoque insuficiente (rollback sem movimento), item sem produto e nota
    inexistente.
  - `Cancelar`: nota aberta (sem movimentar estoque) e nota faturada
    (estorno do saldo, contas em aberto canceladas, pedido de volta a
    `P`, `NUMERO_NFE`/`CHAVE_NFE` limpos, motivo e data gravados).
  - `ExcluirItem` + `RecalcularTotais` e `GerarXML` (declaração, `nfeProc`,
    número, item, total, cliente e nota inexistente).
- **Padrão:** fixtures confirmadas antes de cada Service (os Services
  confirmam a transação internamente), sufixo de timestamp, limpeza no
  `finally` na ordem das dependências e `LOG_SISTEMA` cortado no topo
  capturado antes da suíte.
- **Resultado:** suíte desktop **133/133** (`Scripts\run_tests.bat`), antes
  **99/99**; build **0/0**. Banco real sem resíduos: nenhuma linha com o
  sufixo da rodada e **zero órfãos** na consulta do `TestIntegridade018`.
- **Achados e lições:**
  1. `PRODUTO.CATEGORIA_ID` e `PRODUTO.UNIDADE_ID` são `NOT NULL` no banco
     real (domínio `DM_ID`), mas `uFrmProdutos.Salvar` não grava as duas —
     incluir produto pela tela falha. As fixtures usam `1`/`1`; o bug do
     formulário ficou registrado como pendência (fora do escopo desta etapa).
  2. No SQLDB/Firebird um parâmetro nomeado repetido (`:P`) só é ligado na
     **primeira** ocorrência; as demais ficam `NULL`. A limpeza passou a usar
     `:P1`/`:P2`/`:P3` — sem isso sobravam `CONTA_RECEBER` órfãs.
  3. `RecalcularTotais` não confirma a transação: os testes de processamento
     de entrada chamam `RecalcularTotais` + `Confirmar` antes de `Processar`
     (sem total a nota não gera contas a pagar).
- **Commit:** `f918f8f` (testes + registro no runner/projeto); a documentação
  deste marco vem no commit seguinte.

---

### 3.28 Correção do cadastro de produto: categoria e unidade (07/11, concluído)

- **Bug:** `uFrmProdutos.Salvar` montava o `INSERT`/`UPDATE` de `PRODUTO` sem
  `CATEGORIA_ID` e `UNIDADE_ID`. No banco real as duas colunas usam o domínio
  `DM_ID`, que é `NOT NULL`, então incluir produto pela tela falhava com
  *validation error* — a pendência foi revelada pelos testes das notas (§3.27).
- **Correção em `Desktop\src\Views\uFrmProdutos.pas`:**
  - `Salvar`: `CATEGORIA_ID` e `UNIDADE_ID` entraram no `INSERT` (`:CAT`,
    `:UNID`) e no `UPDATE`; os parâmetros vêm de
    `cmbCategoria.Items.Objects[i]` / `cmbUnidade.Items.Objects[i]` (o ID já
    estava guardado nos combos, só não era usado).
  - `Validar`: categoria e unidade passam a ser **obrigatórias** (mensagem e
    foco no combo), em vez de gravar defaults silenciosos.
  - `PreencherCampos`: depois de carregar o registro, percorre os itens dos
    combos e seleciona o ID gravado (mesmo padrão já usado em `cmbGrade`).
- **Verificação:** `Scripts\build_desktop.bat` **0/0** (725 linhas, sem erros)
  e `Scripts\run_tests.bat` **133/133** — nenhuma regressão nas suítes
  existentes.
- **Commit:** `fed1cbd` (Produtos: gravar categoria e unidade no cadastro).

---

### 3.29 Testes do caixa e filtro com texto longo (07/11, concluído)

- **Escopo:** terceira etapa de "ambos, em etapas" — **17 testes** em
  `Desktop\src\Tests\uCaixaTest.pas`, registrados em `uTestRunner.pas` e
  `Tests.lpi`. `TCaixaService` é somente leitura (consulta `CAIXA` e
  `MOVIMENTO_CAIXA`), então a suíte não audita nada e a limpeza é só DELETE
  dos fixtures pelo sufixo.
- **`CarregarCaixas`:** saldo por caixa (entradas `E` menos saídas `S`;
  `G`/`P` ficam fora do saldo), `NUMERO` convertido para texto, nome do
  usuário via `LEFT JOIN`, `VALOR_ABERTURA`, status `A`/`F` com data e valor
  de fechamento, caixa sem movimento (saldo 0), usuário inexistente (nome
  vazio), ordenação por `ID` decrescente, escopo da empresa da sessão
  (caixa de outra empresa não aparece) e filtros por número/usuário.
- **`CarregarMovimentos`:** tradução `E→ENTRADA`, `S→SAIDA` e `G`/`P`
  mantidos, ordenação por `ID`, valores, descrição e usuário; filtros por
  descrição, tipo (`SAIDA`) e usuário; caixa `0`/negativo recusado.
- **`CarregarResumo`:** `ENTRADAS` (só `E`), `SAIDAS` (só `S`) e `SALDO`
  (E−S) com `CAST NUMERIC(18,4)`; caixa vazio devolve zeros; caixa inválido
  recusado.
- **Bug real encontrado e corrigido:** o filtro de `CarregarCaixas` comparava
  `CAST(C.NUMERO AS VARCHAR(20)) CONTAINING :PESQ2`; quando o texto digitado
  passava de 20 caracteres o Firebird devolvia *string right truncation*
  (`expected length 20, actual 28`). As buscas dos dois métodos passaram a
  comparar com `CAST(:PESQ AS VARCHAR(1000))` (e `:PESQ2`/`:PESQ3`), sem
  alterar o resultado dos filtros.
- **Domínio `DM_ID`:** `CAIXA.EMPRESA_ID`, `CAIXA.USUARIO_ID` e
  `MOVIMENTO_CAIXA.EMPRESA_ID` são `DM_ID` e portanto **NOT NULL** no banco
  real (o `RDB$NULL_FLAG` do campo fica nulo porque a obrigatoriedade vem do
  domínio). Os fixtures informam sempre empresa e usuário; a cláusula
  `OR C.EMPRESA_ID IS NULL` do Service é inalcançável, mas foi mantida.
- **Resultado:** suíte desktop **150/150** (antes **133/133**), build desktop
  **0/0**. Banco conferido: 3 caixas (as pré-existentes), 0 movimentos de
  teste e nenhuma linha com o sufixo da rodada.
- **Commit:** `bf94ef3` (testes + correção do Service + registro no
  runner/projeto); a documentação deste marco vem no commit seguinte.

---

### 3.30 Contas a pagar/receber: Service e testes (07/11, concluído)

- **Refatoração:** as regras que estavam dentro de `uFrmContasPagar` e
  `uFrmContasReceber` foram para `Desktop\src\Services\uContasService.pas`
  (regra de negócio em Service, como no resto do projeto). As telas passaram
  a chamar o Service e mantêm só a interação (InputQuery/MessageDlg) e o
  resumo na tela.
- **Service:**
  - `GarantirFinanceiroPagar`/`Receber`: reutiliza o primeiro `FINANCEIRO`
    da empresa com `TIPO` `P`/`R` e cria o plano padrão quando não existe;
  - `CriarContaPagar`/`Receber`: descrição obrigatória, valor > 0 e
    vencimento informado; grava `FINANCEIRO_ID`, `FORNECEDOR_ID`/`CLIENTE_ID`
    (0 = sem vínculo), status `A`, parcela 1 e audita `INSERT`;
  - `BaixarContaPagar`/`Receber`: só conta `A` no escopo da empresa; grava
    `STATUS` `P`, `DATA_PAGAMENTO = CURRENT_DATE` e `VALOR_PAGO = VALOR`;
    recusa inexistente, paga e cancelada; audita `BAIXA`;
  - `CarregarContasPagar`/`Receber`: período de vencimento, status e pesquisa
    por nome/descrição (com `CAST(:PESQ AS VARCHAR(1000))`), sempre no escopo
    da empresa da sessão e em ordem de vencimento. Antes as telas não
    filtravam empresa.
- **Bug real corrigido:** a inclusão de **conta a receber** pela tela não
  gravava `FINANCEIRO_ID`; como `CONTA_RECEBER.FINANCEIRO_ID` é `DM_ID`
  (`NOT NULL`), a operação falhava com *validation error*. O Service grava o
  plano `R` e `CLIENTE_ID = 0` quando não há vínculo.
- **Testes:** `Desktop\src\Tests\uContasTest.pas`, **16 testes**, cobrindo
  plano (reuso e tipos), criação (campos e validações), baixa (sucesso,
  dupla, inexistente, cancelada), listagem (período, status, texto longo,
  ordem e escopo da empresa) e auditoria. Limpeza por sufixo + corte do
  `LOG_SISTEMA` no topo capturado.
- **Resultado:** suíte desktop **166/166** (antes **150/150**), build desktop
  **0/0**. Banco conferido: 3 contas a pagar e 2 a receber (as
  pré-existentes), 2 planos financeiros e nenhuma linha com o sufixo da
  rodada; nenhum log `CONTA_PAGAR`/`CONTA_RECEBER` sobrou.
- **Commit:** `f0d947d` (Service + telas + testes); a documentação deste
  marco vem no commit seguinte.

---

### 3.31 Estoque: Service e testes (07/11, concluído)

- **Refatoração:** as regras de `uFrmMovEstoque` foram para
  `Desktop\src\Services\uEstoqueService.pas`. A tela continua com os campos,
  o combo de tipo e as mensagens; a regra ficou no Service.
- **Service:**
  - `RegistrarMovimento`: exige produto existente **na empresa da sessão**,
    tipo `E` (entrada), `S` (saída), `A` (ajuste) ou `I` (inventário),
    quantidade > 0 e custo não negativo; recusa documento acima de 50 e
    observação acima de 255 caracteres; grava empresa, usuário, documento e
    observação, devolve o ID e audita `INSERT` em `LOG_SISTEMA`;
  - `CarregarMovimentos`: período do dia inicial ao dia final **inclusive**,
    filtro por tipo, pesquisa por descrição/código/documento e **escopo da
    empresa da sessão**. A tela não filtrava empresa e o texto longo estourava
    `string right truncation` em `CODIGO` (30) / `DOCUMENTO` (50); o Service
    usa `CAST(:PESQ AS VARCHAR(1000))` nas três comparações;
  - `SaldoProduto`: soma `ESTOQUE.QUANTIDADE` por empresa/produto. O `SUM`
    precisa de `CAST(... AS NUMERIC(15,4))`: sem ele o SQLDB entrega o campo
    como `ftUnknown` e `AsFloat` volta **0** (mesma lição do saldo do caixa).
- **Trigger conferida:** `TRG_MOVEST_AI` soma `E` e `A`, subtrai `S`, não
  altera em `I` e cria a linha de `ESTOQUE` quando o produto ainda não tem
  saldo. Os testes exercitam a trigger de verdade, sem mock.
- **Testes:** `Desktop\src\Tests\uEstoqueTest.pas`, **18 testes**, cobrindo
  registro e campos gravados, efeito da trigger (E/S/A/I), criação do saldo,
  validações (produto 0/inexistente/de outra empresa, tipo, quantidade, custo,
  limites de texto), saldo e escopo da empresa, listagem por período (dia final
  inclusive), tipo, documento, texto longo e validações de query/período/tipo.
  Limpeza por sufixo (movimentos → estoque → produto) + corte do `LOG_SISTEMA`
  no topo capturado.
- **Resultado:** suíte desktop **184/184** (antes **166/166**), build desktop
  **0/0**. Banco conferido: 10 movimentos e 4 linhas de `ESTOQUE` (as
  pré-existentes), nenhum produto de teste, nenhuma linha com empresa `999999`
  e nenhum log `MOVIMENTO_ESTOQUE` sobrando.
- **Commit:** `2f0e3f7` (Service + tela + testes); a documentação deste marco
  vem no commit seguinte.

---

### 3.32 Pedido de venda: Service e testes (08/11, concluído)

- **Refatoração:** as regras de `uFrmPedidoVenda` foram para
  `Desktop\src\Services\uPedidoVendaService.pas`. A tela mantém os campos, os
  combos, o grid de itens, o diálogo de grade e as mensagens; a regra de
  negócio (numeração, totais, validação e gravação) ficou no Service.
- **Service:**
  - `ProximoNumero`: maior `NUMERO` **numérico** da empresa da sessão + 1.
    `NUMERO` é `VARCHAR(20)`: valores como `PV-TESTE-5` são ignorados. Antes a
    tela lia todos os pedidos, sem filtrar empresa;
  - `TotalItemPedido`/`TotalDoPedidoVenda` (funções exportadas): item =
    `quantidade * valor unitário - desconto` e pedido = `subtotal - desconto`,
    ambos **nunca negativos**. A tela usa as mesmas funções no grid, então o
    valor exibido e o gravado não divergem;
  - `SubtotalDosItens`/`TotalDoPedido`: quando o item tem grade, a quantidade é
    a **soma das quantidades por tamanho**;
  - `SalvarPedido`: valida cliente ativo do tipo `C` da empresa, pelo menos um
    item, produto da empresa, quantidade > 0, valor unitário e descontos não
    negativos, CFOP até 5 caracteres (vazio usa `5102`), observações até 255 e
    status de 1 caractere (`P` quando vazio); número vazio ou `'0'` usa
    `ProximoNumero`; grava `DATA_ENTREGA` só quando informada e devolve o ID;
  - **Transação única:** cabeçalho + itens + grade efetiva de cada item
    (`ITEM_PEDIDO_GRADE`) entram na mesma transação, com auditoria `INSERT` em
    `LOG_SISTEMA`. A grade usa `TGradeService.SalvarGradeItemPedido`, que não
    commita no meio porque a transação já está aberta;
  - **Correções em relação à tela antiga:** a numeração passou a ser por
    empresa; `PRECO_UNITARIO` passou a ser gravado (antes só `VALOR_UNITARIO`);
    o ID do pedido vem de `RETURNING ID` em vez de `GEN_ID(..., 0)`; e o item
    não pode mais gravar total negativo.
- **Testes:** `Desktop\src\Tests\uPedidoVendaTest.pas`, **25 testes**, cobrindo
  totais (item/pedido e nunca negativo), subtotal/total com grade, gravação
  completa (cabeçalho, itens, `PRECO_UNITARIO`/`VALOR_UNITARIO`, CFOP padrão,
  auditoria), número automático (`''` e `'0'`), numeração ignorando texto e por
  empresa, grade (quantidade = soma, linhas gravadas), múltiplos itens,
  desconto maior que o subtotal, `DATA_ENTREGA`, forma/condição 0 e entrega
  nulas, status padrão `P`, e as validações (cliente 0/inexistente/inativo/
  fornecedor, sem itens, produto 0/inexistente/de outra empresa, quantidade,
  valores negativos, CFOP, observações, número e status). Limpeza por sufixo
  (grade → itens → pedidos → produtos → pessoas) + corte do `LOG_SISTEMA` no
  topo capturado.
- **Resultado:** suíte desktop **209/209** (antes **184/184**), build desktop
  **0/0**. Banco conferido: 4 pedidos e 6 itens (os pré-existentes), nenhuma
  linha em `ITEM_PEDIDO_GRADE`, nenhum cliente/produto de teste e nenhuma linha
  com empresa `999999`.
- **Commit:** `ff66e68` (Service + tela + testes); a documentação deste marco
  vem no commit seguinte.

---

### 3.33 Compras: Service e testes (08/11, concluído)

- **Refatoração:** as regras de `uFrmCompras` foram para
  `Desktop\src\Services\uPedidoCompraService.pas`. A tela mantém os campos, os
  combos, o grid de itens e as mensagens; a regra de negócio (numeração, totais,
  validação e gravação) ficou no Service.
- **Service:**
  - `ProximoNumero`: maior `NUMERO` **numérico** da empresa da sessão + 1.
    `NUMERO` é `VARCHAR(20)`: valores como `PC-TESTE-8` são ignorados. Antes a
    tela lia todos os pedidos, sem filtrar empresa;
  - `TotalItemCompra`/`TotalDoPedidoCompra` (funções exportadas): item =
    `quantidade * valor unitário - desconto` e pedido = `subtotal - desconto`,
    ambos **nunca negativos**. A tela usa as mesmas funções no grid e no
    subtotal/total, então o valor exibido e o gravado não divergem;
  - `SalvarPedido`: valida fornecedor ativo do tipo `F` da empresa, pelo menos um
    material da empresa, quantidade > 0, valor unitário e descontos não
    negativos, observações até 500 e status `ABERTO`/`CONFIRMADO`/`CANCELADO`
    (vazio = `ABERTO`); número vazio ou `'0'` usa `ProximoNumero`; grava
    `DATA_EMISSAO`/`DATA_ENTREGA` só quando informadas (a trigger preenche a
    emissão com a data atual) e devolve o ID;
  - **Transação única:** cabeçalho + itens entram na mesma transação, com
    auditoria `INSERT` em `LOG_SISTEMA`;
  - **Correções em relação à tela antiga:** a numeração passou a ser por
    empresa; o ID do pedido vem de `RETURNING ID` em vez de
    `GEN_ID(..., 0)`; o total do item nunca fica negativo; o desconto do pedido
    passou a ser gravado e abatido do total; e o combo de fornecedores passou a
    listar só os **ativos da empresa** da sessão.
- **Testes:** `Desktop\src\Tests\uPedidoCompraTest.pas`, **22 testes**, cobrindo
  totais (item/pedido e nunca negativo), subtotal/total no Service, gravação
  completa (cabeçalho, itens, `SUBTOTAL`/`DESCONTO`/`TOTAL`, datas, auditoria),
  número automático (`''` e `'0'`), numeração ignorando texto e por empresa,
  múltiplos itens, desconto maior que o subtotal, status
  `ABERTO`/`CONFIRMADO`/`CANCELADO`, datas opcionais, e as validações
  (fornecedor 0/inexistente/inativo/cliente, sem itens, material
  0/inexistente/de outra empresa, quantidade, valores negativos, observações,
  número e status). Limpeza por sufixo (itens → pedidos → materiais → pessoas)
  + corte do `LOG_SISTEMA` no topo capturado.
- **Resultado:** suíte desktop **231/231** (antes **209/209**), build desktop
  **0/0**. Banco conferido: 1 pedido de compra (`PC-TESTE-8`, `CONFIRMADO`) e 1
  item (os pré-existentes), nenhuma pessoa/material de teste e nenhuma linha com
  empresa `999999`.
- **Commit:** `d7e3304` (Service + tela + testes); a documentação deste marco
  vem no commit seguinte.

---

### 3.34 Orçamento: Service e testes (08/11, concluído)

- **Refatoração:** as regras de `uFrmOrcamento` foram para
  `Desktop\src\Services\uOrcamentoService.pas`. A tela mantém os campos, os
  combos, o grid de itens e as mensagens; a regra de negócio (gravação com
  status `O`, numeração, totais, validação e conversão) ficou no Service.
- **Service:** o orçamento é um `PEDIDO_VENDA` com `STATUS='O'`, então a
  gravação delega para `TPedidoVendaService.SalvarPedido` com status `O`
  (reaproveita numeração por empresa, totais, validações, itens,
  `PRECO_UNITARIO`/`VALOR_UNITARIO`, CFOP padrão `5102` e auditoria `INSERT`).
  Regras próprias:
  - `SalvarOrcamento`: grava sempre com `STATUS='O'`, devolve o ID e usa
    `ProximoNumero` quando o número é vazio ou `'0'`;
  - `ConverterEmPedido`: busca o registro, recusa inexistente, de **outra
    empresa** e com status diferente de `O` (inclusive já convertido `P`);
    o `UPDATE` tem `STATUS='O'` no `WHERE` (protege contra conversão dupla) e
    grava auditoria `CONVERSAO` (`STATUS=O` → `STATUS=P`) na mesma transação;
  - `QuantidadeItens` e `ProximoNumero` delegam ao Service de pedido de venda.
- **Correções em relação à tela antiga:** `CarregarClientes` passou a filtrar a
  empresa da sessão; a busca de produto passou a filtrar a empresa e usa
  `:COD1/:COD2/:COD3` (no SQLDB um parâmetro repetido só é ligado na primeira
  ocorrência, então buscar por código de barras/ID não funcionava); o
  orçamento passou a gravar `NUMERO`, `PRECO_UNITARIO`, CFOP e auditoria; o
  total do item/pedido usa as funções do Service (nunca negativo); e a
  conversão não muda mais qualquer registro para `P` sem validar status/escopo.
  A tela também não limpa mais o formulário logo após salvar: mantém o ID para
  o botão **Gerar Pedido** e limpa só o que já foi gravado.
- **Observação:** `edtData`/`edtValidade`/`edtVendedor` continuam apenas na
  interface — `PEDIDO_VENDA` não tem colunas de validade nem de vendedor (o
  vendedor exibido é o usuário da sessão). Nada novo foi persistido à força.
- **Testes:** `Desktop\src\Tests\uOrcamentoTest.pas`, **23 testes**, cobrindo
  totais, gravação completa (cabeçalho, item, `PRECO_UNITARIO`,
  `VALOR_UNITARIO`, CFOP padrão, auditoria, `DATA_EMISSAO` pela trigger e
  entrega nula), número automático, numeração ignorando texto e por empresa,
  múltiplos itens, desconto maior que o subtotal, data de entrega, conversão
  em pedido (`O` → `P` + auditoria `CONVERSAO`), conversão dupla/inexistente/
  de outra empresa/status inválido e as validações (cliente 0/inexistente/
  inativo/fornecedor, sem itens, produto 0/inexistente/de outra empresa,
  quantidade, valores negativos, observações e número). Limpeza por sufixo
  (grade → itens → pedidos → produtos → pessoas) + corte do `LOG_SISTEMA` no
  topo capturado.
- **Resultado:** suíte desktop **254/254** (antes **231/231**), build desktop
  **0/0**. Banco conferido: 4 pedidos e 6 itens (os pré-existentes), nenhuma
  linha em `ITEM_PEDIDO_GRADE`, nenhuma pessoa/produto de teste, nenhuma linha
  com empresa `999999` e nenhum log de `CONVERSAO`.
- **Commit:** `ae86f28` (Service + tela + testes); a documentação deste marco
  vem no commit seguinte.

### 3.35 PDV: Service e testes (08/11, concluído)

- **Refatoração:** as regras de `uFrmPDV` foram para
  `Desktop\src\Services\uPDVService.pas`. A tela manteve o layout, o grid, os
  atalhos (F2–F6/ESC), as mensagens e as listas paralelas
  `FProdutoIds`/`FPrecos` (para não reinterpretar o texto formatado do grid);
  a regra de negócio (caixa, venda, itens, movimento, saldo e fechamento)
  ficou no Service.
- **Correções em relação à tela antiga:** o PDV gravava itens em
  `ITEM_PEDIDO_VENDA` (**tabela inexistente** — a correta é `ITEM_PEDIDO`),
  não informava `CLIENTE_ID` (domínio `DM_ID NOT NULL`), omitia
  `EMPRESA_ID`/`USUARIO_ID` em `MOVIMENTO_CAIXA` e confirmava o movimento no
  meio da venda (venda e baixa podiam divergir). Tudo passou a ser gravado na
  **mesma transação**, com auditoria.
- **Service (`TPDVService`):**
  - `ProximoNumeroVenda`/`ProximoNumeroCaixa`: maior `NUMERO` **numérico** da
    empresa + 1, ignorando textos (ex.: `ORC-...`) e outra empresa;
  - `CaixaAberto(AUsuarioId = 0)`: caixa `STATUS='A'` da empresa/usuário
    (padrão: sessão); `AbrirCaixa` recusa valor negativo e caixa já aberto,
    grava número automático e audita `INSERT`; `FecharCaixa` grava
    `STATUS='F'`, `DATA_FECHAMENTO`, `VALOR_FECHAMENTO` (saldo) e audita
    `FECHAMENTO`, recusando fechar de novo;
  - `BuscarProduto`: por `CODIGO` ou `CODIGO_BARRAS` (`:COD1/:COD2`, pois no
    SQLDB um parâmetro repetido só é ligado na primeira ocorrência), somente
    `ATIVO='A'` e da empresa;
  - `SalvarVenda`: valida caixa aberto da empresa, itens, desconto, cliente e
    observações; calcula subtotal/total (nunca negativos); grava cabeçalho
    `PEDIDO_VENDA` com `STATUS='F'`, número automático e cliente informado ou
    **"Consumidor Final"** (criado/reutilizado por empresa), itens em
    `ITEM_PEDIDO` (`PRECO_UNITARIO`, `VALOR_UNITARIO`, `DESCONTO=0`,
    `VALOR_TOTAL`, CFOP `5102`) e um `MOVIMENTO_CAIXA` `TIPO='V'` com
    `EMPRESA_ID`, `USUARIO_ID`, `PEDIDO_VENDA_ID` e `FORMA_PAGAMENTO_ID`
    opcional — tudo na mesma transação, com auditoria `INSERT` das duas
    tabelas;
  - `RegistrarMovimento`: só `E`/`S`, valor > 0, caixa aberto da empresa e
    descrição até 255, com auditoria;
  - `SaldoCaixa`: abertura + entradas (`E` e `V`) − saídas (`S`), com `CAST`
    numérico (sem ele o Firebird devolve `ftUnknown` e o valor vem 0);
  - `QuantidadeItens` e `CarregarFormasPagamento` (ID em `Objects`).
- **Caixa (`uCaixaService`):** `TIPO='V'` passou a contar como **entrada** no
  saldo da grade e no resumo (`ENTRADAS`/`SALDO`), e o movimento aparece como
  `VENDA` na grade/filtro. Antes a venda do PDV ficava fora do saldo.
  Observação: a grade/resumo do `TCaixaService` mostram o saldo **só dos
  movimentos**; a abertura entra apenas no `SaldoCaixa` do PDV.
- **Consumidor Final:** a venda balcão sem cliente usa/cria uma `PESSOA`
  `TIPO='C'`, `TIPO_PESSOA='F'`, `ATIVO='A'`, nome `Consumidor Final` e
  `CPF_CNPJ='000.000.000-00'`, por empresa; vendas seguintes reutilizam.
- **Testes:** `Desktop\src\Tests\uPDVTest.pas`, **34 testes**, cobrindo totais,
  numeração (texto/outra empresa) de venda e caixa, `CaixaAberto`, abertura
  (inclusive duplicada/negativa), busca de produto (código/barras/inativo/
  outra empresa/vazio), venda completa (cabeçalho `F`, item, movimento `V`,
  auditorias), consumidor final (reuso e forma de pagamento nula), múltiplos
  itens, desconto maior, número automático, saldo (PDV + grade/resumo do
  `TCaixaService`), sangria/suprimento, fechamento, formas de pagamento e as
  validações (sem itens, caixa/produto/cliente inválidos, quantidade, preço,
  desconto e observações). Limpeza por sufixo + remoção dos caixas do usuário
  fictício `990001` + corte do `LOG_SISTEMA` no topo capturado.
- **Resultado:** suíte desktop **288/288** (antes **254/254**), build desktop
  **0/0**. Banco conferido: nenhuma pessoa/produto de teste, nenhum pedido com
  observação de teste, nenhum caixa do usuário `990001`, nenhum movimento
  desses caixas e nenhum "Consumidor Final" criado pela suíte.
- **Commit:** `0bff99d` (Service + tela + caixa + testes); a documentação
  deste marco vem no commit seguinte.

---

### 3.36 Movimento Financeiro: Service e testes (08/11, concluído)

- **Service (`uMovimentoFinanceiroService`):** regras de `uFrmMovimentoFinanceiro`
  extraídas — validação de tipo/categoria/documento/valores, listagem por
  período/status/texto **sempre no `EMPRESA_ID` da sessão**, gravação com
  auditoria `INSERT`/`ALTERAR`/`EXCLUIR` na mesma transação e exclusão bloqueada
  quando o registro é de outra empresa.
- **Tela:** `uFrmMovimentoFinanceiro` passou a delegar ao Service; os filtros
  de texto usam `CAST(... AS VARCHAR(...))` para evitar `string right
  truncation` em campos `CHAR`/`VARCHAR` curtos.
- **Testes:** `uMovimentoFinanceiroTest` — incluir/alterar/excluir na mesma
  empresa, bloqueio de outra empresa (alterar/excluir), listagem com escopo,
  filtros de pesquisa, ordenação `DATA DESC, ID DESC`, busca por ID e
  validações de tipo/categoria/documento/valores. Registrado em
  `uTestRunner.pas` e `Tests.lpi`.
- **Commit:** ver `git log` (marco 3.36).

### 3.37 Inventário: Service e testes (08/11, concluído)

- **Service (`uInventarioService`):** `CarregarInventario` lista produtos
  `ATIVO='A'` com `CONTROLA_ESTOQUE='S'` da empresa da sessão, com filtros de
  texto (descrição/código), "apenas com estoque" e "abaixo do mínimo";
  `ValorTotalEstoque` soma `ESTOQUE.QUANTIDADE * PRODUTO.PRECO_CUSTO`.
- **Correção:** a query usava `P.CONTROLE_ESTOQUE` — coluna inexistente (o nome
  real é `CONTROLA_ESTOQUE`); a tela de Inventário estava quebrada. Corrigido
  no commit `079241a`.
- **Tela:** `uFrmInventario` delega ao Service.
- **Testes:** `uInventarioTest` — escopo de empresa, só `CONTROLA_ESTOQUE='S'`,
  só `ATIVO='A'`, pesquisa por descrição/código, filtros de estoque/mínimo e
  delta de `ValorTotalEstoque`.
- **Commit:** ver `git log` (marco 3.37).

### 3.38 Kardex: Service e testes (08/11, concluído)

- **Service (`uKardexService`):** `BuscarProduto` por código/código de barras/
  ID no escopo da empresa; `CarregarKardex` com período, documento/observação
  (`CONTAINING` parametrizado); `CarregarResumo` (entradas `E`/`A`, saídas `S`,
  saldo) via record `TKardexResumo`.
- **Tela:** `uFrmKardex` delega ao Service.
- **Testes:** `uKardexTest` — busca por código/barras/ID/não encontrado,
  escopo de empresa, filtro de período, pesquisa por documento/observação,
  resumo entradas/saídas/saldo, período vazio e outra empresa.
- **Commit:** ver `git log` (marco 3.38).

### 3.39 Testes MF/Inventário/Kardex no padrão da suíte + correções (08/11, concluído)

- **Problema encontrado:** os 3 arquivos de teste criados nos marcos 3.36–3.38
  estavam em **fpcunit** (`TTestCase`/`RegisterTest`) — o runner customizado
  (`uAssert`/`TTestSuite`) nunca os executava, e eles faziam `DELETE` em
  `PRODUTO`/`ESTOQUE`/`MOVIMENTO_ESTOQUE`/`MOVIMENTO_FINANCEIRO` da empresa de
  teste inteira.
- **Correção:** reescritos com `class procedure RunAllTests(ASuite)` +
  `ASuite.AddResult`, dados com sufixo de timestamp e limpeza só dos IDs
  criados no `finally`; registrados de fato no `uTestRunner.pas`. Suíte subiu
  de 288 para **325** testes.
- **Bugs revelados pelos testes (corrigidos em `079241a`):**
  - `uInventarioService`: `CONTROLE_ESTOQUE` → `CONTROLA_ESTOQUE` (coluna
    inexistente quebrava a listagem); `CAST` nos filtros de texto.
  - `uKardexService`: `BETWEEN :DI AND :DF` → `>= :DI AND < :DF` (o fim
    inclusivo vazava o dia seguinte); `CAST(... AS DOUBLE PRECISION)` em
    `VALOR_TOTAL` e no resumo — **`SUM`/multiplicação de `NUMERIC(15,4)`
    retornava NULL no Firebird 5** (mesmo comportamento do resumo financeiro
    da API, §3.18).
  - `uMovimentoFinanceiroService`: `CAST` em `PESQ3` (documento).
  - `uFrmNFe.CarregarPedidos`: não filtrava `EMPRESA_ID` — agora
    `PV.EMPRESA_ID = :EMP`.
  - `TACBrHelper.GerarNFe`: pedido, sequência de `NUMERO_NFE` e `UPDATE`
    passaram a respeitar `EMPRESA_ID`; join `PESSOA` por empresa; escrita em
    transação com auditoria `LOG_SISTEMA`.
- **Resultado:** suíte desktop **325/325**, build desktop **0/0**.
- **Commit:** `079241a`.

---

### 3.40 Produção: suíte do fluxo de negócio (08/11, concluído)

- **Lacuna:** `uProducaoTest` cobria estrutura/permissões/auditoria, mas o
  fluxo de negócio do `TProducaoService` (ficha técnica → mapa → talões →
  bipagem → consumo) não tinha nenhum teste.
- **`uProducaoFluxoTest` (12 testes, banco real):**
  - `TestFichaValidacoes`/`TestFichaGravarELer`: produto/base/itens
    obrigatórios, material ≠ produto, quantidade/perda válidas, material
    duplicado, leitura e upsert (mesmo ID, itens substituídos).
  - `TestMapaValidacoes`/`TestMapaCriarParciais`/`TestMapaEscopoEmpresa`:
    pedido cancelado/inexistente, quantidade zero/acima do pendente, item
    de outro pedido, parcial (pendente zera), pedido `P`→`E` e mapa que
    herda `EMPRESA_ID` do pedido (999999).
  - `TestTaloesGerar`: modo `ITEM` (1 talão, qtd toda), `UNIDADE` (1 por
    unidade), código `T`+6 dígitos, `GERADO`→item/mapa `EM_PRODUCAO`,
    modo inválido e item já taloado.
  - `TestBiparFluxoCompleto`: `INICIO`→`EM_PRODUCAO`, `CONCLUSAO`→
    `CONCLUIDO`, mapa `CONCLUIDO`, pedido `D`, `DUPLICADO`, `INVALIDO`
    (inexistente/vazio), `ProgressoMapa`.
  - `TestCancelarMapaETalao`: motivo obrigatório, mapa sem concluídos
    cancela (pedido volta `P`), mapa com talão concluído bloqueado,
    talão `GERADO` cancela / já cancelado bloqueado.
  - `TestConsumoSemFicha`/`TestConsumoPlanejadoSemProducao`/
    `TestConsumoConfirmarEstornar`/`TestConsumoSemSaldo`: ficha
    obrigatória nos dois modos, `PRODUZIDO` exige talões concluídos,
    `PLANEJADO` funciona em mapa aberto, `QTD_PREVISTA` = base × consumo
    × (1+perda%), substituição de consumo `PENDENTE`, `QTD_REAL` custom,
    saldo insuficiente, movimentos `S`/`E`, `CONFIRMADO`→`ESTORNADO` e
    re-geração após estorno.
- **Resultado:** suíte desktop **337/337** (antes 325), build **0 erros**.
- **Commit:** `c57cb90`.

### 3.41 Nota de Entrada — escrita movida para o Service (08/11)

- **Problema:** `uFrmNotaEntrada` fazia INSERT/UPDATE direto em
  `NOTA_ENTRADA` e `NOTA_ENTRADA_ITEM` no form, embora
  `TNotaEntradaService` já existisse (totais/processar/cancelar). Update
  do cabeçalho não validava empresa nem status; update do item não
  conferia a nota-pai.
- **Entrega:**
  - `TNotaEntradaService.SalvarCabecalho(ANotaId, ADados)` — record
    `TNotaEntradaCabecalho` na interface; insert com `RETURNING ID` ou
    update com guarda `STATUS <> 'P'` + `EMPRESA_ID` (anti-IDOR);
    `RegistrarAuditoria('NOTA_ENTRADA','I'/'U')`; `RecalcularTotais` na
    mesma transação.
  - `TNotaEntradaService.SalvarItem(ANotaId, AItemId, AProdutoId, ...)` —
    classificação fiscal via `CarregarFiscalDoProduto`, VALOR_ICMS e
    VALOR_TOTAL calculados no Service, update exige `NOTA_ENTRADA_ID`,
    auditoria `NOTA_ENTRADA_ITEM`.
  - Form delega; validações de tela (fornecedor/número preenchidos)
    permanecem na UI antes da chamada.
- **Varredura de telas:** produção (`uFrmConsumoMaterial`,
  `uFrmFichaTecnica`, `uFrmBipagem`, `uFrmCoresProduto`) está 100%
  delegada. Restam escrita direta em cadastros simples
  (`uFrmCategorias`, `uFrmCidade`, `uFrmEstado`, `uFrmPais`,
  `uFrmMaterial`, `uFrmProdutoFiscal`, `uFrmProdutos`, `uFrmUsuarios`) e
  o UPDATE de senha do `uFrmLogin` — backlog em "Próximo passo".
- **Resultado:** build **0 erros**, suíte **337/337**.
- **Commit:** `6e6b707`.

### 3.42 Geográficos — escrita delegada aos Services (08/11)

- **Problema:** `uFrmPais`/`uFrmEstado`/`uFrmCidade` faziam
  INSERT/UPDATE/DELETE direto no form apesar de os Services já existirem
  (e sem auditoria nem validação de filhos no delete).
- **Entrega:**
  - Models `TPais`/`TEstado`/`TCidade` ganharam `Ativo` e `TCidade`
    ganhou `CepPadrao` — campos que a tela já gravava mas o model não
    expunha.
  - Services: `ATIVO`/`CEP_PADRAO` no insert/update, leitura no
    `BuscarPorId`, `LogOperacao` em I/U/D, `ValidarId` no update/excluir
    e checagem de filhos no delete (país→ESTADO, estado→CIDADE) com a
    mesma mensagem que a tela exibia.
  - Forms montam o model e chamam `Inserir`/`Atualizar`/`Excluir`;
    `FService` liberado no `destructor`.
- **Resultado:** build **0 erros**, suíte **337/337** (inclui
  `uGeograficoTest`, que já exercitava os Services).
- **Commit:** `70e946c`.

### 3.43 Cadastros — Material, Produto Fiscal e Categoria via Service (08/11)

- **Material/Produto Fiscal (trabalho já em andamento, commitado):**
  `uFrmMaterial` e `uFrmProdutoFiscal` delegam INSERT/UPDATE/DELETE a
  `TMaterialService`/`TProdutoFiscalService`; `TProdutoFiscal` ganhou
  `Tipo`/`Valor` (colunas de `PRODUTO_FISCAL` da migração 014 que o
  model/service não gravavam); `TRepositoryBase` ganhou
  `InserirParamN`/`AtualizarParamN` + `AplicarParamsN` para gravar
  NULL em parâmetro (TIPO vazio → NULL, pois o CHECK só aceita 'S'/'O').
- **Categoria:** `uFrmCategorias` inseria `EMPRESA_ID`, coluna que
  **não existe** em `CATEGORIA` no banco real (tabela global, como as
  geográficas) — o INSERT falhava com "column unknown". Criado
  `TCategoriaService` (`uCategoriaService.pas`): nome obrigatório,
  nome único global case-insensitive, `LogOperacao` em I/U/D;
  form delega escrita e o INSERT passa a funcionar sem EMPRESA_ID.
- **Testes:** `uCadastrosFase1Test` ganhou `TestProdutoFiscalTipoValor`
  (TIPO ''→NULL e 'S' no insert/update, VALOR) e 3 de Categoria
  (ciclo completo, sem nome, nome duplicado).
- **Migração 019:** `USUARIO.TELEFONE` (a tela de usuários já usava a
  coluna, que não existia) — commitada; já estava aplicada no banco.
- **Resultado:** build **0 erros/0 warnings**, suíte **341/341**.
- **Commits:** `a62868a`, `7e8d706` e o commit deste marco.

### 3.44 Produto — escrita delegada ao novo TProdutoService (08/11)

- **Entrega:** `uProdutoService.pas` criado (não existia): validação de
  descrição, `CATEGORIA_ID`/`UNIDADE_ID` > 0 (`DM_ID` = `BIGINT NOT
  NULL`) e `PRECO_VENDA` > 0; grava o mesmo conjunto de colunas que a
  tela + `GRADE_ID` anulável via `InserirParamN`/`AtualizarParamN`
  (0 → NULL); `LogOperacao` I/U/D; `Pesquisar` com CAST+CONTAINING.
  Model `TProduto` ganhou `GradeId` e `ProdutoFiscalId`. Form delega
  Salvar/Excluir; `FProdutoService` liberado no `FormDestroy`.
- **Testes:** `uCadastrosFase1Test` +4 (`TestProdutoCicloCompleto` —
  inclui GRADE_ID NULL→valor, `TestProdutoSemDescricao`,
  `TestProdutoSemCategoria`, `TestProdutoPrecoVendaZero`).
- **Resultado:** build **0 erros**, suíte **345/345**.
- **Commit:** `69b6e71`.

### 3.45 Usuário — escrita delegada ao novo TUsuarioService (08/11)

- **Entrega:** `uUsuarioService.pas` criado. Senha chega em texto puro
  e é gravada como **SHA-256** no Service (`HashSenha`); no update,
  senha vazia mantém a atual. Login único por empresa
  (case-insensitive). **`GRUPO_ID` passou a ser gravado** — a tela já
  tinha o combo e o model o campo, mas o INSERT/UPDATE antigo não
  gravava a coluna; como `DM_ID` é `NOT NULL`, o cadastro de usuário
  falhava no banco (mesmo bug do `EMPRESA_ID` em CATEGORIA). Service
  exige grupo > 0 e a tela ganhou a mesma validação + reseleção do
  grupo em `PreencherCampos`. `TELEFONE` incluído (migração 019).
  Auto-exclusão bloqueada no Service (além da tela). `LogOperacao`
  I/U/D. Model `TUsuario` ganhou `Telefone`.
- **Extra para o login:** `BuscarPorLogin` (LOGIN + ATIVO='A', traz o
  hash) e `RegistrarAcesso` (ULTIMO_ACESSO + migração de senha legada
  para hash, auditada só quando migra).
- **Testes:** `uCadastrosFase1Test` +4 (`TestUsuarioCicloCompleto` —
  hash SHA-256 no banco, `SenhaConfere`, senha vazia mantém hash,
  senha nova troca hash; `TestUsuarioLoginDuplicado`,
  `TestUsuarioSenhaCurta`, `TestUsuarioSemNome`).
- **Resultado:** build **0 erros**, suíte **349/349**.
- **Commit:** `c7e67b9`.

### 3.46 Login — autenticação delegada ao Service (08/11)

- **Entrega:** `uFrmLogin.Autenticar` não tem mais SQL: usa
  `TUsuarioService.BuscarPorLogin` + `SenhaConfere` (uSenhaHash) +
  `RegistrarAcesso` (ULTIMO_ACESSO e migração de senha legada).
  Comportamento idêntico ao anterior.
- **Varredura final:** `grep -iE "insert into|update |delete from"`
  em `Desktop\src\Views\*.pas` → **zero ocorrências**. Toda escrita
  de tela passa por Service.
- **Resultado:** build **0 erros**, suíte **349/349**.
- **Commit:** `a13f106`.

### 3.47 Consultas — escopo de EMPRESA_ID (08/11)

- **Problema:** os `Pesquisar` de `TMaterialService`,
  `TProdutoFiscalService` e `TProdutoService` e os `CarregarDados`
  de `uFrmMaterial`, `uFrmProdutoFiscal`, `uFrmProdutos` e
  `uFrmUsuarios` não filtravam `EMPRESA_ID` — as listagens e as
  buscas mostravam registros de todas as empresas.
- **Entrega:** predicado `EMPRESA_ID = :EMP` parametrizado
  (`TSessao.GetInstance.EmpresaId`) nos 3 services e nas 4 telas.
  `CATEGORIA` e as tabelas geográficas permanecem globais (sem
  `EMPRESA_ID`). Os lookups de produto/material nas telas de
  Compras (MATERIAL por ID), Movimento de Estoque, Nota de
  Entrada (3 consultas de PRODUTO), Pedido de Venda e Ficha
  Técnica (combo de produtos) também passaram a filtrar a
  empresa da sessão.
- **Extra:** destructors de `uFrmMaterial`/`uFrmProdutoFiscal`
  movidos de `private` para `public` (warnings 3019 do FPC).
- **Resultado:** build **0 erros / 0 warnings**, suíte **349/349**.
- **Commit:** `759fae7`.

### 3.48 Services — guarda de EMPRESA_ID nas escritas por ID (08/11)

- **Problema:** `Atualizar`/`Excluir` dos services de cadastro
  gravavam `WHERE ID = :ID` sem verificar a empresa — um ID de
  outra empresa podia ser alterado ou excluído (IDOR
  multiempresa). O `TNotaSaidaService.ProximoNumero` calculava
  `MAX(NUMERO)` sobre todas as empresas.
- **Entrega:** `GarantirDaEmpresa(AId)` privado em
  `TProdutoService`, `TMaterialService`, `TProdutoFiscalService` e
  `TUsuarioService` (chamado em `Atualizar`/`Excluir`);
  `TPessoaService` ganhou `AND EMPRESA_ID = :EMP` no SELECT de
  tipo e no UPDATE, e verificação de posse no `Excluir`;
  `TGradeService` validou empresa em `Atualizar`, `Excluir`,
  `GradeDoProduto` e `DefinirGradeDoProduto` (produto e grade).
  `ProximoNumero` da nota de saída filtra `EMPRESA_ID = :EMP`.
- **Resultado:** build **0 erros / 0 warnings**, suíte **349/349**.
- **Commit:** `2b588d1`.

### 3.49 Telas — escopo de EMPRESA_ID nas listagens e buscas (08/11)

- **Varredura:** todos os `SELECT` de `Desktop\src\Views` e
  `Desktop\src\Services` foram revisados quanto a `EMPRESA_ID`.
- **Corrigido:** listagens de pedidos sem filtro de empresa em
  `uFrmListaPedidos`, `uFrmMapaProducao` e `uFrmNotaSaida`; listas e
  abertura de nota em `uFrmNotaEntrada`/`uFrmNotaSaida`; buscas de
  cliente/fornecedor por texto, CNPJ e nome (inclusive o lookup de
  fornecedor do XML) em `uFrmNotaEntrada`, `uFrmNotaSaida` e
  `uFrmPedidoVenda` (combo de clientes). Todas passaram a usar
  `EMPRESA_ID = :EMP` com `TSessao`.
- **Mantido propositalmente:** consultas por ID de item
  (`NOTA_*_ID`, `MAPA_PRODUCAO_ID`, `TALAO`) — o pai já é validado
  pela empresa antes; `CATEGORIA`/geográficos são globais.
- **Resultado:** build **0 erros / 0 warnings**, suíte **349/349**.
- **Commit:** `41719b9`.

### 3.50 Services — GarantirDaEmpresa nas notas e Cor (08/11)

- **Entrega:** `uServiceBase` expõe `GarantirEmpresaBanco`
  (função standalone para services sem herança) e os métodos
  `GarantirDaEmpresa`/`GarantirDaEmpresaSql`. `TNotaEntradaService`
  e `TNotaSaidaService` passaram a validar a empresa da sessão em
  todos os pontos de entrada por ID — incluindo itens resolvidos
  pelo registro pai. `CriarDoPedidoCompra`/`CriarDoPedido` validam
  o pedido antes de gerar a nota. `TCorService` ganhou a mesma
  guarda em `Atualizar`/`Excluir`.
- **Exceção deliberada:** `TProducaoService` deriva `EMPRESA_ID` do
  registro pai (mapa/talão/consumo) em vez da sessão — comportamento
  coberto por `TestMapaEscopoEmpresa`; guards de sessão foram
  revertidos lá.
- **Resultado:** build **0 erros**, suíte **349/349**.
- **Commits:** `7114bab` (+ Cor).

---

### 3.51 Auditoria da API — isolamento de empresa nas rotas (08/11)

- **Varredura:** todos os `SELECT`/`INSERT`/`UPDATE`/`DELETE` de
  `API\src\Rotas` conferidos. Listagens, detalhes, escritas e
  validações de cliente/produto/fornecedor já usam
  `EMPRESA_ID = :EMP` derivado do JWT (`DadosDoToken`); queries de
  itens (`ITEM_PEDIDO`) ficam seguras porque o cabeçalho pai é
  validado antes (NotFound se fora da empresa). O `UPDATE` de senha
  em `uRotasLogin` é auto-referente (ID do próprio usuário
  autenticado).
- **Correção:** a segunda passada da criação de orçamento rebuscava
  `PRECO_VENDA` sem `EMPRESA_ID` — a primeira passada já validava o
  produto, mas o filtro foi adicionado por consistência.
- **Resultado:** API compilada (`Scripts\build_api.bat`), commit
  `2417241`.

---

### 3.52 Auditoria Android + varredura final de Services (08/11)

- **Android:** `BancoLocal` filtra `empresa` em **todas** as queries
  (clientes, produtos, orçamentos/itens, vendas, estoque, contas a
  receber/pagar, outbox); `ErpDbHelper` tem coluna `empresa` em toda
  tabela de negócio com índices compostos; a troca de empresa chama
  `Sessao.encerrar` (token JWT descartado → novo login na empresa).
  Configuração de URL/código é por empresa (D9).
- **Desktop — Services restantes:** `uEstoqueService`,
  `uInventarioService`, `uKardexService`, `uContasService`,
  `uMovimentoFinanceiroService`, `uCaixaService`, `uPDVService`,
  `uPedidoVendaService`, `uPedidoCompraService`, `uOrcamentoService`
  conferidos — escritas validam empresa antes do UPDATE/DELETE por
  ID; `uPermissaoService` é global por desenho (GRUPO/PERMISSAO).
- **Convenção confirmada:** `(EMPRESA_ID = :EMP OR EMPRESA_ID IS NULL)`
  em CONFIGURACAO e CAIXA = herança de padrão global / caixas
  legados — deliberado, não é vazamento.
- **Resultado:** nenhum defeito novo; baseline mantido (desktop
  349/349, Android 5/5, API compilada).

---

### 3.53 Relatório LazReport + melhorias de tela + Android (08/11)

- **Relatório de pedidos:** `uFrmListaPedidos` ganhou botão
  "Imprimir" e o modelo `Desktop\relatorios\pedidos_venda.lrf`
  (lista número/emissão/cliente/status/total). A query do relatório
  (`qryPedidosRel` + `frDBPedidos`) repete o filtro da grade —
  período, status e `EMPRESA_ID` da sessão — e adiciona
  `DATA_EMISSAO_STR` formatada dd/mm/yyyy. Filtro da grade
  refatorado em `SqlPedidos`/`VincularParamsPedidos` (sem
  duplicação). Commit `5525e4f`.
- **Visualização de pedido:** o botão "Visualizar" da lista era um
  `MessageDlg` provisório (TODO). Novo `uFrmPedidoDetalhe`
  (somente leitura): cabeçalho com número, cliente, emissão,
  entrega, status, subtotal/desconto/total e observações + grade
  de itens; consulta filtra `EMPRESA_ID` da sessão. Commit
  `d2dae8c`.
- **Android:** o diálogo de detalhe do orçamento em
  `OrcamentosActivity` agora lista os itens (descrição, quantidade
  e total) antes de oferecer sincronizar/converter — funciona
  off-line sobre o cache local.
- **Resultado:** build desktop 0 erros, suíte **349/349**,
  testes Android OK.

---

### 3.54 Testes da NF-e (ACBrHelper) (09/11)

- **Problema:** `uACBrHelper` concentra as regras da tela `uFrmNFe`
  (emissão simulada, numeração por empresa, gravação de
  `NUMERO_NFE`/`CHAVE_NFE` e auditoria), mas só `ImportarXML` tinha
  teste (dentro de `uProducaoTest`).
- **Entrega:** `uNFeTest` (17 testes, banco real) cobre:
  - configuração: padrão homologação/'SP'; certificado, senha, UF e
    ambiente gravados por `Configurar`;
  - emissão: exige certificado e senha; recusa pedido inexistente e de
    outra empresa; calcula `MAX(NUMERO_NFE)` da empresa da sessão + 1
    (ignorando outras empresas); grava número/chave apenas no pedido
    informado; audita em `LOG_SISTEMA` (`PEDIDO_VENDA`/`NFE`, com o
    usuário da sessão e a chave gerada);
  - NFC-e: mesma emissão com natureza "VENDA AO CONSUMIDOR";
  - consulta, cancelamento e manifestação: exigem configuração;
    justificativa de cancelamento com no mínimo 15 caracteres.
- **Resultado:** suíte **366/366**; build desktop 0/0; banco conferido
  sem resíduos (pessoas/pedidos/logs dos testes).
- **Commit:** `162be42`.
- **Nota:** na época, a integração real com ACBr/SEFAZ ainda estava
  desligada (blocos comentados no helper); foi implementada no marco
  **3.55** (§3.55).

---

### 3.55 Integração real da NF-e com ACBr (10/11)

- **Objetivo:** emitir NF-e/NFC-e de verdade pelo ACBr, mantendo a
  emissão simulada que os testes usam.
- **ACBr:** clone em `C:\ACBr`; pacotes `ideintf`, `laz_synapse`,
  `PCNComum`, `ACBrComum`, `ACBrOpenSSL`, `ACBrDiversos`, `ACBrTCP`,
  `ACBrSerial`, `ACBr_Integrador`, `ACBrDFeComum` e `ACBr_NFe`
  compilados com `lazbuild`; `ACBr_NFe` registrado no Lazarus.
- **Projeto:** `Desktop\ERP2026.lpi` passou a exigir `ACBr_NFe` e a
  definir `-dACBR`; `Desktop\Tests.lpi` continua **sem** ACBr e ganhou
  saída própria (`lib/tests/$(TargetCPU)-$(TargetOS)`) para não
  reaproveitar o `.ppu` compilado com ACBr pelo desktop.
- **`uACBrHelper`:**
  - `ModoSimulado` (padrão `True`) preserva `GerarSimulada` e os 17
    testes; `CaminhoSchemas`, `CaminhoSalvar`, `IdCSC` e `CSC` são
    novas propriedades.
  - `EmitirReal` (sob `{$IFDEF ACBR}`) lê empresa, cliente, itens,
    pagamento e cidade IBGE; valida NCM (8), CFOP (4), CST/CSOSN,
    CPF/CNPJ, CEP e dados do emitente; calcula ICMS/PIS/COFINS e
    totais; envia com `Enviar(1, False, True)`; aceita `cStat` 100/150
    e só então grava `NUMERO_NFE`/`CHAVE_NFE` e audita.
  - `ITEM_PEDIDO.VALOR_TOTAL` já é líquido de desconto: o helper
    reconstrói `vProd` bruto (`VALOR_TOTAL + DESCONTO`) e envia
    `vDesc` separado, evitando descontar duas vezes.
  - `ConsultarReal`, `CancelarReal` (protocolo obtido por consulta,
    `teCancelamento`, `cStat` 135/155) e `ManifestarReal`
    (210200/210210/210220/210240) usam a chave de 44 dígitos.
  - `ImportarXML` só confirma/desfaz a transação se foi ele quem a
    abriu.
- **Tela `uFrmNFe`:** checkbox `chkSimulado` (desmarcado = modo real),
  UF lida de `EMPRESA`, paths `bin\schemas`/`bin\nfe`, senha do
  certificado por `InputQuery`, `ConfigurarACBrReal`, status textual e
  `FormDestroy` liberando o helper. Em simulação, certificado/senha
  fictícios satisfazem `ValidarConfiguracao`.
- **Recursos:** `Scripts\preparar_acbr.bat` copia os schemas da NF-e e
  as DLLs x86 (OpenSSL 3.1.3 e LibXml2) para `Desktop\bin`; `*.dll` e
  `Desktop\bin` são ignorados pelo git.
- **Resultado:** build desktop **0/0**; suíte **366/366**; banco sem
  resíduos. A emissão real contra a SEFAZ não foi exercitada por falta
  de certificado A1 válido e de dados fiscais completos no banco.
- **Commit:** `eceb35c`.

---

### 3.56 Validação local da NF-e (10/11)

- **Objetivo:** conferir o XML da NF-e antes de emitir de verdade, sem
  certificado A1 e sem enviar à SEFAZ.
- **Helper:** `ValidarNFe(APedidoId)` chama
  `EmitirReal(..., ASomenteValidar=True)`; nesse modo o helper monta o
  XML, assina se houver certificado e valida contra os schemas, mas
  **não envia** e **não persiste** nada. `ConfigurarACBr(AExigirCertificado)`
  permite configurar o ACBr sem PFX. Sem certificado, os dados fiscais
  são conferidos e a mensagem explica que o schema 4.00 exige
  `Signature`.
- **CLI:** `ERP2026.exe --validar-nfe=<id> [--cert=<pfx>] [--senha=<senha>]`
  grava `Desktop\bin\nfe\validacao_<id>.txt` e retorna 0/1/2. Aceita
  `ERP_NFE_CERT`/`ERP_NFE_SENHA`. Em app GUI o `WriteLn` pode falhar;
  o CLI usa `ExitProcess` para devolver o código correto.
- **Tela:** botão **Validar dados** em `uFrmNFe`, com prompt de
  certificado/senha e aviso de que nada foi enviado.
- **Certificado de teste:** `Scripts\gerar_certificado_teste.ps1` cria
  um PFX autoassinado com CNPJ no subject (padrão `00000000000191` /
  `teste123`), só para validação local; não vale para a SEFAZ.
- **Dados de homologação:** `Scripts\preparar_dados_nfe.sql` preenche
  apenas campos vazios da `EMPRESA` id 1 (CNPJ de teste) e define
  `CRT=3` (Regime Normal), coerente com o CST 00 do produto 1066.
  Pedido 1003, cliente 1340 e produto fiscal 2 já estavam completos.
- **Correções:** `dEmi := Now` (antes `Date`, gerava `dhEmi` 00:00:00)
  e `indIEDest=inIsento`/`IE='ISENTO'` para cliente com IE ISENTO.
- **Validação executada:** `Scripts\validar_nfe.bat 1003` → `OK`, XML
  assinado e validado localmente; `1000` → erro claro de dados do
  destinatário (`NUMERO`, `BAIRRO`). O pedido 1003 continuou com
  `NUMERO_NFE=4` (nada persistido). Build desktop **0/0**; suíte
  **366/366**.
- **Commits:** `81f63ab` (código/scripts) e `9937966` (código de saída
  do CLI).

---

### 3.57 Validação da NF-e em lote (10/11)

- **Objetivo:** conferir todos os pedidos da empresa de uma vez, sem
  parar no primeiro erro, para mapear o que falta no cadastro fiscal.
- **CLI:** `--validar-nfe=todos` percorre os pedidos da empresa em
  ordem de ID e chama `ValidarNFe` isoladamente para cada um. Um erro
  em um pedido não interrompe os demais. O relatório único sai em
  `Desktop\bin\nfe\validacao_todos.txt`, com cabeçalho (empresa/data),
  uma linha por pedido (OK com número/série/chave ou ERRO com a
  mensagem) e o resumo `N OK, M ERRO`.
- **Exit code:** o modo lote retorna **0** somente se todos os pedidos
  passarem; qualquer erro retorna **1**. Uso inválido continua **2**.
- **Wrapper:** `Scripts\validar_nfe.bat` aceita `todos`, calcula o
  caminho do relatório a partir do argumento e agora propaga o
  `ERRORLEVEL` do executável com `exit /b %RC%` (antes o `endlocal`
  descartava o código).
- **Resultado no banco atual:** **1 OK, 3 ERRO**.
  - 1003 (`PV-TESTE-5`): OK, XML assinado e validado localmente.
  - 997 (`PED-001`): destinatário sem `NUMERO`.
  - 998 (`PED-002`) e 1000 (`1`): destinatário sem `NUMERO` e `BAIRRO`.
  São pedidos legados com cadastro incompleto; não servem de cenário
  fiscal. A validação não persiste nada (`NUMERO_NFE` inalterado).
- **Validação:** build desktop **0/0**; suíte **366/366**;
  `Scripts\validar_nfe.bat 1003` → exit 0 e `... todos` → exit 1.
- **Commit:** `3a475cf`.

---

### 3.58 Cenário fiscal de teste completo (10/11)

- **Objetivo:** ter mais de um pedido válido na validação em lote e
  exercitar uma operação interestadual, sem tocar nos pedidos legados
  nem no produto 1 usado pela suíte.
- **Script:** `Scripts\preparar_cenario_fiscal.sql` (idempotente, via
  `EXECUTE BLOCK`) cria ou reutiliza, na empresa 1:
  - cliente `Cliente Cenario Fiscal` (CPF `529.982.247-25`, MG,
    `RG_IE='ISENTO'`, endereço completo, `CIDADE_ID` de Belo Horizonte);
  - `PRODUTO_FISCAL` `CEN-FISCAL` (NCM `61091000`, CEST `2806300`,
    CFOP/CFOP_VENDA `6102`, CST ICMS/PIS/COFINS `00`/`01`/`01`,
    alíquotas 12/1,65/7,6, pesos);
  - `PRODUTO` `CEN-FISCAL-01` (R$ 50,00, unidade `UN`, categoria
    `Geral`, sem controle de estoque);
  - `PEDIDO_VENDA` `CEN-FISCAL-01` (2 × R$ 50,00 = R$ 100,00, forma
    Dinheiro) e o respectivo `ITEM_PEDIDO`.
- **Marcadores fixos:** CPF, `CODIGO` e `NUMERO` acima; rodar o script
  de novo devolve o mesmo pedido (3581) e não duplica registros.
- **Resultado:** `Scripts\validar_nfe.bat 3581` → `OK` (XML assinado e
  validado localmente, sem SEFAZ); `... todos` → **2 OK, 3 ERRO**
  (1003 e 3581 OK; 997/998/1000 continuam legados incompletos).
  `NUMERO_NFE`/`CHAVE_NFE` do 3581 permanecem nulos.
- **Teste ajustado:** `TestIntegridade018` exigia exatamente 9 clientes
  e 2 fornecedores globais; com o cenário persistente passou a exigir
  **ao menos** esses totais (as checagens de órfãos e de tabelas
  antigas continuam iguais).
- **Validação:** build desktop **0/0**; suíte **366/366**.
- **Commit:** `90e583c`.

---

### 3.59 Backup e restauração do banco (11/11)

- **Objetivo:** dar rotina segura de backup/restore para operação em
  produção, sem depender de cópia manual do `.FDB`.
- **Backup:** `Scripts\backup_banco.bat [pasta]` usa `gbak -b -g` e
  grava `DADOS_AAAAMMDD_HHMMSS.fbk` em `Backups\` (padrão) ou na pasta
  informada. Não apaga backups antigos; a retenção fica com o operador.
- **Restauração:** `Scripts\restaurar_banco.bat <arquivo.fbk>
  [destino.fdb] [forcar]` restaura com `gbak -c`. Por segurança, o
  destino padrão é `Banco\DADOS_RESTAURADO.FDB` e um arquivo existente
  só é sobrescrito com o argumento `forcar`.
- **Configuração:** usuário, senha e pasta do Firebird vêm de
  `ERP_DB_USER`, `ERP_DB_PASSWORD` e `ERP_FB_BIN`; sem variáveis, usa
  `SYSDBA`/`masterkey` e `C:\Program Files\Firebird\Firebird_5_0`.
- **Teste executado:** backup gerou um `.fbk` de 362.496 bytes;
  restauração em `%TEMP%\erp_restore_test.fdb` concluiu e o banco
  restaurado respondeu `SELECT COUNT(*) FROM PEDIDO_VENDA` = 5. O
  arquivo temporário foi removido.
- **Git:** `Backups/` e `*.fbk` entram no `.gitignore`.
- **Commit:** `66efaa7`.

---

### 3.60 Configuração por ambiente: banco e JWT (11/11)

- **Objetivo:** tirar do binário o caminho do banco, as credenciais e o
  segredo JWT — pré-requisito para rodar em qualquer servidor sem
  recompilar (itens D1/D2 da auditoria de API/Android/banco).
- **Banco (Desktop e API):** `uConexao` lê `ERP_DB_HOST`, `ERP_DB_PATH`,
  `ERP_DB_USER`, `ERP_DB_PASSWORD` e `ERP_DB_PORT`. Sem `ERP_DB_PATH`, o
  padrão é `<pasta do exe>\..\..\Banco\dados.fdb`; `Conectar` passou a
  usar os campos `Host/User/Password/Port` em vez de valores fixos.
- **JWT (API):** segredo em `ERP_JWT_SECRET` (mínimo de 32 caracteres) e
  validade em `ERP_JWT_EXPIRACAO_HORAS` (1..720, padrão 8). Em produção
  (`ERP_AMBIENTE=producao` ou `ERP_PRODUCAO=1`) a API se recusa a subir
  com o segredo padrão de desenvolvimento, imprime o erro e sai com
  código 2. Em desenvolvimento, avisa uma vez no `stderr`.
- **Documentação:** `Documentacao\CONFIGURACAO_AMBIENTE.md` lista todas
  as variáveis (banco, JWT, pool da API, NF-e e backup) e traz um
  exemplo de configuração de produção no Windows.
- **Validação:** API compila (`Scripts\build_api.bat`); desktop compila
  **0/0**; suíte desktop **366/366**. Testado em execução: conexão padrão
  resolveu `Banco\dados.fdb`; `ERP_DB_PATH` inválido derrubou só a
  conexão; produção sem segredo saiu com código 2 e com segredo subiu.
- **Commit:** `0e0d245`.

---

### 3.61 API: devolução de conexões ao pool e health check (14/11)

- **Objetivo:** fechar D6 (conexões/transações presas por thread) e D12
  (teste de conexão do Android com falso positivo).
- **Middleware:** `API\src\Middleware\uMiddlewareConexao.pas` envolve cada
  requisição e, no `finally`, chama `TConexao.DevolverAtual`. A conexão
  da thread volta ao pool; `Destroy` faz `Rollback` de transação
  pendente e fecha a conexão, então a próxima requisição começa limpa.
- **Health:** `GET /api/health` é público e devolve
  `{"status":"ok","servico":"ERP2026API","pool":"pool=N conexoes, M em uso"}`.
  O thread principal libera a vaga após a checagem inicial de conexão.
- **Android:** `ApiClient.ping` consulta `/api/health` e a tela de
  configuração só considera sucesso em 2xx; antes qualquer 404 de outro
  serviço passava como "conexão funcionando".
- **Validação:** API compila; health respondeu 200 e o pool ficou em
  `0 em uso` após login e três GETs de clientes; suíte desktop
  **366/366**; testes Android **OK** (`Scripts\run_tests_android.bat`).
- **Commit:** `7bffb94`.

---

### 3.62 Login sem credenciais padrão e por empresa (14/11)

- **Objetivo:** fechar T2 (credenciais pré-preenchidas), T3 (login sem
  escopo de empresa) e F7 (API escolhia a empresa silenciosamente).
- **Desktop (T2):** `uFrmLogin.FormShow` não preenche mais
  `admin`/`admin123`; o operador digita usuário e senha.
- **Desktop (T3):** `TUsuarioService.BuscarPorLogin` ganhou
  `AEmpresaId` opcional. Sem ele, se o mesmo login existir em mais de
  uma empresa, levanta `ELoginAmbiguo` com os códigos encontrados em vez
  de escolher a primeira linha. A tela pede o código da empresa e
  repete a busca.
- **API (F7):** `POST /api/login` aceita `empresa_id` (número ou
  string). Sem ele, login repetido em empresas diferentes devolve
  **400** com a lista; com ele, a consulta filtra `U.EMPRESA_ID`.
- **Teste:** novo `TestLoginAmbiguoPorEmpresa` cria o mesmo login em duas
  empresas, confere o `ELoginAmbiguo`, confere a busca com empresa e
  limpa os usuários no `finally`. Suíte desktop **367/367**.
- **Validação manual:** API respondeu 200 sem `empresa_id` (banco com
  uma empresa), 200 com `empresa_id=1`/`"1"` e 401 com `999`; com duas
  empresas temporárias, 400 listando `(1, 2)` e 200 em cada empresa.
- **Commit:** `1cec868`.

---

### 3.63 Importação real de XML de NF-e (14/11)

- **Objetivo:** fechar F1 (o `TACBrHelper.ImportarXML` só auditava; a
  leitura real vivia na tela de nota de entrada).
- **Service novo:** `Desktop\src\Services\uNFeXmlService.pas`.
  `TNFeXmlParser` lê o XML sem fcl-xml, remove BOM/prefixo de namespace
  (`nfe:`, `ns2:`), decodifica entidades (`&amp;` etc.) e devolve
  `TNFeXml` (chave, número, série, modelo, emissão, natureza, emitente,
  totais e itens com NCM/CFOP/CST/quantidade/valor/desconto).
  `TNFeImportService.Importar` grava a nota de entrada:
  - fornecedor por CNPJ (somente dígitos) e, na falta, pelo nome;
  - produto por `CODIGO`/`CODIGO_BARRAS` (`cProd`/`cEAN`);
  - item sem produto fica gravado e é contado para vínculo manual;
  - chave de acesso repetida na empresa é recusada;
  - falha no meio da importação remove a nota parcial;
  - `XML_ARQUIVO` guarda o nome do arquivo e a auditoria
    `XML_FISCAL/IMPORTACAO_XML` cita chave, itens e itens sem produto.
- **Fiscal:** `TNotaEntradaService.SalvarItem` ganhou parâmetros opcionais
  `ANcm`, `ACfop`, `ACstIcms` e `AAliqIcms`; a importação usa os dados do
  documento do fornecedor, que prevalecem sobre o cadastro.
- **Telas:** `uFrmNotaEntrada.ImportarXML` agora só chama o Service e
  abre a nota criada (os auxiliares de tag saíram da View).
  `TACBrHelper.ImportarXML` virou fachada para o mesmo Service e devolve
  o ID da nota.
- **Testes:** `TestNFeImportarXmlNotaEntrada` monta um XML prefixado
  (`nfe:`) com fornecedor/produto temporários, confere cabeçalho, item
  (NCM/CFOP/CST e `&amp;` decodificado), auditoria e recusa da mesma
  chave; `TestImportarXmlRecusaInvalido` (antigo
  `TestImportarXmlGravaAuditoria`) confere arquivo inexistente e XML sem
  `infNFe`, sem gravar auditoria. Suíte desktop **368/368**.
- **Commit:** `0c539c3`.

---

### 3.64 Materialização da NF-e autorizada (14/11)

- **Objetivo:** fechar F2 — a emissão real só gravava `NUMERO_NFE`/
  `CHAVE_NFE` no pedido; a venda não virava `NOTA_SAIDA`, o estoque não
  baixava, as contas a receber não eram geradas e o XML não era guardado.
- **Service:** `TNotaSaidaService.MaterializarAutorizada` recebe o
  retorno da SEFAZ (número, série, modelo, natureza, CFOP, chave,
  protocolo e nome do XML), cria ou reaproveita a `NOTA_SAIDA` do pedido
  (`CriarDoPedido`), grava os dados autorizados (`AtualizarAutorizacao`)
  e fatura (`Faturar`: baixa de estoque, contas a receber e pedido
  Faturado). Uma segunda materialização do mesmo pedido é recusada.
- **Chave:** `Faturar` passou a preservar `CHAVE_ACESSO`/`PROTOCOLO`
  quando já gravados; a chave de homologação (`HOM...`) só é gerada no
  faturamento sem emissão real. Nota faturada manualmente (chave `HOM`)
  pode receber a chave verdadeira.
- **Estoque:** `VerificarSaldoPedido` confere o saldo de todos os itens
  antes do envio; sem saldo, a NF-e não é transmitida (evita documento
  autorizado sem baixa).
- **XML e auditoria:** `EmitirReal` salva o XML em
  `CaminhoSalvar\<chave>.xml`, grava o nome em `NOTA_SAIDA.XML_ARQUIVO`
  e audita `NOTA_SAIDA/NFE_AUTORIZADA` com número, chave e protocolo.
  Se a materialização falhar depois da autorização, a mensagem informa a
  chave, avisa que o XML foi salvo e orienta faturar manualmente.
- **Tela:** `uFrmNFe` mostra o número da nota de saída materializada.
- **Teste:** `TestSaidaMaterializarAutorizada` cobre chave/protocolo da
  SEFAZ, número/série, XML, baixa de estoque, conta a receber, pedido
  Faturado e a recusa da dupla materialização. Suíte desktop **369/369**.
- **Commit:** `46a984f`.

---

### 3.65 CC-e, inutilização e manifestação na tela (14/11)

- **Objetivo:** avançar o F3 com os eventos fiscais do emitente que não
  dependem de impressão — Carta de Correção, inutilização de numeração e
  manifestação do destinatário.
- **Service:** `TACBrHelper` ganhou `EnviarCartaCorrecao(chave, correção,
  sequência)`, `InutilizarNumeracao(modelo, série, inicial, final, ano,
  justificativa)` e `ProximaSequenciaCce(chave)`. Toda validação roda antes
  de qualquer acesso à SEFAZ: chave com 44 dígitos, correção 15..1000,
  sequência 1..20, modelo 55/65, série 0..999, faixa final ≥ inicial,
  justificativa 15..255. Em modo simulado devolvem `False`, igual ao
  cancelamento, sem rede.
- **Modo real:** `CartaCorrecaoReal` monta o evento `teCCe` com CNPJ,
  `cOrgao`, `dhEvento`, `nSeqEvento` e `xCorrecao`, envia por
  `EnviarEvento(1)` e considera sucesso `cStat` 135/136/155.
  `InutilizarReal` chama `LNFe.Inutilizar` e considera sucesso `cStat` 102
  (homologada) ou 563 (duplicidade já registrada). Ambos auditam em
  `LOG_SISTEMA` (`NFE/CCE` e `NFE/INUTILIZACAO`) com chave, sequência,
  protocolo e `cStat`; a CC-e grava também o `ID` da `NOTA_SAIDA` quando a
  chave está cadastrada.
- **Sequência da CC-e:** derivada de `LOG_SISTEMA` (`TABELA='NFE'`,
  `OPERACAO='CCE'`, `DADOS_NOVOS CONTAINING <chave>`) e limitada a 20, sem
  coluna nova no banco.
- **Tela:** segunda linha na toolbar de `uFrmNFe` (`pnlBotoes.Height=72`):
  **Carta de Correção** (chave do pedido selecionado + texto),
  **Inutilizar** (modelo + `série/ano/inicial/final` + justificativa) e
  **Manifestar** (chave digitada + tipo 1..4). `PrepararEnvioReal`
  centraliza a checagem de certificado e a senha; com **Modo simulado**
  marcado as três ações só mostram a confirmação na tela.
- **Ajustes:** `LCStat in [102, 563]` gerava warning de range check
  (constante 563 em `set of Byte`) — trocado por comparação explícita;
  `LNotaId` passou a `Int64`/`AsLargeInt` para acompanhar o `ID` do banco.
- **Teste:** 7 testes novos em `uNFeTest`
  (`TestNFeCartaCorrecaoCurta`, `...ChaveInvalida`,
  `...ComConfiguracao`, `TestNFeInutilizarJustificativaCurta`,
  `...FaixaInvalida`, `...ComConfiguracao`, `TestNFeProximaSequenciaCce`).
  Suíte desktop **376/376**; `LOG_SISTEMA` sem resíduo `CCE`.
- **Pendente do F3:** DANFE (`TACBrNFeDANFeFPDF`; o pacote
  `ACBr_NFe_DanfeFPDF` não está registrado no Lazarus) e NFC-e no PDV.
- **Commit:** `c6652c1`.

---

### 3.66 DANFE e cupom em PDF (14/11)

- **Objetivo:** imprimir o DANFE (modelo 55) e o cupom (modelo 65) sem
  depender do site da SEFAZ e sem instalar pacote novo no Lazarus.
- **Service:** `TACBrHelper.GerarDANFEPDF(chave)` valida os 44 dígitos,
  localiza o XML autorizado (`NOTA_SAIDA.XML_ARQUIVO`, `<chave>.xml`,
  `<chave>-nfe.xml` ou `<chave>-nfce.xml` em `CaminhoSalvar`), escolhe
  `TACBrNFeDANFeFPDF`/`TACBrNFCeDANFeFPDF` pelo modelo da chave, carrega
  a nota com `LerXML`, chama `ImprimirPDF` e devolve
  `LNFe.DANFE.ArquivoPDF`. Em modo simulado devolve `''` sem gerar
  arquivo; sem `-dACBR`, levanta erro claro.
- **Projeto:** as units FPDF entraram em `OtherUnitFiles` do
  `ERP2026.lpi` (`.../DANFE/NFe/FPDF` e `.../DANFE/NFCe/FPDF`). Nada foi
  instalado no IDE: `ACBr_fpdf*` vêm do `ACBrComum`, que o `ACBr_NFe` já
  trazia como dependência.
- **Tela:** botão **DANFE** na segunda linha de `uFrmNFe`, ao lado de
  Manifestar; usa a chave do pedido selecionado, avisa em modo simulado,
  gera o PDF, mostra o caminho e abre no leitor padrão (`OpenDocument`).
- **CLI:** `ERP2026.exe --danfe=<chave>` reimprime off-line a partir do
  XML salvo; grava `bin\nfe\danfe_<chave>.txt` (OK/ERRO) e devolve
  0/1/2, no mesmo padrão do `--validar-nfe`.
- **Teste:** `TestNFeDANFEChaveInvalida` e `TestNFeDANFEModoSimulado` em
  `uNFeTest`. Suíte desktop **378/378**. Verificação manual com o XML
  `35261100000000000191550010000000051021906712`: PDF de 7.155 bytes com
  cabeçalho `%PDF-1.3`.
- **Pendente do F3:** NFC-e no PDV. `EmitirReal` ainda exige endereço
  completo do destinatário em qualquer modelo; para o cupom com
  consumidor não identificado, o modelo 65 precisa aceitar `Dest` vazio.
- **Commit:** `600906d`.

---

### 3.67 NFC-e no PDV (15/11)

- **Objetivo:** emitir a NFC-e (modelo 65) junto com a venda do PDV, sem
  exigir que o consumidor final esteja cadastrado com endereço completo.
- **Service — destinatário:** a regra saiu do bloco `{$IFDEF ACBR}` para
  o método público `TACBrHelper.CamposFaltandoDestinatario(pedido,
  modelo)`: na **NF-e (55)** o destinatário e o endereço completo são
  obrigatórios; na **NFC-e (65)** o destinatário é opcional (só é exigido
  quando há CPF/CNPJ) e o endereço só é cobrado no modelo 55. `EmitirReal`
  passou a usar essa função — uma regra só, sem duplicação.
- **Service — modelo 65:** `Dest`/`EnderDest` só são preenchidos quando
  existem; sem identificação, `idDest` fica `doInterna` e o bloco `Dest`
  sai vazio no XML. `ValidarNFe`/`ValidarNFCe` conferem o destinatário
  **antes** do ACBr, então a recusa por cadastro incompleto vale mesmo na
  build sem ACBr.
- **Configuração fiscal:** `TACBrHelper.CarregarConfiguracaoFiscal` lê da
  tabela `CONFIGURACAO` as chaves `NFE_CERTIFICADO`, `NFE_AMBIENTE`,
  `NFE_MODO`, `NFCE_ID_CSC` e `NFCE_CSC` (a primeira da empresa, senão a
  global) e a UF da `EMPRESA` quando ainda não houver. `NFE_MODO=REAL`
  desliga o modo simulado; qualquer outro valor (ou a ausência da chave)
  mantém a simulação. **A senha do certificado nunca fica no banco** —
  o PDV pergunta com `InputQuery` no momento da emissão.
- **Tela (`uFrmPDV`):** checkbox **"Emitir NFC-e ao finalizar"** no painel
  de ações (`pnlAcoes`); o `btnFinalizar` agora guarda o ID devolvido por
  `SalvarVenda` e chama `EmitirNFCeVenda` **depois** de gravar a venda.
  Em modo real: pede a senha, transmite, avisa se não autorizou e abre o
  cupom em PDF (`GerarDANFEPDF` + `OpenDocument`). Em modo simulado: mostra
  a chave gerada e avisa que nada foi enviado à SEFAZ. Falha na emissão
  **não desfaz a venda** — a mensagem orienta reemitir pela tela de NF-e.
  O `pnlDireita` ganhou altura para caber o checkbox sem cortar os botões.
- **Teste:** `TestNFeDestinatarioOpcionalNFCe` (cliente com CPF e sem
  endereço: NFC-e não acusa falta, NF-e aponta `ENDERECO`/`CIDADE`) e
  `TestNFeCarregarConfiguracaoFiscal` (as 5 chaves são lidas e as
  originais restauradas no `finally`). Suíte desktop **380/380**.
- **Verificação:** build desktop **0/0** (sem o aviso de "Function result
  does not seem to be set"), API compilada, testes Android OK e smoke de
  todas as telas **33/33** com o checkbox visível na evidência do PDV.
- **Commit:** `9d4a445`.

---

### 3.68 Permissões aplicadas em todas as telas — T1 (21/11)

- **Objetivo:** fechar a auditoria T1: antes só 8 telas checavam permissão;
  usuários, produtos, pessoas, contas, NF-e, PDV e compras abriam sem
  checagem.
- **Catálogo canônico:** `Desktop\src\Utils\uPermissao.pas` ganhou
  `CATALOGO_TELAS`, com uma linha por tela do menu (classe, módulo, tela e
  descrição — 33 telas), mais `PermissaoDaTela` e acesso ao catálogo para
  testes e seed. Tela fora do catálogo é **bloqueada (falha fechada)**.
- **Abertura e ações:** `uFrmPrincipal.AbrirFormulario` consulta o catálogo e
  recusa a abertura sem `View`; o menu desabilita os itens que o grupo não
  pode ver. `uFrmCadastroBase` aplica permissão a Novo/Editar/Excluir e à
  gravação, com mensagem clara quando a ação é negada. `uPermissaoUI`
  (`AplicarPermissaoAcao`) desabilita controles de ação em PDV, NF-e, notas,
  compras, pedidos, orçamento, contas e estoque.
- **Módulos corrigidos:** Consumo passou a `SUPRIMENTOS`, Lista de Pedidos a
  `VENDAS` e Central de Relatórios a `RELATORIOS`, para casar com as chaves
  usadas nas permissões.
- **Banco:** `Banco\020_permissoes_telas.sql` semeia o grupo 1 em todas as
  telas de forma idempotente; `Banco\007_initial_data.sql` acompanha a seed.
- **Testes e verificação:** `uTelasAdmTest` cobre catálogo completo, seed e
  falha fechada (suíte passou a **383/383**). Novo
  `Scripts\testes\permissoes_menu.ps1` abre o menu com usuário sem permissão:
  item bloqueado não abre, item liberado abre — **0 falhas**. Smoke de telas
  **33/33**, build desktop **0/0**.
- **Commit:** `cddf5c6` (prompts dos apps de bipagem/PDV mobile em `fca106c`).

---

### 3.69 Isolamento por empresa nas consultas — T4 (21/11)

- **Objetivo:** eliminar consultas/gravações que cruzam empresas no desktop:
  copiloto, produção, bipagem e caixa legado.
- **Copiloto:** `uCopilotoERP` — todas as 12 consultas passaram a filtrar
  `EMPRESA_ID = :EMP`, inclusive subconsultas, `UNION` e o `LEFT JOIN` de
  estoque. `ExecutarSQL` liga `:EMP` com a empresa da sessão; o SQLDB/FPC
  aceita parâmetro nomeado repetido (`TParamBinding`), então `:EMP` pode
  aparecer várias vezes na mesma instrução.
- **Produção:** `uProducaoService` filtra/verifica a empresa da sessão em
  mapa, pedido, item de pedido, talão, bipagem, consumo e ficha técnica, tanto
  em leituras como em gravações por ID. **Mudança de comportamento:**
  `CriarMapa` agora recusa pedido de outra empresa (antes o mapa herdava a
  empresa do pedido — desenho do marco 3.50).
- **Exceções de schema:** `TALAO_BIPAGEM` não tem `EMPRESA_ID`, então
  `uFrmBipagem` isola o histórico via `TALAO.EMPRESA_ID` — ou via
  `USUARIO.EMPRESA_ID` quando `TALAO_ID = 0`. `MOVIMENTO_CAIXA` também não tem
  `EMPRESA_ID`: `uCaixaService` isola movimentos e resumo com `JOIN CAIXA` e
  `(C.EMPRESA_ID = :EMP OR C.EMPRESA_ID IS NULL)` (o `NULL` preserva caixas
  globais/legadas, conforme decisão já usada em `CONFIGURACAO`).
- **Testes:** `TestMapaEscopoEmpresa` passou a exigir a recusa de pedido de
  outra empresa; novo `TestIsolamentoEmpresaProducao` cria cliente/produto/
  pedido/mapa/talão na empresa 999998, verifica que `StatusMapa`,
  `MapaAtivoDoPedido`, `ConsumoAtivoDoMapa`, `CancelarMapa`, `CancelarTalao` e
  `GerarTaloes` não veem nem alteram esses registros, e limpa tudo no
  `finally`. O teste do Copiloto passou a ligar `:EMP`. Suíte **384/384**.
- **Verificação:** build desktop **0/0**, API compilada, Android OK, smoke de
  telas **33/33** (relatório regenerado) e `permissoes_menu.ps1` **0 falhas**.
- **Commit:** `5d17e17`.

---

### 3.70 D3 — API linka Services e sessão por thread (21/11)

- **Objetivo:** acabar com a regra duplicada na API: `build_api.bat`
  compilava apenas `API\src`, `Models` e `Utils`, então cada rota
  reescrevia em SQL o que os Services do desktop já fazem.
- **Build:** `Scripts\build_api.bat` passou a incluir
  `-Fu"%ROOT%\Desktop\src\Repositories"` e
  `-Fu"%ROOT%\Desktop\src\Services"`. `API\src\Config` continua na frente
  para não substituir o pool de conexões pelo singleton do desktop. Sem
  ACBr, LazReport ou UI na API (os Services são headless; `uACBrHelper`
  compila em modo simulado sem `-dACBR`).
- **Contexto por requisição:** os Services leem `TSessao.GetInstance`. Como a
  API atende cada requisição numa thread, compartilhar o singleton do
  desktop daria *race* entre empresas. `uSessao` ganhou
  `DefinirContexto`/`LimparContexto` apoiados em `threadvar`;
  `GetInstance` prefere o contexto da thread quando existe. O desktop
  (thread principal) continua usando `FInstance`.
- **Middleware:** novo `API\src\Middleware\uMiddlewareSessao.pas` roda depois
  do JWT, lê `sub`/`empresa_id` do token, chama `DefinirContexto` e limpa no
  `finally`. `/api/health` e `/api/login` são isentos, pela mesma regra do
  `MiddlewareJWT` (sem essa isenção, as rotas públicas voltaram 401).
- **Rotas migradas:** `GET /api/clientes` e `GET /api/clientes/:id` usam
  `TPessoaService.BuscarTodos('C')` e `BuscarPorId` — sem SQL inline de
  cliente na rota. A rota apenas confirma `EmpresaId` e `Tipo = 'C'` antes
  de devolver o JSON; o contrato da resposta foi preservado.
- **Verificação:** API compilada; smoke em runtime: `health=ok`, login com
  empresa 1, `GET /api/clientes` com 10 registros e `GET /api/clientes/:id`
  OK. Desktop build **0/0** e suíte **384/384**.
- **Commit:** `f1b19ef`. Também foram para o remoto os commits paralelos do
  app de bipagem (`f651c0f` — motor compartilhado `uProducaoBipagem`;
  `9dee0fd` — `POST /api/producao/bipar`) e os arquivos do módulo Android
  `bipe` que estavam no working tree.

---

### 3.71 App Android de bipagem de talões (21/11)

- **Objetivo:** executar o Prompt 1 de `Documentacao/PROMPTS_NOVOS_APPS.md`
  — app dedicado para o chão de fábrica bipar `TALAO.CODIGO_BARRAS` e dar
  baixa na produção, espelhando `uFrmBipagem`/`TProducaoService.BiparTalao`.
- **Motor único:** `Desktop\src\Utils\uProducaoBipagem.pas` concentra
  `ExecutarBipagemTalao` — transição de status, gravação de `TALAO_BIPAGEM`
  e `LOG_SISTEMA`, tudo em transação com `EMPRESA_ID`/`USUARIO_ID` da sessão.
  `TProducaoService.BiparTalao` (desktop) e a API chamam a mesma unit.
- **API:** `POST /api/producao/bipar` em `API\src\Rotas\uRotasProducao.pas`,
  registrado em `ERP2026API.lpr`; JWT + `uMiddlewareSessao` preenchem o
  contexto da thread; resposta JSON com `resultado`
  (`OK`/`DUPLICADO`/`INVALIDO`), descrição do talão e novo status.
- **App `:bipe`:** módulo Gradle novo em `Android\android\bipe`
  (`com.example.erp2026_bipe`, compileSdk 34 / minSdk 21). Telas: login com
  URL do servidor e bipagem. Três formas de bipar: leitor USB/Bluetooth
  (teclado + Enter), digitação manual e câmera via ZXing
  (`zxing-android-embedded:4.3.0`). Bipe sonoro distinto por resultado;
  contadores do turno e histórico SQLite (`bipe.db`, últimas 50) que
  sobrevivem ao fechamento do app. Token JWT em `SharedPreferences`;
  sessão expirada volta ao login.
- **Decisões:** bipagem **online-only** (o status só o servidor conhece);
  sem fila off-line nesta versão — fábrica com Wi-Fi instável pode pedir
  outbox depois. Histórico local é só cache do turno, não sincroniza.
- **Verificação:** `gradlew :bipe:assembleDebug` OK
  (`bipe-debug.apk`); `run_tests_android.bat` OK; desktop build **0/0** e
  suíte **384/384** inalterados; API compilada.
- **Commits:** `223b85e` (módulo) + commit de docs deste marco.
- **Smoke test real (21/11):** API no ar + login `admin` + bipagens via
  `curl` — encontrou e corrigiu um **Access violation** por double-free
  de `TJSONObject` em `uRotasProducao.pas` (`LBody`/`LData` apontavam
  para o mesmo objeto). Após o fix (`ccea527`): código inexistente →
  `INVALIDO`, talão cancelado (`T000003`) → `INVALIDO`, talão de mapa
  concluído (`T000001`) → `DUPLICADO`. O caminho `OK` (transição de
  status) não foi exercitado porque o banco só tem talões concluídos/
  cancelados — coberto pela suíte desktop (384/384). Também foi
  revisado o app contra os contratos de `uRotasLogin`/`uRotasProducao`
  e adicionados: `empresa_id` opcional no login, limpeza do histórico
  ao trocar de empresa, exibição de `{"error": ...}` e sufixo `Tab`/
  `DPAD_CENTER` para leitores que não usam Enter (`a6bdfd8`).

---

### 3.72 F4 + D9 — API de clientes com ID/PUT e índices únicos (21/11)

- **Objetivo:** fechar o bloco da API em clientes. O app Android casava o
  cliente por nome+CPF porque `POST /api/clientes` não devolvia o ID, não
  existia edição e o banco não impedia login/CPF/número de pedido repetidos.
- **F4 (API):** `uRotasClientes.pas` passou a usar `TPessoaService` em todas
  as operações de cliente (exceto o `DELETE`, que segue com SQL parametrizado
  e `EMPRESA_ID`). `POST` devolve `{"id":..., "message":...}` com 201; novo
  `PUT /api/clientes/:id` aplica campos parciais, confirma empresa e
  `TIPO='C'` e grava auditoria pelo Service; `GET /:id` passou a incluir
  `telefone`. Corpo inválido e exceções viram 400 com `{"error":...}`.
- **D9 (banco):** nova migration `Banco\021_indices_unicos.sql` (+ rollback)
  cria `UQ_USUARIO_EMPRESA_LOGIN`,
  `UQ_PESSOA_EMPRESA_TIPO_CPF` e `UQ_PEDIDO_VENDA_EMPRESA_NUMERO`.
  **Decisão:** o índice de pessoa é composto com `TIPO` porque o Service
  permite o mesmo CPF em cliente e fornecedor (`TestPermitirMesmoCpfTiposDiferentes`).
  Antes dos índices a migration apaga duplicatas antigas sem vínculo; no
  banco real foram removidos os IDs `1237`, `1246`, `1247` (o `999`, com um
  pedido, foi mantido), depois de gbak em
  `Backups\DADOS_20261121_164032.fbk`. Os três índices foram aplicados e
  conferidos no `DADOS.FDB`, e `schema_canonico.sql` foi atualizado.
- **Android:** `Sincronizacao.java` lê o `id` do corpo do POST e marca o
  cliente sincronizado; o casamento por nome+CPF e o helper `chaveCliente`
  saíram. O servidor falso do teste agora devolve `{"id":77,...}`.
- **Testes e ajustes:** novo `Scripts\testes\api_clientes_crud.ps1`
  (POST→ID, GET, PUT, CPF duplicado→400, limpeza no `finally`) passou.
  `uPessoaTest` passou a exigir 8 clientes (piso após a limpeza D9) e
  `banco_fresco.ps1` a exigir 48 generators — D3 fundiu `GEN_CLIENTE_ID` e
  `GEN_FORNECEDOR_ID` em `GEN_PESSOA_ID`. Ajustes pendentes no app `:bipe`
  (empresa no login, limpeza do histórico ao trocar de empresa, sufixo Tab
  e erro HTTP visível) também foram lidos e compilados.
- **Verificação:** API recompilada (startup agora anuncia
  `GET/POST/PUT/DELETE /api/clientes`); desktop build **0/0**; suíte
  **384/384**; Android **OK** e `:bipe` compila; telas **33/33**;
  `permissoes_menu.ps1` **0 falhas**; `schema_roundtrip.ps1` e
  `banco_fresco.ps1` **OK** (585 campos, diff vazio).
- **Commits:** `91c420e` (código) e `a6bdfd8` (ajustes do `:bipe`).

---

### 3.73 Bipe — smoke test real, modo offline e histórico do servidor (21/11)

- **Smoke test de verdade:** API no ar + `curl` exercitou o endpoint com
  talões reais. Achou e corrigiu **Access violation** por double-free de
  `TJSONObject` em `uRotasProducao.pas` (`ccea527`). Depois do fix:
  `INVALIDO` (inexistente/cancelado), `DUPLICADO` (mapa concluído) e o
  ciclo completo `OK`: talão de teste `T999999` (GERADO→EM_PRODUCAO→
  CONCLUIDO, `mapa_concluido=true`) — o mapa 1014/pedido 3581 foi
  concluído pelo teste (dados de cenário, "Produto cenario fiscal").
- **App — revisão de contrato:** `empresa_id` opcional no login
  (multiempresa), histórico local zerado ao trocar de empresa, erros
  `{"error":...}` exibidos, sufixo Tab/DPAD_CENTER para leitores (`a6bdfd8`).
- **Modo offline:** `BipeDb` v2 com tabela `pendente` (FIFO + hora
  original). Sem rede a bipagem enfileira; sincroniza no `onResume`,
  após cada bipagem e pelo botão "Enviar fila". Envio com
  `origem=APP_BIPE_OFFLINE`; resultado real do servidor grava no
  histórico. "Zerar turno" não apaga a fila (`ac013c2`).
- **Histórico do servidor:** `GET /api/producao/bipagens?limite=N`
  (máx. 500) lista `TALAO_BIPAGEM` da empresa via `USUARIO.EMPRESA_ID`
  (a tabela não tem `EMPRESA_ID`); `LEFT JOIN TALAO` cobre
  `TALAO_ID=0`. App ganhou `HistoricoActivity` + `ApiClient.get` e o
  botão "Ver bipagens do servidor" (`1fce8fc` + `ac013c2`).
- **Verificação:** `:bipe:assembleDebug` OK; endpoint testado via curl
  (5 bipagens listadas corretamente); desktop **384/384** inalterado.
- **Pendente:** teste no aparelho físico (instalar APK + API na rede
  local) — único passo que depende do usuário.

---

### 3.74 D4 — auditoria `LOG_SISTEMA` nas rotas de escrita da API (21/11)

- **Objetivo:** fechar a auditoria da API sem depender da sessão do desktop.
  Toda escrita passa a registrar `EMPRESA_ID`/`USUARIO_ID` do JWT na mesma
  transação da gravação, usando `RegistrarAuditoriaSeguraConexao` de
  `uAuditoria` (tabela `LOG_SISTEMA`, `OPERACAO` VARCHAR(20)).
- **Rotas auditadas:** `DELETE /api/clientes` (`PESSOA/D`, antes sem trilha),
  `POST /api/produtos` (`PRODUTO/I`), `POST /api/estoque/movimento`
  (`MOVIMENTO_ESTOQUE/I`) e `POST /api/orcamentos` + `/:id/converter`
  (`PEDIDO_VENDA/I` e `PEDIDO_VENDA/CONVERTER`). `POST/PUT /api/clientes`
  já eram auditados por `TPessoaService`, mas o log ficava **depois** do
  `Confirmar` e podia ser perdido: `Inserir`/`Atualizar` agora gravam
  `LOG_SISTEMA` antes do commit (ID lido do generator dentro da transação).
- **Decisão:** não duplicar a auditoria nas rotas de cliente. O middleware
  JWT define `TSessao.DefinirContexto` por thread; ao confirmar que o
  Service auditava com empresa/usuário corretos, bastou tornar essa
  auditoria atômica no Service. `DELETE` segue na rota (não usa Service).
- **IDs e SQL:** produtos e movimentos passaram a ler `GEN_ID(...,1)` antes
  do `INSERT` e a gravar o ID por parâmetro, para ligar a auditoria ao
  registro; nenhum SQL concatenado foi introduzido.
- **Smoke D4:** API temporária na porta 9010, login `admin/admin123`,
  empresa 1; criou cliente, produto, movimento, orçamento, converteu e
  excluiu o cliente. `LOG_SISTEMA` conferido via `isql`: **6 registros**
  (cliente I/D, produto I, estoque I, orçamento I/converter), todos
  ligados aos IDs criados. Limpeza explícita de dados e logs no `finally`.
- **Teste de regressão corrigido:** `TestBiparFluxoCompleto` usava o código
  fixo `T999999` como "inexistente"; o smoke do app `:bipe` criou um talão
  real com esse código, e a suíte passou a ver `DUPLICADO`. O teste agora
  usa `NovoCodigo('INV')`, único por execução — sem tocar nos dados do
  outro agente.
- **Verificação:** suíte desktop **384/384**, telas **33/33**,
  `permissoes_menu.ps1` **0 falhas**, `schema_roundtrip.ps1` e
  `banco_fresco.ps1` **OK** (585 campos, diff vazio), Android **OK**,
  `build_api.bat` OK e `api_clientes_crud.ps1` **OK** na porta 9000.
- **Commits:** `c9bf7f3` (código) + commit de docs deste marco.

---

### 3.75 Teste dos dois apps Android no emulador (21/11)

- **Emulador:** AVD `Pixel_9` (`%LOCALAPPDATA%\Android\Sdk`), API na
  porta 9000 acessada do emulador via `http://10.0.2.2:9000`.
- **App `:bipe` — aprovado de ponta a ponta:** login admin → bipagem
  `T999999` → `DUPLICADO` com contador e histórico local; `XXXX999`
  caiu na **fila offline** quando a API reiniciou no meio do teste e
  sincronizou pelo botão "Enviar fila" → `INVALIDO` gravado no servidor
  e no histórico (modo offline validado na prática, sem simulador de
  rede); "Ver bipagens do servidor" listou 95 registros com operador.
- **App `:app` (ERP2026 Mobile) — aprovado:** login → dashboard com
  dados reais da API (faturamento, a receber/pagar, clientes, últimas
  vendas) e **todas as 5 abas verificadas**: Início, Clientes (8 com
  busca), Estoque (4 produtos com saldo), Vendas (5 pedidos) e
  Financeiro (contas a receber/pagar detalhadas).
- **Coordenacao:** `Documentacao\COMUNICACAO_AGENTES.md` criado para os
  dois agentes (ERP/desktop e `:bipe`) registrarem o que estão fazendo —
  a reinicialização da API pelo outro agente foi absorvida pela fila
  offline do app sem perda.
- **No aparelho físico (Samsung A55, mesmo dia):** APK instalado via USB;
  ciclo completo do talão `T100000` — 1ª bip `OK` INICIO, 2ª caiu na
  fila durante restart da API e **sincronizou sozinha** ao voltar →
  `CONCLUSAO` + mapa 3 concluído, 3ª → `DUPLICADO`. Aprendizado de rede:
  o PC estava em USB tethering do celular (Wi-Fi do PC desconectado);
  IP correto para o app = `http://10.103.239.156:9000`, e foi preciso
  liberar a porta 9000 no Firewall (perfil Público → regra
  `ERP2026API 9000`). **Câmera validada no aparelho:** EAN-13
  `7898083661293` lido pelo ZXing → API → `INVALIDO` — scanner físico
  funcionando. App `:bipe` **completo e testado**.
- **Commits:** `71c18a5` (diagnóstico de erro no HistoricoActivity) +
  docs deste marco.

---

### 3.76 D5 + F5 — estoque pelo Service e numeração por empresa (21/11)

- **D5 — `POST /api/estoque/movimento`:** a rota deixou de fazer SQL e
  auditoria própria e passou a chamar `TEstoqueService.RegistrarMovimento`
  (a mesma regra do desktop). O Service valida o produto da empresa da
  sessão (contexto JWT por thread), grava o movimento, deixa a trigger
  `TRG_MOVEST_AI` atualizar `ESTOQUE` e audita `MOVIMENTO_ESTOQUE/INSERT`
  na mesma transação. Erros de validação do Service passam a devolver
  **HTTP 400** com `{"error":...}`; a resposta de sucesso continua **201**
  e agora também devolve o `id` do movimento.
- **Operação do log:** mudou de `MOVIMENTO_ESTOQUE/I` (gravada pela rota)
  para `MOVIMENTO_ESTOQUE/INSERT` (gravada pelo Service); `api_auditoria.ps1`
  foi ajustado e segue conferindo os 6 registros do fluxo D4.
- **F5 — numeração de orçamento:** `ProximoNumero` em
  `uRotasOrcamentos.pas` passou a filtrar `WHERE EMPRESA_ID = :EMP`,
  espelhando `TPedidoVendaService.ProximoNumero` do desktop (NUMERO é
  VARCHAR, valores não numéricos ignorados). Antes a API computava o
  máximo global e podia herdar a sequência de outra empresa.
- **Smokes (API na 9000):**
  - `api_estoque_service.ps1`: 201 com ID, saldo **0 → 3** pela trigger,
    exatamente **1** log `INSERT`, **400** para produto de outra empresa
    (`UPDATE` temporário para `EMPRESA_ID=2`, sem FK no campo) e **400**
    para quantidade zero.
  - `api_numeracao_empresa.ps1`: orçamento 1 da empresa 1 = número 2;
    pedido fantasma da empresa 2 com número 990000; orçamento 2 da
    empresa 1 = número 3 (sequência preservada). Tudo limpo no `finally`.
  - `api_auditoria.ps1`, `api_clientes_crud.ps1`: **OK**.
- **Bateria:** desktop **384/384**, telas **33/33**, `permissoes_menu.ps1`
  **0 falhas**, `schema_roundtrip.ps1` e `banco_fresco.ps1` **OK** (585
  campos, diff vazio), Android **OK**, `build_api.bat` **OK**.
- **Coordenação:** API principal parada/recompilada/reiniciada na 9000 com
  aviso prévio em `COMUNICACAO_AGENTES.md`; nenhum arquivo de
  `Android\android\bipe\**` foi tocado.
- **Commits:** código D5+F5 (`bf8bcce`) + docs (`f40b63b`).

---

### 3.77 D7 + D8 + F6 — banco novo confiável e paginação opcional (21/11)

- **D7 — `Banco\script_completo.sql`:** o script legado (caminhos absolutos
  e `INPUT` de `002..008`) foi reescrito para o fluxo canônico, com apenas
  dois `INPUT` **relativos a `Banco\`**: `schema_canonico.sql` e
  `007_initial_data.sql`. Teste isolado com cópias em temp (o
  `CREATE DATABASE` da cópia apontava para um `.fdb` descartável)
  confirmou que os `INPUT` relativos funcionam, o banco é criado e a seed
  grava `Peça` com 4 caracteres / 5 bytes. `banco_fresco.ps1` agora
  valida a forma do script (2 INPUTs, só os dois arquivos canônicos, sem
  caminho absoluto nem migration antiga).
- **D8 — acentos no banco novo:** `007_initial_data.sql` ganhou
  `SET NAMES UTF8;` no início. Medição controlada mostrou que, com o isql
  em `-ch WIN1252`, `Peça` virava 5 caracteres / 7 bytes mesmo com
  `SET NAMES` no seed — o charset do **cliente** também precisa ser
  UTF-8. Por isso `executar_banco.bat` e `Invoke-Iql` do
  `banco_fresco.ps1` passaram a usar `-ch UTF8`. O teste confere
  `CHAR_LENGTH=4` e `OCTET_LENGTH=5` na `UNIDADE` `PC`.
- **F6 — paginação:** novo helper `API\src\Rotas\uPaginacao.pas`.
  `GET /api/vendas`, `GET /api/financeiro/receber` e
  `GET /api/financeiro/pagar` continuam devolvendo o **array de até 100**
  quando chamados sem parâmetros (contrato usado pelo `:app`); com
  `?pagina=N&por_pagina=M` devolvem
  `total`, `pagina`, `por_pagina`, `total_paginas` e `itens`.
  O `total` vem de `COUNT(*)` com o mesmo filtro de empresa/status da
  listagem; a fatia usa `ROWS :LINI TO :LIMF`. Parâmetros inválidos são
  normalizados (`pagina=0` → 1, `por_pagina>200` → 200, nunca 500).
  Corrigido um `double-free` no helper: `TJSONObject.Add` assume a posse
  do array, então a resposta clona `AItens` antes de liberar o original.
- **Smoke `api_paginacao.ps1`:** contrato legado preservado nas 3 rotas;
  página 1/2 com total e `total_paginas` corretos; página 2 sem repetir
  itens; página 999999 vazia com total preservado; parâmetros inválidos
  normalizados; pedido fantasma da empresa 2 não alterou o total da
  empresa 1. Limpeza no `finally`.
- **Armadilha de teste:** no Windows PowerShell 5.1,
  `@(ConvertFrom-Json -InputObject $json)` devolve o array como um único
  objeto; é preciso atribuir a uma variável e só então fazer `@($var)`.
- **Bateria:** desktop **384/384**, telas **33/33**, `permissoes_menu.ps1`
  **0 falhas**, `schema_roundtrip.ps1` e `banco_fresco.ps1` **OK** (585
  campos, diff vazio), Android **OK**, `build_api.bat` **OK**, 5 smokes
  da API **OK** na 9000. O `build_api.bat` só falhou uma vez porque o
  `.exe` estava travado pela API rodando — parar/recompilar/reiniciar
  resolveu; não é regressão de código.
- **Coordenação:** API parada/recompilada/reiniciada na 9000 com aviso no
  canal. Nada de `Android\android\bipe\**` foi tocado.
- **Commits:** código D7+D8+F6 (`90f2af2`) + docs (`58f34b9`).

---

### 3.78 F9 — erros de sincronização visíveis, backoff e dead-letter (21/11)

- **Escopo:** só `Android\android\app\src\`. O mapeamento confirmou que
  `:app` e `:bipe` não compartilham nenhum arquivo Java; nenhum arquivo de
  `Android\android\bipe\**`, `HistoricoActivity.java` ou dos dados de cenário
  do outro agente foi tocado.
- **Schema (migração v3 → v4 em `ErpDbHelper`):** a outbox ganhou
  `proxima_tentativa` (epoch ms) e `status` (`PENDENTE`/`ERRO`/`DEAD`). Itens
  antigos com tentativa/erro passam para `ERRO` com retry livre, preservando
  o histórico. `onCreate` já cria as colunas para instalações novas.
- **Política (`ItemOutbox`):** backoff exponencial de 1/2/4/8/16 minutos;
  após 5 falhas a linha vira `DEAD`. Erro HTTP 4xx (exceto 408/429, que são
  transitórios), resposta de POST sem `id` e orçamento sem itens vão direto
  para `DEAD` — reenviar não mudaria a causa e poderia duplicar registro.
  Falhas de rede/5xx e dependências ainda pendentes ficam em `ERRO` com retry.
- **`BancoLocal`:** `pendentes()` agora devolve só o que pode ser enviado
  (não-dead e com backoff vencido); `fila()` devolve tudo para diagnóstico;
  `registrarErro()` grava tentativa/erro/status/próxima data;
  `requererTentativa()` zera o backoff sem apagar o histórico;
  `limparDeadLetter()` remove só falhas definitivas; `resumoFila()` conta
  prontos/aguardando/dead. Reenfileirar o mesmo registro volta para
  `PENDENTE`.
- **`Sincronizacao`:** `Resultado.fila` e `resumo()` mostram o estado da fila;
  o envio classifica cada falha. Não foi adicionado retry automático em
  `ApiClient.post` — POST não é idempotente e a outbox já reenvia com backoff.
- **Tela:** `activity_sincronizacao.xml` ganhou o card "Fila de envio" com
  resumo, lista das primeiras 20 operações (`ItemOutbox.descricao()`),
  `Tentar novamente` (libera backoff e roda a rodada) e `Limpar falhas`.
  Todos os `android:id` existentes foram preservados; os novos são
  `textViewFilaResumo`, `containerFila`, `buttonTentarFila` e
  `buttonLimparFalhas`.
- **Testes Android 9/9** (antes 5): 3 casos novos de backoff/dead-letter/
  limpeza e 1 de inflação da Activity com os novos IDs. Nenhum teste antigo
  precisou mudar.
- **Bateria:** desktop **384/384**, telas **33/33**, `permissoes_menu.ps1`
  **0 falhas**, `schema_roundtrip.ps1` e `banco_fresco.ps1` **OK** (585 campos,
  diff vazio), Android **9/9**, `build_api.bat` **OK**, 5 smokes da API **OK**.
- **Coordenação:** API parada/recompilada/reiniciada na 9000 com aviso prévio
  no canal. Canal registra que o próximo bloco é F1 (CRUD da API).
- **Commits:** código F9 + docs deste marco.

---

### 3.79 F1 — CRUD completo na API e auditoria atômica de produto (21/11)

- **Escopo:** rotas `uRotasProdutos.pas`, `uRotasOrcamentos.pas`,
  `uRotasVendas.pas`, lista de endpoints em `ERP2026API.lpr`, novos métodos em
  `TOrcamentoService`, ajuste de auditoria em `TProdutoService` e variantes
  sem `Commit` em `TRepositoryBase`. Nenhum arquivo de `Android\android\bipe\**`
  nem o cenário fiscal foi tocado.
- **Produtos:** `PUT /api/produtos/:id` e `DELETE /api/produtos/:id` usam
  `TProdutoService` (mesma validação do desktop: descrição, categoria, unidade
  e preço), conferem `EMPRESA_ID` do JWT e gravam `PRODUTO/U` e `PRODUTO/D`.
- **Orçamentos:** `TOrcamentoService.AtualizarOrcamento` e
  `ExcluirOrcamento` exigem STATUS 'O' da empresa da sessão, revalidam
  cliente/itens/totais, substituem os itens por inteiro na mesma transação e
  auditam `PEDIDO_VENDA/U` e `PEDIDO_VENDA/D`. A rota devolve 404 para registro
  de outra empresa, 409 para rascunho já convertido e 400 para dados inválidos.
- **Vendas:** `POST /api/vendas` usa `TPedidoVendaService.SalvarPedido` com
  STATUS 'P', numeração/recalcimento de totais pelo Service e auditoria
  `PEDIDO_VENDA/INSERT`. Resposta 201 com `id`, `numero`, `subtotal`,
  `desconto` e `total`. Quando o app não envia `valor_unitario`, a rota busca
  `PRECO_VENDA` do produto da empresa antes de chamar o Service.
- **Correção descoberta pelo smoke:** o `TProdutoService` auditava **depois**
  do `Commit` do repositório; no desktop o teste antigo passava, mas na API
  os logs `U`/`D` desapareciam silenciosamente. Foram acrescentadas as
  variantes `InserirParamNNaTransacao`, `AtualizarParamNNaTransacao` e
  `ExcluirNaTransacao` em `TRepositoryBase`; o Service agora abre a transação,
  grava, chama `LogOperacao` e confirma (ou cancela) tudo junto.
- **Smoke F1:** `Scripts\testes\api_f1.ps1` cria cliente/produto, edita e
  exclui produto, cria/edita/exclui orçamento, cria venda e confere as 7
  auditorias (`PRODUTO/I,U,D`, `PEDIDO_VENDA/I,U,D,INSERT`) com limpeza no
  `finally`. Resultado: **API-F1 CONCLUIDO**.
- **Bateria:** desktop **384/384**, telas **33/33**, `permissoes_menu.ps1`
  **0 falhas**, `schema_roundtrip.ps1` e `banco_fresco.ps1` **OK** (585 campos,
  diff vazio), Android **9/9**, `build_desktop.bat`/`build_api.bat` **OK** e os
  6 smokes da API **OK** (os 5 anteriores + F1).
- **Coordenação:** API parada/recompilada/reiniciada na 9000 com aviso prévio
  no canal; `/api/health` = `ok`. Canal registra o F1 como fechado.
- **Commits:** código F1 (`5a3bd7b`) + docs deste marco.

---

### 3.80 Bipe — feedback de erro evidente e layout acima do teclado (21/11)

- **Pedido do usuário em campo:** no Samsung A55 a mensagem de erro já
  aparecia, mas o teclado virtual a cobria — e o operador não percebia
  quando a bipagem falhava.
- **`BipagemActivity.java`:** resultado agora tem **cor semântica** —
  verde `#2E7D32` (OK), amarelo `#F9A825` (DUPLICADO), vermelho
  `#C62828` (INVALIDO/erro de API), cinza `#616161` (fila offline).
  **Vibração** distinta por resultado (OK 80 ms, duplicado/offline
  200 ms, erro 400 ms) via `VIBRATOR_SERVICE` — permissão `VIBRATE`
  adicionada ao manifest. Em INVALIDO o app exibe também o
  **código como o servidor o interpretou** (`codigo_barras` da
  resposta) — resolve a dúvida do caso "1001" → `T001001` que não
  existe.
- **`activity_bipagem.xml`:** `txtResultado` movido de baixo para
  logo abaixo do campo de código (minHeight 64dp) — fica sempre
  acima do teclado virtual, sem depender de rolagem.
- **Verificação:** `:bipe:assembleDebug` OK; APK reinstalado no
  Samsung A55 via adb Wi-Fi (`192.168.100.126:43511`).
- **Talão de teste criado para o usuário:** `T100001` (talão nº 1001,
  mapa de produção nº 4, status GERADO, empresa 1).

---

### 3.81 Preferência de homologação para NF-e/NFC-e e PDV (21/11)

- **Pedido do usuário:** um único interruptor para testar notas fiscais e o
  PDV em homologação, com emissão real na SEFAZ de testes ("simulação real").
- **Decisão:** não criar tabela/coluna nem estado redundante. A preferência
  reusa a tabela `CONFIGURACAO` da empresa da sessão:
  - ativa = `CHAVE='NFE_AMBIENTE'`, `VALOR='2'` **e**
    `CHAVE='NFE_MODO'`, `VALOR='REAL'`;
  - desativada = `NFE_MODO='SIMULADO'`, mantendo `NFE_AMBIENTE` configurado.
  - `DESCRICAO` é apenas texto explicativo; o escopo é `EMPRESA_ID` da sessão
    com fallback em `EMPRESA_ID IS NULL`.
- **`TConfiguracaoService`:** novos `LerValor`, `HomologacaoAtiva` e
  `DefinirModoHomologacao`; `Gravar` continua gravando `CONFIGURACAO/ALTERACAO`
  em transação, então ligar/desligar fica auditado.
- **Tela:** checkbox "Modo homologação (NF-e/NFC-e e PDV)" em
  *Sistema > Configurações*, ao lado do interruptor `USA_GRADE`. O estado é
  lido das chaves reais; se o usuário editar a grade, o checkbox reflete o
  que está gravado. Mensagem informa explicitamente ambiente/modo.
- **Consumidores:** `TACBrHelper.CarregarConfiguracaoFiscal` já lia
  `NFE_AMBIENTE`/`NFE_MODO`, então NF-e, NFC-e, consultas e o PDV passaram a
  usar a preferência sem mudança adicional. `Ambiente=2` +
  `ModoSimulado=False` = SEFAZ de homologação.
- **Teste:** `TestNFeModoHomologacao` ativa/desativa pelo Service, confere
  `Ambiente=2`/`ModoSimulado` no helper e restaura valores, descrições e logs
  (`CONFIGURACAO` acima de `LTopoLog`) no `finally`.
- **Correção de infraestrutura:** `Scripts\build_tests.bat` agora usa
  `lazbuild -B`; sem isso a suíte reaproveitou um `.ppu` antigo e executou
  384 testes em vez dos 385.
- **Bipe incluído na bateria (pedido do usuário):** criado
  `Scripts\build_bipe.bat` (`gradlew :bipe:assembleDebug`), validado com
  `BUILD SUCCESSFUL` e APK em `bipe\build\outputs\apk\debug\bipe-debug.apk`.
  O app de talão já estava fechado/testado no marco 3.80 (Samsung A55);
  nenhum arquivo Java/XML dele foi alterado aqui.
- **Bateria:** desktop **385/385**, telas **33/33** (inclusive Configurações),
  `permissoes_menu.ps1` **0 falhas**, `schema_roundtrip.ps1` e
  `banco_fresco.ps1` **OK** (585 campos, diff vazio), Android **9/9**,
  `build_desktop.bat` e `build_bipe.bat` **OK** e os 6 smokes da API **OK**
  com `/api/health` = `ok`. API não precisou ser reiniciada (mudança
  desktop-only).
- **Escopo:** nenhum arquivo de `Android\android\bipe\**` tocado; o marco
  3.80 pertence ao ajuste de bipe de outro agente. Cenário fiscal
  (talão 533/mapa 1014/pedido 3581) preservado.
- **Commits:** código (`462531f`) + docs deste marco, com `git push`.

---

### 3.83 D10 — CI local e executor único dos smokes da API (21/11)

- **Pedido do usuário:** os agentes devem se atualizar e se comunicar de tempos
  em tempos por `Documentacao\COMUNICACAO_AGENTES.md`. Foi formalizada uma
  rotina no topo do canal: escrever ao iniciar/bloco e ao concluir, ler antes
  de arquivo compartilhado, avisar antes de parar/reiniciar a API e registrar
  "sem novidades" quando aplicável. O `PROMPT_AMANHA.md` agora repete a regra.
- **Espaço de numeração:** 3.82 fica reservado ao app PDV mobile do outro
  agente; este marco é 3.83.
- **`Scripts\testes\api_todos.ps1`:** novo executor único dos 6 smokes
  (`clientes_crud`, `auditoria`, `estoque_service`, `numeracao_empresa`,
  `paginacao`, `f1`). Faz `GET /api/health` primeiro, para na primeira falha
  com `$LASTEXITCODE` e **não inicia nem reinicia a API**. Resultado local:
  **API-TODOS CONCLUIDO: 6 smokes OK**.
- **`.github\workflows\bateria.yml`:** pipeline `self-hosted` (Lazarus/FPC,
  Firebird e API já na 9000 vivem na máquina de desenvolvimento). Job 1:
  build desktop + suíte + `:bipe` + `:app` + telas + permissões. Job 2:
  `api_todos.ps1`. Não compila a API para não disputar o `.exe` com o
  servidor em uso; recompilação continua manual e avisada no canal.
- **Validação:** `api_todos.ps1` rodou com os 6 smokes OK contra a API já
  ativa; `/api/health` = `ok`. Nenhuma mudança em cada um dos 6 scripts.
- **Escopo:** nada em `uRotasPDV.pas`, `ERP2026API.lpr`, `:pdv/**`,
  `AndroidManifest.xml` ou `Android\android\bipe\**`. Nenhum restart da API.
- **Commits:** código/CI deste marco + docs.

---

## 4. Convenções e avisos (não reabrir)

- Firebird 5: **não** renomeia tabela/coluna (`ALTER ... RENAME`) — usar ADD+cópia+DROP.
- Sem FKs reais; integridade no Service; generators `GEN_X_ID`; triggers `TRG_X_BI`/`BU`.
- Migrações numeradas, `SET ECHO ON`; acentos exigem `SET NAMES UTF8`.
- Tabelas geográficas são **globais** (sem `EMPRESA_ID`).
- `PRODUTO` é o produto de produção (nome físico mantido; `PRODUTO_PRODUCAO` é conceitual).
- `PRODUTO_FINANCEIRO` não existe mais.
- Android: preservar todos os `android:id`.
