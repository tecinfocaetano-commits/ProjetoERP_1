# CHECKPOINT — último ponto de parada (03/11/2026)

> Documento de retomada. **Leia só este arquivo para continuar.**
> O log vivo (decisões + backlog + executado) fica em
> `Documentacao\PLANO_E_LOG.md`.

---

## COMO RETOMAR (qualquer agente, qualquer sessão)

0. Se você é um agente: leia também `Documentacao\INSTRUCOES_AGENTE.md`
   (regras de condução: checkpoint por marco, comandos, o que não fazer).
1. `cd C:\Users\Charles\Documents\ProjetoERP_1`
2. `git log --oneline -3` e `git status --short` — **o disco é a verdade**,
   este texto pode estar um passo atrás.
3. Ler "Estado atual" abaixo e abrir os arquivos citados.
4. `Scripts\build_desktop.bat` (deve linkar) e `Scripts\run_tests.bat`
   (deve dar **65/65**). Ruído conhecido: `InitializeFppkg failed`.
5. Executar o **Próximo passo** e atualizar este arquivo ao fechar cada marco.

Regras do projeto: português; regra de negócio em Services; SQL sempre
parametrizado; transação + auditoria (`LogOperacao`); LazReport apenas;
Firebird: **31 chars** por identificador e `DEFAULT` **antes** de `NOT NULL`.

---

## Estado atual da sessão (03/11/2026)

**HEAD:** `862b26f` (Android: modo off-line de clientes e orçamentos com sincronização). Árvore: **limpa** no commit de código; este texto foi gravado no commit de docs seguinte (só `CHECKPOINT.md` e `PLANO_E_LOG.md`).
Build: Android `BUILD SUCCESSFUL` · suíte desktop **65/65** (sem alteração no desktop nesta etapa).

> Se `git log -1` mostrar um hash diferente de `862b26f`, é porque o commit
> que gravou este texto veio depois — o disco vence, como sempre.

### Em andamento (não commitado)

- Nada — o modo off-line está no commit `862b26f`. Os registros usados para
  validar a sincronização ("Cliente Offline Teste", PESSOA 1396, e orçamento
  1007/número 2) foram removidos do banco real ao final, devolvendo a base aos
  **9 clientes** e à suíte **65/65**.

### Próximo passo (executável)

1. Não há item aberto no backlog: aguardar o próximo pedido do usuário.
2. Opcional: validar no emulador a **conversão** de um orçamento sincronizado e
   o fluxo de **sessão expirada (401)** durante a sincronização.
3. Antes de qualquer commit do desktop, rodar `Scripts\build_desktop.bat`
   (esperado 0/0) e `Scripts\run_tests.bat` (esperado **65/65**); se a suíte
   cair, não commitar.

### O que fechou nesta sessão

| Item | Entrega |
|---|---|
| **Modo off-line (Android)** | Banco SQLite local `erp2026.db` (schema v2) + fila `outbox` + `Sincronizacao`: **clientes** e **orçamentos** funcionam sem rede (cache local, cadastro salvo no aparelho, "Sincronizar (N pendentes)") e sobem sozinhos quando a conexão volta. Sem dependência nova (só `SQLiteOpenHelper`). Detalhes em `PLANO_E_LOG.md` §3.23 |
| **Teste de todas as telas (desktop)** | `Scripts\testes\telas_todas_ui.ps1` percorre os **33 itens do menu** por `WM_COMMAND`, valida janela + controles, lê/fecha avisos e gera `Documentacao\TESTE_TELAS_DESKTOP.md` + evidências. Resultado **33/33 OK**. Encontrou e corrigiu 3 bugs: geo (`... WHERE ORDER BY NOME`), NF-e (campos `edtInicio/edtFim` sem componente no `.lfm` → AV) e Compras (`MAX(NUMERO)` sobre texto `PC-TESTE-8`). Detalhes em §3.22 |
| **D3 — PESSOA unificada** | `CLIENTE` + `FORNECEDOR` → `PESSOA` (`TIPO` C/F). Tela única **Cadastros > Pessoas** (`uFrmPessoas`) com filtro Todos/Clientes/Fornecedores; tipo imutável após salvo; exclusão bloqueada quando referenciada. API `/api/clientes` mantém o contrato e filtra `TIPO='C'`. Suíte **65/65** (§3.19) |
| **Dashboard de vendas (Android)** | `activity_dashboard.xml` sem botões: faturamento do mês + vendas, A receber / A pagar, orçamentos abertos, clientes e as 3 últimas vendas; cards abrem `OrcamentosActivity`, `ClientesActivity` e `VendasActivity`. Configuração e saída foram para o menu **⋮** (Atualizar resumo / Configuração / Sair). Validado no emulador — §3.18 |
| **Seta de voltar + busca** | `BaseActivity` centraliza a seta em todas as telas; `BaseListaActivity` coloca a barra de pesquisa ao lado dela (Clientes e Vendas), filtrando sem diferenciar caixa/acentos. Commit `1a1c719` |
| **Resumo financeiro da API** | `SUM(CASE ...)` vinha como BCD nulo no driver e zerava `a_receber`/`a_pagar`/`faturamento_mes`; somas agora com `CAST(... AS DOUBLE PRECISION)`. `ApiClient.get` repete GET até 3× em queda de conexão. Detalhes em §3.18 |
| **Orçamentos (item 11)** | API `GET/POST /api/orcamentos`, `GET /api/orcamentos/:id` e `POST /api/orcamentos/:id/converter`; telas `OrcamentosActivity` e `InserirOrcamentoActivity`; card **Orçamentos abertos** no Dashboard e botão em Vendas. Validado no emulador (criar e converter). Detalhes em `PLANO_E_LOG.md` §3.17 |
| **Menu inferior (item 11)** | `include_bottom_nav.xml` + `menu_bottom_nav.xml` com Início/Clientes/Estoque/Vendas/Financeiro; `Navegacao.java` reaproveita as Activities; ícones vetoriais próprios (`ic_nav_*`), sem dependências novas |
| **D9 (Android)** | Configuração **por empresa**: URL do servidor + código de usuário em `SharedPreferences`; tela com **Testar conexão / Salvar / Usar esta empresa / Excluir**. Commit `67d26f4` — §3.13 |
| **Geo (correção)** | `uEstadoService`/`uCidadeService` com `BuscarTodos` simples. Commit `5075a06` — §3.14 |
| **Schema canônico (item 13)** | `Banco\schema_canonico.sql` regenerado do banco real (**49 tabelas / 602 campos**) + sementes (Brasil + 27 UFs, `USA_GRADE`) no `007_initial_data.sql`. Round-trip e banco novo verdes — §3.15 |
| **Encoding (item 14)** | `SetMultiByteConversionCodePage(CP_UTF8)` no início do app e dos testes; **sem `-FcUTF8`** (a flag gerava 213 warnings e corrompia concatenações). Contorno local removido; banco sem mojibake — §3.16 |
| **Backlog 5–9** | fechado em 01/11 (ver "Estado anterior" abaixo) |

