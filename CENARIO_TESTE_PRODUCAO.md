# Cenário de Teste de Produção - ERP 2026

## Objetivo
Simular um fluxo completo de uso do sistema em ambiente de produção, validando todas as funcionalidades críticas do ERP.

## Pré-condições
- Servidor Firebird: ✅ Rodando na porta 3050
- Banco de Dados: ✅ DADOS.FDB em C:\Users\Charles\Documents\ProjetoERP_1\Banco\
- Aplicativo: ✅ ERP2026.exe em C:\Users\Charles\Documents\ProjetoERP_1\Desktop\bin\
- Usuário Teste: SYSDBA / masterkey

## Cenário: Fluxo Completo de Venda de Produtos

### Passo 1: Login no Sistema
- [ ] Abre o aplicativo ERP2026
- [ ] Tela de login aparece
- [ ] Insira usuário: SYSDBA
- [ ] Insira senha: masterkey
- [ ] Clique em "Entrar"
- [ ] Sistema autentica com sucesso
- [ ] Tela principal é exibida

### Passo 2: Cadastro de Cliente Novo
- [ ] No menu principal, clique em "Clientes"
- [ ] Tela de Clientes é aberta
- [ ] Clique em "Novo"
- [ ] Preencha os dados:
  - Nome: João Silva Teste
  - CPF/CNPJ: 123.456.789-00 (fictício)
  - Endereço: Rua Teste, 123
  - Bairro: Centro
  - Cidade: São Paulo
  - Estado: SP
  - CEP: 01000-000
- [ ] Clique em "Salvar"
- [ ] Cliente é gravado com sucesso
- [ ] Cliente aparece na lista

### Passo 3: Consulta de Produtos
- [ ] No menu principal, clique em "Produtos"
- [ ] Tela de Produtos é aberta
- [ ] Verifique se há produtos listados
- [ ] Clique em um produto para ver detalhes
- [ ] Anote o nome e preço de um produto para teste

### Passo 4: Nova Venda
- [ ] No menu principal, clique em "Pedido de Venda"
- [ ] Tela de Pedido de Venda é aberta
- [ ] Clique em "Novo"
- [ ] Selecione o cliente "João Silva Teste" no dropdown
- [ ] Clique em "Adicionar Produto"
- [ ] Digite o código do produto anotado anteriormente
- [ ] Informe quantidade: 5
- [ ] Clique em "Adicionar"
- [ ] Produto aparece na lista de itens
- [ ] Repita para adicionar mais 1 item se desejar
- [ ] Clique em "Salvar/Gravar"
- [ ] Pedido é gravado com sucesso
- [ ] Status do pedido definido (geralmente "A" - Aberto)

### Passo 5: Verificação de Estoque
- [ ] Volte para a tela de Produtos
- [ ] Verifique o estoque do produto vendido
- [ ] Estoque deve ter diminuído conforme a quantidade vendida

### Passo 6: Registro Financeiro (Opcional)
- [ ] No menu principal, clique em "Contas a Receber"
- [ ] Verifique se uma conta foi gerada automaticamente para a venda
- [ ] Verifique o valor da conta (deve ser igual ao total da venda)

## Resultados Esperados
- Sistema deve responder sem erros
- Todos os dados devem ser gravados corretamente no banco
- Integridade dos dados mantida (estoque atualizado, contas financeiras geradas)
- Nenhum erro de banco de dados ou access violation

## Observações
- Este cenário testa as funcionalidades críticas do ERP
- Valida a integridade transacional do sistema
- Simula um uso real em ambiente de produção
