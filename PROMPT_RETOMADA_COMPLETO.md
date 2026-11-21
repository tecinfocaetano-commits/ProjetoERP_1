# PROMPT COMPLETO DE RETOMADA — ERP 2026 (após reinício da máquina)

> **Copie o bloco abaixo numa nova sessão.** Ele é autocontido: não depende de
> conversa anterior. Se houver conflito com outro prompt, **o disco vence** —
> rode `git log`/`git status` e leia `Documentacao\COMUNICACAO_AGENTES.md`.
>
> Outros prompts complementares (não substituem este):
> - `Documentacao\PROMPT_CONTINUACAO_PDV.md` e
>   `Documentacao\PROMPT_EXECUCAO_PAGAMENTOS.md` — trabalho do outro agente
>   (PDV/pagamentos). **Não são nossos; não executar sem autorização.**
> - `PROMPT_TESTES_FISCAIS_GRATUITOS.md` — bateria local/gratuita já pronta.

---

## 1. Quem somos e como trabalhamos

Projeto: `C:\Users\Charles\Documents\ProjetoERP_1` — ERP 2026:
Lazarus/FPC + Firebird 5 no desktop, API REST Horse, apps Android `:app`,
`:bipe` e `:pdv`. **Equipe de especialistas; nos comunicamos por prompt e,
principalmente, por `Documentacao\COMUNICACAO_AGENTES.md`.**

Regras obrigatórias:

1. Responder sempre em **português**; toda resposta normal termina com
   **exatamente 3 linhas**: `Feito` / `Falta` / `Próximo passo`.
2. Atualizar `CHECKPOINT.md` e `Documentacao\PLANO_E_LOG.md` **por marco**
   (não a cada resposta). **Todo commit de marco é seguido de
   `git push origin master`** (GitHub privado
   `tecinfocaetano-commits/ProjetoERP_1`).
3. **Ler e escrever `Documentacao\COMUNICACAO_AGENTES.md`** no início e no fim
   de cada bloco, antes de mexer em arquivo compartilhado, antes de
   parar/reiniciar a API e de tempos em tempos — mesmo que seja só
   "sem novidades". Se o usuário disser "se precisar consulte COMUNICACAO_AGENTES",
   **ler na hora**.
4. **Avisar antes de instalar dependências** e **antes de parar/reiniciar a
   API** (o usuário autoriza reinícios com aviso). Avisar no canal com PID.
5. Preservar todos os `android:id`. **Não editar** `Android\android\bipe\**`,
   `HistoricoActivity.java`, nem o cenário fiscal **talão 533 / mapa 1014 /
   pedido 3581** (`CEN-FISCAL-01`).
6. **Não tocar** em `Android\android\pdv\**`, `Android\android\settings.gradle`,
   `API\src\Rotas\uRotasPDV.pas`, `uMiddlewareJWT.pas`,
   `uMiddlewareSessao.pas`, `uPagamentoService.pas` nem incluir `:pdv` em
   bateria/CI/docs **sem autorização explícita do usuário**. Rotina do `:pdv`
   suspensa até lá.
7. Regras técnicas: SQL sempre parametrizado; regra de negócio em **Services**;
   transação + auditoria via `LogOperacao`; LazReport apenas; Firebird 5 —
   identificadores **≤31 chars**, `DEFAULT` **antes** de `NOT NULL`,
   **nunca** `ALTER ... RENAME`; `build_tests.bat` usa `lazbuild -B`.
   Não reescrever/`git checkout` em arquivo não commitado sem ler antes.
8. `tmp_shots/` fica **untracked** e nunca é commitado. Certificados `.pfx`,
   senhas e `Desktop\bin\nfe\*` também não entram no git.

---

## 2. Estado atual (21/11/2026 — gravado após o marco 3.86)

