# Configuração por variáveis de ambiente

O ERP 2026 não guarda mais caminho do banco nem segredo JWT no código.
Desktop e API leem a configuração do ambiente do processo, então o mesmo
executável roda em desenvolvimento e em produção sem recompilar.

## Banco de dados (Desktop e API)

| Variável | Padrão | Observação |
|---|---|---|
| `ERP_DB_HOST` | vazio | Vazio usa a conexão local do Firebird. Em servidor, use o IP/nome da máquina do Firebird. |
| `ERP_DB_PATH` | `<pasta do exe>\..\..\Banco\dados.fdb` | Caminho do `.FDB`. Aceita caminho absoluto ou relativo. |
| `ERP_DB_USER` | `SYSDBA` | Usuário do Firebird. |
| `ERP_DB_PASSWORD` | `masterkey` | Senha do Firebird. **Não versionar a senha real.** |
| `ERP_DB_PORT` | `3050` | Porta do Firebird (só é usada quando `ERP_DB_HOST` não está vazio). |

O padrão do caminho é calculado a partir da pasta do executável:
`Desktop\bin` e `API\bin` apontam para `Banco\dados.fdb` na raiz do
projeto. Isso mantém o desenvolvimento funcionando sem variáveis e evita
o caminho absoluto de uma máquina específica.

## API REST

| Variável | Padrão | Observação |
|---|---|---|
| `ERP_JWT_SECRET` | segredo de desenvolvimento | Chave HMAC-SHA256 dos tokens. Mínimo de 32 caracteres em produção. |
| `ERP_JWT_EXPIRACAO_HORAS` | `8` | Validade do token, limitada a 1..720 horas. |
| `ERP_AMBIENTE` | vazio | `producao` ou `production` ativa as travas de produção. |
| `ERP_PRODUCAO` | vazio | `1` é equivalente a `ERP_AMBIENTE=producao`. |
| `ERP_API_POOL` | `8` | Conexões simultâneas com o Firebird, limitada a 2..64. |

Com `ERP_AMBIENTE=producao` (ou `ERP_PRODUCAO=1`) e sem
`ERP_JWT_SECRET` forte, a API **não inicia**: imprime o erro e sai com
código 2. Em desenvolvimento, sem a variável, ela sobe com o segredo
padrão e imprime um aviso no `stderr`.

## Emissão fiscal (Desktop)

| Variável | Observação |
|---|---|
| `ERP_NFE_CERT` | Caminho do certificado A1 (`.pfx`) usado na validação/emissão. |
| `ERP_NFE_SENHA` | Senha do certificado. Evite deixar em script versionado. |
| `ERP_FB_BIN` | Pasta `bin` do Firebird para `gbak` (backup/restauração). |

## Exemplo de produção (Windows)

Em um prompt de administrador, uma vez por máquina:

```bat
setx ERP_AMBIENTE producao
setx ERP_DB_HOST 192.168.0.10
setx ERP_DB_PATH D:\ERP\Banco\dados.fdb
setx ERP_DB_USER ERP_APP
setx ERP_DB_PASSWORD "senha-forte-do-banco"
setx ERP_DB_PORT 3050
setx ERP_JWT_SECRET "uma-chave-aleatoria-com-32-caracteres-ou-mais"
```

Abra um prompt novo depois do `setx` (ele não altera o ambiente atual) e
inicie `API\bin\ERP2026API.exe`.

Para uma sessão apenas, use `set` em vez de `setx`.

## Cuidados

- Não commitar senhas, tokens ou `.env` com valores reais. O `.gitignore`
  já bloqueia `.FDB`, `.fbk` e artefatos de build.
- O segredo JWT é a chave de todos os tokens: trocá-lo invalida as sessões
  ativas dos aplicativos Android.
- A API continua usando HTTP simples; para publicar fora da rede local,
  coloque-a atrás de um proxy HTTPS (IIS, nginx ou similar).
