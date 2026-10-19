# CHECKPOINT — último ponto de parada (19/10/2026)

> Documento de retomada. O PC foi desligado neste ponto; ao voltar, seguir
> "Para continuar" abaixo. Árvore git **limpa** (nada pendente de commit).

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
- Verificação final verde:
  - `Scripts\build_desktop.bat` → compila.
  - `Scripts\build_api.bat` → compila.
  - `Scripts\run_tests.bat` → **54/54** (39 base + 10 Produção + 4 SHA-256 + 1 serviço de clientes).
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
4. Testes unit: `Scripts\run_tests.bat` → esperado **54/54**.
5. Testes UI: `powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\fase6_01.ps1`
   → esperado **FASE6-01 CONCLUIDO**.

---

## Pendências (fora do módulo Produção — próximo trabalho)

- ~~Senhas em **SHA-256**~~ — **concluído (19/10)**.
- ~~`uClienteService.pas` monta SQL com `Format` → parametrizar.~~ — **concluído (19/10)**.
- `uMiddlewareJWT.pas` rotula HS256 mas usa HMAC próprio → HS256 real (ou remover rótulo).
- API usa conexão única → pool de conexões (produção).
- Consolidar `Banco\004_tables.sql` / `banco_simplificado.sql` vs banco real.
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
