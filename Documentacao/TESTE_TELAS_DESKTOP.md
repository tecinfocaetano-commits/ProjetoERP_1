# Teste de UI em todas as telas do desktop

Gerado por `Scripts\testes\telas_todas_ui.ps1` em 22/11/2026 01:45 (HEAD `7e4c1e5`).

**Resultado: 34 OK, 0 aviso(s), 0 falha(s)** - 34 telas do menu.

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
| 7 | 9 | Produção > Lista de Pedidos | Pedidos de Venda | 13 | **OK** | evidencias/telas_09_pedidos_de_venda.png |
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
| 18 | 24 | Fiscal > NF-e / NFC-e | NF-e / NFC-e - Notas Fiscais Eletrônicas | 22 | **OK** | evidencias/telas_24_nf_e_nfc_e_notas_fiscais_eletronicas.png |
| 19 | 25 | Fiscal > Nota de Serviço | Nota de Serviço (NFS-e resumida) | 24 | **OK** | evidencias/telas_25_nota_de_servico_nfs_e_resumida.png |
| 20 | 27 | Cadastros > Pessoas | Pessoas | 39 | **OK** | evidencias/telas_27_pessoas.png |
| 21 | 28 | Cadastros > Categorias | Categorias | 18 | **OK** | evidencias/telas_28_categorias.png |
| 22 | 29 | Cadastros > Grades | Grades | 22 | **OK** | evidencias/telas_29_grades.png |
| 23 | 30 | Cadastros > Países | Países | 19 | **OK** | evidencias/telas_30_paises.png |
| 24 | 31 | Cadastros > Estados | Estados | 20 | **OK** | evidencias/telas_31_estados.png |
| 25 | 32 | Cadastros > Cidades | Cidades | 20 | **OK** | evidencias/telas_32_cidades.png |
| 26 | 34 | Cadastros > Usuários | Usuários | 24 | **OK** | evidencias/telas_34_usuarios.png |
| 27 | 36 | Estoque > Movimentação | Movimentação de Estoque | 11 | **OK** | evidencias/telas_36_movimentacao_de_estoque.png |
| 28 | 37 | Estoque > Inventário | Inventário de Estoque | 9 | **OK** | evidencias/telas_37_inventario_de_estoque.png |
| 29 | 38 | Estoque > Kardex | Kardex do Produto | 12 | **OK** | evidencias/telas_38_kardex_do_produto.png |
| 30 | 40 | PDV > Abrir PDV | PDV - Ponto de Venda | 19 | **OK** | evidencias/telas_40_pdv_ponto_de_venda.png |
| 31 | 42 | Relatórios > Central de Relatórios... | Central de Relatórios | 6 | **OK** | evidencias/telas_42_central_de_relatorios.png |
| 32 | 44 | IA Copiloto > Abrir Copiloto ERP | Copiloto ERP - Assistente Inteligente | 16 | **OK** | evidencias/telas_44_copiloto_erp_assistente_inteligente.png |
| 33 | 46 | Sistema > Configurações | Configurações | 20 | **OK** | evidencias/telas_46_configuracoes.png |
| 34 | 47 | Sistema > Permissões | Permissões | 16 | **OK** | evidencias/telas_47_permissoes.png |

Telas fora do menu cobertas em outros testes: **Login** (fluxo do `Start-ERPApp`),
dialogos `uFrmCoresProduto` e `uFrmGradeQuantidades` (abertos por botao nas telas
de Produto Producao e Grades) e `uFrmCadastroBase` (classe base, nao instanciavel).