- **HEAD esperado:** `3672290` (canal) e, logo atrás, `9fa4a87` (código+docs do marco
  3.86), `1313eff`, `09024b6` (docs/canal), `d580eb4`, `3f74ee5`, `5e4e527`
  (outro agente). **Rode `git log --oneline -8` e `git status --short`:**
  se o disco estiver diferente, o disco vence.
- **API estável — problema resolvido:** antes `/api/health` dizia `ok` mas
  `/api/login` devolvia `TIBConnection : DoInternalConnect : -connection shutdown`.
  Causa: `TConexaoPool.Devolver` destruía a `TIBConnection` a cada request;
  com 20 threads o fbclient local entrava em `connection shutdown`.
  Correção em `API\src\Config\uConexao.pas`: `Devolver` devolve a conexão
  **viva** (cancela só a transação), `Obter` faz ping real (`SELECT 1`) e
  renova o socket, `Conectar` tem retry. `API\ERP2026API.lpr`: health com
  `"banco":"ok"` e **503** quando o banco falha. Validação: 60/60 logins
  concorrentes (20 simultâneos, `KeepAlive=false`), 0 exceções, PID estável;
  6 smokes OK; suíte 385/385. **Não reabrir esse bug.**
- Últimos marcos: 3.86 (API/pool + prompt fiscal), 3.85 (esqueleto de
  pagamentos do outro agente), 3.84 (cupom PDF `:pdv`), 3.83 (D10/CI),
  3.82 (app `:pdv`), 3.81 (homologação), 3.80 (`:bipe`), F9 (3.78), F1 (3.79).
- Bateria esperada após o reboot: desktop **385/385**, `build_api.bat` **OK**
  (pare a API antes de compilar), Android **9/9**, `build_bipe.bat` **OK**,
  telas **33/33**, permissões **0 falhas**, schema/banco fresco **OK**,
  `api_todos.ps1` **6 smokes OK**. Ruído conhecido: `InitializeFppkg failed`.
- Outro agente: pagamentos eletrônicos PDV (Fase 0 no ar, webhook idempotente
  validado em `d580eb4`), escreveu `Documentacao\PROMPT_CONTINUACAO_PDV.md`
  e `Documentacao\PROMPT_EXECUCAO_PAGAMENTOS.md`. Pode seguir no app `:pdv`;
  se pedir janela de rebuild, **avisar no canal antes de parar/subir a API**.

---

## 3. Checklist imediato pós-reinício da máquina

1. `cd C:\Users\Charles\Documents\ProjetoERP_1`
2. `git log --oneline -8` e `git status --short` (confirmar HEAD acima;
   **não** commitar `tmp_shots/` nem arquivos do outro agente).
3. Ler `Documentacao\COMUNICACAO_AGENTES.md` e `CHECKPOINT.md`; escrever no
   canal: "máquina reiniciada, retomando bloco X".
4. Subir o Firebird se necessário:
   `Get-Service Firebird* | Select Name,Status` (esperado `Running`).
5. Subir a API **só depois de avisar no canal**:
   `Remove-Item Env:ERP_DB_PATH -ErrorAction SilentlyContinue`;
   `Start-Process 'API\bin\ERP2026API.exe' -WorkingDirectory 'API\bin'`.
   Conferir `Invoke-RestMethod http://localhost:9000/api/health` →
   `"status":"ok"` **e** `"banco":"ok"` (se 503, ler o campo `banco`).
   Registrar o novo PID no canal. **O PID 18576 era da sessão anterior e
   não sobrevive ao reboot.**
6. Rodar a bateria curta:
   `powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\api_todos.ps1`
   e `Scripts\run_tests.bat` (385/385).

---

## 4. Decisões já tomadas — não reabrir

- **Homologação reusa `CONFIGURACAO`:** ativa = `NFE_AMBIENTE=2` +
  `NFE_MODO=REAL`; desativada = `NFE_MODO=SIMULADO`, mantendo o ambiente.
  Sem tabela/estado redundante.
