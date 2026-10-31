# CHECKPOINT — último ponto de parada (19/10/2026)

> Documento de retomada. O PC foi desligado neste ponto; ao voltar, seguir
> "Para continuar" abaixo. Árvore git **limpa** (nada pendente de commit).

---

## Estado

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
- **Redesenho do layout Android (Material You) concluído (30/10)**: tema
  Material 3 com cores dinâmicas (Android 12+) + paleta estática claro/escuro
  como fallback; 8 layouts redesenhados com IDs intactos — seção própria abaixo
  + `TESTES_EXECUTADOS.md`.
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

## Redesenho do layout Android — Material You (concluído em 30/10)

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
| IDs de menu | `Documentacao\MAPA_IDS_MENU.md` (+ gerador `Scripts\dump_menu_ids.ps1`) |
| Evidências PNG (gitignored) | `Documentacao\evidencias\fase6_01..06_*.png`, `telas_adm_0*.png`, `android_0*_*.png` |
| PDFs gerados | `Desktop\bin\relatorios\taloes_mapa_1.pdf`, `mapa_1.pdf` |

---

## Para continuar (ao ligar o PC)

1. Firebird 5 ativo (serviço) — o banco é `Banco\DADOS.FDB`.
2. Abrir o app: `Desktop\bin\ERP2026.exe` (login `admin` / `admin123`).
3. Build: `Scripts\build_desktop.bat` (matar `ERP2026.exe` antes, se estiver aberto).
4. Testes unit: `Scripts\run_tests.bat` → esperado **62/62**.
5. Testes UI: `powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\fase6_01.ps1`
   → esperado **FASE6-01 CONCLUIDO**; e
   `powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\telas_adm_ui.ps1`
   → esperado **TELAS-ADM-UI CONCLUIDO**.
6. Teste da API: `powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\pool_api.ps1`
   → esperado **POOL-TEST CONCLUIDO** (sobe a API com `ERP_API_POOL=3`; se a porta
   9000 estiver ocupada, mate `ERP2026API.exe` antes).
7. APK Android: `Scripts\build_android.bat` → esperado **BUILD SUCCESSFUL**
   (visual Material You — conferir no emulador `Pixel_9`; o app consome a API
   em `10.0.2.2:9000`, então a API precisa estar no ar).

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
