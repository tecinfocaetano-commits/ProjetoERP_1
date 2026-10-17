# Usuários Disponíveis no ERP 2026

## Usuário SYSDBA (Admin do Firebird)

**Credenciais:**
- Usuário: `SYSDBA`
- Senha: `masterkey`

**Permissões:**
- Acesso total ao banco de dados
- Pode criar/drop tabelas
- Pode gerenciar usuários
- Superusuário do Firebird

**Observação:**
A senha SYSDBA/masterkey foi verificada e está funcionando. Se você esqueceu a senha do aplicativo ERP, use estas credenciais.

## Usuário do Aplicativo ERP

**Credenciais no Banco:**
A tabela USUARIO no banco DADOS.FDB contém os usuários do aplicativo.

**Senha Padrão:**
- O sistema usa criptografia na senha
- Se criou um usuário anteriormente, verifique qual senha definiu

## Como Resetar Senha do Usuário do Aplicativo

### Opção 1: Via FlameRobin (GUI)
1. Abra FlameRobin
2. Conecte ao banco DADOS.FDB
3. Navegue para a tabela USUARIO
4. Localize o usuário
5. Atualize a senha diretamente

### Opção 2: Via SQL
```sql
UPDATE USUARIO
SET SENHA = 'nova_senha_criptografada'
WHERE LOGIN = 'usuario';
COMMIT;
```

### Opção 3: Criar Novo Usuário no Aplicativo
1. Abra o ERP2026
2. Faça login como SYSDBA/masterkey
3. Vá em Usuários
4. Crie um novo usuário com senha conhecida

## Verificação de Conexão

✅ Conexão com SYSDBA/masterkey: **FUNCIONANDO**
✅ Banco DADOS.FDB: **ACESSÍVEL**
✅ Serviço Firebird: **RODANDO**

## Próximos Passos

Use SYSDBA/masterkey para acessar o sistema e:
1. Criar ou resetar usuários do aplicativo
2. Executar a simulação de produção
3. Realizar testes
