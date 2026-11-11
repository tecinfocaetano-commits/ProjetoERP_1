# CHECKPOINT — último ponto de parada (10/11/2026)

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
   (deve dar **366/366**). Ruído conhecido: `InitializeFppkg failed`.
   Para o Android: `Scripts\run_tests_android.bat` (deve dar **5/5**).
5. Executar o **Próximo passo** e atualizar este arquivo ao fechar cada marco.

Regras do projeto: português; regra de negócio em Services; SQL sempre
parametrizado; transação + auditoria (`LogOperacao`); LazReport apenas;
Firebird: **31 chars** por identificador e `DEFAULT` **antes** de `NOT NULL`;
**todo commit de marco deve ser seguido de `git push`** para `origin`
(GitHub privado — `tecinfocaetano-commits/ProjetoERP_1`).

---

## Estado atual da sessão (10/11/2026)

**HEAD:** `eceb35c` — "NFe: integracao real com ACBr (modo simulado preservado)".
Árvore: limpa (o commit de docs deste marco vem logo acima). Build: desktop
**0/0** · suíte desktop **366/366** · API compilada
(`Scripts\build_api.bat`) · testes Android **5/5** (inalterados).

> Se `git log -1` mostrar um hash diferente, o disco vence, como sempre.

### Em andamento (não commitado)

- Nada.

### O que fechou nesta sessão (marco 3.55 — integração real da NF-e)

| Item | Entrega |
|---|---|
| **ACBr instalado** | Clone em `C:\ACBr`; pacotes `ideintf`, `laz_synapse`, `PCNComum`, `ACBrComum`, `ACBrOpenSSL`, `ACBrDiversos`, `ACBrTCP`, `ACBrSerial`, `ACBr_Integrador`, `ACBrDFeComum` e `ACBr_NFe` compilados com `lazbuild`; `ACBr_NFe` registrado no Lazarus. |
| **Helper real** | `uACBrHelper` ganhou `ModoSimulado` (padrão `True`, preserva os testes), `CaminhoSchemas`, `CaminhoSalvar`, `IdCSC`/`CSC` e, sob `{$IFDEF ACBR}`, `EmitirReal`/`ConsultarReal`/`CancelarReal`/`ManifestarReal`. Emissão mapeia empresa/cliente/itens (NCM, CEST, CFOP, CST/CSOSN, alíquotas, pesos, unidade, cidade IBGE), valida dados fiscais com mensagens claras, calcula ICMS/PIS/COFINS e totais, envia síncrono (`Enviar(1, False, True)`) e só persiste/audita após autorização (`cStat` 100/150). Consulta/cancelamento/manifestação usam a chave de 44 dígitos e o protocolo obtido na consulta. |
| **Tela** | `uFrmNFe` ganhou `chkSimulado` (desmarcado = modo real), UF lida de `EMPRESA`, paths `bin\schemas`/`bin\nfe`, senha do certificado via `InputQuery` e `FormDestroy` com `FreeAndNil(FACBr)`. Em simulação, passa certificado/senha fictícios para satisfazer `ValidarConfiguracao`. |
| **Projeto/recursos** | `ERP2026.lpi` com `ACBr_NFe` em `RequiredPackages` e `-dACBR`; `Tests.lpi` sem ACBr e com saída própria (`lib/tests/...`) para não reutilizar o `.ppu` do desktop. `Scripts\preparar_acbr.bat` copia schemas (`C:\ACBr\Exemplos\ACBrDFe\Schemas\NFe`) e DLLs x86 (OpenSSL/LibXml2) para `Desktop\bin`. |
| **Validação** | Build desktop **0/0**, suíte **366/366**, banco sem resíduos. Emissão real contra a SEFAZ depende de certificado A1 válido e de dados fiscais/endereço preenchidos em `EMPRESA`, `PESSOA` e `PRODUTO`/`PRODUTO_FISCAL`. |

### O que fechou nesta sessão (marco 3.54 — testes da NF-e)

| Item | Entrega |
|---|---|
| **Suíte da NF-e** | `uNFeTest` (17 testes, banco real) cobre `TACBrHelper`: configuração (certificado/senha/UF/ambiente), emissão simulada (exige certificado e senha, só pedido da empresa, grava `NUMERO_NFE`/`CHAVE_NFE` e audita `PEDIDO_VENDA`/`NFE`), numeração `MAX(NUMERO_NFE)` por empresa, NFC-e, consulta, cancelamento (justificativa ≥15) e manifestação. Registrada no `uTestRunner`/`Tests.lpi`. Suíte **366/366**. Commit `162be42`. |