- **Modo off-line validado no emulador `Pixel_9` (API local no ar):** em modo
  avião, cliente "Cliente Offline Teste" foi salvo no aparelho e apareceu como
  "(aguardando sincronização)" com o botão **Sincronizar (1 pendente)**;
  orçamento #1 (1 × R$ 35,00) para esse cliente levou o contador a **2
  pendentes**. Religando a rede e tocando **Sincronizar**, o servidor recebeu
  o cliente (id 1396) e o orçamento (id 1007 / número 2 / R$ 35,00 / 1 item), e
  o app passou a mostrar **Orçamento 2** com contador **0**. `force-stop` +
  relançamento ainda em modo avião carregou clientes e orçamento do banco
  (`clientes=10 pendentes=0 produtos=4 orcamentos=1 outbox=0`).
- **Dashboard validado no emulador `Pixel_9` (Android 16)** com a API local no
  ar: faturamento **R$ 70,00** (1 venda no mês), **A receber R$ 170,00**,
  **A pagar R$ 1.595,00**, **0 orçamentos**, **9 clientes** e as 3 últimas
  vendas; menu ⋮ com os 3 itens; **Atualizar resumo** recarregou 4× sem erro;
  os cards e a configuração abrem as telas certas e a seta volta; **Sair**
  pede confirmação.
- **Item 11 validado no emulador `Pixel_9` (Android 16)** com a API local no
  ar: criar orçamento com 2 × R$ 35 e desconto R$ 5 → lista mostra
  **Orçamento 3 / R$ 65,00 / 1 item(ns)**; converter pela confirmação → some
  da lista e o banco fica `STATUS = 'P'`. Repetir a conversão pela API dá
  **HTTP 409**; criação via `curl` deu **201** (id 1004). Dados de teste
  removidos do banco ao final.
- Uso do Android documentado em `Android\README.md` (dashboard, busca e
  orçamentos) e `Android\CONFIGURACAO_POR_EMPRESA.md` (D9).
- Banco **sem migração nova** nesta sessão (orçamento reusa `PEDIDO_VENDA`).

- **D3 validado (02/11):** migração `018` aplicada no banco real (backup
  `Banco\DADOS_backup_antes_018.fdb`); **9 clientes / 2 fornecedores** em
  `PESSOA`, zero órfãos, tabelas antigas removidas. Build desktop **0/0**,
  suíte **65/65**, build API OK, Android `BUILD SUCCESSFUL`, schema canônico
  regenerado (49 tabelas / 584 campos) com round-trip vazio. Emulador
  `Pixel_9`: 9 clientes, faturamento R$ 70,00, a receber R$ 170,00, a pagar
  R$ 1.595,00. Smoke de runtime instanciou as 11 telas alteradas (0 falhas).

- **Filtros + incluir cliente (02/11):** telas de Estoque (Movimentação e
  Kardex; Inventário já tinha) e Financeiro (Contas a Pagar/Receber,
  Movimento Financeiro e Caixa) com pesquisa; app Android com FAB
  **Incluir cliente** na lista de Clientes. Build desktop **0/0**, suíte
  **65/65**, Android `BUILD SUCCESSFUL`; smoke de runtime dos filtros com
  0 falhas e inclusão real validada no emulador (§3.20).

### Próximo passo (executável)

Nenhuma pendência aberta do usuário. O próximo passo é o que for pedido;
ao fechar cada marco: build 0/0, suíte verde, atualizar este checkpoint,
`PLANO_E_LOG.md` e commitar.

---

## Estado anterior (01/11/2026) — itens 5–9 do backlog desktop

| Item | Entrega |
|---|---|
| 5 | Notas de saída e de entrada leem `PRODUTO_FISCAL` (NCM/CFOP/CST/alíquotas) e gravam `PRODUTO_FISCAL_ID` no item |
| 6 | Consumo de materiais: itens do mapa no topo (`sgMapaItens`), materiais do consumo no rodapé (`sgItens` em `alClient`) |
| 7 | Diálogo **Cores do produto** (`uFrmCoresProduto`) com a ficha técnica da cor |
| 8 | **Compras → Nota de Entrada**: `CriarDoPedidoCompra` + `Processar` com material (estoque, movimento, custo, contas a pagar) |
| 9 | Vínculo geográfico em CLIENTE/FORNECEDOR (`CIDADE_ID`, migração `017`, `uGeoCombos`) |

- Detalhes técnicos: `Documentacao\PLANO_E_LOG.md` §3.7 a §3.12.
- Migração `017` aplicada no real (backup `Banco\DADOS_backup_antes_017.fdb`);
  nenhuma migração pendente.
- Teste de ponta a ponta (harness temporário, já removido): **38/38** — compra
  → nota de entrada → processamento e venda → nota de saída → faturamento.
  Um smoke também instanciou as 7 telas alteradas e todas carregaram o `.lfm`
  (o build não valida `.lfm`).
- Banco deixado com **um exemplo completo de cada fluxo** e os cadastros de
  apoio (`FISC-TESTE`, `MAT-TESTE8`, `PROD-TESTE8`, `PC-TESTE-8`,
  `PV-TESTE-5`, saldos 15 e 98) — nada de lixo das rodadas do harness.

---

## Estado anterior (31/10/2026) — GRADE concluída

**HEAD na época:** `879db53` + commit da grade no pedido/mapa.
Build **0 erros / 0 warnings** · suíte **62/62**.


### GRADE — COMPLETA (D5/D6/D7)

- **Cadastro** (`uGrade`, `uGradeService`, `uFrmGrade`, menu
  **Cadastros → Grades**, checkbox `USA_GRADE` em Configurações) — commit
  `87b6246`.
- **Grade no item do pedido** (`uFrmPedidoVenda`):
  - coluna **Grade** no `sgItens` (oculta com `USA_GRADE='N'`);
  - botão **"Grade do item..."** em `pnlItens` (visível só com `UsaGrade`);
  - ao adicionar produto com `PRODUTO.GRADE_ID`, abre o diálogo de
    quantidades já com os tamanhos da grade padrão;
  - a quantidade do item passa a ser `SomarQuantidades(grade)` e o total é
    recalculado;
  - no save, cada `ITEM_PEDIDO` grava `ITEM_PEDIDO_GRADE` na **mesma
    transação** (ID via `GEN_ID(GEN_ITEM_PEDIDO_ID, 0)`).
- **Grade no mapa** (`uFrmMapaProducao`):
  - painel **"Grade do item"** à direita de `dbGridItensMapa` (só com
    `UsaGrade`; sem a preferência o grid volta à largura cheia);
  - botões **"Editar grade..."** (diálogo editável) e **"Copiar do pedido"**
    (`CopiarGradeDoPedidoParaMapa`);
  - resumo/total atualizado ao selecionar o item (`OnDataChange` do
    `DataSourceItensMapa`);
  - gravação via `SalvarGradeMapaItem` + `CarregarMapas` após o commit.
- **Diálogo reutilizável** `Desktop\src\Views\uFrmGradeQuantidades.pas/.lfm`
  (`TStringGrid` com `FixedCols=1`: tamanho não editável, quantidade
  editável, total no rodapé).
- **Produto**: combo **Grade** em `uFrmProdutos` (`PRODUTO.GRADE_ID`), usado
  como grade padrão na inserção do item.
- **Transação composta**: `uGradeService.GravarGradeEfetiva` só
  inicia/commita/rollback quando `not Conexao.EmTransacao`; com transação
  aberta pelo chamador, a grade entra nela.

### Próximo passo na época (já executado em 01/11)

