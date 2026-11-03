# Teste de UI em todas as telas do desktop

Gerado por `Scripts\testes\telas_todas_ui.ps1` em 03/11/2026 19:21 (HEAD `b0539fd`).

**Resultado: 33 OK, 0 aviso(s), 0 falha(s)** - 33 telas do menu.

Criterio: o item de menu foi acionado por `WM_COMMAND`; a tela precisa abrir uma
janela visivel com pelo menos um controle. Avisos de negocio (ex.: caixa fechado)
sao lidos e fechados, e a tela por tras continua sendo validada.

| # | ID | Tela (menu) | Janela | Controles | Status | Evidencia |
|---:|---:|---|---|---:|---|---|
| 1 | 2 | Suprimentos > Materiais | Materiais | 25 | **OK** | evidencias/telas_02_materiais.png |
| 2 | 3 | Suprimentos > Compras | Compras - Pedido de Compra | 25 | **OK** | evidencias/telas_03_compras_pedido_de_compra.png |
| 3 | 4 | Suprimentos > Consumo de Materiais | Produção - Consumo de Materiais | 14 | **OK** | evidencias/telas_04_producao_consumo_de_materiais.png |
| 4 | 6 | Produção > Produto Produção | Produtos | 34 | **OK** | evidencias/telas_06_produtos.png |
| 5 | 7 | Produção > Novo Pedido | Pedido de Venda | 27 | **OK** | evidencias/telas_07_pedido_de_venda.png |
| 6 | 8 | Produção > Novo Orçamento | Orçamento | 26 | **OK** | evidencias/telas_08_orcamento.png |
| 7 | 9 | Produção > Lista de Pedidos | Pedidos de Venda | 12 | **OK** | evidencias/telas_09_pedidos_de_venda.png |
| 8 | 11 | Produção > Mapa de Produção | Produção - Mapa de Produção | 21 | **OK** | evidencias/telas_11_producao_mapa_de_producao.png |
| 9 | 12 | Produção > Bipagem de Talões | Produção - Bipagem de Talões | 11 | **OK** | evidencias/telas_12_producao_bipagem_de_taloes.png |
| 10 | 14 | Produção > Ficha Técnica | Produção - Ficha Técnica | 18 | **OK** | evidencias/telas_14_producao_ficha_tecnica.png |
| 11 | 16 | Financeiro > Contas a Receber | Contas a Receber | 13 | **OK** | evidencias/telas_16_contas_a_receber.png |
| 12 | 17 | Financeiro > Contas a Pagar | Contas a Pagar | 13 | **OK** | evidencias/telas_17_contas_a_pagar.png |
| 13 | 18 | Financeiro > Caixa | Caixa | 8 | **OK** | evidencias/telas_18_caixa.png |
| 14 | 19 | Financeiro > Produto Fiscal | Produto Fiscal | 34 | **OK** | evidencias/telas_19_produto_fiscal.png |
| 15 | 20 | Financeiro > Movimentação Financeira | Movimentação Financeira | 22 | **OK** | evidencias/telas_20_movimentacao_financeira.png |
| 16 | 22 | Fiscal > Nota de Saída | Nota de Saída (Faturamento de Venda) | 16 | **OK** | evidencias/telas_22_nota_de_saida_faturamento_de_venda.png |
| 17 | 23 | Fiscal > Nota de Entrada | Nota de Entrada (Compra de Mercadoria) | 18 | **OK** | evidencias/telas_23_nota_de_entrada_compra_de_mercadoria.png |
| 18 | 24 | Fiscal > NF-e / NFC-e | NF-e / NFC-e - Notas Fiscais Eletrônicas | 16 | **OK** | evidencias/telas_24_nf_e_nfc_e_notas_fiscais_eletronicas.png |
| 19 | 26 | Cadastros > Pessoas | Pessoas | 39 | **OK** | evidencias/telas_26_pessoas.png |
| 20 | 27 | Cadastros > Categorias | Categorias | 18 | **OK** | evidencias/telas_27_categorias.png |
| 21 | 28 | Cadastros > Grades | Grades | 22 | **OK** | evidencias/telas_28_grades.png |
| 22 | 29 | Cadastros > Países | Países | 19 | **OK** | evidencias/telas_29_paises.png |
| 23 | 30 | Cadastros > Estados | Estados | 20 | **OK** | evidencias/telas_30_estados.png |
| 24 | 31 | Cadastros > Cidades | Cidades | 20 | **OK** | evidencias/telas_31_cidades.png |
| 25 | 33 | Cadastros > Usuários | Usuários | 24 | **OK** | evidencias/telas_33_usuarios.png |
| 26 | 35 | Estoque > Movimentação | Movimentação de Estoque | 11 | **OK** | evidencias/telas_35_movimentacao_de_estoque.png |
| 27 | 36 | Estoque > Inventário | Inventário de Estoque | 9 | **OK** | evidencias/telas_36_inventario_de_estoque.png |
| 28 | 37 | Estoque > Kardex | Kardex do Produto | 12 | **OK** | evidencias/telas_37_kardex_do_produto.png |
| 29 | 39 | PDV > Abrir PDV | Abertura de Caixa | 4 | **OK** | evidencias/telas_39_abertura_de_caixa.png |
| 30 | 41 | Relatórios > Central de Relatórios... | Central de Relatórios | 6 | **OK** | evidencias/telas_41_central_de_relatorios.png |
| 31 | 43 | IA Copiloto > Abrir Copiloto ERP | Copiloto ERP - Assistente Inteligente | 16 | **OK** | evidencias/telas_43_copiloto_erp_assistente_inteligente.png |
| 32 | 45 | Sistema > Configurações | Configurações | 19 | **OK** | evidencias/telas_45_configuracoes.png |
| 33 | 46 | Sistema > Permissões | Permissões | 16 | **OK** | evidencias/telas_46_permissoes.png |

Telas fora do menu cobertas em outros testes: **Login** (fluxo do `Start-ERPApp`),
dialogos `uFrmCoresProduto` e `uFrmGradeQuantidades` (abertos por botao nas telas
de Produto Producao e Grades) e `uFrmCadastroBase` (classe base, nao instanciavel).
