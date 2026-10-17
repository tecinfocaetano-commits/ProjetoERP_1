# Módulo Produção — FASE 0: Reconhecimento

Data: 17/10/2026
Escopo: reconhecimento do projeto antes de implementar o Mapa de Produção, Talões,
Bipagem e Consumo de Materiais. **Nenhum código foi alterado nesta fase.**

---

## 1. Stack e padrões encontrados

| Item | Resposta |
|---|---|
| Banco | **Firebird 5.0** (`Banco\DADOS.FDB`, UTF8, SYSDBA/masterkey) |
| Acesso a dados | **SQLDB** (`TIBConnection` + `TSQLTransaction` + `TSQLQuery`) |
| Camadas | `Models` (entidades), `Repositories`, `Services`, `Views`, `Utils`, `Config` |
| Conexão | `Config\uConexao.pas` — singleton `TConexao.GetInstance`, com `IniciarTransacao` / `Confirmar` / `Cancelar` |
| Sessão | `Utils\uSessao.pas` — singleton `TSessao.GetInstance` (`UsuarioId`, `EmpresaId`, `Administrador`, `GrupoId`) |
| Build | `Scripts\build_desktop.bat` (lazbuild, i386-win32, `Desktop\bin\ERP2026.exe`) |
| Pacotes do projeto | `SQLDBLaz` + `LCL` **apenas** |
| Scripts de banco | `Banco\001..011_*.sql` — aditivos, numerados, terminator `^`, application via isql |
| Versionamento | git; `.gitignore` ignora `bin/`, `*.exe`, `*.FDB` |

### Padrão real de código (importante)
Existem duas gerações de código no projeto:

1. **Gen 1 (`Models` + `Repositories` + `ServiceBase`)** — `uModelBase`, `uPedidoVenda`,
   `uRepositoryBase`, `uClienteService`… **só o `uClienteService` usa de fato**; as telas
   não utilizam essa camada.
2. **Gen 2 (`Services` + `Views`, SQLDB direto)** — é o padrão dos módulos mais novos e
   completos: `uNotaEntradaService`/`uFrmNotaEntrada` e `uNotaSaidaService`/`uFrmNotaSaida`.

**Decisão:** a Produção seguirá a **Gen 2** (a mesma dos módulos 1 e 2), que é o padrão
vigente e testado:
- `Service` concentra regras, validações e **transação** (try/except + Confirmar/Cancelar);
- `View` só monta tela, valida campos e chama o Service (SELECTs de grid ficam na View,
  como nos módulos 1 e 2 — nenhuma **regra de negócio** em evento de formulário);
- SQL sempre **parametrizado**; `Free` em try/finally.

---

## 2. Tabelas existentes relevantes