1. Backlog do `PLANO_E_LOG.md` §2: itens **5 a 10** (notas lendo
   `PRODUTO_FISCAL`, re-layout do Consumo, Produto com Cores, Compras → Nota
   de Entrada, vínculo geo em CLIENTE/FORNECEDOR).
2. **D9 (Android, depois do backlog):** tela de configuração com **caminho
   do servidor + código de usuário, salvos por empresa** — cada empresa
   usada tem a sua própria configuração.
3. Ao fechar cada marco: build 0/0 + suíte 65/65; atualizar este checkpoint
   e o `PLANO_E_LOG.md`; commitar.

### Último marco concluído — migração `016` GRADE (commit `17be6ff`)

- `Banco\016_grade.sql` (+ `_rollback.sql`): `GRADE`, `GRADE_TAMANHO`,
  `ITEM_PEDIDO_GRADE`, `MAPA_PRODUCAO_ITEM_GRADE`, `PRODUTO.GRADE_ID`,
  `CONFIGURACAO.USA_GRADE='N'`; 4 generators, 5 triggers, 5 índices.
- Testada em cópia (aplica → rollback limpo) e aplicada no `DADOS.FDB` real
  (backup `DADOS_backup_antes_016.fdb`).

### Módulo geográfico — CONCLUÍDO (decisão D2, commit `63782eb`)

- Models `uPais` (`NOME`/`CODIGO`/`DDI`), `uEstado` (`PAIS_ID`/`NOME`/`UF`/`CODIGO_IBGE`),
  `uCidade` (`ESTADO_ID`/`NOME`/`CODIGO_IBGE`) — colunas reais do banco.
- Services `uPaisService`/`uEstadoService`/`uCidadeService` com SQL parametrizado
  (`InserirParam`/`AtualizarParam`/`BuscarTodosParam`), filtros por país/estado.
- Telas `uFrmPais`, `uFrmEstado`, `uFrmCidade` (`.pas` + `.lfm`) no padrão
  `TfrmCadastroBase`: CRUD, validação (UF 2 letras, país/estado obrigatórios),
  status Ativo/Inativo e bloqueio de exclusão com vínculos (país→estado, estado→cidade).
- Menu **Cadastros → Países / Estados / Cidades** (`uFrmPrincipal` + `.lfm`).
- `Desktop\ERP2026.lpi` com as 9 units novas; `Desktop\ERP2026.lpr` atualizado.

### Próximo passo na época (backlog — superado em 01/11)

Ver `Documentacao\PLANO_E_LOG.md` §2. **GRADE** está em andamento: migração
`016` aplicada, model + service escritos (com stubs). Depois: grade no item do
pedido + subgrid editável no mapa sob `USA_GRADE`. Demais itens: notas lendo
`PRODUTO_FISCAL`; re-layout do Consumo; Produto com Cores; Compras → Nota de
Entrada; vínculo geo em CLIENTE/FORNECEDOR; unificação CLIENTE+FORNECEDOR
(adiada); Android (deferido).

---

## Estado (histórico)

- **Redesenho em 4 abas + cadastros da fase 1 concluído (31/10)** — ver seção
  própria abaixo: migração `014` (9 tabelas + 4 colunas), 4 models, 5 services,
  5 telas novas, o menu reorganizado em **Suprimentos · Produção · Financeiro ·
  Fiscal** e o **consumo automático** (base planejada). Verde: build **0/0**,
  suíte **62/62**. Pendências da fase listadas na mesma seção.
- **Módulo de Produção: 8 fases COMPLETAS e commitadas** — última: FASE 8 = `40bbd8b`.
- **Modelos I/II dos relatórios concluídos e commitados (30/10)** — `74df45a`
  (Talão e Mapa com Modelo I e Modelo II, mesmos datasets; escolha na
  `CONFIGURACAO`; seção própria abaixo + `TESTES_EXECUTADOS.md`).
- **Pool de conexões da API concluído e commitado (30/10)** — `f9df7d7` (seção
  própria abaixo + `TESTES_EXECUTADOS.md`): cada thread de requisição passou a ter
  a **sua** `TConexao` (o Horse atende em thread própria; conexão única era
  corrida), `TConexao.GetInstance` **não mudou** (as 6 rotas intocadas), tamanho
  via `ERP_API_POOL` (padrão 8) e reciclagem de vagas por detecção de thread
  morta.
- **Pendência "itens de menu inertes" concluída e commitada (30/10)** — `f746c12`:
  as 4 telas novas (Financeiro ▸ Caixa, Sistema ▸ Configurações, Sistema ▸
  Permissões, Relatórios ▸ Central de Relatórios) estão implementadas e ligadas ao
  menu — seção própria abaixo + `TESTES_EXECUTADOS.md`. Os itens deixaram de ser
  inertes (todos têm `OnClick`).
- **Redesenho do layout Android (Material You) concluído e commitado (30/10)** —
  `d16500e`: tema Material 3 com cores dinâmicas (Android 12+) + paleta estática
  claro/escuro como fallback; 8 layouts redesenhados com IDs intactos — seção
  própria abaixo + `TESTES_EXECUTADOS.md`.
- **Pendência SHA-256 concluída (19/10)**: senhas em hash SHA-256 no Desktop,
  API e semente (`uSenhaHash.pas`, migração progressiva no login) — ver
  `Documentacao\TESTES_EXECUTADOS.md` §8.
- **Pendência parametrização do `uClienteService` concluída (19/10)**: o service
  não monta mais SQL com `Format`. Métodos novos no `uRepositoryBase`
  (`InserirParam`, `AtualizarParam`, `BuscarTodosParam`, `ContarParam`) recebem
  os valores por `ParamByName`. Corrigidos junto: `CpfCnpjExiste` e `Pesquisar`
  (que interpolavam o texto do usuário — vetor de apóstrofo/injeção) e
  `BuscarTodos` (filtrava por `Connection.Tag`, sempre 0 → lista vazia; agora
  filtra pela empresa da sessão).
- Verificação final verde (**19/10, após o Modelo I/II**):
  - `Scripts\build_desktop.bat` → compila, **0 warning / 0 erro** (rebuild
    forçado das unidades alteradas).
  - `Scripts\build_api.bat` → compila (sem mudança de API nesta rodada).
  - `Scripts\run_tests.bat` → **58/58** (56 anteriores + 2 do Modelo I/II).
  - `Scripts\testes\fase6_01.ps1` → **FASE6-01 CONCLUIDO** (tela, menu ▼, preview,
    `taloes_mapa_1.pdf`, `mapa_1.pdf`, editor abre/fecha/reabre, `.lrf` intocado) —
    rodada **de dentro do projeto** (sem depender do `%TEMP%`).
- Verificação final verde (**30/10, após o pool da API**):
  - `Scripts\build_api.bat` → compila, **0 warning / 0 erro** (API reescrita).
  - `Scripts\testes\pool_api.ps1` → **POOL-TEST CONCLUIDO** (API com
    `ERP_API_POOL=3`; 40 req / 20 simultâneas = **200=40, 401=0, outros=0** nas
    duas fases — keep-alive e **TCP nova por requisição/thread nova**, que é o que
    exercita a reciclagem de vagas — e 401 sem token).
  - Desktop inalterado nesta rodada (build/testes verdes na verificação do
    Modelo I/II acima).
