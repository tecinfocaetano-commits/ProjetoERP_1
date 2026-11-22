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
PostMessage(hMain, 0x0111, 11, 0);   // ID 11 = Mapa de Producao
```

## Tabela

| ID | Menu | Item | Componente | Tela / acao |
|---:|---|---|---|---|
| 2 | Suprimentos | Materiais | ? | ? |
| 3 | Suprimentos | Compras | ? | ? |
| 4 | Suprimentos | Consumo de Materiais | mnuProConsumo | TfrmConsumoMaterial (permissao CONSUMO) |
| 6 | Produção | Produto Produção | ? | ? |
| 7 | Produção | Novo Pedido | mnuVenPedidos | TfrmPedidoVenda |
| 8 | Produção | Novo Orçamento | mnuVenOrcamentos | TfrmOrcamento |
| 9 | Produção | Lista de Pedidos | mnuVenListaPedidos | TfrmListaPedidos |
| - | Produção | (separador) | - | - |
| 11 | Produção | Mapa de Produção | mnuProMapaProducao | TfrmMapaProducao (permissao MAPA_PRODUCAO) |
| 12 | Produção | Bipagem de Talões | mnuProBipagem | TfrmBipagem (permissao BIPAGEM) |
| - | Produção | (separador) | - | - |
| 14 | Produção | Ficha Técnica | mnuProFichaTecnica | TfrmFichaTecnica (permissao FICHA_TECNICA) |
| 16 | Financeiro | Contas a Receber | mnuFinContasReceber | TfrmContasReceber |
| 17 | Financeiro | Contas a Pagar | mnuFinContasPagar | TfrmContasPagar |
| 18 | Financeiro | Caixa | mnuFinCaixa | TfrmCaixa (consulta de caixas e movimentos) |
| 19 | Financeiro | Produto Fiscal | ? | ? |
| 20 | Financeiro | Movimentação Financeira | ? | ? |
| 22 | Fiscal | Nota de Saída | mnuVenNotaSaida | TfrmNotaSaida |
| 23 | Fiscal | Nota de Entrada | mnuComNotaEntrada | TfrmNotaEntrada |
| 24 | Fiscal | NF-e / NFC-e | mnuFisNFe | TfrmNFe |
| 25 | Fiscal | Nota de Serviço | mnuFisNotaServico | TfrmNotaSaidaServico |
| 27 | Cadastros | Pessoas | ? | ? |
| 28 | Cadastros | Categorias | mnuCadCategorias | TfrmCategorias |
| 29 | Cadastros | Grades | ? | ? |
| 30 | Cadastros | Países | ? | ? |
| 31 | Cadastros | Estados | ? | ? |
| 32 | Cadastros | Cidades | ? | ? |
| - | Cadastros | (separador) | - | - |
| 34 | Cadastros | Usuários | mnuCadUsuarios | TfrmUsuarios |
| 36 | Estoque | Movimentação | mnuEstMovimentacao | TfrmMovEstoque |
| 37 | Estoque | Inventário | mnuEstInventario | TfrmInventario |
| 38 | Estoque | Kardex | mnuEstKardex | TfrmKardex |
| 40 | PDV | Abrir PDV | mnuPDVAbrirPDV | TfrmPDV |
| 42 | Relatórios | Central de Relatórios... | mnuRelCentral | TfrmCentralRelatorios (caminhos/.lrf, modelo ativo, atalho p/ tela do Mapa) |
| 44 | IA Copiloto | Abrir Copiloto ERP | mnuIACopiloto | TfrmCopiloto |
| 46 | Sistema | Configurações | mnuSisConfiguracoes | TfrmConfiguracoes (editor da CONFIGURACAO da empresa) |
| 47 | Sistema | Permissões | mnuSisPermissoes | TfrmPermissoes (editor da matriz PERMISSAO) |
| - | Sistema | (separador) | - | - |
| 49 | Sistema | Sair | mnuSisSair | Close do formulario principal |

Notas:

- Nenhum item do menu principal e inerte (todos tem OnClick).
- O grupo "Relatorios" tem o subitem "Central de Relatorios...".
- Menus de popup das telas (ex.: botao "Relatorio" da tela do Mapa) nao sao menu de
  janela: a automacao de testes le por MSAA e clica por coordenadas.

Controle de sanidade: ID de "Mapa de Producao" = 11 (testes da Fase 6 usam 11).
