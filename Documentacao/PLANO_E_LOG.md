# PLANO E LOG DE DESENVOLVIMENTO — ERP 2026

> Documento **vivo**: registra o planejamento, as decisões do usuário e o que já
> foi executado. Atualizar a cada etapa concluída.
> Última atualização: 31/10/2026

---

## 1. Decisões do usuário (não reabrir)

| # | Decisão | Data | Situação |
|---|---|---|---|
| D1 | Produto **fiscal e financeiro é o mesmo** → uma tabela só (`PRODUTO_FISCAL` absorve `TIPO`/`VALOR`; `PRODUTO_FINANCEIRO` removida) | 31/10 | ✅ executado (015) |
| D2 | Criar cadastro de **País → Estado → Cidade** (globais, sem empresa) | 31/10 | ✅ banco (015) · 🔨 telas em andamento |
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
| 1 | **Consertar telas geográficas** (País/Estado/Cidade) e voltar build/suíte ao verde | 🔨 **em andamento** | build estava quebrado (assinaturas de `InserirParam`, falta `uFrmCidade`, `.lfm`, colunas `SIGLA`×`CODIGO`/`UF`) |
| 2 | Migração `016` **GRADE**: `GRADE` + `GRADE_TAMANHO`, `PRODUTO.GRADE_ID`, `ITEM_PEDIDO_GRADE`, `MAPA_PRODUCAO_ITEM_GRADE`, config `USA_GRADE` | ✅ concluído (31/10) | aplicada no `DADOS.FDB` real (backup `DADOS_backup_antes_016.fdb`); testada em cópia (aplica→rollback) |
| 3 | Tela de cadastro de GRADE (master + tamanhos) | ✅ concluído (31/10) | D5 |
| 4 | GRADE no item do pedido + subgrid editável no mapa, sob `USA_GRADE` | ✅ concluído (31/10) | D6/D7 |
| 5 | Notas lerem `PRODUTO_FISCAL` (NCM/CFOP/CST/alíquotas no service) | 📋 pendente | colunas prontas (015) |
| 6 | Re-layout da tela de Consumo | 📋 pendente | |
| 7 | Produto Produção com Cores (expor `COR`) | 📋 pendente | services prontos |
| 8 | Compras → gerar Nota de Entrada na confirmação | 📋 pendente | |
| 9 | Vínculo geo (país/estado/cidade) em CLIENTE/FORNECEDOR | 📋 pendente | depende do item 1 |
| 10 | Unificação CLIENTE+FORNECEDOR | ⏸ adiado | D3 |
| 11 | Android: orçamentos + telas | ⏸ deferido | |
| 12 | **Android: tela de configuração por empresa** — caminho do servidor (URL da API) + código de usuário, salvos **separadamente por empresa** (cada empresa tem a sua configuração) | 📋 pendente | D9 — fazer depois dos itens acima |

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

---

## 4. Convenções e avisos (não reabrir)

- Firebird 5: **não** renomeia tabela/coluna (`ALTER ... RENAME`) — usar ADD+cópia+DROP.
- Sem FKs reais; integridade no Service; generators `GEN_X_ID`; triggers `TRG_X_BI`/`BU`.
- Migrações numeradas, `SET ECHO ON`; acentos exigem `SET NAMES UTF8`.
- Tabelas geográficas são **globais** (sem `EMPRESA_ID`).
- `PRODUTO` é o produto de produção (nome físico mantido; `PRODUTO_PRODUCAO` é conceitual).
- `PRODUTO_FINANCEIRO` não existe mais.
- Android: preservar todos os `android:id`.