- Verificação final verde (**30/10, após as 4 telas de administração**):
  - `Scripts\build_desktop.bat` → compila, **0 warning / 0 erro** (2 Notes
    inofensivas: 1 pré-existente em `uFrmMapaProducao`, 1 de `Locate` Int64→Variant
    em `uFrmConfiguracoes`).
  - `Scripts\run_tests.bat` → **62/62** (58 anteriores + 4 novos de
    `uTelasAdmTest`).
  - `Scripts\testes\telas_adm_ui.ps1` → **TELAS-ADM-UI CONCLUIDO** (as 4 telas
    abrem pelo menu — IDs lidos por caption, não fixos —, têm botões, tiram
    evidência e fecham). `Scripts\dump_menu_ids.ps1` regenerado: `Mapa de Produção`
    continua = **21** (a suíte da Fase 6 segue válida); novos IDs 31/35/39/40.

### Commits do módulo Produção

| Fase | Commit |
|---|---|
| 0+1 | `fce74f7` |
| 2 | `bdad0a8` |
| 3 | `091b7f8` |
| 4 | `a3d5832` |
| 5 | `2954420` |
| 6 | `2eeb642` |
| 7 | `90fdd44` |
| 8 | `40bbd8b` |
| Modelos I/II dos relatórios | `74df45a` |
| Pool de conexões da API | `f9df7d7` |

(Anteriores, já commitados: Android `40bd164`, Módulo 1 `ea32594`, Módulo 2 `c776076`.)

---

## Modelos I e II dos relatórios (concluído em 30/10)

Pedido: no "visualizar" dos relatórios de **Talão** e **Mapa**, ter **Modelo I e
Modelo II com os mesmos links (mesmos datasets)**, para o usuário configurar como
preferir. Modelo II = cópia do Modelo I, que o usuário edita no designer LazReport.

**O que foi feito:**

- `Desktop\src\Services\uProducaoService.pas`
  - Constantes na interface: `CFG_TALAO_RELATORIO`, `CFG_TALAO_RELATORIO_M2`,
    `CFG_TALAO_MODELO`, `CFG_MAPA_MODELO` (chaves da tabela `CONFIGURACAO`).
  - Privados: `ResolverCaminhoRelatorio(configurado, arquivoPadrao)` (lógica que
    era só do talão) e `GravarChaveConfig(chave, valor, descricao)` — valor vazio
    = DELETE (restaura padrão), senão UPDATE/INSERT; **uma transação** com
    `RegistrarAuditoria` e `Confirmar`/`Cancelar`.
  - Públicos novos: `CaminhoRelatorioTalaoModelo(1|2)`,
    `DefinirCaminhoRelatorioTalaoModelo`, `CaminhoRelatorioMapaModelo(1|2)`,
    `ModeloAtivo(chave)` (ausente/inválido = 1) e
    `DefinirModeloAtivo(chave, modelo): Boolean` (**False = não gravou** → a tela
    não recarrega, evitando COMMIT à toa).
  - `CaminhoRelatorioTalao`/`DefinirCaminhoRelatorioTalao` agora **delegam ao
    Modelo I** (comportamento antigo preservado; única diferença: na *primeira*
    gravação o texto de auditoria passou a mostrar o valor cru da chave em vez do
    caminho padrão resolvido).
- `Desktop\src\Views\uFrmMapaProducao.pas`
  - `PrepararRelatorioTalaoModelo(1|2)` / `PrepararRelatorioMapaModelo(1|2)` —
    MESMOS datasets para os dois modelos: `frDBTalao`/`frDBMapa`/`qryMapaRel` são
    criados no `FormCreate` e compartilhados; só o `.lrf` carregado muda.
  - `PrepararRelatorioTalao`/`PrepararRelatorioMapa` (usados por visualizar,
    imprimir e exportar PDF) passaram a usar o **modelo ativo**.
  - `CaminhoRelatorioMapa` agora delega ao service (era caminho fixo no form).
  - `VisualizarModeloTalao/Mapa`: valida → grava o modelo ativo → se gravou chama
    `CarregarMapas` (o COMMIT invalida os cursores SQLDB) → carrega → `ShowReport`.
  - `MarcarModelosNoMenu` marca o modelo ativo antes do `PopUp` (try/except: falha
    de leitura não impede o menu de abrir).
- `Desktop\src\Views\uFrmMapaProducao.lfm` — 4 itens **puramente aditivos**:
  `Modelo I/II - visualizar talões` logo após `Visualizar talões` e
  `Modelo I/II - visualizar mapa` logo após `Relatório do mapa (visualizar)`.
  **Nenhum item existente mudou de legenda nem virou submenu**: a suíte de UI só
  enxerga itens de nível superior (MSAA no HMENU) e exige que `'(visualizar)'`,
  `'Exportar talões'`, `'mapa (exportar PDF)'` e `'abrir editor'` continuem
  ações diretas (clique que abre janela).
- `Desktop\relatorios\talao_modelo2.lrf` e `mapa_producao_modelo2.lrf` — cópias
  **byte a byte** dos Modelos I (SHA-256 idêntico); `build_desktop.bat` já copia
  `*.lrf` para `bin\relatorios`.
- `Scripts\build_tests.bat` — passou a copiar os `.lrf` também (os testes
  conferem que os 4 arquivos existem ao lado do `Tests.exe`).
- `Desktop\src\Tests\uProducaoTest.pas` — 2 testes novos:
  `TestModelosRelatorioApontamArquivosDiferentes` (nomes, arquivos distintos,
  existência) e `TestEscolhaDoModeloFicaNaConfiguracao` (round-trip na
  `CONFIGURACAO`, sem regravar quando a escolha não muda, **restauração do estado
  original no `finally`**).

**Fechado em 30/10:**

1. **Origem dos audits 134/147 esclarecida — não eram das suítes.** A suíte de UI
   (`fase6_01.ps1`) e a de unit, ambas rodadas do zero a partir de banco limpo,
   deixam `RESTOS = 0` e a auditoria estável (15 linhas, inalteradas). Eram
   cliques numa instância do `ERP2026.exe` deixada aberta pela suíte de UI (ela
   **não mata o processo** no fim — confirmado e encerrado pid 13220).
2. **Rastro removido**: as 2 chaves (`PRODUCAO_TALAO_MODELO`,
   `PRODUCAO_MAPA_MODELO`) e os audits de teste (134, 141–147, 154–157). Sobraram
   só os 3 registros legítimos de 18/10 (IDs 52/58/59 — histórico do app).
3. **Teste passou a limpar também a própria auditoria**: o `finally` de
   `TestEscolhaDoModeloFicaNaConfiguracao` apaga as chaves e as linhas de
   `LOG_SISTEMA` acima do topo capturado no início (convenção "teste não deixa
   rastro"); antes ele deixava 4 linhas por rodada.
4. **Docs**: `TESTES_EXECUTADOS.md` ganhou a seção "Modelos I e II dos relatórios
   de Talão e de Mapa (30/10/2026)" e o título foi atualizado.
5. **Verificação final verde (30/10)**: `build_desktop.bat` **0 warning / 0 erro**;
   `run_tests.bat` **58/58** (inclusive de banco limpo); `fase6_01.ps1`
   **FASE6-01 CONCLUIDO**.

**Não é desta rodada**: **itens de menu inertes** — ver "Pendências (fora do
módulo Produção)".

---

## Pool de conexões da API (concluído em 30/10)