### O que fechou nesta sessão (marco 3.53)

| Item | Entrega |
|---|---|
| **Relatório LazReport** | Botão "Imprimir" em `uFrmListaPedidos` + `relatorios\pedidos_venda.lrf`; mesmo filtro da grade com `EMPRESA_ID`. Commits `5525e4f`. |
| **Melhoria de tela** | `uFrmPedidoDetalhe` (somente leitura) substitui o `MessageDlg` provisório do botão Visualizar. Commit `d2dae8c`. |
| **Android** | Diálogo do orçamento lista os itens (off-line). |

### O que fechou nesta sessão (marco 3.52 — auditoria Android + Services)

Android já era isolado por empresa (coluna `empresa` em todas as
tabelas locais, `empresaAtual()` em toda query, token descartado na
troca de empresa). Varredura final dos Services de estoque,
financeiro, PDV, pedidos e configuração: nenhuma escrita por ID sem
validação de empresa. Padrão `(EMPRESA_ID = :EMP OR EMPRESA_ID IS
NULL)` em CONFIGURACAO/CAIXA confirmado como deliberado (padrão
global/legado). Nenhum defeito novo.

### O que fechou nesta sessão (marco 3.51 — auditoria da API)

Varredura de `API\src\Rotas`: todas as consultas já filtram
`EMPRESA_ID` do JWT; única correção — segunda passada de
`uRotasOrcamentos` agora filtra empresa ao rebuscar `PRECO_VENDA`
(commit `2417241`). Itens de `ITEM_PEDIDO` seguros via validação do
cabeçalho pai.

### O que fechou nesta sessão (marco 3.50)

| Item | Entrega |
|---|---|
| **Guarda de empresa nos services de nota** | `uServiceBase` ganhou `GarantirEmpresaBanco` (função reutilizável para services que não herdam da base) + métodos `GarantirDaEmpresa`/`GarantirDaEmpresaSql`. `TNotaEntradaService` e `TNotaSaidaService` validam empresa em todos os métodos públicos por ID (cabeçalho, itens via pai, processar/faturar/cancelar, contas, XML); `CriarDoPedidoCompra`/`CriarDoPedido` validam o pedido. `TCorService` ganhou `GarantirDaEmpresa` em Atualizar/Excluir. `TProducaoService` **mantém desenho próprio** (deriva `EMPRESA_ID` do registro pai — `TestMapaEscopoEmpresa`). Commits `7114bab` + `839fefd`. |
| **Leitura por ID nas telas** | `PreencherCampos`/`NumeroDoMapa` de Material, Produto Fiscal, Produtos, Usuários, Cores do Produto e Mapa de Produção passaram a filtrar `EMPRESA_ID = :EMP`. Globais mantidos: CATEGORIA, CONDICAO_PAGAMENTO, FORMA_PAGAMENTO, geográficos, GRUPO/PERMISSAO. Commit `1098221`. |

### O que fechou nesta sessão (marco 3.49)

| Item | Entrega |
|---|---|
| **Escopo de empresa nas telas** | Varredura completa dos `SELECT` de `Desktop\src\Views` e `Desktop\src\Services`: listagens de pedidos (`uFrmListaPedidos`, `uFrmMapaProducao`, `uFrmNotaSaida`), notas de entrada/saída (lista + abertura por ID), buscas de cliente/fornecedor (`uFrmNotaEntrada`, `uFrmNotaSaida`, `uFrmPedidoVenda`) não filtravam `EMPRESA_ID` — todos ganharam `:EMP` da sessão. Consultas por ID de item (`NOTA_*_ID`, `MAPA_*`, `TALAO`) permanecem escopadas pelo registro pai já validado. Commit `41719b9`. |

### O que fechou nesta sessão (marco 3.48)

