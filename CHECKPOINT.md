# CHECKPOINT — último ponto de parada (19/10/2026)

> Documento de retomada. O PC foi desligado neste ponto; ao voltar, seguir
> "Para continuar" abaixo. **ATENÇÃO: há trabalho NÃO commitado** (Modelo I/II
> dos relatórios) — ler antes a seção "Em andamento: Modelo I e Modelo II".

---

## Estado

- **Módulo de Produção: 8 fases COMPLETAS e commitadas** — última: FASE 8 = `40bbd8b`.
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

**Não é desta rodada**: **pool de conexões da API** e **itens de menu inertes** —
ver "Pendências (fora do módulo Produção)".

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
| IDs de menu | `Documentacao\MAPA_IDS_MENU.md` (+ gerador `Scripts\dump_menu_ids.ps1`) |
| Evidências PNG (gitignored) | `Documentacao\evidencias\fase6_01..06_*.png` |
| PDFs gerados | `Desktop\bin\relatorios\taloes_mapa_1.pdf`, `mapa_1.pdf` |

---

## Para continuar (ao ligar o PC)

1. Firebird 5 ativo (serviço) — o banco é `Banco\DADOS.FDB`.
2. Abrir o app: `Desktop\bin\ERP2026.exe` (login `admin` / `admin123`).
3. Build: `Scripts\build_desktop.bat` (matar `ERP2026.exe` antes, se estiver aberto).
4. Testes unit: `Scripts\run_tests.bat` → esperado **58/58**.
5. Testes UI: `powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\fase6_01.ps1`
   → esperado **FASE6-01 CONCLUIDO**.

---

## Pendências (fora do módulo Produção — próximo trabalho)

- ~~Senhas em **SHA-256**~~ — **concluído (19/10)**.
- ~~`uClienteService.pas` monta SQL com `Format` → parametrizar.~~ — **concluído (19/10)**.
- ~~`uMiddlewareJWT.pas` rotula HS256 mas usa HMAC próprio~~ **concluído (19/10)**: HS256 real em `uHMAC.pas` (HMAC-SHA256 RFC 2104, sobre `SHA256Raw`) + assinatura em tempo constante.
- API usa conexão única → pool de conexões (produção).
- ~~Consolidar `Banco\004_tables.sql` / `banco_simplificado.sql` vs banco real.~~ —
  **concluído (19/10)**. Gerador `Desktop\src\Tools\GerarSchema.lpr` lê o metadata
  `RDB$*` do banco real e emite `Banco\schema_canonico.sql` (34 tabelas, 34 generators,
  6 domains, 111 constraints — 34 PK + 65 NOT NULL + 12 CHECK —, 34 índices, 36 triggers).
  Validação: `Scripts\testes\schema_roundtrip.ps1` (banco novo × real → 450 campos,
  diff vazio) e `Scripts\testes\banco_fresco.ps1` (banco novo completo com sementes).
  `004_tables.sql`/`banco_simplificado.sql` ficaram marcados como `[SUPERADO]`
  (conteúdo intacto); `executar_banco.bat` passou a usar `schema_canonico.sql`
  + `007_initial_data.sql` (antes gerava só 22 das 34 tabelas).
- Itens de menu inertes (sem `OnClick`): Financeiro > Caixa, Sistema > Configurações,
  Sistema > Permissões, grupo Relatórios — implementar só se houver pedido.

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