Pendência: *"API usa conexão única → pool de conexões (produção)"*.

**O problema.** O Horse (provider `FPC.HTTPApplication`) atende cada requisição em
**thread própria** (`THTTPApplication.Threaded := True`, `TFPHTTPConnectionThread`,
com keep-alive). Com uma única `TIBConnection` para o servidor inteiro, duas
requisições simultâneas disputariam a **mesma** conexão e a **mesma** transação.

**O que foi feito:**

- `API\src\Config\uConexao.pas` reescrito: **pool com afinidade por thread** —
  cada thread de requisição recebe a **sua** `TConexao` (conexão + transação).
  `TConexaoPool` com `Obter`, `Devolver`, `LiberarThreadsMortas` e `Descricao`.
- **API pública não mudou** (`GetInstance`, `ReleaseInstance`, `Conectar`,
  `Confirmar`/`Cancelar`…) → as **6 unidades de rota (15 pontos** de
  `TConexao.GetInstance`) **não foram tocadas**.
- Conexões já saem **conectadas** (reconectam sozinhas se o Firebird reiniciar) e
  `Desconectar` faz `Rollback` antes de fechar (nada fica transação pendurada).
- **Reciclagem de vagas por thread morta** (Windows: `OpenThread` +
  `GetExitCodeThread` = `STILL_ACTIVE`): a thread keep-alive morreu → a vaga
  volta ao pool e a conexão do Firebird é fechada; sem isso o servidor esgotaria
  o pool com o tempo. Fora do Windows `ThreadViva` assume viva (`{$ELSE}` perde só
  a reciclagem, o limite continua valendo).
- **Espera em vez de compartilhar**: sem vaga livre, `Obter` espera ~5 s
  (250 × 20 ms) e só então falha apontando `ERP_API_POOL` — **nunca** entrega a
  mesma conexão a duas threads.
- Tamanho via variável de ambiente **`ERP_API_POOL`** (padrão **8**, limitada a
  2..64); o pool nasce no `initialization` e morre no `finalization`.
- `TConexao.PoolDescricao` impresso no startup (`ERP2026API.lpr`), ex.:
  `Pool de conexoes: pool=3 conexoes, 1 em uso`.
- `DevolverAtual` existe como opção, mas **nenhuma rota o chama**: a reciclagem é
  pela morte da thread — e é justamente isso que o teste comprova.

**Teste de concorrência** (`Scripts\testes\pool_api.ps1`):

1. API subida com **`ERP_API_POOL=3`** de propósito (força o caminho de espera).
2. `POST /api/login` → token.
3. **Fase 1 (keep-alive)**: 40 requisições / 20 simultâneas em `GET /api/clientes`.
4. **Fase 2 (TCP nova por requisição)**: no servidor cada request roda numa
   **thread nova** — com só 3 conexões no pool as 40 passam **só** reciclando vagas
   de thread morta.
5. `GET /api/clientes` sem token; encerra a API no fim.

**Verificação (30/10):**

- `Scripts\build_api.bat` → **0 warning / 0 erro**.
- `Scripts\testes\pool_api.ps1` → **POOL-TEST CONCLUIDO**: fase 1
  **200=40, 401=0, outros=0, exceções=0**; fase 2 idem; sem token **401**.
- **Rastro no banco: nenhum** — a API não grava em `LOG_SISTEMA` e o teste só lê.
  Conferido depois do run: `LOG_SISTEMA` = 63 linhas **todas de 18/10** (história
  legítima do módulo, incluindo os 3 audits de `CONFIGURACAO` 52/58/59) e
  `CONFIGURACAO` = só as 3 chaves de produção (os modelos seguem ausentes =
  Modelo I, que é o padrão).
- Desktop **não foi tocado** nesta rodada (build/testes verdes na verificação do
  Modelo I/II acima).

**Docs**: `TESTES_EXECUTADOS.md` ganhou a seção "Pool de conexões da API
(30/10/2026)" e o título foi atualizado.

---

## Telas de administração (concluído e commitado em 30/10 — `f746c12`)

Os 4 itens que eram inertes no menu principal foram implementados e ligados
(`OnClick`): **Financeiro ▸ Caixa**, **Sistema ▸ Configurações**,
**Sistema ▸ Permissões** e **Relatórios ▸ Central de Relatórios**.