| Item | Entrega |
|---|---|
| **Guarda de empresa nas escritas** | `Atualizar`/`Excluir` de `TProdutoService`, `TMaterialService`, `TProdutoFiscalService`, `TUsuarioService` e `TPessoaService` não verificavam a empresa do registro — ID de outra empresa podia ser alterado/excluído. Cada service ganhou `GarantirDaEmpresa` (ou `AND EMPRESA_ID = :EMP` no UPDATE/DELETE do Pessoa). `TGradeService`: `Atualizar`/`Excluir` com guarda, contagens de `PRODUTO` filtradas por empresa, `GradeDoProduto` e `DefinirGradeDoProduto` com `EMPRESA_ID = :EMP` (produto **e** grade validados). Commit `2b588d1`. |
| **Numeração da nota de saída** | `TNotaSaidaService.ProximoNumero` fazia `MAX(NUMERO)` sobre **todas** as empresas — agora `WHERE EMPRESA_ID = :EMP` (mesmo padrão de Pedido/PedidoCompra/PDV). |

### O que fechou nesta sessão (marco 3.47)

| Item | Entrega |
|---|---|
| **Escopo de empresa nas consultas** | `Pesquisar` de `TMaterialService`/`TProdutoFiscalService`/`TProdutoService` e `CarregarDados` de `uFrmMaterial`/`uFrmProdutoFiscal`/`uFrmProdutos`/`uFrmUsuarios` listavam registros de **todas** as empresas. Todos ganharam `EMPRESA_ID = :EMP` (`TSessao.GetInstance.EmpresaId`, parametrizado). `CATEGORIA`/geográficos permanecem globais (sem `EMPRESA_ID`). Lookups de produto/material nas telas de Compras, Movimento de Estoque, Nota de Entrada, Pedido de Venda e Ficha Técnica também filtrados. Destructors movidos para `public` (warnings 3019). Commit `759fae7`. |

### O que fechou nesta sessão (marcos 3.44–3.46)

| Item | Entrega |
|---|---|
| **Produto via Service** | `uProdutoService` criado; `uFrmProdutos` sem INSERT/UPDATE/DELETE. Model ganhou `GradeId`/`ProdutoFiscalId`; `GRADE_ID` 0 → NULL via `InserirParamN`. Valida descrição, categoria/unidade (>0, `DM_ID` NOT NULL) e preço de venda > 0. +4 testes. Commit `69b6e71`. |
| **Usuário via Service** | `uUsuarioService` criado; `uFrmUsuarios` sem SQL. Senha hasheada no Service (SHA-256); **`GRUPO_ID` agora gravado** (a tela tinha o combo mas o INSERT/UPDATE antigo não gravava a coluna — `DM_ID` NOT NULL, cadastro quebrava); login único por empresa; telefone; auto-exclusão bloqueada no Service. +4 testes. Commit `c7e67b9`. |
| **Login via Service** | `uFrmLogin.Autenticar` usa `BuscarPorLogin` + `SenhaConfere` + `RegistrarAcesso` (último acesso + migração de senha legada). Commit `a13f106`. |
| **Varredura final** | Nenhuma tela (`Desktop\src\Views\*.pas`) tem mais INSERT/UPDATE/DELETE — **toda escrita passa por Service**. Suíte **349/349**. |

### O que fechou nesta sessão (marco 3.43)

| Item | Entrega |
|---|---|
| **Material + Produto Fiscal via Service** | Trabalho encontrado não commitado na árvore; revisado, build 0/0 e suíte verde. `uFrmMaterial`/`uFrmProdutoFiscal` sem INSERT/UPDATE/DELETE. `TProdutoFiscal` ganhou `Tipo`/`Valor` (colunas da migração 014); `TRepositoryBase` ganhou `InserirParamN`/`AtualizarParamN`/`AplicarParamsN` (parâmetro gravado como NULL — TIPO vazio → NULL pois o CHECK só aceita 'S'/'O'). Commit `a62868a`. |
| **Categoria via Service (novo)** | `uFrmCategorias` inseria `EMPRESA_ID`, coluna **inexistente** em `CATEGORIA` (tabela global, sem empresa — INSERT falhava com "column unknown"). Criado `TCategoriaService` (`Desktop\src\Services\uCategoriaService.pas`): nome obrigatório, nome único global case-insensitive, `LogOperacao` I/U/D, `Pesquisar` com CAST+CONTAINING. Unit registrada no `ERP2026.lpi`. Commit `0b1eb2d`. |
| **Migração 019** | `USUARIO.TELEFONE` — a tela de usuários já lia/grava a coluna, que não existia. SQL + rollback commitados (`7e8d706`); já aplicada no banco real. |
| **Testes** | `uCadastrosFase1Test` +4: `TestProdutoFiscalTipoValor` (TIPO ''→NULL / 'S' em insert e update, VALOR), `TestCategoriaCicloCompleto`, `TestCategoriaSemNome`, `TestCategoriaNomeDuplicado`. Suíte **341/341**. |

