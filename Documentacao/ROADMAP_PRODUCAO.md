# Roadmap de produção — comércio/indústria

Consolidação das auditorias de completude feitas em 11/11/2026 (desktop e
API/Android/banco). É um documento de priorização, não um backlog fechado:
cada item deve ser confirmado com o usuário antes de virar código.

Legenda de prioridade: **A** = risco de conformidade/segurança ou bloqueia
operação real; **M** = funcionalidade esperada em produção; **B** =
polimento/dívida.

## 1. Fiscal (maior risco)

| # | Prior. | Item | Onde |
|---|---|---|---|
| F3 | A | **Fechado nos marcos 3.65–3.67:** CC-e, inutilização e manifestação (3.65), DANFE/cupom em PDF (3.66) e NFC-e no PDV com destinatário opcional (3.67). | `uFrmNFe.pas`, `uFrmPDV.pas` |
| F13 | M | Cadastro de produto não expõe/persiste peso, `PRODUTO_FISCAL_ID`, fornecedor e imagem. | `uProdutoService.pas`, `uFrmProdutos.pas` |
| F14 | M | `ACRESCIMO` de pedido/item nunca é lido nem gravado (frete/encargos). | `uPedidoVendaService.pas`, telas de pedido |

## 2. Acesso e isolamento por empresa

| # | Prior. | Item | Onde |
|---|---|---|---|
| T1 | A | **CONCLUÍDO (marco 3.68):** catálogo canônico de 33 telas, falha fechada na abertura, menu desabilitado e ações protegidas em todas as telas. | `uPermissao.pas`, `uPermissaoUI.pas`, `uFrmPrincipal.pas`, `uFrmCadastroBase.pas` |
| T4 | A | **CONCLUÍDO (marco 3.69):** copiloto, produção, bipagem e caixa filtram/verificam `EMPRESA_ID`; `CriarMapa` recusa pedido de outra empresa. | `uFrmBipagem.pas`, `uProducaoService.pas`, `uCopilotoERP.pas`, `uCaixaService.pas` |

## 3. API REST

| # | Prior. | Item | Onde |
|---|---|---|---|
| D3 | A | **CONCLUÍDO (marco 3.70):** build linka Services/Repositories, sessão por thread via JWT e rotas de clientes migradas para `TPessoaService`. | `Scripts\build_api.bat`, `uMiddlewareSessao.pas`, `uRotasClientes.pas` |
| F4 | A | **CONCLUÍDO (marco 3.72):** `POST /api/clientes` devolve o ID (201), novo `PUT /:id`, `GET /:id` com telefone; app usa o ID do POST em vez de casar nome+CPF. | `uRotasClientes.pas`, `Sincronizacao.java` |
| D9 | A | **CONCLUÍDO (marco 3.72):** migration 021 com `UQ_USUARIO_EMPRESA_LOGIN`, `UQ_PESSOA_EMPRESA_TIPO_CPF` (TIPO faz parte da chave) e `UQ_PEDIDO_VENDA_EMPRESA_NUMERO`, aplicadas ao banco real e ao canônico. | `Banco\021_indices_unicos.sql`, `Banco\schema_canonico.sql` |
| D4 | A | Zero auditoria (`LOG_SISTEMA`) na API. | `API\src\Rotas\*` |
| D5 | A | `POST /api/estoque/movimento` aceita produto de outra empresa e não atualiza saldo. | `uRotasEstoque.pas` |
| F5 | A | Numeração de orçamento global na API (sem `EMPRESA_ID`). | `uRotasOrcamentos.pas` |
| F1 | A | CRUD incompleto: sem edição/exclusão de produtos e orçamentos, sem criação de venda. | `uRotasProdutos.pas`, `uRotasOrcamentos.pas`, `uRotasVendas.pas` |
| F6 | M | Listas truncadas em 100 registros, sem paginação nem total. | rotas de vendas/financeiro |
| D10 | M | Sem CI e sem testes de API. | repositório |
| D11 | B | App: `usesCleartextTraffic`, token sem checar `exp`, CORS `*`. | `AndroidManifest.xml`, `Sessao.java`, `uMiddlewareCORS.pas` |
| F10 | B | `DELETE /api/clientes` físico, sem auditoria (desktop inativa). | `uRotasClientes.pas` |

