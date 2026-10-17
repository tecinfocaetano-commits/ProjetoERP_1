# 📱 Simulação de Inserção pelo App Android

## 🎯 Objetivo

Inserir um novo cliente usando o app Android e sincronizar com o banco de dados Firebird.

## 📋 Passo a Passo

### 1. Abrir o App Android
O app deve estar aberto no emulador Pixel 9.

### 2. Fazer Login
- Usuário: `admin`
- Senha: `admin123`
- Clique em **Login**

### 3. Navegar para o Dashboard
Após o login, você verá o Dashboard com os botões:
- Clientes
- **Inserir Cliente** (botão verde)
- Estoque
- Vendas
- Financeiro

### 4. Clicar em "Inserir Cliente"
Clique no botão verde **"Inserir Cliente"** para abrir a tela de cadastro.

### 5. Preencher os Dados do Cliente

**Campos obrigatórios:**
- **Nome:** Ex: "João Santos Android"
- **CPF/CNPJ:** Ex: "987.654.321-00"

**Campos opcionais:**
- **Endereço:** Ex: "Av. Brasil, 500"
- **Cidade:** Ex: "Rio de Janeiro"
- **UF:** Ex: "RJ"
- **CEP:** Ex: "20000-000"
- **Telefone:** Ex: "(21) 98888-8888"
- **Email:** Ex: "joao.android@teste.com"

### 6. Clicar em "Salvar Cliente"
- O app mostrará: "Conectando ao banco..."
- Em seguida: "Inserindo cliente..."
- Após sucesso: "✅ Cliente inserido com sucesso! ID: XXXX"
- O sistema gerará um ID único automaticamente

### 7. Verificar no Banco de Dados

**Via SQL:**
```sql
SELECT ID, NOME, CPF_CNPJ, ENDERECO, CIDADE, UF, CEP, TELEFONE, EMAIL, ATIVO
FROM CLIENTE
WHERE ID > 999
ORDER BY ID DESC;
```

**Via Desktop ERP2026:**
1. Abra a tela de Clientes
2. O cliente inserido pelo Android deve aparecer na lista
3. Verifique os dados: Nome, CPF, Endereço, etc.

## 🔗 Sincronização Real

**Fluxo de Sincronização:**
```
App Android (Emulador)
    ↓ Usuário preenche formulário
    ↓ Clica em Salvar
    ↓ DatabaseHelper.connect()
    ↓ INSERT via JDBC Jaybird
    ↓ Firebird Database (localhost:3050)
    ↓ Cliente gravado no banco
    ↓
Desktop ERP2026
    ↓ Pode consultar o cliente
    ↓ Dados sincronizados em tempo real
```

## ✅ Validação

**App Android:**
- Mensagem de sucesso com ID gerado
- Campos limpos após inserção

**Banco de Dados:**
- Cliente aparece na tabela CLIENTE
- ID > 999 (gerado pelo Android)
- Todos os campos preenchidos corretamente

**Desktop ERP:**
- Cliente aparece na lista de clientes
- Dados consistentes com o inserido pelo Android

## 🎯 Cenário Real Simulado

**Situação:**
Um vendedor usando o app Android cadastra um novo cliente durante uma visita.

**Ações:**
1. Vendedor abre o app no celular
2. Faz login
3. Navega para "Inserir Cliente"
4. Preenche os dados do cliente
5. Salva
6. Cliente é gravado no banco central
7. Desktop pode consultar o cliente imediatamente

**Resultado:**
- ✅ Cliente cadastrado remotamente
- ✅ Dados sincronizados com banco central
- ✅ Desktop acessa os dados em tempo real
- ✅ Integração Android-Firebird funcionando

## 📊 Monitoramento

**Para verificar a inserção:**
```powershell
# Verificar clientes inseridos pelo Android
& "C:\Program Files\Firebird\Firebird_5_0\isql.exe" -user SYSDBA -password masterkey "C:\Users\Charles\Documents\ProjetoERP_1\Banco\DADOS.FDB" -i "C:\Users\Charles\Documents\ProjetoERP_1\verificar_cliente_android.sql"
```

**Pronto para testar a inserção pelo app Android!** 🚀
