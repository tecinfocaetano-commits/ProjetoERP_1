# Desenho — Novas abas: Suprimentos, Fiscal, Financeiro e Produtos

> Status: **EM DESENHO** (aguardando validação antes da implementação)
> Origem: pedido do usuário para reorganizar o Desktop em abas/seções e criar
> cadastros de material, produto financeiro, produto fiscal e produto de produção.

---

## 1. Visão geral

Reorganizar o menu do Desktop em seções claras e criar os cadastros de item
separados por natureza, cada um com seu vínculo ao **produto fiscal (NF)**:

- **MATERIAL** — insumo comprado e consumido na produção.
- **PRODUTO_PRODUCAO** — item fabricado e usado em **pedido e venda**.
- **PRODUTO_FINANCEIRO** — serviço/outros, usado na nota e no financeiro.
- **PRODUTO_FISCAL** — classificação fiscal (NCM, CEST, CFOP, CST, alíquotas)
  referenciada pelos cadastros acima.

---

## 2. Menu Desktop (alvo) — estrutura confirmada pelo usuário

```
Aba SUPRIMENTOS (nova)
 ├─ Materiais  → cadastro com abas: Dados (comb. produto fiscal) | Ficha Técnica (do próprio material)
 ├─ Compras    → pedido de compra de materiais (gera Nota de Entrada)
 └─ Consumo de Materiais (movido de Produção)
                 → em cima: lista de mapas + item do mapa
                 → embaixo: grid com os materiais do consumo

Aba PRODUÇÃO
 ├─ Produto Produção → cadastro com abas: Dados (comb. produto fiscal) | Cores
 │                       └─ Cor → Ficha Técnica → grid de materiais (cadastrar/importar)
 ├─ Novo Pedido          ┐
 ├─ Novo Orçamento       │ já existem hoje (hoje no menu Vendas)
 ├─ Lista de Pedidos     │
 ├─ Mapa de Produção     ┐
 ├─ Bipagem de Talões    │ já existem hoje (menu Produção)
 └─ Ficha Técnica        ┘
   (Consumo de Materiais SAI daqui → vai para Suprimentos)

Aba FINANCEIRO
 ├─ Contas a Receber   ┐
 ├─ Contas a Pagar     │ já existem
 ├─ Caixa              │
 ├─ Produtos Financeiros (novo)  → serviço/outros
 └─ Produto Fiscal (novo)        → classificação fiscal NCM/CEST/CFOP/CST/alíquotas

Aba FISCAL
 ├─ Nota de Saída      ┐ movidas das abas Vendas e Compras
 ├─ Nota de Entrada    │
 └─ NF-e / NFC-e       ┘ já existia
```

Alterações de menu (resumo):
- **Nova aba Suprimentos** com Materiais + Compras + **Consumo de Materiais**.
- **Consumo de Materiais** sai de `Produção` → vai para **Suprimentos**.
- **Produto Produção + Pedido/Vendas/Orçamentos** passam para a aba **Produção**
  (saiem de `Cadastros` e `Vendas`).
- **Produto Fiscal + Produtos Financeiros** entram na aba **Financeiro**.
- **Nota de Saída** (de `Vendas`) e **Nota de Entrada** (de `Compras`) passam
  para a aba **Fiscal**.
- `Compras` deixa de ser seção de topo → vira item dentro de **Suprimentos**.
- Seção `Vendas` como topo é desmembrada (itens vão para Produção/Fiscal).

### 2.1 Consumo automático ao gerar o Mapa (novo comportamento)

**Hoje:** o consumo de materiais só é gerado **depois** que a produção conclui.
`TProducaoService.GerarConsumoMaterial` calcula pelo **produzido** (soma dos
`TALAO` com `STATUS='CONCLUIDO'`) e **aborta** com erro *"o mapa ainda não tem
produção concluída"* se não houver nada produzido.

**Novo:** ao **gerar o Mapa de Produção**, passa a haver a **opção de gerar o
consumo automático** dos materiais vinculados àquele produto de produção.
- **Onde:** *checkbox* "Gerar consumo automaticamente" na tela de criação do
  Mapa, junto do botão **Gerar Mapa**.
- **Base de cálculo (decidido):** quantidade **planejada** do item do mapa.
- O consumo baseado no **produzido** continua sendo uma **geração manual**
  posterior (na tela de Consumo), para apontar o **real**.
  - Fluxo: **planejado** (automático, no mapa) → **real** (manual, no consumo).
- Fórmula mantida: `QTD = (qtd / rendimento) × consumo × (1 + perda%)`.
- Materiais vêm da **Ficha Técnica da Cor** do produto
  (`FICHA_TECNICA.TIPO_BASE='COR'` → `FICHA_TECNICA_ITEM` → `MATERIAL`).
