# Configuração por empresa (D9)

O app Android guarda, **por empresa**, o endereço do servidor (URL da API) e o
código de usuário. Ao trocar de empresa o app passa a usar a configuração
daquela empresa e pede login novamente.

## Como abrir

- **Tela de login:** botão **Servidor e empresa**.
- **Menu principal:** botão **Configuração (servidor e empresa)** (acima de
  "Sair").

## Campos

| Campo | O que é |
|---|---|
| **Empresa (código)** | identificador da empresa no app (ex.: `MATRIZ`, `FILIAL`). Não diferencia maiúsculas de minúsculas: `filial` e `FILIAL` são a mesma empresa |
| **Caminho do servidor (URL da API)** | endereço do servidor, com ou sem `http://` (ex.: `10.0.2.2:9000` vira `http://10.0.2.2:9000`) |
| **Código do usuário** | código enviado no login como `codigoUsuario` (ver observação abaixo) |

### Qual URL usar

- **Emulador:** `http://10.0.2.2:9000` — `10.0.2.2` é o "localhost" da máquina
  que hospeda o emulador.
- **Aparelho físico:** `http://IP-da-máquina:9000` (descubra o IP com
  `ipconfig`; o aparelho e o PC precisam estar na mesma rede e o firewall deve
  liberar a porta 9000).

A API precisa estar no ar (`Scripts\build_api.bat` gera executável em
`API\bin\ERP2026API.exe`; o servidor escuta na porta **9000**).

## Botões

- **Testar conexão:** faz `GET <url>/` e mostra o resultado. Qualquer resposta
  HTTP (inclusive 404) significa que há um servidor no endereço — a API não
  possui rota de health, então a raiz responde 404.
- **Salvar:** grava a configuração da empresa. A **primeira** empresa salva
  passa a ser a empresa em uso.
- **Usar esta empresa:** define a empresa selecionada como atual, aplica a URL
  no cliente da API e **encerra a sessão** (o token anterior vale para o
  servidor antigo). Volte ao login e entre novamente.
- **Excluir:** remove a empresa selecionada. Se for a empresa em uso, o app
  volta ao login e passa a usar a URL padrão.

## Onde os dados ficam

`SharedPreferences` do aparelho, arquivo `erp2026_config.xml`:

```
empresaAtual        -> código da empresa em uso
empresas            -> conjunto de códigos cadastrados
url_<EMPRESA>       -> URL normalizada (http://host:porta)
codigo_<EMPRESA>    -> código do usuário
```

Nada disso vai para o banco de dados nem para o repositório: cada aparelho tem
a sua configuração. Para inspecionar no emulador:

```powershell
adb shell run-as com.example.erp2026_mobile cat shared_prefs/erp2026_config.xml
```

## Sem configuração

O app continua funcionando como antes: usa `http://10.0.2.2:9000` e o login
envia apenas `login` e `senha`. Configurar uma empresa é opcional.

## Observação sobre "código de usuário"

A API (`POST /api/login`) hoje valida apenas `login`/`senha` e **ignora campos
extras**. O app envia `codigoUsuario` junto no corpo do login; quando a API
passar a usar esse campo (validação por empresa, por exemplo), o app já estará
enviando o valor. Se o significado de "código de usuário" for outro (matrícula,
código do vendedor etc.), basta ajustar o campo no `MainActivity` e a chave
`codigo_<EMPRESA>` em `Configuracao.java`.

## Verificação rápida (emulador)

1. Suba a API na máquina e abra o app.
2. **Servidor e empresa** → preencha empresa, URL e código.
3. **Testar conexão** → deve responder "Servidor alcançável (HTTP 404)".
4. **Salvar** → a empresa aparece no topo e no status.
5. **Usar esta empresa** → o app volta ao login mostrando a empresa.
6. Entre com `admin` / `admin123` → o título do menu mostra `ERP 2026 - EMPRESA`.
7. Feche e reabra o app → a configuração continua aplicada.