| Tabela | Colunas principais |
|---|---|
| `PEDIDO_VENDA` | ID, EMPRESA_ID, CLIENTE_ID, NUMERO, DATA_EMISSAO, DATA_ENTREGA, **STATUS CHAR(1)**, SUBTOTAL, DESCONTO, ACRESCIMO, TOTAL, FORMA_PAGAMENTO_ID, CONDICAO_PAGAMENTO_ID, NUMERO_NFE, CHAVE_NFE, OBSERVACOES, USUARIO_ID |
| `ITEM_PEDIDO` | ID, PEDIDO_VENDA_ID, PRODUTO_ID, QUANTIDADE, PRECO_UNITARIO, VALOR_UNITARIO, DESCONTO, ACRESCIMO, VALOR_TOTAL, CFOP, CST_ICMS, ALIQ_ICMS, VALOR_ICMS |
| `PRODUTO` | ID, EMPRESA_ID, CATEGORIA_ID, UNIDADE_ID, CODIGO, CODIGO_BARRAS, DESCRICAO, PRECO_CUSTO, PRECO_VENDA, ESTOQUE_MINIMO/MAXIMO, CONTROLA_ESTOQUE, NCM, CEST, CFOP/CFOP_VENDA/CFOP_COMPRA, CST_ICMS/PIS/COFINS, ALIQ_*, ATIVO, FORNECEDOR_ID, PESO_BRUTO/LIQUIDO |
| `ESTOQUE` | ID, EMPRESA_ID, PRODUTO_ID, QUANTIDADE, QUANTIDADE_MINIMA/MAXIMA, LOCALIZACAO, CUSTO_MEDIO, DATA_ATUALIZACAO |
| `MOVIMENTO_ESTOQUE` | ID, EMPRESA_ID, PRODUTO_ID, **TIPO CHAR(1)** (‘E’ entrada, ‘S’ saída, ‘A’ ajuste), QUANTIDADE, CUSTO_UNITARIO, DOCUMENTO, DATA_MOVIMENTO (DATE), OBSERVACAO, USUARIO_ID |
| `USUARIO` | ID, EMPRESA_ID, GRUPO_ID, LOGIN, SENHA, NOME, EMAIL, **ADMINISTRADOR CHAR(1)**, ATIVO |
| `GRUPO` | ID, NOME, DESCRICAO, ATIVO |
| `PERMISSAO` | ID, GRUPO_ID, MODULO, TELA, PODE_VISUALIZAR, PODE_INSERIR, PODE_EDITAR, PODE_EXCLUIR, PODE_IMPRIMIR (todos CHAR(1)) |
| `LOG_SISTEMA` | ID, EMPRESA_ID, USUARIO_ID, TABELA, OPERACAO, REGISTRO_ID, DADOS_ANTERIORES VARCHAR(255), DADOS_NOVOS VARCHAR(255), DATA_HORA, DATA_OPERACAO, IP_ORIGEM |
| `CONFIGURACAO` | ID, EMPRESA_ID, CHAVE, VALOR, DESCRICAO |
| `EMPRESA` | ID, RAZAO_SOCIAL, NOME_FANTASIA, CNPJ, IE, IM, ENDERECO, NUMERO, BAIRRO, CIDADE, UF, CEP, CRT, REGIME_TRIBUTARIO, LOGO |
| `UNIDADE` | ID, NOME, SIGLA, ABREVIATURA, ATIVO |

**Total: 30 tabelas.** Não existem *chaves estrangeiras* no banco (nem CHECKs de status) —
o padrão atual é integridade garantida na aplicação + índices.

### Trigger de estoque (reaproveitado pela Produção)
`TRG_MOVEST_AI` (BEFORE INSERT em `MOVIMENTO_ESTOQUE`): grava `ESTOQUE` somando quando
`TIPO` = ‘E’/‘A’ e **subtraindo** quando ‘S’; cria a linha de `ESTOQUE` se não existir e
**não impede saldo negativo** (a validação de saldo é do Service).

---

## 3. Existe Ficha Técnica?

**Não.** Não há `FICHA_TECNICA`, `MAPA_PRODUCAO`, `TALAO`, `BIPAGEM`, `CONSUMO*`
nem qualquer referência a produção/fabricação no banco ou no código
(grep por FICHA_TECNICA|ORDEM_PRODUCAO|MAPA_PRODUCAO|TALAO|BIPAGEM → 0 resultados).

Os arquivos `simulacao_producao.sql` / `SIMULACAO_PRODUCAO_COMPLETA.md` da raiz são
**simulações antigas de ambiente** (e usam colunas que não existem mais: `DATA_PEDIDO`,
`ITEM_PEDIDO_VENDA`, `PRODUTO.ESTOQUE`) — não são modelo de manufatura.

**Proposta de modelo (Fase 1)** — ver seção 7.

---

## 4. Como o status do pedido é controlado hoje

`PEDIDO_VENDA.STATUS` é **CHAR(1)** e gravado direto, sem máquina de estados:

