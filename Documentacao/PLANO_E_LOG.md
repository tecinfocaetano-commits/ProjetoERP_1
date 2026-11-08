# PLANO E LOG DE DESENVOLVIMENTO — ERP 2026

> Documento **vivo**: registra o planejamento, as decisões do usuário e o que já
> foi executado. Atualizar a cada etapa concluída.
> Última atualização: 08/11/2026

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

## 4. Convenções e avisos (não reabrir)

- Firebird 5: **não** renomeia tabela/coluna (`ALTER ... RENAME`) — usar ADD+cópia+DROP.
- Sem FKs reais; integridade no Service; generators `GEN_X_ID`; triggers `TRG_X_BI`/`BU`.
- Migrações numeradas, `SET ECHO ON`; acentos exigem `SET NAMES UTF8`.
- Tabelas geográficas são **globais** (sem `EMPRESA_ID`).
- `PRODUTO` é o produto de produção (nome físico mantido; `PRODUTO_PRODUCAO` é conceitual).
- `PRODUTO_FINANCEIRO` não existe mais.
- Android: preservar todos os `android:id`.
