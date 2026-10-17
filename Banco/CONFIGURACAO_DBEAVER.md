# Guia de Configuração do DBeaver para Banco Firebird

## Passo 1: Baixar Driver Firebird

1. Abra o DBeaver
2. Vá em: **Database** → **Driver Manager**
3. Na lista de drivers, encontre **Firebird**
4. Clique em **Download/Update Driver**
5. Selecione a versão mais recente
6. Clique em **Download**
7. Aguarde o download completar
8. Clique em **OK**

## Passo 2: Criar Nova Conexão

1. Clique no ícone "New Database Connection" (database com sinal de +) na barra de ferramentas
2. Ou pressione `Ctrl + N`
3. Na lista de bancos de dados, selecione **Firebird**
4. Clique em **Next**

## Passo 3: Configurar os Parâmetros de Conexão

### **Página: Main (Geral)**

**Path/URL (Caminho do banco):**
```
C:\Users\Charles\Documents\ProjetoERP_1\Banco\dados.fdb
```

**User (Usuário):**
```
SYSDBA
```

**Password (Senha):**
```
masterkey
```

**Host (Servidor):**
```
localhost
```

**Port (Porta):**
```
3050
```

### **Página: Driver Settings (Configurações do Driver)**

1. Clique na aba **Driver settings**
2. Na seção **Connection properties**, adicione as seguintes propriedades:

**Nova Propriedade:**
- **Name:** `authPluginName`
- **Value:** `Legacy_Auth`

Clique em **Add** para adicionar cada propriedade.

## Passo 4: Testar a Conexão

1. Clique no botão **Test Connection** (ícone de conexão)
2. Se aparecer a mensagem "Connected successfully", clique em **OK**
3. Se der erro, verifique:
   - Se o serviço Firebird está rodando
   - Se o caminho do arquivo dados.fdb está correto
   - Se a senha está correta
   - Se a propriedade `authPluginName` está configurada como `Legacy_Auth`

## Passo 5: Salvar a Conexão

1. Dê um nome para a conexão (ex: "ERP2026")
2. Clique em **Finish**

## Verificar o Serviço Firebird

Antes de configurar, verifique se o serviço Firebird está rodando:

1. Pressione `Win + R`, digite `services.msc` e pressione Enter
2. Procure por "FirebirdServerDefaultInstance" ou "Firebird Guardian"
3. Verifique se o status é "Running"
4. Se não estiver, clique com botão direito → Start

## Acessar o Banco Após Configuração

1. No painel "Database Navigator" (esquerda), expanda a conexão criada
2. Você verá todas as tabelas do banco:
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

## Executar Queries SQL

1. Clique com botão direito na conexão
2. Selecione "SQL Editor" → "New SQL Script"
3. Ou pressione `Alt + Q`

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

- **Host:** localhost
- **Porta:** 3050
- **Banco:** C:\Users\Charles\Documents\ProjetoERP_1\Banco\dados.fdb
- **Usuário:** SYSDBA
- **Senha:** masterkey
- **Auth Plugin:** Legacy_Auth

## Troubleshooting

### Erro: "The specified driver 'firebird_jaybird' could not be found"
- Solução: Baixe o driver Firebird conforme Passo 1 acima

### Erro: "Connection refused"
- Verifique se o serviço Firebird está rodando
- Verifique se a porta 3050 não está bloqueada pelo firewall

### Erro: "Unable to complete network request"
- Verifique o caminho do arquivo dados.fdb
- Verifique se o arquivo existe e não está corrompido

### Erro: "Your user name and password are not defined"
- Verifique se a propriedade `authPluginName` está configurada como `Legacy_Auth`
- Reinicie o serviço Firebird após alterar a configuração

### Erro: "Client attempted to attach unencrypted but wire encryption is required"
- Se este erro persistir mesmo com `authPluginName=Legacy_Ath`, pode ser necessário:
  - Desabilitar criptografia no firebird.conf (não recomendado para produção)
  - Ou usar versão mais recente do driver Jaybird que suporta criptografia