**Services novos** (`Desktop\src\Services\`, regra de negócio fora dos forms):

- `uCaixaService.pas` — `CarregarCaixas` / `CarregarMovimentos` /
  `CarregarResumo`. **Só leitura** (o PDV é quem abre/fecha caixa);
  `SALDO`/`ENTRADAS`/`SAIDAS` usam `CAST(... AS NUMERIC(18,4))` na subconsulta
  `COALESCE` (sem isso o SQLDB devolve `ftUnknown`).
- `uConfiguracaoService.pas` — `Carregar` / `Gravar` / `Excluir` da
  `CONFIGURACAO` da empresa, com auditoria na mesma transação. **Valor vazio =
  apagar a chave** (ela volta ao padrão do código).
- `uPermissaoService.pas` — `CarregarGrupos` / `CarregarPermissoes` /
  `Gravar` (**UPSERT** por `GRUPO_ID`+`MODULO`+`TELA`, comparados em
  MAIÚSCULAS, igual ao `TemPermissao`) / `Excluir`; tudo com auditoria.

**Telas novas** (`Desktop\src\Views\`): `uFrmCaixa` (2 grades + resumo),
`uFrmConfiguracoes` (herda `TfrmCadastroBase`), `uFrmPermissoes` (matriz
grupo × tela + gates `PODE_*`), `uFrmCentralRelatorios` (`.lrf` com caminho,
modelo ativo e situação + atalho para a tela do Mapa — a **execução** do
relatório continua na tela do Mapa, porque depende do mapa selecionado).

**Permissões**: as 4 telas têm gate de **abrir** (`VISUALIZAR`) no menu e gates
de **INSERIR/EXCLUIR** nos botões de gravar/excluir da própria tela de
Permissões (`uPermissao` ganhou `MODULO_SISTEMA/TELA_CONFIGURACOES/
TELA_PERMISSOES/MODULO_FINANCEIRO/TELA_CAIXA/MODULO_RELATORIOS/
TELA_CENTRAL_RELATORIOS`). Seed em dois lugares, como no precedente do 012:
`Banco\007_initial_data.sql` (banco novo) + `Banco\013_telas_administracao.sql`
(idempotente, já executado no `DADOS.FDB`; `PERMISSAO` = 8 linhas).

**Bug visual corrigido na tela Permissões**: a grade ficava **em branco** (sem a
linha de títulos) — as colunas existiam (`cols=8`) mas a linha de títulos saía
com altura zero. Fix: colunas **persistentes no `.lfm`** (mesmo padrão da tela
do Mapa), em vez de criadas só em runtime; `ConfigurarGrid` ficou só com
`ReadOnly := True`.

**Validação (30/10)**: `build_desktop.bat` 0/0; `run_tests.bat` **62/62** (4
testes novos em `uTelasAdmTest`, que limpam todo o rastro — `LOG_SISTEMA`
voltou a 63, nenhum resíduo); `Scripts\testes\telas_adm_ui.ps1` **CONCLUIDO**
(abre as 4 telas pelo menu lendo os IDs por caption); `dump_menu_ids.ps1`
regenerado (Mapa de Produção segue = 21). Evidências em
`Documentacao\evidencias\telas_adm_0*.png`.

---

## Redesenho do layout Android — Material You (concluído e commitado em 30/10 — `d16500e`)

Pedido explícito: modernizar o visual do app Android. Escopo acordado: **só
visual** (nenhuma lógica de Activity/ViewModel/API foi tocada), direção
**Material You + cores dinâmicas**, validado com **APK + screenshots** no
emulador `Pixel_9`.

**Bases novas** (`Android\android\app\src\main\`):

- `res\values\themes.xml` + `res\values-night\themes.xml` — `Theme.Erp2026`
  sobre `Theme.Material3.DayNight` (**com** ActionBar, para os títulos das
  telas de lista continuarem aparecendo como antes), status/nav bar no tom de
  fundo.
- `res\values\colors.xml` + `res\values-night\colors.xml` — paleta estática
  (azul `#4F6BED`) com variantes clara/escura; verde/vermelho semânticos para
  o Financeiro.
- `java\...\App.java` (novo, registrado no Manifest) —
  `DynamicColors.applyToActivitiesIfAvailable`: no **Android 12+** a paleta
  inteira vem do papel de parede (Material You); abaixo do 12 fica a paleta
  estática. Nenhuma Activity foi alterada.
- `app\build.gradle` — material `1.9.0` → `1.12.0`.
- `AndroidManifest.xml` — `android:theme=@style/Theme.Erp2026` +
  `android:name=.App`.

**Os 8 layouts redesenhados** (`res\layout\`), todos com **os mesmos
`android:id`** (o Java os lê por `findViewById`; nada mudou de comportamento):

| Layout | O que mudou no visual |
|---|---|
| `activity_main` (login) | selo circular "ERP", `TextInputLayout` outlined com cantos 16dp, password toggle, botão filled 56dp |
| `activity_dashboard` | botões `MaterialButton` (1 filled + 5 tonal + "Sair" outlined vermelho), cantos 20dp |
| `activity_clientes` / `_estoque` / `_vendas` | lista dentro de `MaterialCardView` (cantos 20dp), divisores com cor do tema, "Tentar novamente" tonal |
| `activity_financeiro` | cartão de totais em `colorPrimaryContainer` (verde/vermelho semânticos) + lista em card |
| `activity_inserir_cliente` | formulário em card com `TextInputLayout` outlined (UF+CEP lado a lado) |
| `activity_consultar_clientes` | texto monoespaçado dentro de card |

**Validação (30/10)**: `Scripts\build_android.bat` → **BUILD SUCCESSFUL**;
APK instalado no emulador `Pixel_9` (login `admin`/`admin123` via API no ar);
as 8 telas abrem e listam **dados reais** da API (8 clientes, 3 produtos);
evidências em `Documentacao\evidencias\android_0*_*.png`.

---

## Redesenho em 4 abas + cadastros da fase 1 (concluído em 31/10)

Redesenho de navegação do Desktop e cadastros novos (ver
`Documentacao\DESENHO_NOVAS_ABAS.md`, a fonte do desenho).

### Banco — migração `014`

- `Banco\014_suprimentos_fiscal.sql` (+ `014_..._rollback.sql`), aplicada e
  **testada em cópia** (aplica → rollback limpo) antes de ir para o
  `DADOS.FDB` real.
  - **9 tabelas novas:** `PRODUTO_FISCAL`, `MATERIAL`, `COR`,
    `PRODUTO_FINANCEIRO`, `PEDIDO_COMPRA`(+`_ITEM`), `ESTOQUE_MATERIAL`,
    `MOVIMENTO_MATERIAL`, `MOVIMENTO_FINANCEIRO`.
  - **4 colunas aditivas:** `PRODUTO.PRODUTO_FISCAL_ID`,
    `FICHA_TECNICA.TIPO_BASE`/`ID_BASE`, `CONSUMO_MATERIAL_ITEM.STATUS_PRODUCAO`.
  - permissões de `SUPRIMENTOS`/`FINANCEIRO` (grupo 1) sem duplicar.
- **`PRODUTO` NÃO foi renomeada** — o Firebird não suporta
  `ALTER TABLE ... RENAME` (erro "Token unknown - RENAME", testado). Como
  `PRODUTO` **já é** a tabela usada em pedido/venda (produto de produção),
  mantivemos o nome físico e o `PRODUTO_PRODUCAO` ficou como nome **conceitual**
  do modelo. Aditivo apenas `PRODUTO_FISCAL_ID` — os 524 pontos de código que
  citam `PRODUTO` ficaram intactos. Registro no desenho §5.

### Código (models, services, telas, menu)

- **4 models:** `uProdutoFiscal`, `uMaterial`, `uProdutoFinanceiro`, `uCor`.
- **5 services:** `uProdutoFiscalService`, `uMaterialService`,
  `uProdutoFinanceiroService`, `uCorService` (padrão `TServiceBase`/
  `TRepositoryBase`, SQL parametrizado, auditoria via `LogOperacao`).
- **5 telas novas** (herdam `TfrmCadastroBase`, exceto Compras que é
  master-detail no padrão da `uFrmPedidoVenda`): `uFrmProdutoFiscal`,
  `uFrmMaterial`, `uFrmProdutoFinanceiro`, `uFrmMovimentoFinanceiro`,
  `uFrmCompras` (cabeçalho + itens `sgItens`, gera `PEDIDO_COMPRA`).
- **Menu reorganizado em 4 abas de negócio** (`uFrmPrincipal`): a barra começa
  por **Suprimentos · Produção · Financeiro · Fiscal**; vêm depois os utilitários
  (Cadastros, Estoque, PDV, Relatórios, IA, Sistema). Movimentos:
  - `Consumo de Materiais` → **Suprimentos**;
  - `Produto Produção` (era "Produtos" em Cadastros), `Novo Pedido`,
    `Novo Orçamento`, `Lista de Pedidos` → **Produção**;
  - `Nota de Saída` (de Vendas) e `Nota de Entrada` (de Compras) → **Fiscal**;
  - seções de topo `Compras`/`Vendas` **removidas** (conteúdo redistribuído);
  - itens novos: Materiais, Compras, Produtos Financeiros, Produto Fiscal,
    Movimentação Financeira — todos com `OnClick`.

### Verificação verde (31/10)

- `Scripts\build_desktop.bat` → compila, **0 warning / 0 erro** (só hints
  "Sender não usado" inofensivos).
- `Scripts\run_tests.bat` → **62/62** (nenhum teste quebrou; nenhum novo ainda).
- Cruzamento estático (evita crash em runtime que o compilador não pega):
  campos `.pas` × objetos `.lfm` conferem nas 6 telas mexidas; todos os
  `OnClick` do `.lfm` existem como método.
- Smoke visual em runtime **não foi capturável** neste ambiente (a janela do
  app fica em sessão/desktop isolado — `GetWindowRect` devolve 0×0); a
  confiança vem da verificação estática + build + suíte acima.

### Consumo automático no mapa (concluído em 31/10)

O consumo passou a ter duas **bases de cálculo**, escolhidas ao gerar:

- **Produzido** (padrão, manual): só os talões **CONCLUÍDOS** entram —
  comportamento antigo, preservado;
- **Planejado** (automático): usa a **quantidade planejada do item do mapa**
  (`MAPA_PRODUCAO_ITEM.QUANTIDADE`), gerando o consumo já no início da
  produção, sem depender de talão concluído.

`TProducaoService.GerarConsumoMaterial` ganhou o parâmetro opcional
`APorPlanejado: Boolean = False` (quem já chamava continua igual). A fórmula é
a mesma nos dois casos — só muda a base (numerador):

    QTD_PREVISTA = (base / QUANTIDADE_BASE) × insumo × (1 + perda%)

`base` = produzido (talões concluídos) ou planejado (item do mapa). A auditoria
passou a registrar `BASE=PLANEJADO|PRODUZIDO`. **Confirmar** (baixa no estoque)
e **Estorno** continuam iguais para as duas bases.

Na tela **Mapa de Produção → Novo Mapa** há o checkbox **"Consumo automático"**
(`chkConsumoAutomatico`, em `pnlRodapeCriar`): marcado, ao gerar o mapa o
sistema chama `GerarConsumoMaterial(..., APorPlanejado=True)` na sequência.
Falha na geração do consumo **não desfaz** o mapa já criado (só avisa).

**Verificação manual sugerida** (sem teste automatizado — a fixture de
PRODUTO/FICHA/MAPA é pesada e poderia ser frágil; anotado como follow-up):
criar um produto com ficha técnica ativa; criar um mapa com quantidade
planejada e **nenhum** talão concluído; marcar "Consumo automático"; gerar. O
`CONSUMO_MATERIAL_ITEM` deve gravar `QTD_PREVISTA = (planejada / base) × insumo
× (1 + perda)`. Repetir **sem** marcar: deve falhar com "o mapa ainda não tem
produção concluída".

### Banco da fase 1 — PRONTO (migration `015_completar_fase1.sql`)

Aplicado no `DADOS.FDB` real (backup `DADOS_backup_antes_015.fdb`), testado antes
em cópia. Build 0 erros · suíte **62/62**. Conteúdo:
- **`STATUS_PRODUCAO`** ganhou CHECK (`ABERTO`/`PARCIALMENTE_CONCLUIDO`/`CONCLUIDO`).
- **Fusão Fiscal+Financeiro** (decisão: "produto fiscal e financeiro é o mesmo"):
  `PRODUTO_FISCAL` absorveu `TIPO` (S/O) + `VALOR`; `PRODUTO_FINANCEIRO` (vazia)
  **removida**; tela de Produto Fiscal virou a única (ganhou Tipo/Valor); menu e
  build limpos.
- **Itens de nota → `PRODUTO_FISCAL`** (B2): `NOTA_ENTRADA_ITEM` + `MATERIAL_ID`
  + `PRODUTO_FISCAL_ID`; `NOTA_SAIDA_ITEM` + `PRODUTO_FISCAL_ID`.
- **Rename** `MOVIMENTO_FINANCEIRO.CONTAPRODUCAO_ID` → `CONTA_ID` (pend. 7).
- **Cadastros geográficos (novos):** `PAIS`→`ESTADO`→`CIDADE`; seed Brasil + 27 UFs.

### Pendências desta fase (próximos passos)

- **`STATUS_PRODUCAO` por talão**: a regra (recalcular a cada talão concluído) —
  coluna e CHECK prontos, falta o hook no service de bipagem/conclusão.
- **Notas lerem o `PRODUTO_FISCAL`**: colunas prontas; falta o Service preencher
  NCM/CFOP/CST/alíquotas a partir do produto fiscal vinculado.
- **Unificar CLIENTE + FORNECEDOR** (novo, decidido): tabela única com `TIPO`
  (C=cliente/F=fornecedor). **Alto risco — adiado para etapa própria:** 49 refs
  de `CLIENTE_ID`/`FORNECEDOR_ID` (NF-e, contas a receber/pagar, pedidos, API) e
  estruturas diferentes (`NOME` vs `RAZAO_SOCIAL`/`NOME_FANTASIA`/`TIPO_PESSOA`/
  `IE`). Precisa de plano detalhado + aprovação antes de mexer no núcleo fiscal.
- **CRUD de País/Estado/Cidade** (telas) + eventual vínculo em CLIENTE/FORNECEDOR
  (hoje ainda em texto).
- **Re-layout da tela de Consumo** (topo = lista de mapas + item; rodapé = grid
  dos materiais com prevista/real/custo/status).
- **Produto Produção com Cores**: expor `COR` + Ficha Técnica da Cor na tela de
  produto (`uFrmProdutos`) — models/services já prontos.
- **Compras → Nota de Entrada**: o botão Confirmar hoje só grava o pedido;
  falta gerar a `NOTA_ENTRADA` a partir dele.
- **Android** (deferido): API `POST /api/orcamentos` + bottom nav Material +
  telas.

---

## O que foi feito nas últimas rodadas (FASEs 6–8)

- **Bug "editar relatório" (reportado) — resolvido e commitado na FASE 6**: a unit
  `lr_desgn` não estava linkada — sem ela `TfrReport.DesignReport` retorna **em
  silêncio** (sem janela, sem erro). Fix: `lr_desgn` no uses de implementação de
  `uFrmMapaProducao.pas`. Editor agora abre "Designer - talao.lrf", fecha (WM_CLOSE),
  reabre, e salva no `.lrf` certo (caminho vem do `LoadFromFile`).
- **FASE 7**: `uACBrHelper.ImportarXML` (INSERT com colunas inexistentes → *Column
  unknown*) e `uServiceBase.LogOperacao` (concatenação + `USUARIO_ID=0`) passaram a
  delegar ao `uAuditoria` (parametrizado, usuário/empresa da sessão); `CAST` nos
  `COALESCE((subquery),0)` de `uCopilotoERP` (o SQLDB lia 0); 10 testes novos.
- **FASE 8**: docs (`TESTES_EXECUTADOS.md` §7, `AMBIENTE_RODANDO.md`), mapa de IDs de
  menu (`Documentacao\MAPA_IDS_MENU.md`, regenerável por `Scripts\dump_menu_ids.ps1`;
  **ID 21 = Mapa de Produção**) e regressão final completa.

---

## Onde estão as coisas

| O quê | Onde |
|---|---|
| Suíte de **UI** (autônoma) | `Scripts\testes\{erpui, fase5lib, fase6_01, fase6_pdftext}.ps1` |
| Suíte de **unit tests** | `Scripts\build_tests.bat` / `Scripts\run_tests.bat` → `Desktop\bin\Tests.exe` |
| Testes de Produção | `Desktop\src\Tests\uProducaoTest.pas` (+ `uTestRunner.pas`, `Tests.lpi`) |
| Testes das telas de administração | `Desktop\src\Tests\uTelasAdmTest.pas` (+ `uTestRunner.pas`, `Tests.lpi`) |
| Suíte de UI das telas novas | `Scripts\testes\telas_adm_ui.ps1` (abre as 4 telas pelo menu) |
| App Android (tema Material You) | `Android\android\app\src\main\res\{values,values-night}\` + `java\...\App.java` (cores dinâmicas 12+) |
| App Android (configuração por empresa) | `Android\CONFIGURACAO_POR_EMPRESA.md` + `java\...\Configuracao.java` / `ConfiguracaoActivity.java` |
| IDs de menu | `Documentacao\MAPA_IDS_MENU.md` (+ gerador `Scripts\dump_menu_ids.ps1`) |
| Evidências PNG (gitignored) | `Documentacao\evidencias\fase6_01..06_*.png`, `telas_adm_0*.png`, `android_0*_*.png` |
| PDFs gerados | `Desktop\bin\relatorios\taloes_mapa_1.pdf`, `mapa_1.pdf` |

---

## Para continuar (ao ligar o PC)

0. **Próximo marco:** nenhum item aberto no backlog — D3 (`PESSOA`), os
   filtros de Estoque/Financeiro e o botão "incluir cliente" no Android estão
   concluídos (ver §3.19/§3.20 do `PLANO_E_LOG.md`). O próximo passo é o que
   o usuário pedir.
1. Firebird 5 ativo (serviço) — o banco é `Banco\DADOS.FDB`.
2. Abrir o app: `Desktop\bin\ERP2026.exe` (login `admin` / `admin123`).
3. Build: `Scripts\build_desktop.bat` (matar `ERP2026.exe` antes, se estiver aberto).
4. Testes unit: `Scripts\run_tests.bat` → esperado **65/65**.
5. Testes UI: `powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\telas_todas_ui.ps1`
   → esperado **TELAS-DESKTOP-UI CONCLUIDO** (33/33); `... Scripts\testes\fase6_01.ps1`
   → esperado **FASE6-01 CONCLUIDO**; e
   `... Scripts\testes\telas_adm_ui.ps1`
   → esperado **TELAS-ADM-UI CONCLUIDO**.
6. Teste da API: `powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\pool_api.ps1`
   → esperado **POOL-TEST CONCLUIDO** (sobe a API com `ERP_API_POOL=3`; se a porta
   9000 estiver ocupada, mate `ERP2026API.exe` antes).
7. APK Android: `Scripts\build_android.bat` → esperado **BUILD SUCCESSFUL**
   (visual Material You — conferir no emulador `Pixel_9`; o app consome a API
   em `10.0.2.2:9000`, então a API precisa estar no ar). Para apontar para
   outro servidor/empresa, use o menu **⋮ ▸ Configuração (servidor e empresa)**
   dentro do app (ver `Android\CONFIGURACAO_POR_EMPRESA.md`).

---

## Pendências (fora do módulo Produção — próximo trabalho)

- ~~Senhas em **SHA-256**~~ — **concluído (19/10)**.
- ~~`uClienteService.pas` monta SQL com `Format` → parametrizar.~~ — **concluído (19/10)**.
- ~~`uMiddlewareJWT.pas` rotula HS256 mas usa HMAC próprio~~ **concluído (19/10)**: HS256 real em `uHMAC.pas` (HMAC-SHA256 RFC 2104, sobre `SHA256Raw`) + assinatura em tempo constante.
- ~~API usa conexão única → pool de conexões (produção).~~ — **concluído (30/10)**:
  pool com afinidade por thread em `uConexao.pas` (seção própria acima);
  `Scripts\testes\pool_api.ps1` prova 40 req / 20 simultâneas com pool de 3.
- ~~Consolidar `Banco\004_tables.sql` / `banco_simplificado.sql` vs banco real.~~ —
  **concluído (19/10)**. Gerador `Desktop\src\Tools\GerarSchema.lpr` lê o metadata
  `RDB$*` do banco real e emite `Banco\schema_canonico.sql` (34 tabelas, 34 generators,
  6 domains, 111 constraints — 34 PK + 65 NOT NULL + 12 CHECK —, 34 índices, 36 triggers).
  Validação: `Scripts\testes\schema_roundtrip.ps1` (banco novo × real → 450 campos,
  diff vazio) e `Scripts\testes\banco_fresco.ps1` (banco novo completo com sementes).
  `004_tables.sql`/`banco_simplificado.sql` ficaram marcados como `[SUPERADO]`
  (conteúdo intacto); `executar_banco.bat` passou a usar `schema_canonico.sql`
  + `007_initial_data.sql` (antes gerava só 22 das 34 tabelas).
- ~~Itens de menu inertes (sem `OnClick`): Financeiro > Caixa, Sistema > Configurações,
  Sistema > Permissões, grupo Relatórios.~~ — **concluído (30/10)**: as 4 telas foram
  implementadas e ligadas ao menu (seção própria abaixo).
- ~~Redesenhar o layout do app Android para visual mais moderno.~~ — **concluído
  (30/10)**: Material You (cores dinâmicas no 12+) + Material 3 claro/escuro,
  8 layouts redesenhados com IDs intactos (seção própria acima). Sem pendências
  abertas do usuário — o próximo passo é o que for pedido.
- ~~Android: configuração por empresa (URL do servidor + código de usuário).~~ —
  **concluído (02/11)**: commit `67d26f4`, tela `ConfiguracaoActivity`, dados em
  `SharedPreferences`, validado no emulador `Pixel_9` (ver "Estado atual da
  sessão"); uso em `Android\CONFIGURACAO_POR_EMPRESA.md`.
- ~~Encoding dos literais acentuados (`NF de saÃ­da` no `CONTA_RECEBER`).~~ —
  **concluído (02/11)**: `SetMultiByteConversionCodePage(CP_UTF8)` no app/testes,
  sem `-FcUTF8`; contorno local removido e banco sem mojibake (§3.16).

---

## Avisos e suposições (NÃO reabrir — já resolvido/decidido)

- **Nenhum pacote novo foi instalado** no Lazarus: `lazreport`/`lr_pdfexport` já
  existentes são só *requeridos* no `.lpi`; `lr_desgn` entrou por `uses`.
- **Impressora padrão permanece "Microsoft Print to PDF"** — os testes só geram PDF
  (`TlrPdfExportFilter`); nunca chamar `PrintPreparedReport` num teste.
- Erros FASE 6 já resolvidos (não investigar de novo): `TIBConnection Fetch` (datas →
  duplo `CAST(CAST(x AS DATE) AS VARCHAR(10))`), `Undefined symbol: frDBMapa."..."`
  (expressões do `.lrf` usam a query `qryMapaRel`, definida no `FormCreate`), clique em
  `Aj&uda` no SaveDialog (comparar removendo `&`), nome do arquivo do diálogo Vista
  (lê o sugerido; detecta o PDF novo por `LastWriteTime`).
- Estado do banco: 1 mapa (NUMERO 1), 4 talões todos com código de barras, seed de
  `PERMISSAO` com as 4 telas do módulo (grupo 1, tudo `S`); os testes limpam as linhas
  de `LOG_SISTEMA` que criam (0 remanescentes).
- Suposições FASEs 6–8: editor modeless (padrão LazReport); `ImportarXML` continua stub
  (só a auditoria foi corrigida); testes rodam no **mesmo** `DADOS.FDB` de desenvolvimento;
  IDs de menu estáveis para o mesmo executável (regenerar com o script se o menu mudar);
  "FASE 8" = encerramento/documentação (não havia plano persistido).
- **Transação em teste que chama um service**: o `Confirmar` do service faz `Commit`
  na `TSQLTransaction` compartilhada do singleton. Qualquer `DELETE`/`UPDATE` de
  limpeza logo depois precisa abrir transação própria (`Transaction.StartTransaction`),
  senão o SQLDB descarta o comando em silêncio e o teste deixa rastro — foi o caso
  do `TestServiceClienteApostrofo` (3 linhas de `LOG_SISTEMA` órfãs, já removidas).
