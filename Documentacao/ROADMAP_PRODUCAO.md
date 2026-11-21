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
| F16 | M | **PLANO (marco 3.86, não implementado): NFS-e de prefeitura.** Preferência por **Código do provedor** (`SIGCORP`, `BETA`, `NACIONAL`, `OUTRO`) em `CONFIGURACAO`, adapter do padrão nacional 2026 como principal e adapters legados por provedor; sem envio em testes locais. Detalhes em `PROMPT_TESTES_FISCAIS_GRATUITOS.md` §5. | `CONFIGURACAO`, `TNFSeHelper` (futuro) |
| F17 | M | **PLANO (marco 3.86, não implementado): nota de entrada aceitar serviços/comunicação/internet e notas municipais.** Detectar `infNFS-e`/`RPS`/`InfDeclaracaoPrestacaoServico`, item sem NCM/CFOP/estoque, migração aditiva com `TIPO_DOCUMENTO`/`PROVEDOR` e dedupe por tipo. Detalhes no `PROMPT_TESTES_FISCAIS_GRATUITOS.md` §6 e no `PROMPT_RETOMADA_COMPLETO.md` §5. | `uNFeXmlParser`, `uNFeImportService`, `NOTA_ENTRADA` |
| F18 | A | **PLANO (marco 3.87, não implementado): importação de XML com resolução de produto.** Verificar se o produto do XML já existe; se não existir, abrir tela para o usuário escolher um compatível ou cadastrar novo (pré-preenchido), sem criação automática. Tabela aditiva `IMPORTACAO_XML_ITEM` guarda CNPJ do fornecedor, descrição original da nota, produto da nota e classificação fiscal que veio, com dedupe por empresa+chave+código. | `uNFeImportService`, tela de mapeamento, `Banco\023_importacao_xml.sql` |

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
| D4 | A | **CONCLUÍDO (marco 3.74):** escritas da API auditadas em `LOG_SISTEMA` com empresa/usuário do JWT e na mesma transação; `TPessoaService` audita antes do commit. | `API\src\Rotas\*`, `uPessoaService.pas` |
| D5 | A | **CONCLUÍDO (marco 3.76):** rota usa `TEstoqueService.RegistrarMovimento`, valida produto por empresa, saldo pela trigger e erros 400. | `uRotasEstoque.pas` |
| F5 | A | **CONCLUÍDO (marco 3.76):** `ProximoNumero` filtra por `EMPRESA_ID`, igual ao desktop. | `uRotasOrcamentos.pas` |
| F1 | A | **CONCLUÍDO (marco 3.79):** `PUT/DELETE /api/produtos/:id`, `PUT/DELETE /api/orcamentos/:id` (só STATUS 'O') e `POST /api/vendas` (STATUS 'P'), todos via Services com validação, isolamento e auditoria atômica. | `uRotasProdutos.pas`, `uRotasOrcamentos.pas`, `uRotasVendas.pas`, `uOrcamentoService.pas`, `uProdutoService.pas` |
| F6 | M | **CONCLUÍDO (marco 3.77):** paginação opcional com `total`/`total_paginas` em vendas e financeiro; sem parâmetros o array de até 100 é mantido. | `uPaginacao.pas`, rotas de vendas/financeiro |
| D10 | M | **CONCLUÍDO (marco 3.83):** `.github\workflows\bateria.yml` (self-hosted) e `Scripts\testes\api_todos.ps1` com os 6 smokes e checagem de `/api/health`. | repositório |
| D13 | A | **CONCLUÍDO (marco 3.86):** instabilidade da API eliminada — pool devolve a conexão viva (não destrói a `TIBConnection` por request), ping real ao retirar a vaga, renovação do socket e `/api/health` com 503 quando o banco falha. 60/60 logins concorrentes, 0 exceções. | `uConexao.pas`, `ERP2026API.lpr` |
| D11 | B | App: `usesCleartextTraffic`, token sem checar `exp`, CORS `*`. | `AndroidManifest.xml`, `Sessao.java`, `uMiddlewareCORS.pas` |
| F10 | B | `DELETE /api/clientes` físico (a auditoria `PESSOA/D` já foi fechada em 3.74; falta decidir exclusão lógica). | `uRotasClientes.pas` |

## 4. Android

| # | Prior. | Item | Onde |
|---|---|---|---|
| F3 | M | Vendas, estoque e financeiro somente leitura; sem baixa de título nem movimento de estoque. | `VendasActivity`, `EstoqueActivity`, `FinanceiroActivity` |
| F2 | M | Sem espelho de caixa, PDV, produção e notas fiscais na API. | `API\src\Rotas\*` |
| F9 | M | **CONCLUÍDO (marco 3.78):** outbox com status/backoff/dead-letter, tela de diagnóstico e botões "Tentar novamente"/"Limpar falhas"; 4xx vai direto para dead-letter. | `BancoLocal.java`, `Sincronizacao.java`, `SincronizacaoActivity.java` |
| F8 | B | Tela órfã `ConsultarClientesActivity` e card de faturamento inerte. | `AndroidManifest.xml`, `DashboardActivity` |

## 5. Banco e operação