### Varredura de telas (08/11) — resultado

- **Produção limpa:** `uFrmConsumoMaterial`, `uFrmFichaTecnica`,
  `uFrmBipagem`, `uFrmCoresProduto` não têm nenhum INSERT/UPDATE/DELETE —
  100% delegado a `TProducaoService`/`TCorService`.
- **Nota de Entrada — RESOLVIDO (marco 3.41):** `SalvarCabecalho` e
  `SalvarItem` criados em `TNotaEntradaService` (transação própria +
  `RegistrarAuditoria`); o form só coleta campos e delega. Update do
  cabeçalho ganhou guarda `STATUS <> 'P'` + `EMPRESA_ID` e update do item
  exige `NOTA_ENTRADA_ID` (anti-IDOR). Build 0/0, suíte **337/337**.
  Commit `6e6b707`.
- **Geográficos — RESOLVIDO (marco 3.42):** `uFrmPais`/`uFrmEstado`/
  `uFrmCidade` não têm mais INSERT/UPDATE/DELETE — montam o model e
  chamam `Inserir`/`Atualizar`/`Excluir` do Service. Models ganharam
  `Ativo` (+`CepPadrao` em `TCidade`); Services passaram a gravar
  `ATIVO`/`CEP_PADRAO`, auditar via `LogOperacao` e validar filhos no
  delete (país→estados, estado→cidades). Build 0/0, suíte **337/337**.
  Commit `70e946c`.
- **Material/ProdutoFiscal/Categoria — RESOLVIDO (marco 3.43):**
  ver tabela acima. Commits `a62868a`, `7e8d706`, `0b1eb2d`.
- **Escrita direta nas telas — ZERADA (08/11):** `grep -iE
  "insert into|update |delete from"` em `Desktop\src\Views\*.pas`
  não retorna nada. Cadastros (Categorias, Material, Produto Fiscal,
  Produtos, Usuários), geográficos, Nota de Entrada e Login estão
  todos delegados aos Services. Marcos 3.41–3.46.

### Próximo passo (executável)

1. **A definir com o usuário** — o backlog documentado (§2 do
   `PLANO_E_LOG.md`) e a fila de testes desktop estão concluídos
   (**366/366**). Antes de qualquer commit: `Scripts\build_desktop.bat`
   (0/0) e `Scripts\run_tests.bat` (**366/366** ou mais); Android
   `Scripts\run_tests_android.bat` (**5/5**).
2. **NF-e real (ACBr/SEFAZ)** implementada no código (marco 3.55). Para
   emitir de verdade: preencher os dados fiscais/endereço de `EMPRESA`,
   do cliente (`PESSOA`) e dos produtos (`PRODUTO`/`PRODUTO_FISCAL`),
   rodar `Scripts\preparar_acbr.bat` e usar um certificado A1 válido
   com a senha na tela. Sem certificado, mantenha **Modo simulado**
   marcado. NFC-e real também exige `IdCSC`/`CSC`.

### O que fechou nesta sessão (marco 3.39)

| Item | Entrega |
|---|---|
| **Testes MF/Inventário/Kardex** | Os 3 arquivos de teste criados antes estavam em **fpcunit** (nunca executados — o runner não os chamava) e faziam `DELETE` em `PRODUTO`/`ESTOQUE`/`MOVIMENTO_ESTOQUE`/`MOVIMENTO_FINANCEIRO` da empresa inteira. Reescritos no framework `uAssert` (`RunAllTests`/`AddResult`), com sufixo de timestamp e limpeza só dos IDs criados; registrados de fato no `uTestRunner.pas`. Suíte subiu de 288 para **325**. |
| **Correções de Service achadas pelos testes** | `uInventarioService`: coluna `CONTROLE_ESTOQUE` não existe (é `CONTROLA_ESTOQUE`) — a tela de Inventário estava quebrada; `CAST` em `PESQ`/`FILTRO2` (string right truncation). `uKardexService`: período `BETWEEN` virou `>= :DI AND < :DF` (vazava o dia seguinte) e `CAST(... AS DOUBLE PRECISION)` em `VALOR_TOTAL` e no resumo — **multiplicação/soma de `NUMERIC(15,4)` retornava NULL no Firebird 5** (mesmo problema já visto no resumo financeiro da API, §3.18). `uMovimentoFinanceiroService`: `CAST` em `PESQ3` (documento). |
| **NF-e / empresa** | `uFrmNFe.CarregarPedidos` não filtrava `EMPRESA_ID` — agora `PV.EMPRESA_ID = :EMP`. `TACBrHelper.GerarNFe`: pedido, sequencia de `NUMERO_NFE` e `UPDATE` passaram a respeitar a empresa; join `PESSOA` por empresa; escrita em transação com auditoria `LOG_SISTEMA`. |

