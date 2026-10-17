# ERP 2026 - Checklist FASE 1: Fundação

## Banco de Dados

- [x] Criar banco de dados Firebird 5 (`dados.fdb`)
- [x] Definir domínios (tipos customizados)
- [x] Criar generators (auto-incremento)
- [x] Criar tabela EMPRESA
- [x] Criar tabela GRUPO
- [x] Criar tabela USUARIO
- [x] Criar tabela PERMISSAO
- [x] Criar tabela CONFIGURACAO
- [x] Criar tabela CATEGORIA
- [x] Criar tabela UNIDADE
- [x] Criar tabela CLIENTE
- [x] Criar tabela FORNECEDOR
- [x] Criar tabela PRODUTO
- [x] Criar tabela ESTOQUE
- [x] Criar tabela MOVIMENTO_ESTOQUE
- [x] Criar tabela FORMA_PAGAMENTO
- [x] Criar tabela CONDICAO_PAGAMENTO
- [x] Criar tabela PEDIDO_VENDA
- [x] Criar tabela ITEM_PEDIDO
- [x] Criar tabela FINANCEIRO
- [x] Criar tabela CONTA_RECEBER
- [x] Criar tabela CONTA_PAGAR
- [x] Criar tabela CAIXA
- [x] Criar tabela MOVIMENTO_CAIXA
- [x] Criar tabela LOG_SISTEMA
- [x] Criar triggers de auto-incremento
- [x] Criar trigger de atualização de estoque
- [x] Criar índices de performance
- [x] Inserir dados iniciais (unidades, formas pagamento, admin)

## Estrutura do Projeto Lazarus

- [x] Criar estrutura de pastas padrão
- [x] Criar unit de conexão (uConexao.pas) - Singleton
- [x] Criar Repository Base (uRepositoryBase.pas)
- [x] Criar Model Base (uModelBase.pas)
- [x] Criar Service Base (uServiceBase.pas)
- [x] Criar Model Cliente (uCliente.pas)
- [x] Criar Model Produto (uProduto.pas)
- [x] Criar Service Cliente (uClienteService.pas)
- [x] Criar Utilitários de Validação (uValidacoes.pas)
- [x] Criar Gerenciador de Sessão (uSessao.pas)

## Documentação

- [x] Documentar arquitetura (padrões, stack, decisões)
- [x] Diagrama ER textual (Mermaid)
- [x] Checklist de entregas
- [x] Plano de testes

## Próximos Passos (FASE 2 - Cadastros)

- [ ] Formulário de Login
- [ ] Formulário principal (menu)
- [ ] CRUD Clientes (form + controller)
- [ ] CRUD Fornecedores
- [ ] CRUD Produtos
- [ ] CRUD Categorias
- [ ] CRUD Usuários
- [ ] Tela de Permissões
- [ ] Configurações da empresa