- Grava `CONSUMO_MATERIAL` (STATUS=`PENDENTE`) + `CONSUMO_MATERIAL_ITEM`
  (`MATERIAL_ID`, `QTD_PREVISTA`) — schema atual já comporta.

**Tela de Consumo de Materiais (re-layout):**
- Topo: lista de **mapas** + **item do mapa** selecionado.
- Rodapé: **grid com os materiais do consumo** (material, qtd prevista, real,
  custo, status).
- Ações: gerar automático (do mapa), confirmar, estornar (services existentes).

### 2.2 Status de andamento do consumo (por talão concluído)

Ao **concluir um talão**, o consumo passa a refletir o andamento da produção.

- **Onde (decidido):** novo campo em **cada item** do consumo
  (`CONSUMO_MATERIAL_ITEM`), por material — ex.: `STATUS_PRODUCAO`.
- **Valores:** `ABERTO` (nenhum talão daquele produto concluído) ·
  `PARCIALMENTE_CONCLUIDO` (alguns talões concluídos) ·
  `CONCLUÍDO` (todos os talões daquele produto concluídos).
- **Quando (decidido):** atualizado **automaticamente a cada talão concluído**
  (no service de bipagem/conclusão, recalcula o status do item de consumo
  correspondente ao produto daquele talão).
- **Não confundir** com `CONSUMO_MATERIAL.STATUS` (existente), que significa
  `PENDENTE`/`CONFIRMADO`/`ESTORNADO` (relação com estoque). O andamento de
  produção é um campo **novo e separado**.

Rastreio: talão concluído → produto do item do mapa → itens de consumo daquele
material → recalcula `QTD_REAL`/`STATUS_PRODUCAO` conforme talões concluídos ×
total de talões daquele produto.

---

## 3. Modelo de dados

### 3.1 Tabelas novas

**`PRODUTO_FISCAL`** — classificação fiscal reaproveitada por todos.
- `ID`, `EMPRESA_ID`, `DESCRICAO`, `ATIVO`, `DATA_CADASTRO`
- `NCM`, `CEST`, `CFOP`, `CFOP_VENDA`, `CFOP_COMPRA`
- `CST_ICMS`, `CST_PIS`, `CST_COFINS`
- `ALIQ_ICMS`, `ALIQ_PIS`, `ALIQ_COFINS`
- `PESO_LIQUIDO`, `PESO_BRUTO`

**`MATERIAL`** — insumo.
- `ID`, `EMPRESA_ID`, `CODIGO`, `DESCRICAO`, `UNIDADE_ID`
- **`PRODUTO_FISCAL_ID`** → combobox do vínculo fiscal
- `PRECO_CUSTO`, `CONTROLA_ESTOQUE`, `ESTOQUE_MINIMO`, `ATIVO`, `DATA_CADASTRO`

**`PRODUTO_FINANCEIRO`** — serviço / outros.
- `ID`, `EMPRESA_ID`, `CODIGO`, `DESCRICAO`
- **`TIPO`** (`S` = serviço, `O` = outros)
- **`PRODUTO_FISCAL_ID`** → combobox do vínculo fiscal
- `VALOR`, `ATIVO`, `DATA_CADASTRO`

**`PRODUTO_PRODUCAO`** — **substitui o `PRODUTO` atual** (ver §5).
- Toda a estrutura atual de `PRODUTO` (código, descrição, preços, estoque,
  unidade, categoria, fiscal) **+ `PRODUTO_FISCAL_ID`**.

**`COR`** — sub-tabela do produto de produção.
- `ID`, `EMPRESA_ID`, `PRODUTO_PRODUCAO_ID`, `NOME`, `HEX`, `ATIVO`

**`PEDIDO_COMPRA`** / **`PEDIDO_COMPRA_ITEM`** — pedido de compra de materiais.
- Cabeçalho: `FORNECEDOR_ID`, datas, `STATUS`, totais.
- Itens: `MATERIAL_ID`, qtd, preço, totais.
- Ao confirmar → **gera Nota de Entrada** (§6).

### 3.2 Tabelas alteradas

**`FICHA_TECNICA`** — ganha base genérica:
- `TIPO_BASE` (`COR` | `MATERIAL` | `FISCAL` | `PRODUCAO`)
- `ID_BASE` (id do registro dono da ficha)
- Mantém `QUANTIDADE_BASE` (rendimento) e `ATIVO`.

**`FICHA_TECNICA_ITEM`** — `MATERIAL_ID` passa a apontar para **`MATERIAL`**
(era `PRODUTO`).

**`ESTOQUE` / `MOVIMENTO_ESTOQUE`** — hoje só apontam para `PRODUTO`.
Precisam passar a referenciar também `MATERIAL` (e eventualmente
`PRODUTO_FINANCEIRO`) → **ver ponto bloqueante B1**.

