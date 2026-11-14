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
| F3 | A | Sem DANFE, cupom/NFC-e no PDV, manifestação do destinatário, CC-e ou inutilização na UI. | `uFrmNFe.pas`, `uFrmPDV.pas` |
| F13 | M | Cadastro de produto não expõe/persiste peso, `PRODUTO_FISCAL_ID`, fornecedor e imagem. | `uProdutoService.pas`, `uFrmProdutos.pas` |
| F14 | M | `ACRESCIMO` de pedido/item nunca é lido nem gravado (frete/encargos). | `uPedidoVendaService.pas`, telas de pedido |

## 2. Acesso e isolamento por empresa

| # | Prior. | Item | Onde |
|---|---|---|---|
| T1 | A | Permissões aplicadas em apenas 8 telas; usuários, produtos, pessoas, contas, NF-e, PDV e compras não checam permissão. | `Desktop\src\Views\*` |
| T4 | A | Consultas/gravações cruzando empresas (bipagem, consumo, produção, copiloto, caixa legado). | `uFrmBipagem.pas`, `uProducaoService.pas`, `uCopilotoERP.pas`, `uCaixaService.pas` |

## 3. API REST

| # | Prior. | Item | Onde |
|---|---|---|---|
| D3 | A | Build da API não linka `Desktop\src\Services`: regra de negócio duplicada em SQL inline (causa de F5/D5). | `Scripts\build_api.bat` |
| F4 | A | `POST /api/clientes` não devolve o ID; app casa por nome+CPF. Sem `PUT /api/clientes`. | `uRotasClientes.pas`, `Sincronizacao.java` |
| D9 | A | Faltam índices únicos `USUARIO(EMPRESA_ID,LOGIN)`, `PESSOA(EMPRESA_ID,CPF_CNPJ)`, `PEDIDO_VENDA(EMPRESA_ID,NUMERO)`. | `Banco\schema_canonico.sql` |
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
| D7 | A | Schema não reproduzível: `USUARIO.TELEFONE` fora do canônico, 48 generators vs 49 esperados, `script_completo.sql` incompleto. | `Banco\schema_canonico.sql`, `Scripts\testes\banco_fresco.ps1` |
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

1. **F3** — fechar o ciclo fiscal de ponta a ponta (F1 no marco 3.63 e F2 no 3.64).
2. **T1 + T4 + F7 (login da API)** — controle de acesso e isolamento por empresa.
3. **D3 + F4 + D9 + D4 + D5 + F5** — API com Services, ID/índices, auditoria e numeração por empresa.
4. **D7 + D8** — banco novo confiável a partir do repositório.
5. **F6 + F9** — paginação e visibilidade de erros na API/Android.
6. **F5/F6/F9 + F4/F13 + F7 (relatórios)/F15** — ciclo de vida de pedidos, financeiro real, cadastros estruturantes, relatórios e backup pela aplicação.
7. **F8, F10, F11, F12, F14, T5, D10, D11** — completudes e dívida.

## Já resolvido (não reabrir)

- **D1/D2** — banco e JWT por variáveis de ambiente (marco 3.60).
- **F1 (fiscal)** — importação real de XML de NF-e em `uNFeXmlService`, com fornecedor/produto, fiscal do documento, recusa de chave repetida e limpeza de nota parcial (marco 3.63).
- **F2 (fiscal)** — NF-e autorizada materializa `NOTA_SAIDA` (chave/protocolo da SEFAZ), baixa estoque, gera contas a receber e salva o XML; saldo conferido antes do envio (marco 3.64).
- **D6** — conexões da API devolvidas ao pool ao fim de cada requisição (marco 3.61).
- **D12 (health)** — `GET /api/health` público; teste de conexão do Android exige 2xx (marco 3.61).
- **T2/T3/F7 (login da API)** — login sem credenciais padrão, desambiguado por empresa no desktop e na API (marco 3.62).
- Backup/restauração por `gbak` (marco 3.59).
- Cenário fiscal de teste e validação local/em lote da NF-e (marcos 3.55–3.58).
- Menu desktop sem itens inertes; DML só em Services; SQL parametrizado nos filtros.
- CRUD dos descendentes de `uFrmCadastroBase` (categorias, cidades, estados, produtos, usuários etc.).