### O que fechou nesta sessão (marco 3.40)

| Item | Entrega |
|---|---|
| **Suíte do fluxo de produção** | `uProducaoFluxoTest` (12 testes) cobre o `TProducaoService` com banco real — antes só havia testes de estrutura/permissão/auditoria (`uProducaoTest`). Cobre: validações e upsert de `GravarFichaTecnica`, `CriarMapa` (pendente/parcial, status do pedido `P`→`E`, empresa herdada do pedido), `GerarTaloes` (`ITEM`/`UNIDADE`, código `T`+6 dígitos, transições `PENDENTE`→`EM_PRODUCAO`), `BiparTalao` (`INICIO`→`CONCLUSAO`, `DUPLICADO`/`INVALIDO`, mapa `CONCLUIDO` e pedido `D`), `CancelarMapa`/`CancelarTalao` e o ciclo de consumo (`GerarConsumoMaterial` planejado × produzido, ficha obrigatória, `QTD_PREVISTA` com perda, `QTD_REAL`, saldo insuficiente, movimentos `S`/`E` e estorno). Registrado no `uTestRunner`/`Tests.lpi`. Suíte **337/337**. Commit `c57cb90`. |

### O que fechou nesta sessão

| Item | Entrega |
|---|---|
| **PDV (Service + testes)** | `uPDVService` tirou as regras de `uFrmPDV`: um caixa aberto por empresa/usuário, abertura com número automático e auditoria `INSERT`, venda como `PEDIDO_VENDA` com `STATUS='F'`, cliente informado ou **"Consumidor Final"** da empresa, itens em `ITEM_PEDIDO` (com `PRECO_UNITARIO`/`VALOR_UNITARIO` e CFOP `5102`) e movimento de caixa `V` na **mesma transação**, além de sangria/suprimento, saldo e fechamento. Corrigiu o PDV antigo, que gravava em `ITEM_PEDIDO_VENDA` (tabela inexistente), omitia `CLIENTE_ID`, `EMPRESA_ID`/`USUARIO_ID` do movimento e confirmava no meio da venda. O `TCaixaService` passou a contar `TIPO='V'` como entrada (venda do PDV aparecia fora do saldo). `uPDVTest` com **34 testes**. Suíte **288/288**. Detalhes em `PLANO_E_LOG.md` §3.35 |
| **Orçamento (Service + testes)** | `uOrcamentoService` tirou as regras de `uFrmOrcamento`: o orçamento é um `PEDIDO_VENDA` com `STATUS='O'`, então a gravação delega ao `TPedidoVendaService` (numeração por empresa, totais nunca negativos, `PRECO_UNITARIO`/`VALOR_UNITARIO`, CFOP `5102`, itens na mesma transação e auditoria `INSERT`). `ConverterEmPedido` só aceita orçamento da empresa com status `O`, usa `STATUS='O'` no `WHERE` (conversão dupla bloqueada) e audita `CONVERSAO`. A tela passou a filtrar clientes/produtos pela empresa, buscar produto por `:COD1/:COD2/:COD3` e manter o ID após salvar para o botão **Gerar Pedido**. `uOrcamentoTest` com **23 testes**. Suíte **254/254**. Detalhes em `PLANO_E_LOG.md` §3.34 |
| **Compras (Service + testes)** | `uPedidoCompraService` tirou as regras de `uFrmCompras`: numeração **por empresa** (maior `NUMERO` numérico + 1, ignorando textos como `PC-TESTE-8`), total do item = quantidade × valor − desconto e total do pedido = subtotal − desconto (ambos nunca negativos), status `ABERTO`/`CONFIRMADO`/`CANCELADO`, datas opcionais, cabeçalho + itens na **mesma transação** com auditoria `INSERT` e ID por `RETURNING ID`. A tela passou a listar só fornecedores ativos da empresa. `uPedidoCompraTest` com **22 testes** cobre totais, numeração, gravação, status, datas e todas as validações. Suíte **231/231**. Detalhes em `PLANO_E_LOG.md` §3.33 |
| **Pedido de venda (Service + testes)** | `uPedidoVendaService` tirou as regras de `uFrmPedidoVenda`: numeração **por empresa** (maior `NUMERO` numérico + 1, ignorando textos), totais de item/pedido nunca negativos, gravação de cabeçalho e itens na **mesma transação** com `PRECO_UNITARIO` e `VALOR_UNITARIO`, CFOP padrão `5102`, `DATA_ENTREGA` opcional e auditoria `INSERT`; a quantidade do item com grade passa a ser a soma dos tamanhos e a grade efetiva entra na transação do pedido. `uPedidoVendaTest` com **25 testes** cobre totais, numeração, gravação, grade, desconto maior que o subtotal, data de entrega, campos opcionais nulos e todas as validações. Suíte **209/209**. Detalhes em `PLANO_E_LOG.md` §3.32 |
| **Estoque (Service + testes)** | `uEstoqueService` tirou as regras de `uFrmMovEstoque`: registro com produto da empresa da sessão, tipo `E/S/A/I`, quantidade > 0, custo não negativo, limites de documento (50) e observação (255) e auditoria `INSERT`; a listagem passou a filtrar a empresa e usa `CAST` no texto (evita `string right truncation` em `CODIGO`/`DOCUMENTO`). `SaldoProduto` usa `CAST` no `SUM` (sem ele `AsFloat` volta 0). `uEstoqueTest` com **18 testes** cobre a trigger `TRG_MOVEST_AI` (E/A somam, S subtrai, I não altera), criação da linha de `ESTOQUE`, escopo da empresa e validações. Suíte **184/184**. Detalhes em `PLANO_E_LOG.md` §3.31 |
| **Contas a pagar/receber (Service + testes)** | `uContasService` tirou as regras de dentro das telas: plano financeiro por tipo, criação com `FINANCEIRO_ID` obrigatório, baixa só de conta aberta, listagem por período/status/texto no escopo da empresa e auditoria `INSERT`/`BAIXA`. Corrigiu a inclusão de **conta a receber**, que não gravava `FINANCEIRO_ID` (`DM_ID NOT NULL`). `uContasTest` com **16 testes**. Suíte **166/166**. Detalhes em `PLANO_E_LOG.md` §3.30 |
| **Testes unitários do caixa (desktop)** | `uCaixaTest` (17 testes) cobre `TCaixaService`: saldo por caixa (E−S; G/P fora do saldo), número como texto, usuário do `LEFT JOIN`, status/datas de fechamento, escopo da empresa, ordenação por ID decrescente, filtros por número/usuário/descrição/tipo e o resumo ENTRADAS/SAIDAS/SALDO, além das validações de query nula e caixa inválido. Suíte **150/150**. Revelou que o filtro por número estourava `string right truncation` acima de 20 caracteres — corrigido no Service. Detalhes em `PLANO_E_LOG.md` §3.29 |
| **Correção do cadastro de produto** | `uFrmProdutos` não gravava `CATEGORIA_ID`/`UNIDADE_ID` no `INSERT`/`UPDATE`, mas o domínio `DM_ID` é `NOT NULL` — incluir produto pela tela falhava. Agora os combos são **obrigatórios** na validação, entram no `INSERT`/`UPDATE` e são reselecionados em `PreencherCampos`. Build **0/0**, suíte **133/133**. Detalhes em `PLANO_E_LOG.md` §3.28 |
| **Testes unitários das notas fiscais (desktop)** | `uNotasFiscaisTest` (34 testes: 15 de entrada + 19 de saída) cobre criação a partir do pedido, processamento/faturamento, estoque e custo médio, contas a pagar/receber, chave de acesso de 44 dígitos com DV, cancelamento/estorno, itens, classificação fiscal e XML, com banco real. Suíte **133/133**. Revelou que `PRODUTO` exige `CATEGORIA_ID`/`UNIDADE_ID` (domínio `DM_ID` NOT NULL). Detalhes em `PLANO_E_LOG.md` §3.27 |
| **Testes unitários dos cadastros (desktop)** | `uGeograficoTest` (11) + `uCadastrosFase1Test` (23) cobrem País/Estado/Cidade, Cor, Material, Produto Fiscal e Grade com banco real. Suíte **99/99**. Revelaram e corrigiram 3 bugs: *double free* em `BuscarPorId` (País/Estado/Cidade/Grade), `string right truncation` no `Pesquisar` (Material/Produto Fiscal) e validação de produto na tabela errada (`DefinirGradeDoProduto`). Detalhes em `PLANO_E_LOG.md` §3.26 |
| **Testes unitários da sincronização (Android)** | `SincronizacaoTest` (JUnit 4 + Robolectric 4.13, apenas `testImplementation` — não entra no APK) roda na JVM com SQLite real e servidor HTTP falso: download dos 6 conjuntos, envio da outbox e id do servidor, snapshots isolados por empresa e 401 (no envio e no download). **5/5** verdes; a rodada agora para no primeiro 401. Detalhes em `PLANO_E_LOG.md` §3.25 |
| **Sincronização total (Android + API)** | Menu **⋮ › Sincronizar dados** abre `SincronizacaoActivity`: empresa/usuário do token, contagem e última sincronização de cada conjunto, pendências e **Baixar tudo**. A API passou a filtrar **todas** as consultas por `EMPRESA_ID` do JWT (clientes, produtos, vendas, estoque e financeiro) e os POSTs usam a empresa do token. Android: schema local **v3** com `venda_local`, `estoque_local`, `conta_receber_local` e `conta_pagar_local`; Vendas/Estoque/Financeiro e Dashboard leem do banco local e sincronizam em segundo plano. Detalhes em `PLANO_E_LOG.md` §3.24 |
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
- **Sincronização total validada no emulador `Pixel_9` (03/11):** com a API
  local no ar, o menu ⋮ abriu **Sincronizar dados** mostrando Empresa 1 /
  Administrador e as contagens (9 clientes, 4 produtos, 0 orçamentos, 4 vendas,
  4 itens de estoque, 5 contas). **Baixar tudo** respondeu "Salvo no aparelho:
  9 cliente(s), 4 produto(s), 0 orçamento(s), 4 venda(s), 4 item(ns) de estoque,
  2 conta(s) a receber e 3 a pagar."; o Dashboard passou a exibir faturamento
  R$ 70,00, A receber R$ 170,00 e A pagar R$ 1.595,00, e as telas Vendas,
  Estoque e Financeiro mostraram os dados do cache. Em **modo avião**, após
  `force-stop`, as mesmas telas continuaram abrindo com os dados locais e o
  botão exibiu "Sem conexão. Os dados continuam salvos no aparelho.".
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