**`ITEM_PEDIDO`** (`PRODUTO_ID`) → `PRODUTO_PRODUCAO_ID`.
**`NOTA_SAIDA_ITEM`** (`PRODUTO_ID`) → `PRODUTO_PRODUCAO_ID`.
**`NOTA_ENTRADA_ITEM`** (`PRODUTO_ID`) → **`MATERIAL_ID`** (compra de insumos)
→ **ver ponto bloqueante B2**.
**`MAPA_PRODUCAO_ITEM`** → `PRODUTO_PRODUCAO_ID`.

### 3.3 Hierarquia do produto de produção

```
PRODUTO_PRODUCAO ──┬── PRODUTO_FISCAL (combobox no cadastro)
                   │
                   └── [sub-tabela] COR   ← OBRIGATÓRIA (todo produto tem cor)
                            │
                            └── [sub-tabela] FICHA_TECNICA  (TIPO_BASE = 'COR')
                                      │
                                      └── GRID de MATERIAIS
                                           · cadastrar linha a linha
                                           · ou IMPORTAR vários (arquivo)
```

---

## 4. Telas novas

| Tela | Aba | Conteúdo |
|---|---|---|
| **Cadastro de Materiais** *(nova)* | Suprimentos | abas: **Dados** (combobox produto fiscal) · **Ficha Técnica** do próprio material |
| **Compras** *(nova)* | Suprimentos | pedido de compra (cabeçalho + itens de MATERIAL) → gera Nota de Entrada |
| **Produtos Financeiros** *(nova)* | Financeiro | CRUD com tipo (serviço/outros) + combobox produto fiscal |
| **Produto Fiscal** *(nova)* | Financeiro | CRUD da classificação fiscal (NCM/CEST/CFOP/CST/alíquotas) |
| **Produto Produção** *(existente `uFrmProdutos`)* | Produção | ganha combobox produto fiscal + **aba Cores** → Cor → Ficha Técnica → grid de materiais (cadastrar/importar) |

Reaproveitamento (sem mudança de comportamento, só de posição no menu):
- `uFrmNotaEntrada` (Nota de Entrada) → aba **Fiscal**.
- `uFrmNotaSaida` (Nota de Saída) → aba **Fiscal**.
- `uFrmPedido` / `uFrmOrcamento` / Lista de Pedidos → aba **Produção**.
- `uFrmConsumoMaterial`, `uFrmFichaTecnica`, Mapa, Bipagem → seguem em **Produção**.

### 4.1 Telas de Movimentação (uma por aba, tabelas diferentes)

Cada aba terá sua própria tela de movimentação, cada uma gravando em
**tabela própria** (sem tabela polimórfica):

| Tela de movimentação | Aba | Tabela(s) de movimentação |
|---|---|---|
| **Movimentação de Materiais** *(nova)* | Suprimentos | `ESTOQUE_MATERIAL` + `MOVIMENTO_MATERIAL` *(novas)* |
| **Movimentação de Produção** *(nova/ajuste)* | Produção | `ESTOQUE` + `MOVIMENTO_ESTOQUE` *(existentes, agora sobre `PRODUTO_PRODUCAO`)* |
| **Movimentação Financeira** *(nova)* | Financeiro | `MOVIMENTO_FINANCEIRO` *(nova, separada do Caixa)* |

Isso resolve os pontos **B1** e **B4**: cada aba tem sua própria tabela de
movimentação, sem nada polimórfico e sem compartilhar com o Caixa.

---

## 5. Migração `PRODUTO` → `PRODUTO_PRODUCAO`

**Decisão técnica (durante a implementação):** o **Firebird não suporta
`ALTER TABLE ... RENAME TO`** (erro "Token unknown - RENAME", confirmado em
teste real no `DADOS.FDB`). Criar uma tabela nova + copiar + dropar a antiga +
refazer trigger/índices/view seria frágil e o **oposto de enxuto**, arriscando
o app que já funciona e a suíte (62/62).

**Abordagem adotada (segura e enxuta):**
- A tabela física **`PRODUTO` é mantida** — ela **já é** a tabela usada em
  pedido/venda (ou seja, já é o produto de produção).
- `PRODUTO_PRODUCAO` passa a ser o **nome conceitual/canônico** do modelo
  (documentado), não uma tabela física separada.
- O que muda de verdade é **aditivo**: `PRODUTO` ganha `PRODUTO_FISCAL_ID`.
- Nenhum dos 524 pontos de código que referenciam `PRODUTO` é alterado.

Plano (aditivo):
1. `PRODUTO` ganha coluna `PRODUTO_FISCAL_ID` (vínculo ao produto fiscal).
2. Novas tabelas independentes: `PRODUTO_FISCAL`, `MATERIAL`, `COR`,
   `PRODUTO_FINANCEIRO`, `PEDIDO_COMPRA`, `ESTOQUE_MATERIAL`,
   `MOVIMENTO_MATERIAL`, `MOVIMENTO_FINANCEIRO`.