- **Homologação real está bloqueada:** exige CNPJ/IE regulares, e-CNPJ A1
  ICP-Brasil, habilitação na SEFAZ e IdCSC/CSC. Usuário não tem cliente
  real/MEI e **não quer usar dados de terceiros**. Certificados autoassinados
  (local `C:\certificados\teste.pfx` / senha `teste123`, e kit em
  `C:\Users\Charles\AppData\Local\Temp\opencode\cert_kit\` / senha `123456`)
  servem **só** para assinar e validar XML/DANFE localmente — **nunca** SEFAZ.
- **Testes fiscais por ora apenas locais/gratuitos:** usar pedido **1003**
  (`PV-TESTE-5`); **nunca** 3581 / `CEN-FISCAL-01`. Ver
  `PROMPT_TESTES_FISCAIS_GRATUITOS.md`.
- PDF gerado localmente é DANFE/cupom **off-line, sem protocolo**; não é
  cupom NFC-e autorizado. API PDV fase 1 não emite NFC-e — emissão fiscal
  continua no desktop.
- D10 CI `self-hosted` **não recompila nem reinicia** a API.
- `PROMPT_TESTES_FISCAIS_GRATUITOS.md` já registra (§5 e §6) o plano de
  NFS-e e de nota de entrada de serviços — **agora o usuário pediu para
  transformar esses planos em trabalho concreto na próxima sessão** (§5 abaixo).

---

## 5. TRABALHO FISCAL PENDENTE — pedido literal do usuário nesta sessão

> "lembrando de tudo que solicitei como notas preparada para nota de serviço
> diverso e geração xml e também as notas de entradas e importação de xml, na
> importação do xml na nota de entrada verificar se um produto ja existe se ele
> não existir abrir uma tela para o usuário escolher um produto compatível ou
> cadastrar um novo, ter um tabela de importação xml para salvar o cnpj do
> fornecedor a descrição original da nota e produto da nota e a classificação
> fiscal que veio"

Traduzido em 3 frentes (implementar nesta ordem, com marcos separados):

### 5.1 Nota de serviço diverso + geração de XML

- Preparar o ERP para **notas de serviço diverso** (serviços em geral,
  comunicação/internet, notas municipais), sem estoque e sem NF-e de produtos.
- **Gerar XML localmente** no padrão adequado (NFS-e nacional 2026 como
  adapter principal; adapters legados por **Código do provedor** —
  `SIGCORP`, `BETA`, `NACIONAL`, `OUTRO`), com:
  - preferências em `CONFIGURACAO`: `NFSE_PROVEDOR`,
    `NFSE_MUNICIPIO_IBGE`, `NFSE_INSCRICAO_MUNICIPAL`, `NFSE_AMBIENTE`,
    `NFSE_MODO` (`SIMULADO`/`REAL`, igual NF-e), `NFSE_SERIE`,
    `NFSE_RPS_SEQUENCIA`; senha/token **nunca em claro no banco**;
  - `TNFSeHelper` paralelo ao `TACBrHelper`: `GerarRPS`, `Emitir`,
    `Consultar`, `Cancelar`, `GerarPDF`, `GerarXML`;
  - retenções de ISS (e PIS/COFINS/INSS conforme regime), código de
    serviço/CMC e município do fato gerador;
  - **nenhum envio à SEFAZ/prefeitura** enquanto `NFSE_MODO=SIMULADO`;
    validar o XML contra schemas locais e assinar com certificado de teste;
  - auditoria `LOG_SISTEMA` com provedor, ambiente, chave/RPS e resultado;
    dedupe por chave + provedor.
- Critério de aceite: XML de serviço gerado, assinado e validado **off-line**;
  teste novo na suíte sem quebrar os 385 atuais; nada é enviado.

### 5.2 Nota de entrada — importação de XML com resolução de produto

Hoje `TNFeXmlParser.DeTexto` exige `<infNFe>` e `TNFeImportService.Importar`
grava `Modelo='55'`; o parser **não** cria/resolve produto sozinho. Evoluir:

- Aceitar `infNFe` (55/65) **e** `infNFS-e` / `RPS` /
  `InfDeclaracaoPrestacaoServico` (serviços/municipais), detectando o tipo
  pela tag raiz; modelo interno comum com chave, emitente (CNPJ/CPF/IM),
  data, município, código de serviço/CMC, descrição, valor, ISS/PIS/COFINS.
- **Para cada item do XML, verificar se o produto já existe** (buscar por
  `cProd` + descrição + NCM no `EMPRESA_ID` da sessão, via
  `TProdutoService`):
  - **achou exatamente um** → associar e seguir;
  - **achou vários** → mostrar os compatíveis para o usuário escolher;
  - **não achou** → **não criar automaticamente**: abrir tela de mapeamento
    com os dados originais do XML e duas ações:
    1. **"Selecionar produto compatível"** — lista filtrada por NCM/descrição;
    2. **"Cadastrar novo produto"** — abre o cadastro com código, descrição e
       classificação fiscal pré-preenchidos do XML; ao salvar, grava o
       `PRODUTO_ID` no mapeamento.
    - opcional "Ignorar item", sempre com auditoria.
- Itens de **serviço/comunicação/internet** entram sem NCM/CFOP obrigatórios,
  sem quantidade de estoque e **sem movimento de estoque**; cadastro pode
  ganhar `TIPO='S'` com `CONTROLA_ESTOQUE='N'`.
- Reimportar a mesma chave deve **reaproveitar** os mapeamentos já salvos
  (não perguntar de novo); chave repetida continua recusada dentro do mesmo
  tipo de documento.
- Auditoria: `XML_FISCAL/IMPORTACAO_XML` e
  `IMPORTACAO_XML/MAPEAMENTO_PRODUTO` com usuário, empresa e origem
  (XML vs cadastro manual).

### 5.3 Tabela de importação XML (campos exigidos pelo usuário)

Migração **aditiva** `Banco\023_importacao_xml.sql`
(+ `023_importacao_xml_rollback.sql`), sem rename, aplicada ao banco real
**e** ao `Banco\schema_canonico.sql`. Nomes ≤31 chars, `DEFAULT` antes de
`NOT NULL`. Estrutura mínima proposta (`IMPORTACAO_XML_ITEM`):

```sql
CREATE TABLE IMPORTACAO_XML_ITEM (
  ID                  INTEGER NOT NULL,
  EMPRESA_ID          INTEGER DEFAULT 1 NOT NULL,
  NOTA_ENTRADA_ID     INTEGER,
  CHAVE               VARCHAR(44),
  TIPO_DOCUMENTO      VARCHAR(12) DEFAULT '55' NOT NULL,
  PROVEDOR            VARCHAR(20),
  FORNECEDOR_CNPJ     VARCHAR(14) NOT NULL,   -- CNPJ do fornecedor
  DESCRICAO_ORIGINAL  VARCHAR(250) NOT NULL,  -- descrição original da nota
  CODIGO_PRODUTO_NOTA VARCHAR(60) NOT NULL,   -- produto da nota (cProd)
  CLASSIFICACAO_FISCAL VARCHAR(60),           -- classificação fiscal que veio
  NCM                 VARCHAR(10),
  CFOP                VARCHAR(4),
  CST_ICMS            VARCHAR(3),
  CEST                VARCHAR(7),
  UNIDADE             VARCHAR(6),
  QUANTIDADE          NUMERIC(15,4),
  VALOR_UNITARIO      NUMERIC(15,4),
  PRODUTO_ID          INTEGER,                -- null até o usuário mapear
  SITUACAO            VARCHAR(12) DEFAULT 'PENDENTE' NOT NULL,
  USUARIO_ID          INTEGER,
  DATA_IMPORTACAO     TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
  CONSTRAINT PK_IMPORTACAO_XML_ITEM PRIMARY KEY (ID)
);
CREATE UNIQUE INDEX UQ_IMPXML_EMP_CHAVE_COD
  ON IMPORTACAO_XML_ITEM (EMPRESA_ID, CHAVE, CODIGO_PRODUTO_NOTA);
CREATE INDEX IX_IMPXML_PRODUTO ON IMPORTACAO_XML_ITEM (PRODUTO_ID);
```

`SITUACAO`: `PENDENTE` → `MAPEADO` (escolheu existente) ou `NOVO`
(cadastrou pela tela). A tela deve mostrar **CNPJ do fornecedor, descrição
original da nota, produto da nota e classificação fiscal que veio** — são os
quatro campos que o usuário explicitamente pediu para guardar.

---

## 6. Ordem sugerida de execução na próxima sessão

1. Retomar com o checklist §3 e registrar no canal.
2. **Marco 3.87 — documentação de retomada:** este prompt +
   `CHECKPOINT.md`/`PLANO_E_LOG.md`/`ROADMAP` (se ainda não publicado).
3. **Marco 3.88 — tabela + mapeamento: CONCLUÍDO em 21/11** (registrado como
   §3.89 no `PLANO_E_LOG.md`, pois o outro agente ocupou o §3.88 com o fix de
   idempotência). Migração `023` aplicada, `IMPORTACAO_XML_ITEM`, service
   `uImportacaoXmlMapService`, tela `uFrmMapearProdutoXML`, auditoria e 3
   testes novos (achou / não achou / reimportar). Suíte 388/388.
4. **Marco 3.90 — nota de serviço diverso + XML:** `TNFSeHelper`, preferências
   `NFSE_*`, XML assinado/validado off-line, testes novos.
5. **Marco 3.91 — nota de entrada ampliada:** NFS-e/serviços no parser,
   integração com o mapeamento do 3.88, bateria completa.
6. A cada marco: bateria (388/388, `api_todos.ps1` 6 smokes, Android 9/9,
   telas 33/33, permissões 0 falhas, schema/banco fresco) + commit + push.

---

## 7. O que **não** afirmar como feito

- Certificado autoassinado nunca autoriza nota na SEFAZ/prefeitura.
- PDF local não tem protocolo e não substitui cupom autorizado.
- Homologação real exige CNPJ/IE/e-CNPJ A1/CSC próprios — não usar terceiros.
- NFS-e, nota de serviço diverso, `TNFSeHelper`, tabela
  `IMPORTACAO_XML_ITEM` e a tela de mapeamento **são plano até serem
  implementados e testados**. Não marcar como concluído só por estar neste
  prompt.
- `:pdv` continua fora da bateria/CI/docs sem autorização; pagamentos e TEF/
  PIX reais aguardam escolha de provedor do usuário.

---

## 8. Comandos de referência rápida

```bat
cd /d C:\Users\Charles\Documents\ProjetoERP_1
git log --oneline -8
git status --short
Scripts\build_api.bat
Scripts\run_tests.bat
Scripts\build_tests.bat
Scripts\build_desktop.bat
Scripts\run_tests_android.bat
Scripts\build_bipe.bat
powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\api_todos.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\telas_todas_ui.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\permissoes_menu.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\schema_roundtrip.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\banco_fresco.ps1
Scripts\validar_nfe.bat 1003 C:\certificados\teste.pfx teste123
Desktop\bin\ERP2026.exe --danfe=<chave de 44 digitos>
```

Banco: `Banco\dados.fdb` (SYSDBA/masterkey), Firebird 5 em
`C:\Program Files\Firebird\Firebird_5_0`. Login do ERP: `admin`/`admin123`.
API: porta 9000. Antes de commitar, reler `CHECKPOINT.md`,
`Documentacao\PLANO_E_LOG.md` (§3.86 em diante) e
`Documentacao\COMUNICACAO_AGENTES.md`.
