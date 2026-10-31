# Mapa de IDs de menu (WM_COMMAND) - ERP 2026

Leitura empirica do menu Win32 da janela principal (login `admin` / `admin123`),
gerada por `Scripts\dump_menu_ids.ps1`. Regenerar apos qualquer mudanca de menu:

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\dump_menu_ids.ps1
```

Os IDs sao atribuidos pelo LCL na ordem de criacao dos itens do `.lfm` e sao
estaveis para o mesmo executavel. Uso em automacao de testes (cross-process):

```pascal
PostMessage(hwndPrincipal, WM_COMMAND (0x0111), wParam=ID, lParam=0)
```

Exemplo (tela Producao > Mapa de Producao, usada nos testes da Fase 6):

```pascal
PostMessage(hMain, 0x0111, 21, 0);   // ID 21 = Mapa de Producao
```

## Tabela

| ID | Menu | Item | Componente | Tela / acao |
|---:|---|---|---|---|
| 2 | Cadastros | Clientes | mnuCadClientes | TfrmClientes |
| 3 | Cadastros | Fornecedores | mnuCadFornecedores | TfrmFornecedores |
| 4 | Cadastros | Produtos | mnuCadProdutos | TfrmProdutos |
| 5 | Cadastros | Categorias | mnuCadCategorias | TfrmCategorias |
| - | Cadastros | (separador) | - | - |
| 7 | Cadastros | Usuários | mnuCadUsuarios | TfrmUsuarios |
| 9 | Estoque | Movimentação | mnuEstMovimentacao | TfrmMovEstoque |
| 10 | Estoque | Inventário | mnuEstInventario | TfrmInventario |
| 11 | Estoque | Kardex | mnuEstKardex | TfrmKardex |
| 13 | Compras | Nota de Entrada | mnuComNotaEntrada | TfrmNotaEntrada |
| 15 | Vendas | Novo Pedido | mnuVenPedidos | TfrmPedidoVenda |
| 16 | Vendas | Novo Orçamento | mnuVenOrcamentos | TfrmOrcamento |
| - | Vendas | (separador) | - | - |
| 18 | Vendas | Lista de Pedidos | mnuVenListaPedidos | TfrmListaPedidos |
| 19 | Vendas | Nota de Saída | mnuVenNotaSaida | TfrmNotaSaida |
| 21 | Produção | Mapa de Produção | mnuProMapaProducao | TfrmMapaProducao (permissao MAPA_PRODUCAO) |
| 22 | Produção | Bipagem de Talões | mnuProBipagem | TfrmBipagem (permissao BIPAGEM) |
| - | Produção | (separador) | - | - |
| 24 | Produção | Ficha Técnica | mnuProFichaTecnica | TfrmFichaTecnica (permissao FICHA_TECNICA) |
| 25 | Produção | Consumo de Materiais | mnuProConsumo | TfrmConsumoMaterial (permissao CONSUMO) |
| 27 | PDV | Abrir PDV | mnuPDVAbrirPDV | TfrmPDV |
| 29 | Financeiro | Contas a Receber | mnuFinContasReceber | TfrmContasReceber |
| 30 | Financeiro | Contas a Pagar | mnuFinContasPagar | TfrmContasPagar |
| 31 | Financeiro | Caixa | mnuFinCaixa | TfrmCaixa (consulta de caixas e movimentos) |
| 33 | Fiscal | NF-e / NFC-e | mnuFisNFe | TfrmNFe |
| 35 | Relatórios | Central de Relatórios... | mnuRelCentral | TfrmCentralRelatorios (caminhos/.lrf, modelo ativo, atalho p/ tela do Mapa) |
| 37 | IA Copiloto | Abrir Copiloto ERP | mnuIACopiloto | TfrmCopiloto |
| 39 | Sistema | Configurações | mnuSisConfiguracoes | TfrmConfiguracoes (editor da CONFIGURACAO da empresa) |
| 40 | Sistema | Permissões | mnuSisPermissoes | TfrmPermissoes (editor da matriz PERMISSAO) |
| - | Sistema | (separador) | - | - |
| 42 | Sistema | Sair | mnuSisSair | Close do formulario principal |

Notas:

- Nenhum item do menu principal e inerte (todos tem OnClick).
- O grupo "Relatorios" tem o subitem "Central de Relatorios...".
- Menus de popup das telas (ex.: botao "Relatorio" da tela do Mapa) nao sao menu de
  janela: a automacao de testes le por MSAA e clica por coordenadas.

Controle de sanidade: ID de "Mapa de Producao" = 21 (testes da Fase 6 usam 21).