| Código | Significado | Quem grava |
|---|---|---|
| `P` | Pendente | `uFrmPedidoVenda` (INSERT **fixo** em `'P'`) |
| `A` | Aprovado | legado (não há ação de aprovar na tela) |
| `F` | Faturado | `uNotaSaidaService.Faturar` |
| `C` | Cancelado | (nenhum fluxo ativo) |

A descrição do código está duplicada em 4 lugares (`uFrmListaPedidos`, `uFrmNFe`,
`uFrmNotaSaida`, `uNotaSaidaService`).

### Proposta para os novos status
O pedido precisa de **Em Produção** e **Produzido**. Duas opções:

- **Opção A (escolhida):** manter `CHAR(1)` e usar `E` = Em Produção e `D` = Produzido.
  Novos códigos não quebram os existentes (`CASE ... ELSE` já trata desconhecido).
  - *Prós:* zero DDL, zero risco no que já funciona.
  - *Contra:* código de uma letra.
- **Opção B:** alargar `STATUS` para `VARCHAR(15)` e usar `EM_PRODUCAO`/`PRODUZIDO`.
  - *Prós:* legível.
  - *Contra:* exige tocar todos os pontos que hoje comparam `'P'/'A'/'F'/'C'`
    (telas, services, PDV, NF-e, Android, API) — risco de quebra.

**Fluxo completo proposto:** `P` → `E` (mapa criado) → `D` (todos os talões concluídos)
→ `F` (nota de saída faturada) → `C` (cancelado). A validação ficará em
`Models\uPedidoStatus.pas` (máquina de estados com transições válidas e inválidas bloqueadas).

---

## 5. Relatórios (LazReport)

- **Não existe nenhum relatório no projeto**: nenhum arquivo `.lrf`, nenhuma referência a
  `TfrReport`/`TfrDBDataSet`, nenhum código de impressão. O item de menu **Relatórios**
  existe mas **sem handler**.
- Portanto **não há padrão de relatório para reaproveitar** — a Produção criará o primeiro
  padrão (que depois serve para as notas).
- Os pacotes estão **disponíveis na instalação do Lazarus**, porém **não instalados no projeto**:
  - `C:\lazarus\components\lazreport\source\lazreport.lpk`
  - `C:\lazarus\components\lazreport\source\addons\lrFclPDFExport\lr_pdfexport.lpk`
    (contém `TlrPDFExport`, PDF nativo via fcl-pdf) → **filtro PDF disponível**.
- **Ponto de atenção:** será necessário acrescentar `lazreport` (e `lrFclPDFExport`) aos
  *pacotes requeridos* do `Desktop\ERP2026.lpi`. Isso altera o `.lpi` (não instala nada
  fora do Lazarus). Farei isso na Fase 3 (os talões em Code128 exigem LazReport) e valido
  o build imediatamente; se o lazbuild não resolver o pacote, aviso antes de prosseguir.

---

## 6. Auditoria e permissões (já existem, mas não são usadas)

- `PERMISSAO` (GRUPO_ID + MODULO + TELA + PODE_*) **não é consultada em nenhum lugar** do
  código. A única checagem hoje é `TSessao.Administrador`.
- `LOG_SISTEMA` é gravado só em `uServiceBase.LogOperacao` (não usado por nenhum service) e
  em `uACBrHelper`.

### Bugs/observações encontrados (proponho corrigir neste módulo)
1. **`uACBrHelper.ImportarXML` grava em `LOG_SISTEMA` colunas inexistentes**
   (`MODULO`, `ACAO`, `DESCRICAO`): qualquer chamada estoura *Column unknown*. A tabela tem
   `TABELA`, `OPERACAO`, `DADOS_ANTERIORES`, `DADOS_NOVOS`.
2. **`uServiceBase.LogOperacao` concatena strings no SQL** (viola “queries parametrizadas”)
   e grava `USUARIO_ID = 0` (TODO) e `EMPRESA_ID` do `Connection.Tag`.