| # | Prior. | Item | Onde |
|---|---|---|---|
| D7 | A | **CONCLUÍDO (marco 3.77):** `script_completo.sql` reescrito para o fluxo canônico com `INPUT` relativos; banco novo validado isoladamente. | `Banco\script_completo.sql`, `Scripts\testes\banco_fresco.ps1` |
| D8 | M | **CONCLUÍDO (marco 3.77):** `SET NAMES UTF8` no seed + `-ch UTF8` no isql; acentos conferidos (`Peça` = 4/5). | `Banco\007_initial_data.sql`, `Scripts\executar_banco.bat` |
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
3. **D3 + F4 + D9 + D4 + D5 + F5** — API com Services e auditoria concluída (D3 no 3.70; F4+D9 no 3.72; D4 no 3.74; D5+F5 no 3.76).
4. **D7 + D8** — banco novo confiável a partir do repositório (concluído no 3.77).
5. **F6 + F9 + F1 + bipe + preferência de homologação** — paginação no 3.77; F9 no 3.78; F1 no 3.79; app `:bipe` fechado e testado no 3.80; interruptor único de NF-e/NFC-e e PDV em homologação no 3.81. `:bipe` agora entra na bateria padrão.
6. **D10 (concluído 3.83), app `:pdv` (3.82, outro agente), D11, F3/F2/F8 (Android), F5/F6/F9 + F4/F13 + F7 (relatórios)/F15** — HTTPS/CORS/token, ciclo de vida de pedidos, cadastros estruturantes, relatórios, deploy e backup pela aplicação.
7. **F8, F10, F11, F12, F14, T5, D11** — completudes e dívida.
8. **D13 — CONCLUÍDO (3.86)** — estabilidade da API (pool/health), pedido
   explícito do usuário. **F16/F17** — NFS-e e nota de entrada de serviços:
   apenas plano registrado no `PROMPT_TESTES_FISCAIS_GRATUITOS.md`, aguardando
   decisão de provedor e prazos do padrão nacional antes de virar código.
9. **F18 (marco 3.87)** — tabela `IMPORTACAO_XML_ITEM` + tela de escolha/cadastro
   de produto na importação de XML, depois integrada ao parser ampliado (F17).
   Sequência prevista: 3.88 tabela/mapeamento → 3.89 nota de serviço + XML →
   3.90 nota de entrada ampliada, conforme `PROMPT_RETOMADA_COMPLETO.md` §6.

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
- **D4** — auditoria `LOG_SISTEMA` nas escritas da API (empresa/usuário do JWT); `TPessoaService` passou a auditar antes do commit; smoke com 6 logs conferidos (marco 3.74).
- **D5 + F5** — estoque pelo Service (validação por empresa, saldo pela trigger, log atômico, 400) e numeração de orçamento por empresa (marco 3.76).
- **D7 + D8 + F6** — banco novo pelo fluxo canônico (script sem caminhos absolutos, seed com `SET NAMES UTF8` e isql `-ch UTF8`) e paginação opcional sem quebrar o contrato do app (marco 3.77).
- **F9 (Android)** — fila offline com backoff 1/2/4/8/16 min, dead-letter após 5 falhas ou 4xx, tela de diagnóstico e ação manual de retry/limpeza (marco 3.78).
- **F1 (API)** — CRUD completo de produtos/orçamentos e criação de venda pela API, com regra nos Services, STATUS 'O' protegido na edição/exclusão de orçamento, STATUS 'P' na venda e auditoria atômica corrigida em `TProdutoService` (marco 3.79).
- **Preferência de homologação (pedido do usuário)** — checkbox em *Sistema > Configurações* grava `NFE_AMBIENTE=2` + `NFE_MODO=REAL` na `CONFIGURACAO` da empresa; desativar volta a `NFE_MODO=SIMULADO`. `TACBrHelper` e o PDV leem as mesmas chaves, sem estado redundante (marco 3.81).
- **App `:bipe` de talão — CONCLUÍDO** (marco 3.80, outro agente): feedback visual/vibração/código lido e resultado acima do teclado; ciclo validado no Samsung A55. Incluído na bateria via `Scripts\build_bipe.bat`; código de `Android\android\bipe\**` não é alterado por esta sessão.
- **D10 — CI local e smokes unificados** (marco 3.83): `.github\workflows\bateria.yml` roda desktop/testes/`:bipe`/`:app`/telas/permissões e, em job separado, `Scripts\testes\api_todos.ps1` (6 smokes com `/api/health`). API não é recompilada nem reiniciada pela pipeline.
- **D6** — conexões da API devolvidas ao pool ao fim de cada requisição (marco 3.61).
- **D12 (health)** — `GET /api/health` público; teste de conexão do Android exige 2xx (marco 3.61). Reforçado no marco 3.86: passou a checar o banco de verdade (`"banco":"ok"`) e a devolver 503 quando ele falha, em vez de mentir dizendo `ok`.
- **D13 (estabilidade da API)** — pool devolve a conexão viva (o `Conexao.Free` por request causava `connection shutdown` com 20 threads), ping real na retirada, renovação do socket e retry; 60/60 logins concorrentes sem exceções (marco 3.86).
- **T2/T3/F7 (login da API)** — login sem credenciais padrão, desambiguado por empresa no desktop e na API (marco 3.62).
- Backup/restauração por `gbak` (marco 3.59).
- Cenário fiscal de teste e validação local/em lote da NF-e (marcos 3.55–3.58).
- Menu desktop sem itens inertes; DML só em Services; SQL parametrizado nos filtros.
- CRUD dos descendentes de `uFrmCadastroBase` (categorias, cidades, estados, produtos, usuários etc.).
