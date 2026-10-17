# Guia Rápido: Configurar Banco no FlameRobin

## Passo 1: Criar Nova Conexão

1. No FlameRobin, clique em **Database** → **Register Existing Database**
2. Ou clique no ícone de servidor verde com sinal de +

## Passo 2: Configurar Parâmetros

**Na aba "Connection":**
- **Server:** `localhost`
- **Port:** `3050`
- **Database:** `C:\Users\Charles\Documents\ProjetoERP_1\Banco\dados.fdb`
- **Username:** `SYSDBA`
- **Password:** `masterkey`

**Na aba "Advanced":**
- **Auth Plugin:** `Legacy_Auth` (ou desmarque "Use Encryption")

## Passo 3: Testar Conexão

1. Clique no botão **Test Connection**
2. Se aparecer "Connected successfully", clique em **Register**
3. Se der erro, verifique:
   - Se o serviço Firebird está rodando
   - Se o caminho do arquivo dados.fdb está correto
   - Se a senha está correta

## Passo 4: Acessar o Banco

1. No painel esquerdo, expanda a conexão criada
2. Você verá todas as tabelas:
   - EMPRESA
   - USUARIO
   - GRUPO
   - CLIENTE
   - FORNECEDOR
   - PRODUTO
   - CATEGORIA
   - UNIDADE
   - ESTOQUE
   - PEDIDO_VENDA
   - CONTA_PAGAR
   - CONTA_RECEBER
   - CAIXA
   - Etc.

## Passo 5: Executar Queries

1. Clique com botão direito na conexão
2. Selecione **SQL Editor** → **New SQL Script**
3. Digite sua query SQL
4. Pressione F9 para executar

## Exemplo de Query

```sql
-- Listar todos os usuários
SELECT * FROM USUARIO;

-- Listar todos os clientes ativos
SELECT * FROM CLIENTE WHERE ATIVO = 'A';

-- Listar todos os produtos
SELECT * FROM PRODUTO;
```

## Resumo das Credenciais

- **Server:** localhost
- **Port:** 3050
- **Database:** C:\Users\Charles\Documents\ProjetoERP_1\Banco\dados.fdb
- **Username:** SYSDBA
- **Password:** masterkey
- **Auth Plugin:** Legacy_Auth

## Se o FlameRobin Não Funcionar

1. Verifique se o serviço Firebird está rodando:
   - Pressione Win + R → digite `services.msc`
   - Procure "FirebirdServerDefaultInstance"
   - Se não estiver "Running", clique com botão direito → Start

2. Tente usar o DBeaver seguindo o guia completo:
   - C:\Users\Charles\Documents\ProjetoERP_1\Banco\CONFIGURACAO_DBEAVER.md
