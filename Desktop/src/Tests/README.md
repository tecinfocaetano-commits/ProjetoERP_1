# Testes Unitários - ERP 2026

Este diretório contém a suite de testes unitários para o sistema ERP 2026 desenvolvido em Lazarus/FPC.

## Estrutura

```
Tests/
├── uAssert.pas           - Framework simples de asserts para testes
├── uFrmLoginTest.pas     - Testes de autenticação
├── uFrmClientesTest.pas  - Testes de CRUD de clientes
├── uFrmProdutosTest.pas  - Testes de CRUD de produtos
├── uFrmCategoriasTest.pas - Testes de CRUD de categorias
├── uFrmUsuariosTest.pas  - Testes de CRUD de usuários
├── uTestRunner.pas       - Programa principal para executar todos os testes
└── README.md             - Este arquivo
```

## Framework de Testes

O framework de testes é simples e baseado em asserts, implementado em `uAssert.pas`:

### Funções de Assert Disponíveis:

- `AssertTrue(Condition, Message)` - Verifica se a condição é verdadeira
- `AssertFalse(Condition, Message)` - Verifica se a condição é falsa
- `AssertEquals(Expected, Actual, Message)` - Verifica se dois valores são iguais
- `AssertNotNull(Value, Message)` - Verifica se o valor não é nil
- `AssertNil(Value, Message)` - Verifica se o valor é nil
- `AssertFail(Message)` - Falha o teste intencionalmente

### TTestSuite

Classe que gerencia a execução dos testes e coleta os resultados:
- `AddResult(TestName, Passed, Message)` - Adiciona resultado de um teste
- `PrintResults()` - Imprime o resumo de todos os testes executados
- `PassedCount` - Contagem de testes que passaram
- `FailedCount` - Contagem de testes que falharam

## Como Executar os Testes

### Pré-requisitos

1. O banco de dados deve estar configurado e acessível
2. As tabelas do sistema devem existir
3. Deve haver pelo menos uma empresa configurada (ID=1)

### Compilação e Execução

```bash
# Navegar até o diretório de testes
cd C:\Users\Charles\Documents\ProjetoERP_1\Desktop\src\Tests

# Compilar o test runner
fpc uTestRunner.pas -Fu..\Config -Fu..\Utils -Fu..\Views -Fu..\Models -Fu..\Services

# Executar os testes
uTestRunner.exe
```

Ou usando o Lazarus:
1. Abra o arquivo `uTestRunner.pas`
2. Compile e execute (F9)

## Testes Implementados

### 1. uFrmLoginTest.pas - Testes de Autenticação

**Testes Positivos:**
- `TestAutenticacaoSucesso` - Autenticação com credenciais válidas
- `TestAtualizarUltimoAcesso` - Atualização do timestamp de último acesso

**Testes Negativos:**
- `TestAutenticacaoFalhaSenhaIncorreta` - Falha com senha incorreta
- `TestAutenticacaoFalhaUsuarioInexistente` - Falha com usuário inexistente
- `TestAutenticacaoFalhaUsuarioInativo` - Falha com usuário inativo

### 2. uFrmClientesTest.pas - Testes de CRUD de Clientes

**Testes Positivos:**
- `TestInserirClienteSucesso` - Inserção de cliente com dados válidos
- `TestBuscarClientePorId` - Busca de cliente por ID
- `TestAtualizarCliente` - Atualização de dados do cliente
- `TestListarClientes` - Listagem de todos os clientes
- `TestFiltrarClientesPorNome` - Filtragem de clientes por nome
- `TestExcluirCliente` - Exclusão de cliente

**Testes Negativos:**
- `TestInserirClienteSemNome` - Validação de campo nome obrigatório
- `TestInserirClienteSemCpfCnpj` - Validação de campo CPF/CNPJ obrigatório

### 3. uFrmProdutosTest.pas - Testes de CRUD de Produtos

**Testes Positivos:**
- `TestInserirProdutoSucesso` - Inserção de produto com dados válidos
- `TestBuscarProdutoPorId` - Busca de produto por ID
- `TestAtualizarProduto` - Atualização de dados do produto
- `TestListarProdutos` - Listagem de todos os produtos
- `TestFiltrarProdutosPorDescricao` - Filtragem por descrição
- `TestFiltrarProdutosPorCodigo` - Filtragem por código
- `TestExcluirProduto` - Exclusão de produto

**Testes Negativos:**
- `TestInserirProdutoSemDescricao` - Validação de campo descrição obrigatório
- `TestInserirProdutoPrecoVendaZero` - Validação de preço de venda > 0

### 4. uFrmCategoriasTest.pas - Testes de CRUD de Categorias

**Testes Positivos:**
- `TestInserirCategoriaSucesso` - Inserção de categoria com dados válidos
- `TestBuscarCategoriaPorId` - Busca de categoria por ID
- `TestAtualizarCategoria` - Atualização de dados da categoria
- `TestListarCategorias` - Listagem de todas as categorias
- `TestFiltrarCategoriasPorNome` - Filtragem por nome
- `TestExcluirCategoria` - Exclusão de categoria

**Testes Negativos:**
- `TestInserirCategoriaSemNome` - Validação de campo nome obrigatório

### 5. uFrmUsuariosTest.pas - Testes de CRUD de Usuários

**Testes Positivos:**
- `TestInserirUsuarioSucesso` - Inserção de usuário com dados válidos
- `TestBuscarUsuarioPorId` - Busca de usuário por ID
- `TestAtualizarUsuario` - Atualização de dados do usuário
- `TestListarUsuarios` - Listagem de todos os usuários
- `TestFiltrarUsuariosPorNome` - Filtragem por nome
- `TestExcluirUsuario` - Exclusão de usuário (exceto usuário logado)

**Testes Negativos:**
- `TestInserirUsuarioSemNome` - Validação de campo nome obrigatório
- `TestInserirUsuarioSemLogin` - Validação de campo login obrigatório
- `TestInserirUsuarioSemSenha` - Validação de campo senha obrigatório para novos usuários
- `TestInserirUsuarioSenhaCurta` - Validação de senha com mínimo 6 caracteres

## Dados de Teste

Os testes criam dados temporários no banco de dados:
- Nomes de teste incluem timestamp para evitar conflitos
- Dados são criados e excluídos durante os testes
- Em caso de falha, pode haver dados residuais no banco

## Observações Importantes

1. **Banco de Dados**: Os testes requerem uma conexão ativa com o banco de dados configurado em `uConexao.pas`

2. **Sessão**: O test runner inicializa uma sessão de teste com usuário administrador para executar as operações

3. **Transações**: Os testes usam transações para garantir rollback em caso de erro

4. **Dados Residuais**: Se um teste falhar durante a exclusão, dados de teste podem permanecer no banco

5. **Execução em Produção**: NÃO execute estes testes em ambiente de produção, pois eles modificam dados reais

## Melhorias Futuras

- Implementar mock de banco de dados para não afetar dados reais
- Adicionar testes de integração mais complexos
- Implementar testes de performance
- Adicionar cobertura de código
- Criar testes para as outras telas do sistema

## Suporte

Para dúvidas ou problemas com os testes, verifique:
1. Configuração da conexão em `uConexao.pas`
2. Estrutura das tabelas no banco de dados
3. Logs de erro durante a execução dos testes