3. **`uFrmListaPedidos`**: o combo de status oferece “Pendente/Aberto/Cancelado” mas o
   `case` mapeia 5 posições (`P/A/F/C`) para 4 itens — o filtro *Cancelado* é inalcançável e
   “Aberto” no rótulo é “Aprovado” no código.

**Plano:** criar `Utils\uAuditoria.pas` (INSERT parametrizado em `LOG_SISTEMA` com
`TSessao`, truncando em 255) e `Utils\uPermissao.pas` (checa `PERMISSAO` do grupo do usuário,
com *bypass* para `ADMINISTRADOR = 'S'`), corrigir os itens 1 e 2 e ajustar o item 3.

---

## 7. Proposta de modelo de dados (Fase 1)

Script novo: **`Banco\012_producao.sql`** (aditivo, no padrão do 010/011).
Padrões adotados: `ID BIGINT PK` + generator + trigger `BI`; `NUMERIC(15,4)` para
quantidades/valores; `TIMESTAMP` para eventos; índices em todas as colunas de ligação;
`CHECK` de status; `UNIQUE (EMPRESA_ID, NUMERO)` onde há numeração.
**Sem FKs** (para manter a convenção do banco) — integridade garantida no Service.

### 7.1 Ficha técnica
- **`FICHA_TECNICA`**: ID, EMPRESA_ID, PRODUTO_ID (produto fabricado), DESCRICAO,
  QUANTIDADE_BASE (rendimento da receita, default 1), ATIVO, OBSERVACOES, USUARIO_ID,
  DATA_CADASTRO, DATA_ATUALIZACAO. `UNIQUE (EMPRESA_ID, PRODUTO_ID)`.
- **`FICHA_TECNICA_ITEM`**: ID, FICHA_TECNICA_ID, MATERIAL_ID (produto insumo), QUANTIDADE
  (por QUANTIDADE_BASE), PERDA_PERCENTUAL, OBSERVACOES.

### 7.2 Mapa de produção
- **`MAPA_PRODUCAO`**: ID, EMPRESA_ID, NUMERO (integer sequencial), PEDIDO_VENDA_ID, STATUS,
  DATA_CRIACAO, DATA_PREVISTA, DATA_INICIO, DATA_FIM, OBSERVACAO, USUARIO_ID,
  MOTIVO_CANCELAMENTO, DATA_CANCELAMENTO.
  `UNIQUE (EMPRESA_ID, NUMERO)`. Status: `ABERTO`, `EM_PRODUCAO`, `CONCLUIDO`, `CANCELADO`.
- **`MAPA_PRODUCAO_ITEM`**: ID, MAPA_PRODUCAO_ID, ITEM_PEDIDO_ID, PRODUTO_ID, QUANTIDADE,
  STATUS, OBSERVACAO. Status: `PENDENTE`, `EM_PRODUCAO`, `CONCLUIDO`, `CANCELADO`.
  O mesmo item do pedido pode aparecer em vários mapas (produção **parcial**); o Service
  valida `soma(mapeado) + novo <= ITEM_PEDIDO.QUANTIDADE`.

### 7.3 Talões e bipagem
- **`TALAO`**: ID, EMPRESA_ID, NUMERO (integer, único por empresa), MAPA_PRODUCAO_ITEM_ID,
  SEQUENCIA, QUANTIDADE, CODIGO_BARRAS (Code128), STATUS, DATA_GERACAO, DATA_IMPRESSAO,
  DATA_INICIO, DATA_CONCLUSAO, DATA_CANCELAMENTO, QTD_IMPRESSOES, USUARIO_ID, OBSERVACAO.
  Status: `GERADO`, `IMPRESSO`, `EM_PRODUCAO`, `CONCLUIDO`, `CANCELADO`.