## 4. Android

| # | Prior. | Item | Onde |
|---|---|---|---|
| F3 | M | Vendas, estoque e financeiro somente leitura; sem baixa de título nem movimento de estoque. | `VendasActivity`, `EstoqueActivity`, `FinanceiroActivity` |
| F2 | M | Sem espelho de caixa, PDV, produção e notas fiscais na API. | `API\src\Rotas\*` |
| F9 | M | Falhas de sincronização invisíveis (outbox sem tela, sem dead-letter/retry exponencial). | `BancoLocal.java`, telas |
| F8 | B | Tela órfã `ConsultarClientesActivity` e card de faturamento inerte. | `AndroidManifest.xml`, `DashboardActivity` |

## 5. Banco e operação

| # | Prior. | Item | Onde |
|---|---|---|---|
| D7 | A | **Em parte (marco 3.72):** `USUARIO.TELEFONE` e os 3 índices únicos já estão no canônico; `banco_fresco.ps1` aceita 48 generators (D3 fundiu CLIENTE+FORNECEDOR) e valida 585 campos com diff vazio. Falta revisar `script_completo.sql`. | `Banco\schema_canonico.sql`, `Scripts\testes\banco_fresco.ps1` |
| D8 | M | `007_initial_data.sql` sem `SET NAMES UTF8` (acentos corrompem em banco novo). | `Banco\007_initial_data.sql` |
| F15 | M | Backup/restauração só por `.bat`; sem tela nem agendamento no app. | `Scripts\backup_banco.bat` |
| — | M | HTTPS/rate limiting, monitoramento e manual de deploy. | operação |

## 6. Gestão (desktop)

