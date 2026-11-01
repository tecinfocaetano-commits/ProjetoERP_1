# PLANO E LOG DE DESENVOLVIMENTO — ERP 2026

> Documento **vivo**: registra o planejamento, as decisões do usuário e o que já
> foi executado. Atualizar a cada etapa concluída.
> Última atualização: 01/11/2026

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
| D9 | **Android: configuração por empresa** — tela onde o usuário define o **caminho do servidor** (URL da API) e o **código de usuário**; cada empresa usada guarda a sua própria configuração de servidor + usuário | 31/10 | 📋 pendente (executar após os itens do backlog atual) |

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
| 10 | Unificação CLIENTE+FORNECEDOR | ⏸ adiado | D3 |
| 11 | Android: orçamentos + telas | ⏸ deferido | |
| 12 | **Android: tela de configuração por empresa** — caminho do servidor (URL da API) + código de usuário, salvos **separadamente por empresa** (cada empresa tem a sua configuração) | 📋 pendente | D9 — prompt pronto em `Documentacao\BACKLOG_ANDROID.md` |
| 13 | Regenerar `Banco\schema_canonico.sql` (está anterior à `015`: sem `PAIS`, `CIDADE_ID`, `GRADE`, `ESTOQUE_MATERIAL`) | 📋 pendente | usar `Desktop\src\Tools\DumpSchema.lpr` para conferir o round-trip |
| 14 | **Encoding dos literais acentuados** — o fonte é UTF-8, mas o projeto compila sem `-FcUTF8`: o FPC etiqueta o literal como CP1252 e o SQLDB reconverte os bytes (grava `NF de saÃ­da`). Contornado na descrição da conta a receber (`AsUTF8String` + `SetCodePage`); os demais literais ainda dependem disso | 📋 pendente (precisa decisão) | corrigir de vez com `-FcUTF8` gera **213 warnings** 4104/4105 (mistura de AnsiString/UnicodeString) — decidir entre suprimir por unit ou manter o contorno local |

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

**Parada de sessão:** o checkpoint detalhado está em `CHECKPOINT.md` →
"Estado atual da sessão".

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

---

## 4. Convenções e avisos (não reabrir)

- Firebird 5: **não** renomeia tabela/coluna (`ALTER ... RENAME`) — usar ADD+cópia+DROP.
- Sem FKs reais; integridade no Service; generators `GEN_X_ID`; triggers `TRG_X_BI`/`BU`.
- Migrações numeradas, `SET ECHO ON`; acentos exigem `SET NAMES UTF8`.
- Tabelas geográficas são **globais** (sem `EMPRESA_ID`).
- `PRODUTO` é o produto de produção (nome físico mantido; `PRODUTO_PRODUCAO` é conceitual).
- `PRODUTO_FINANCEIRO` não existe mais.
- Android: preservar todos os `android:id`.
