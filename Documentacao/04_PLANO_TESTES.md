# ERP 2026 - Plano de Testes - FASE 1

## 1. Testes de Banco de Dados

### 1.1 Criação de Estrutura
| # | Teste | Resultado Esperado |
|---|-------|-------------------|
| 1 | Executar 002_domains.sql | Domínios criados sem erro |
| 2 | Executar 003_generators.sql | Generators criados |
| 3 | Executar 004_tables.sql | Todas as tabelas criadas |
| 4 | Executar 005_triggers.sql | Triggers compiladas |
| 5 | Executar 006_indexes.sql | Índices criados |
| 6 | Executar 007_initial_data.sql | Dados iniciais inseridos |

### 1.2 Integridade Referencial
| # | Teste | Resultado Esperado |
|---|-------|-------------------|
| 1 | Inserir USUARIO sem EMPRESA | FK violation |
| 2 | Inserir PRODUTO sem EMPRESA | FK violation |
| 3 | Deletar EMPRESA com USUARIOS | FK violation |
| 4 | Inserir CLIENTE com EMPRESA válida | Sucesso |
| 5 | Inserir LOGIN duplicado | UQ violation |

### 1.3 Triggers de Auto-Incremento
| # | Teste | Resultado Esperado |
|---|-------|-------------------|
| 1 | INSERT CLIENTE sem ID | ID gerado automaticamente |
| 2 | INSERT PRODUTO sem ID | ID gerado automaticamente |
| 3 | INSERT com DATA_CADASTRO null | Timestamp atual preenchido |

### 1.4 Trigger de Estoque
| # | Teste | Resultado Esperado |
|---|-------|-------------------|
| 1 | INSERT MOVIMENTO_ESTOQUE tipo 'E' | ESTOQUE.QUANTIDADE incrementada |
| 2 | INSERT MOVIMENTO_ESTOQUE tipo 'S' | ESTOQUE.QUANTIDADE decrementada |
| 3 | INSERT MOVIMENTO_ESTOQUE produto novo | Registro ESTOQUE criado |

## 2. Testes de Conexão (Lazarus)

| # | Teste | Resultado Esperado |
|---|-------|-------------------|
| 1 | TConexao.GetInstance | Singleton retornado |
| 2 | TConexao.Conectar | Conexão estabelecida |
| 3 | TConexao.Conectar com dados errados | Exception com msg clara |
| 4 | TConexao.IniciarTransacao | Transação ativa |
| 5 | TConexao.Confirmar | Commit executado |
| 6 | TConexao.Cancelar | Rollback executado |

## 3. Testes de Repository

| # | Teste | Resultado Esperado |
|---|-------|-------------------|
| 1 | BuscarPorId existente | Registro retornado |
| 2 | BuscarPorId inexistente | Query vazia |
| 3 | BuscarTodos sem filtro | Todos os registros |
| 4 | BuscarTodos com filtro | Registros filtrados |
| 5 | Inserir registro válido | ID retornado > 0 |
| 6 | Atualizar registro | True retornado |
| 7 | Excluir registro | True retornado |
| 8 | Contar registros | Número correto |
| 9 | Existe com ID válido | True |
| 10 | Existe com ID inválido | False |

## 4. Testes de Validação

| # | Teste | Resultado Esperado |
|---|-------|-------------------|
| 1 | ValidarCPF('111.444.777-35') | True |
| 2 | ValidarCPF('111.111.111-11') | False |
| 3 | ValidarCPF('123') | False |
| 4 | ValidarCNPJ('11.222.333/0001-81') | True |
| 5 | ValidarCNPJ('00.000.000/0000-00') | False |
| 6 | ValidarEmail('teste@email.com') | True |
| 7 | ValidarEmail('invalido') | False |
| 8 | FormatarCPF('11144477735') | '111.444.777-35' |
| 9 | FormatarCNPJ('11222333000181') | '11.222.333/0001-81' |
| 10 | FormatarTelefone('11999887766') | '(11) 99988-7766' |

## 5. Testes de Service (ClienteService)

| # | Teste | Resultado Esperado |
|---|-------|-------------------|
| 1 | Inserir cliente válido | ID retornado |
| 2 | Inserir sem Nome | Exception 'campo obrigatório' |
| 3 | Inserir sem CPF/CNPJ | Exception 'campo obrigatório' |
| 4 | Inserir CPF duplicado | Exception 'já existe' |
| 5 | Atualizar cliente válido | True |
| 6 | Atualizar ID inexistente | Exception 'não encontrado' |
| 7 | Excluir cliente válido | True |
| 8 | Pesquisar por nome | Registros retornados |

## Como Executar

### Banco
```sql
-- No isql ou IBExpert, executar em ordem:
-- 002_domains.sql → 003_generators.sql → 004_tables.sql →
-- 005_triggers.sql → 006_indexes.sql → 007_initial_data.sql
```

### Lazarus
```
1. Abrir projeto no Lazarus
2. Compilar (Ctrl+F9)
3. Executar testes unitários (se configurados)
4. Testar conexão manualmente na tela de login
```