| # | Prior. | Item | Onde |
|---|---|---|---|
| F5 | M | Pedido de venda sem editar/cancelar/excluir/alterar status. | `uPedidoVendaService.pas`, `uFrmListaPedidos.pas` |
| F6 | M | Pedido de compra sem listagem/edição/cancelamento. | `uPedidoCompraService.pas`, `uFrmCompras.pas` |
| F9 | M | Financeiro sem baixa parcial, juros/multa, estorno; lançamento sem cliente/fornecedor. | `uContasService.pas`, `uFrmContas*` |
| F4 | M | Sem CRUD de empresa, grupo, unidade, condição/forma de pagamento. | `Desktop\src\Views\` |
| F7 (desktop) | M | Relatórios limitados a talão/mapa/pedidos; sem exportação CSV/Excel. | `Desktop\relatorios\`, `uFrmCentralRelatorios.pas` |
| F8 | B | Orçamento salvo não pode ser reaberto/convertido depois. | `uFrmOrcamento.pas` |
| F10 | B | Inventário sem contagem/ajuste. | `uInventarioService.pas`, `uFrmInventario.pas` |
| F11 | B | Caixa somente leitura fora do PDV. | `uFrmCaixa.pas` |
| F12 | B | Copiloto IA é placeholder. | `uFrmCopiloto.pas` |
| T5 | B | Testes dependem de banco real, empresa fixa em 1, sem cobertura de UI. | `Desktop\src\Tests\` |

## Ordem de execução acordada

1. **F3 — CONCLUÍDO** (F1 no marco 3.63, F2 no 3.64, CC-e/inutilização/manifestação no 3.65, DANFE/cupom em PDF no 3.66 e NFC-e no PDV no 3.67).
2. **T1 + T4 + F7 (login da API) — CONCLUÍDO** (T1 no marco 3.68, T4 no 3.69 e F7 no 3.62) — controle de acesso e isolamento por empresa.
3. **D3 + F4 + D9 + D4 + D5 + F5** — API com Services (D3 no marco 3.70; F4+D9 no 3.72); restam auditoria (`D4`), estoque (`D5`) e numeração por empresa (`F5`).
4. **D7 + D8** — banco novo confiável a partir do repositório.
5. **F6 + F9** — paginação e visibilidade de erros na API/Android.
6. **F5/F6/F9 + F4/F13 + F7 (relatórios)/F15** — ciclo de vida de pedidos, financeiro real, cadastros estruturantes, relatórios e backup pela aplicação.
7. **F8, F10, F11, F12, F14, T5, D10, D11** — completudes e dívida.

## Já resolvido (não reabrir)

- **D1/D2** — banco e JWT por variáveis de ambiente (marco 3.60).
- **F1 (fiscal)** — importação real de XML de NF-e em `uNFeXmlService`, com fornecedor/produto, fiscal do documento, recusa de chave repetida e limpeza de nota parcial (marco 3.63).
- **F2 (fiscal)** — NF-e autorizada materializa `NOTA_SAIDA` (chave/protocolo da SEFAZ), baixa estoque, gera contas a receber e salva o XML; saldo conferido antes do envio (marco 3.64).
- **F3 parcial (fiscal)** — CC-e (com sequência derivada do `LOG_SISTEMA`), inutilização de numeração e manifestação do destinatário na tela de NF-e, com validação, auditoria e 7 testes novos (marco 3.65).
- **F3 parcial (fiscal)** - DANFE (modelo 55) e cupom (modelo 65) em PDF a partir do XML autorizado, com botão na tela de NF-e e `--danfe=<chave>` para reimpressão; units FPDF no path do projeto, sem pacote novo (marco 3.66).
- **F3 completo (fiscal)** - NFC-e emitida ao finalizar a venda no PDV, com destinatário opcional no modelo 65 (regra única em `CamposFaltandoDestinatario`), configuração fiscal lida da `CONFIGURACAO` (`NFE_CERTIFICADO`, `NFE_AMBIENTE`, `NFE_MODO`, `NFCE_ID_CSC`, `NFCE_CSC`) e cupom em PDF aberto no leitor padrão (marco 3.67).
- **T1** — permissões nas 33 telas via catálogo canônico, abertura em falha fechada, menu/ações por permissão e seed idempotente; teste de UI `permissoes_menu.ps1` com 0 falhas (marco 3.68).
- **T4** — isolamento por empresa no copiloto (12 consultas com `:EMP`), produção (mapa/pedido/talão/consumo), bipagem (via `TALAO`/`USUARIO`) e caixa (via `JOIN CAIXA`); `CriarMapa` recusa pedido de outra empresa (marco 3.69).
- **D3** — API compila com `Desktop\src\Services` + `Repositories`; `uSessao` por thread e `uMiddlewareSessao` levam `empresa_id` do JWT aos Services, sem singleton compartilhado; clientes passaram a usar `TPessoaService` (marco 3.70).
- **F4 + D9** — `POST /api/clientes` devolve o ID, `PUT /:id` edita e o sync Android usa o ID do POST; migration 021 cria 3 índices únicos e remove duplicatas sem vínculo, com backup gbak (marco 3.72).
- **D6** — conexões da API devolvidas ao pool ao fim de cada requisição (marco 3.61).
- **D12 (health)** — `GET /api/health` público; teste de conexão do Android exige 2xx (marco 3.61).
- **T2/T3/F7 (login da API)** — login sem credenciais padrão, desambiguado por empresa no desktop e na API (marco 3.62).
- Backup/restauração por `gbak` (marco 3.59).
- Cenário fiscal de teste e validação local/em lote da NF-e (marcos 3.55–3.58).
- Menu desktop sem itens inertes; DML só em Services; SQL parametrizado nos filtros.
- CRUD dos descendentes de `uFrmCadastroBase` (categorias, cidades, estados, produtos, usuários etc.).