**A definir com o usuário** — a suíte dos pedidos de venda fechou em 08/11
(ver "Estado atual" no topo). Ao fechar cada marco: build 0/0, suíte verde,
atualizar este checkpoint, `PLANO_E_LOG.md` e commitar.

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
| Testes do app **Android** (JVM) | `Android\android\app\src\test\java\com\example\erp2026_mobile\SincronizacaoTest.java` (`Scripts\run_tests_android.bat`) |
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

0. **Próximo marco:** a suíte desktop das áreas cobertas fechou (cadastros,
   notas fiscais, caixa, contas, estoque, pedidos de venda, compras, orçamento
   e PDV). O próximo passo é **Movimento Financeiro**; depois
   Inventário/Kardex, Consumo/Ficha/Bipagem/Cores e NFe.
1. Firebird 5 ativo (serviço) — o banco é `Banco\DADOS.FDB`.
2. Abrir o app: `Desktop\bin\ERP2026.exe` (login `admin` / `admin123`).
3. Build: `Scripts\build_desktop.bat` (matar `ERP2026.exe` antes, se estiver aberto).
4. Testes unit: `Scripts\run_tests.bat` → esperado **288/288**.
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
8. Testes Android (JVM, sem emulador): `Scripts\run_tests_android.bat`
   → esperado **5/5** (`SincronizacaoTest`, JUnit + Robolectric).

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
- ~~**Cadastro de produto não grava `CATEGORIA_ID`/`UNIDADE_ID`**~~ —
  **concluído (07/11)**: `uFrmProdutos.Salvar` passou a gravar as duas colunas
  no `INSERT`/`UPDATE`, `PreencherCampos` reseleciona os combos e `Validar`
  exige categoria/unidade (domínio `DM_ID` é `NOT NULL`). Commit `fed1cbd`
  (§3.28).

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