3. `FICHA_TECNICA` ganha `TIPO_BASE`/`ID_BASE` (base genérica).
4. `CONSUMO_MATERIAL_ITEM` ganha `STATUS_PRODUCAO` (andamento por talão).
5. Scripts `014_suprimentos_fiscal.sql` + `014_..._rollback.sql`.

---

## 6. Pontos bloqueantes (precisam de decisão)

**B1 — Estoque de materiais. RESOLVIDO.**
O usuário definiu **tabelas separadas por natureza**: materiais têm
`ESTOQUE_MATERIAL` + `MOVIMENTO_MATERIAL` próprias. `ESTOQUE` /
`MOVIMENTO_ESTOQUE` continuam para `PRODUTO_PRODUCAO`. Nada polimórfico.

**B2 — Item de nota. RESOLVIDO: notas usam o `PRODUTO_FISCAL`.**
Definição do usuário: **Nota de Entrada e Nota de Saída usam o
`PRODUTO_FISCAL`**, e esse produto fiscal deve estar **vinculado ao MATERIAL
ou ao PRODUTO** (via `PRODUTO_FISCAL_ID` que ambos já possuem).

Modelo resultante:
- Os dados fiscais da linha da nota (NCM, CFOP, CST, alíquotas) vêm do
  `PRODUTO_FISCAL`, não são copiados soltos.
- `NOTA_ENTRADA_ITEM` → identifica o **`MATERIAL_ID`** + seu
  `PRODUTO_FISCAL_ID`.
- `NOTA_SAIDA_ITEM` → identifica o **`PRODUTO_PRODUCAO_ID`** (e
  `PRODUTO_FINANCEIRO_ID` quando for serviço/outro) + seu
  `PRODUTO_FISCAL_ID`.
- O vínculo material/produto → produto fiscal resolve qual classificação
  fiscal se aplica em cada linha.

**B3 — Cores são obrigatórias. RESOLVIDO.**
Definição do usuário: **todo produto de produção tem que ter a Cor.**
A aba Cores é obrigatória; a Ficha Técnica fica dentro de cada Cor
(`TIPO_BASE = 'COR'`). Não existe ficha técnica direto no produto sem cor.

**B4 — Tabela da Movimentação Financeira. RESOLVIDO.**
Definição do usuário: **tabela nova `MOVIMENTO_FINANCEIRO`**, separada
do Caixa (`MOVIMENTO_CAIXA` continua existindo para o módulo de Caixa).

---

## 7. Suposições

- Nota de Entrada existente não muda de comportamento, só de posição no menu.
- `PEDIDO_COMPRA` é novo; hoje só existe `PEDIDO_VENDA`.
- "Produto fiscal" é um cadastro próprio (não campos dentro do produto).
- Materiais, produtos de produção e financeiros são tabelas separadas
  (decisão explícita do usuário).
- Importação de materiais da ficha técnica = arquivo (planilha/CSV).

---

## 8. Fase 2 — GRADE de tamanhos (em análise, após a fase 1)

Objetivo: tornar o sistema **opcional e funcional** para **indústrias de
calçados**, **confecções** e **comércio de vendas em geral**.

Requisitos:
- **Produto de produção** e **Material** ganham **opção de usar GRADE** (flag)
  ou não (padrão: não usa).
- Na grade, **cada tamanho pode vincular um `PRODUTO_FISCAL`**.
- Tela de **cadastro de grade** com campos: **tamanho**, **tamanho_confecao**,
  **grupo**.
- Estrutura: **tabela PAI (unidade volume)** e **tabela FILHA (a grade)**.
- A grade deve **fluir para pedido, venda e nota** (item com tamanho).

Perguntas em aberto (para a análise da fase 2):
1. O que é a **"tabela pai (unidade volume)"** — o cabeçalho/grupo da grade
   (ex.: "Calçado Adulto") e a **filha** são as linhas de tamanho?
2. Os campos **tamanho / tamanho_confecao / grupo** ficam todos na **filha**,
   ou `grupo` é o vínculo com a pai?
3. Como o **tamanho** aparece no **item de pedido/venda/nota** (coluna nova
   `TAMANHO`?) e no **estoque** (estoque por tamanho)?
4. A **grade** é uma tabela única **reaproveitada** por vários produtos
   (`GRADE_ID`) ou cada produto tem sua grade própria?

Implicações de schema (migration própria, fase 2 — fora da fase 1):
- Novas tabelas `GRADE` (pai) e `GRADE_ITEM` (filha).
- Colunas novas em `PRODUTO_PRODUCAO` e `MATERIAL` (`USA_GRADE`, `GRADE_ID`).
- `GRADE_ITEM.PRODUTO_FISCAL_ID` (vínculo fiscal por tamanho).
