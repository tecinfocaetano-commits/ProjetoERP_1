# BACKLOG ANDROID — prompt pronto para retomada (D9)

> Documento de transferência. Serve para retomar a **parte Android** depois de
> concluído o backlog desktop (itens 5–9). Não é para executar agora.
>
> Contexto: `Android\android` (projeto Android Studio, Java, sem dependências
> externas além do `org.json`).

---

## 1. Situação atual do app (conferida em 01/11/2026)

- Pacote: `com.example.erp2026_mobile`.
- Telas: `MainActivity` (login), `DashboardActivity`, `ClientesActivity`,
  `ConsultarClientesActivity`, `InserirClienteActivity`, `EstoqueActivity`,
  `VendasActivity`, `FinanceiroActivity`.
- `ApiClient.java`: HTTP via `HttpURLConnection`; **`BASE_URL` é uma constante
  fixa** `http://10.0.2.2:9000`; token em campo estático; `get/post/request`.
- `Sessao.java`: `SharedPreferences` `"erp2026"` com `token` e `nome`;
  `restaurar`, `guardar`, `encerrar`, `ativa`, `tratarSessaoExpirada`.
- `MainActivity`: login em `POST /api/login` (`{"login","senha"}`) → guarda
  `token` + `nome`; se `Sessao.ativa(this)` vai direto ao dashboard.
- Manifest: `INTERNET`, `ACCESS_NETWORK_STATE`, `usesCleartextTraffic="true"`,
  `android:theme="@style/Theme.Erp2026"` (Material You).

---

## 2. Objetivo do D9 (decisão do usuário, 31/10/2026)

Criar a **tela de configuração por empresa**: o usuário informa

1. **caminho do servidor** (URL da API, ex.: `http://192.168.0.10:9000`), e
2. **código de usuário** (código que identifica o usuário naquela empresa);

e a configuração é gravada **separadamente por empresa** — ou seja, cada
empresa tem a sua própria URL + código de usuário; trocar de empresa no app
troca a configuração usada nas chamadas.

---

## 3. Prompt para o próximo agente

Copie o bloco abaixo como pedido inicial.

```
Continue o app Android do ERP 2026 em C:\Users\Charles\Documents\ProjetoERP_1\Android\android
(Java, Android Studio, pacote com.example.erp2026_mobile).

TAREFA (D9): tela de configuração por empresa com caminho do servidor (URL da
API) e código de usuário, salvos separadamente por empresa.

Regras:
- Preserve todos os android:id existentes (telas atuais e layouts atuais).
- Sem dependências novas: Java + org.json + SharedPreferences nativos.
- Não mexa nas regras de negócio do desktop/API; o app só consome a API.
- Português nos textos de tela e nas mensagens.
- Ao terminar: entregar o diff, dizer como compilar e quais passos de teste
  manual o usuário deve seguir.

Entregáveis:
1. `Configuracao.java` (modelo + persistência em SharedPreferences):
   - chave por empresa: `empresa` (código/nome curto da empresa);
   - campos: `urlServidor` e `codigoUsuario`;
   - operações: `salvar`, `carregar(empresa)`, `listarEmpresas`,
     `remover(empresa)`, `empresaAtual()` / `definirEmpresaAtual(codigo)`.
   - normalização da URL: aceitar "192.168.0.10:9000", "http://host:porta",
     "host/erp"; sempre terminar sem barra final.
2. `ApiClient`: a URL base deixa de ser a constante fixa. Use
   `ApiClient.setBaseUrl(url)` / `ApiClient.getBaseUrl()`, com fallback para
   `http://10.0.2.2:9000` (emulador) quando ainda não houver configuração.
   `BASE_URL` atual pode continuar existindo como constante padrão.
3. `ConfiguracaoActivity` + `activity_configuracao.xml`:
   - spinner/lista de empresas já configuradas + "Nova empresa";
   - campos: código da empresa, URL do servidor, código de usuário;
   - botão "Testar conexão" -> `GET /api/health` (ou `/api/ping`) na URL
     informada, com timeout curto, mostrando Sucesso/Falha sem travar a UI
     (Thread + runOnUiThread, como em MainActivity.autenticar);
   - botões Salvar, Excluir e "Usar esta empresa";
   - validação: URL obrigatória com esquema http/https e host; código de
     usuário obrigatório; empresa obrigatória; mensagens claras.
4. `MainActivity`:
   - carregar a empresa atual ao abrir; se houver configuração, mostrar no
     rodapé "Empresa: X — servidor: Y" (TextView novo, sem remover ids atuais);
   - botão de engrenagem (ícone) abrindo `ConfiguracaoActivity`;
   - no login (`POST /api/login`), enviar também o código de usuário
     configurado (`{"login","senha","codigoUsuario"}`) — o campo extra deve ser
     aceito pela API sem quebrar as rotas atuais; se a API ainda não usar,
     o app deve continuar funcionando;
   - ao trocar de empresa, limpar a sessão (Sessao.encerrar) e voltar ao login.
5. `DashboardActivity`: item de menu "Configuração" abrindo a nova tela.
6. Manifest: registrar `.ConfiguracaoActivity`.
7. Documentar no README.md do Android: como configurar, exemplo de URL para
   emulador (10.0.2.2) e para aparelho físico (IP da máquina na rede local;
   a API precisa escutar em 0.0.0.0), e o passo de teste.

Critérios de aceite:
- Dois cadastros de empresa com URLs diferentes ficam gravados e sobrevivem a
  fechar/abrir o app; trocar a empresa atual troca a URL usada por ApiClient.
- "Testar conexão" informa sucesso/falha sem travar a interface.
- Login continua funcionando com a configuração padrão quando nada foi
  cadastrado (comportamento atual preservado).
- Nenhum android:id existente é removido ou renomeado.
- `./gradlew :app:assembleDebug` compila sem erro.

Antes de começar: confirmar com o usuário o significado exato de "código de
usuário" (código do usuário para login automático? matrícula/crachá usado no
app? identificador da empresa?). Implementar a interpretação confirmada.
```

---

## 4. Pontos a confirmar com o usuário

1. **"Código de usuário"** — é (a) o login curto usado no app, (b) um código
   de operador/crachá já cadastrado no desktop, ou (c) um identificador da
   empresa? O prompt acima assume (a) e envia o campo extra no login.
2. A API precisa de rota de health check (`/api/health`)? Hoje o `ApiClient`
   só usa `/api/login` e as rotas de listagem; se não existir, usar
   `GET /api/clientes` apenas para teste de conectividade.
3. A configuração deve ser sincronizada do desktop ou é local do aparelho
   (SharedPreferences)? O D9 diz "salvos por empresa" — a proposta é local.