- **`TALAO_BIPAGEM`**: ID, TALAO_ID, USUARIO_ID, DATA_HORA, ETAPA, ORIGEM, RESULTADO,
  OBSERVACAO. `RESULTADO` = `OK` / `DUPLICADO` / `INVALIDO` (bipagem idempotente + log de
  reimpressão em `ETAPA`).

### 7.4 Consumo de materiais
- **`CONSUMO_MATERIAL`**: ID, EMPRESA_ID, MAPA_PRODUCAO_ID, DATA_CONSUMO, STATUS,
  JUSTIFICATIVA, OBSERVACAO, USUARIO_ID, DATA_CONFIRMACAO, DATA_ESTORNO, USUARIO_ESTORNO_ID.
  Status: `PENDENTE`, `CONFIRMADO`, `ESTORNADO`.
- **`CONSUMO_MATERIAL_ITEM`**: ID, CONSUMO_MATERIAL_ID, MATERIAL_ID, QTD_PREVISTA, QTD_REAL,
  CUSTO_UNITARIO, **MOVIMENTO_ESTOQUE_ID**, OBSERVACAO.
  *Decisão:* o vínculo com `MOVIMENTO_ESTOQUE` fica **no item** (cada material gera o seu
  próprio movimento de saída), e não no cabeçalho como no esboço da especificação.

### 7.5 Configurações e permissões
- `CONFIGURACAO`: `PRODUCAO_TALAO_MODO` (ITEM|UNIDADE|LOTE) e `PRODUCAO_TALAO_LOTE` (n),
  `PRODUCAO_PERMITE_ESTOQUE_NEGATIVO` (S/N).
- `PERMISSAO`: registros `MODULO='PRODUCAO'` / `TELA` = `MAPA_PRODUCAO`, `TALAO`, `BIPAGEM`,
  `CONSUMO` para o grupo do administrador.

### 7.6 Numeração
Generators próprios: `GEN_FICHA_TECNICA_ID`, `GEN_FICHA_TECNICA_ITEM_ID`,
`GEN_MAPA_PRODUCAO_ID`, `GEN_MAPA_PRODUCAO_ITEM_ID`, `GEN_TALAO_ID`,
`GEN_TALAO_BIPAGEM_ID`, `GEN_CONSUMO_MATERIAL_ID`, `GEN_CONSUMO_MATERIAL_ITEM_ID`.
Número do mapa/talão = `MAX+1` por empresa **dentro da transação** (evita duplicidade) com
o `UNIQUE` como rede de segurança.

---

## 8. Suposições (para confirmar)

1. **Produção é por pedido de venda** (não por estoque): o mapa nasce de um `PEDIDO_VENDA`,
   permitindo itens e quantidades **parciais**.
2. Um pedido pode ter **vários mapas** (produção em etapas); só vira `D` (Produzido) quando
   não houver mais saldo pendente.
3. **Talão = 1 linha de `TALAO`**; a bipagem conclui o talão. Quantidade por talão é
   configurável (item / unidade / lote).
4. O produto **fabricado** é identificado por possuir `FICHA_TECNICA` (não criei campo novo
   em `PRODUTO`).
5. Consumo de materiais é **por mapa** (não por talão) e usa `MOVIMENTO_ESTOQUE` ‘S’,
   mantendo o custo médio pelo mesmo trigger dos módulos 1 e 2.
6. Baixa de estoque bloqueia saldo negativo, com exceção liberável por configuração
   (`PRODUCAO_PERMITE_ESTOQUE_NEGATIVO`) — conforme “permissão especial, configurável”.
7. Relatórios só com **LazReport** (barcode Code128 e PDF pelo `TlrPDFExport`).

## 9. Itens de “capricho” que já vou corrigir
- bug do `LOG_SISTEMA` no `uACBrHelper`;
- `uServiceBase.LogOperacao` parametrizado e com usuário da sessão;
- filtro de status do `uFrmListaPedidos` (5 rótulos × 4 códigos);
- rótulos/descrições de status centralizados (hoje duplicados em 4 telas).
