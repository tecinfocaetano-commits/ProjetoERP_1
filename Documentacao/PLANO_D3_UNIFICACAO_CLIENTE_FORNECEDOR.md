# D3 — Unificação de CLIENTE + FORNECEDOR em PESSOA

> Plano detalhado para aprovação. **Nada neste documento foi aplicado no banco.**
> Regra do projeto: o núcleo fiscal só é tocado depois deste plano aprovado.
>
> Data: 02/11/2026 · Banco: Firebird 5 · Projeto: `C:\Users\Charles\Documents\ProjetoERP_1`

---

## 1. Objetivo

Substituir as tabelas `CLIENTE` e `FORNECEDOR` por uma única tabela `PESSOA`,
com a coluna `TIPO` (`C` = cliente, `F` = fornecedor), mantendo:

- todos os IDs e vínculos já existentes;
- os contratos da API usados pelo Android (`/api/clientes`, `cliente_id`,
  `fornecedor_id`);
- os nomes das colunas de referência (`CLIENTE_ID` / `FORNECEDOR_ID`), que
  passam a apontar para `PESSOA.ID`;
- o comportamento fiscal (notas de entrada/saída, NF-e, contas a pagar/receber,
  pedidos e mapa de produção).

**Não é objetivo** deste marco: mudar regras fiscais, renomear colunas de
referência ou criar `TIPO = 'A'` (pessoa que é cliente e fornecedor ao mesmo
tempo). O backlog registra `TIPO` **C/F**.

---

## 2. Decisões propostas (aprovar antes de executar)

| # | Decisão | Proposta |
|---|---|---|
| D3-1 | Nome da tabela | `PESSOA` |
| D3-2 | Papel da pessoa | `TIPO CHAR(1) NOT NULL DEFAULT 'C'`, `CHECK (TIPO IN ('C','F'))` |
| D3-3 | Natureza jurídica | mantém `TIPO_PESSOA CHAR(1)` (`F` = física, `J` = jurídica) |
| D3-4 | ID de cliente | **preservado** (999–1340 no banco atual) |
| D3-5 | ID de fornecedor | **remapeado** para acima do maior ID existente, com tabela de mapeamento; evita colisão em qualquer ambiente |
| D3-6 | Colunas de referência | **não renomear** `CLIENTE_ID` / `FORNECEDOR_ID`; documentar que apontam para `PESSOA.ID` |
| D3-7 | Tela | um único cadastro **Pessoas**, com filtro Todos/Clientes/Fornecedores; o tipo não pode ser alterado depois de salvo |
| D3-8 | API | manter `/api/clientes` (filtrado por `TIPO = 'C'`); não criar endpoint novo nesta etapa |
| D3-9 | Exclusão | bloquear exclusão de pessoa referenciada por pedido/nota/conta/produto/financeiro |
| D3-10 | Mesmo CPF/CNPJ | permitido entre um cliente e um fornecedor; duplicado **dentro do mesmo TIPO** continua bloqueado |
| D3-11 | Views de compatibilidade | **não** criar; todas as consultas serão migradas para `PESSOA` |
| D3-12 | Rollback | script `018_..._rollback.sql` + backup `DADOS_backup_antes_018.fdb` |

### Alternativas consideradas

1. **Manter as duas tabelas e criar uma view de união** — não unifica de fato,
   mantém dois cadastros e dois IDs; descartado.
2. **Renomear `CLIENTE` para `PESSOA` e copiar fornecedores** — o Firebird 5 não
   renomeia tabela/coluna; exigiria ADD + cópia + DROP de qualquer forma.
3. **Preservar também os IDs de fornecedor** — no banco atual não há colisão
   (fornecedores 1–2, clientes 999–1340), mas um ambiente real pode ter IDs
   sobrepostos. O remapeamento sistemático é mais seguro e mantém o gerador
   único previsível.
4. **`TIPO = 'A'` (cliente e fornecedor)** — exigiria decidir o que fazer com
   referências dos dois lados e com o rollback; fica para uma eventual D3b.

---

## 3. Estrutura de `PESSOA`

União dos campos dos dois cadastros (25 colunas). Tipos e tamanhos preservam os
maiores valores atuais.

| Coluna | Tipo | Nulo | Observação |
|---|---|---|---|
| `ID` | `DM_ID` (`BIGINT NOT NULL`) | não | PK |
| `EMPRESA_ID` | `DM_ID` | não | empresa do cadastro |
| `TIPO` | `CHAR(1) DEFAULT 'C'` | não | `C` cliente / `F` fornecedor |
| `TIPO_PESSOA` | `CHAR(1) DEFAULT 'F'` | sim | `F` física / `J` jurídica |
| `NOME` | `DM_NOME` (`VARCHAR(100) NOT NULL`) | não | cliente: `NOME`; fornecedor: `RAZAO_SOCIAL` |
| `NOME_FANTASIA` | `VARCHAR(100)` | sim | |
| `CPF_CNPJ` | `VARCHAR(20)` | sim | maior tamanho entre as duas tabelas |
| `RG_IE` | `VARCHAR(20)` | sim | cliente: `RG_IE`; fornecedor: `IE` |
| `ENDERECO` | `VARCHAR(200)` | sim | |
| `NUMERO` | `VARCHAR(20)` | sim | |
| `COMPLEMENTO` | `VARCHAR(100)` | sim | |
| `BAIRRO` | `VARCHAR(100)` | sim | |
| `CIDADE` | `VARCHAR(100)` | sim | texto legado |
| `CIDADE_ID` | `BIGINT` | sim | vínculo geográfico (017) |
| `UF` | `CHAR(2)` | sim | |
| `CEP` | `VARCHAR(10)` | sim | |
| `TELEFONE` | `VARCHAR(20)` | sim | |
| `CELULAR` | `VARCHAR(20)` | sim | |
| `EMAIL` | `VARCHAR(150)` | sim | |
| `CONTATO` | `VARCHAR(100)` | sim | fornecedor |
| `DATA_NASCIMENTO` | `DATE` | sim | cliente (mantido no modelo) |
| `LIMITE_CREDITO` | `NUMERIC(15,4)` | sim | cliente |
| `OBSERVACOES` | `VARCHAR(1000)` | sim | |
| `ATIVO` | `DM_STATUS` (`CHAR(1) DEFAULT 'A'`) | sim | `A`/`I` |
| `DATA_CADASTRO` | `TIMESTAMP` | sim | preenchida pelo trigger |

**Constraints/índices** (as constraints abaixo entram no `CREATE TABLE PESSOA`)

```sql
PRIMARY KEY (ID),
CONSTRAINT CK_PESSOA_TIPO   CHECK (TIPO IN ('C','F')),
CONSTRAINT CK_PESSOA_ATIVO  CHECK (ATIVO IS NULL OR ATIVO IN ('A','I'))

CREATE INDEX IDX_PESSOA_EMPRESA_TIPO ON PESSOA (EMPRESA_ID, TIPO, NOME);
CREATE INDEX IDX_PESSOA_CPF          ON PESSOA (CPF_CNPJ);
CREATE INDEX IDX_PESSOA_CIDADE       ON PESSOA (CIDADE_ID);
```

- Gerador: `GEN_PESSOA_ID`.
- Trigger `TRG_PESSOA_BI`: preenche `ID` (`GEN_ID`) e `DATA_CADASTRO`.
- Sem FK real (padrão do banco), integridade nas Services.
- Sem `UNIQUE (EMPRESA_ID, CPF_CNPJ)`: o banco atual já tem CPF repetido
  (ex.: `123.456.789-00` em dois clientes). A validação fica na Service, por
  `TIPO`.

---

## 4. Migração `Banco/018_unificar_pessoa.sql`

### 4.1 Pré-condições

1. API e desktop fechados.
2. Backup: `Banco\DADOS_backup_antes_018.fdb` (cópia do `DADOS.FDB`).
3. Teste completo em cópia (`%TEMP%\DADOS_teste_018.fdb`): aplicar 018 →
   validar → aplicar rollback → comparar.
4. Script gravado em UTF-8 **sem BOM**, com `SET NAMES UTF8`.

### 4.2 Sequência do script

```sql
SET NAMES UTF8;
SET ECHO ON;

-- 1) tabela + gerador
CREATE GENERATOR GEN_PESSOA_ID;
CREATE TABLE PESSOA ( ... );
COMMIT;

-- trigger (o isql exige SET TERM ao redor do bloco)
SET TERM ^ ;
CREATE TRIGGER TRG_PESSOA_BI FOR PESSOA ACTIVE BEFORE INSERT POSITION 0 AS
BEGIN
  IF (NEW.ID IS NULL OR NEW.ID = 0) THEN NEW.ID = GEN_ID(GEN_PESSOA_ID, 1);
  IF (NEW.DATA_CADASTRO IS NULL) THEN NEW.DATA_CADASTRO = CURRENT_TIMESTAMP;
END^
SET TERM ; ^
COMMIT;

-- 2) clientes: IDs preservados, TIPO='C'
INSERT INTO PESSOA (ID, EMPRESA_ID, TIPO, TIPO_PESSOA, NOME, NOME_FANTASIA,
                    CPF_CNPJ, RG_IE, ENDERECO, NUMERO, COMPLEMENTO, BAIRRO,
                    CIDADE, CIDADE_ID, UF, CEP, TELEFONE, CELULAR, EMAIL,
                    DATA_NASCIMENTO, LIMITE_CREDITO, OBSERVACOES, ATIVO,
                    DATA_CADASTRO)
SELECT ID, EMPRESA_ID, 'C', TIPO_PESSOA, NOME, NOME_FANTASIA,
       CPF_CNPJ, RG_IE, ENDERECO, NUMERO, COMPLEMENTO, BAIRRO,
       CIDADE, CIDADE_ID, UF, CEP, TELEFONE, CELULAR, EMAIL,
       DATA_NASCIMENTO, LIMITE_CREDITO, OBSERVACOES, ATIVO,
       DATA_CADASTRO
FROM CLIENTE;
COMMIT;

-- 3) fornecedores: novos IDs acima de MAX(cliente, fornecedor)
CREATE TABLE MIGRA_FORN_018 (
  ID_ANTIGO BIGINT NOT NULL PRIMARY KEY,
  ID_NOVO   BIGINT NOT NULL UNIQUE
);
CREATE TABLE MIGRA_BASE_018 (BASE BIGINT);
INSERT INTO MIGRA_BASE_018
SELECT CASE
         WHEN (SELECT COALESCE(MAX(ID),0) FROM CLIENTE) >
              (SELECT COALESCE(MAX(ID),0) FROM FORNECEDOR)
         THEN (SELECT COALESCE(MAX(ID),0) FROM CLIENTE)
         ELSE (SELECT COALESCE(MAX(ID),0) FROM FORNECEDOR)
       END
FROM RDB$DATABASE;

INSERT INTO MIGRA_FORN_018 (ID_ANTIGO, ID_NOVO)
SELECT F.ID, B.BASE + ROW_NUMBER() OVER (ORDER BY F.ID)
FROM FORNECEDOR F CROSS JOIN MIGRA_BASE_018 B;

INSERT INTO PESSOA (ID, EMPRESA_ID, TIPO, TIPO_PESSOA, NOME, NOME_FANTASIA,
                    CPF_CNPJ, RG_IE, ENDERECO, NUMERO, COMPLEMENTO, BAIRRO,
                    CIDADE, CIDADE_ID, UF, CEP, TELEFONE, CELULAR, EMAIL,
                    CONTATO, OBSERVACOES, ATIVO, DATA_CADASTRO)
SELECT M.ID_NOVO, F.EMPRESA_ID, 'F', F.TIPO_PESSOA, F.RAZAO_SOCIAL,
       F.NOME_FANTASIA, F.CPF_CNPJ, F.IE, F.ENDERECO, F.NUMERO,
       F.COMPLEMENTO, F.BAIRRO, F.CIDADE, F.CIDADE_ID, F.UF, F.CEP,
       F.TELEFONE, F.CELULAR, F.EMAIL, F.CONTATO, F.OBSERVACOES,
       F.ATIVO, F.DATA_CADASTRO
FROM FORNECEDOR F
JOIN MIGRA_FORN_018 M ON M.ID_ANTIGO = F.ID;
COMMIT;

-- 4) remapear as 5 colunas de fornecedor (somente onde há vínculo)
UPDATE CONTA_PAGAR CP SET FORNECEDOR_ID =
  (SELECT M.ID_NOVO FROM MIGRA_FORN_018 M WHERE M.ID_ANTIGO = CP.FORNECEDOR_ID)
WHERE EXISTS (SELECT 1 FROM MIGRA_FORN_018 M WHERE M.ID_ANTIGO = CP.FORNECEDOR_ID);
-- idem: FINANCEIRO.FORNECEDOR_ID, NOTA_ENTRADA.FORNECEDOR_ID,
--       PEDIDO_COMPRA.FORNECEDOR_ID, PRODUTO.FORNECEDOR_ID
COMMIT;

-- 5) avançar o gerador único até o maior ID já gravado
EXECUTE BLOCK AS
  DECLARE VMAX BIGINT;
  DECLARE VNOW BIGINT;
BEGIN
  SELECT COALESCE(MAX(ID),0) FROM PESSOA INTO :VMAX;
  VNOW = GEN_ID(GEN_PESSOA_ID, 0);
  WHILE (VNOW < VMAX) DO
    VNOW = GEN_ID(GEN_PESSOA_ID, 1);
END^
SET TERM ; ^
COMMIT;

-- 6) remover estruturas antigas
DROP TRIGGER TRG_CLIENTE_BI;
DROP TRIGGER TRG_FORNECEDOR_BI;
DROP TABLE CLIENTE;
DROP TABLE FORNECEDOR;
DROP GENERATOR GEN_CLIENTE_ID;
DROP GENERATOR GEN_FORNECEDOR_ID;
DROP TABLE MIGRA_BASE_018;   -- MIGRA_FORN_018 fica para rollback/auditoria
COMMIT;
```

> **Observação:** `MIGRA_FORN_018` fica no banco (2 linhas no banco atual) para
> permitir o rollback e servir de rastro. Pode ser removida em uma limpeza
> posterior, mas aí o rollback deixa de reverter os IDs de fornecedor.

### 4.3 Validações obrigatórias após aplicar

Executar e conferir (script/consultas de verificação):

| Verificação | Esperado |
|---|---|
| `SELECT TIPO, COUNT(*) FROM PESSOA GROUP BY TIPO` | `C = 9`, `F = 2` |
| `SELECT COUNT(*) FROM MIGRA_FORN_018` | 2 (igual ao total de fornecedores) |
| Órfãos em `CONTA_RECEBER.CLIENTE_ID` | 0 |
| Órfãos em `CONTA_PAGAR.FORNECEDOR_ID` | 0 |
| Órfãos em `NOTA_ENTRADA.FORNECEDOR_ID` | 0 |
| Órfãos em `NOTA_SAIDA.CLIENTE_ID` | 0 |
| Órfãos em `PEDIDO_COMPRA.FORNECEDOR_ID` | 0 |
| Órfãos em `PEDIDO_VENDA.CLIENTE_ID` | 0 |
| Órfãos em `PRODUTO.FORNECEDOR_ID` | 0 |
| Órfãos em `FINANCEIRO.CLIENTE_ID` / `FORNECEDOR_ID` | 0 / 0 |
| `GEN_ID(GEN_PESSOA_ID, 0)` | `>= MAX(PESSOA.ID)` |
| Totais de `CONTA_PAGAR`, `CONTA_RECEBER`, `NOTA_ENTRADA`, `NOTA_SAIDA`, `PEDIDO_COMPRA`, `PEDIDO_VENDA` | iguais aos de antes |
| `SELECT ... FROM PESSOA WHERE TIPO='F'` | nomes/razões sociais iguais aos antigos |

No banco atual, os fornecedores 1 e 2 passam a 1341 e 1342 (maior ID 1340 +
`ROW_NUMBER`). As referências em `CONTA_PAGAR` (3), `NOTA_ENTRADA` (4) e
`PEDIDO_COMPRA` (1) são atualizadas para 1341/1342.

---

## 5. Rollback `Banco/018_unificar_pessoa_rollback.sql`

1. Recriar `CLIENTE` e `FORNECEDOR` exatamente como no schema canônico atual
   (23 colunas, PK, triggers `TRG_CLIENTE_BI`/`TRG_FORNECEDOR_BI`, índices
   `IDX_CLIENTE_CIDADE`/`IDX_FORNECEDOR_CIDADE`).
2. Recriar `GEN_CLIENTE_ID` e `GEN_FORNECEDOR_ID`.
3. Copiar `PESSOA WHERE TIPO='C'` para `CLIENTE` (IDs preservados).
4. Copiar `PESSOA WHERE TIPO='F'` para `FORNECEDOR`, usando
   `MIGRA_FORN_018.ID_NOVO → ID_ANTIGO`; pessoas criadas depois da 018 recebem
   IDs acima do maior ID antigo.
5. Reverter as 5 colunas de fornecedor com o mapa inverso.
6. Avançar os dois geradores antigos até o maior ID de cada tabela.
7. `DROP TABLE PESSOA`, `DROP GENERATOR GEN_PESSOA_ID`,
   `DROP TABLE MIGRA_FORN_018` (o `MIGRA_BASE_018` já foi removido na 018).

**Limite conhecido:** rollback não ressuscita registros apagados depois da 018.
Para perda de dados, a recuperação oficial é o backup
`DADOS_backup_antes_018.fdb`. O rollback serve para voltar a estrutura e os
dados existentes no momento da reversão.

---

## 6. Impacto no código

### 6.1 Novos arquivos

| Arquivo | Conteúdo |
|---|---|
| `Desktop/src/Models/uPessoa.pas` | `TPessoa` com `Tipo: Char`, `Nome`, `Contato`, `LimiteCredito`, etc. |
| `Desktop/src/Services/uPessoaService.pas` | CRUD parametrizado, filtro por `TIPO`, validações, auditoria, bloqueio de exclusão referenciada |
| `Desktop/src/Views/uFrmPessoas.pas/.lfm` | cadastro único com filtro de tipo |
| `Desktop/src/Tests/uPessoaTest.pas` | testes de CRUD, tipo, duplicidade, integridade da 018 |
| `Banco/018_unificar_pessoa.sql` | migração |
| `Banco/018_unificar_pessoa_rollback.sql` | reversão |

### 6.2 Arquivos removidos/substituídos

- `Desktop/src/Models/uCliente.pas`, `uFornecedor.pas`
- `Desktop/src/Services/uClienteService.pas`
- `Desktop/src/Views/uFrmClientes.pas/.lfm`, `uFrmFornecedores.pas/.lfm`
- `Desktop/src/Tests/uFrmClientesTest.pas` (substituído por `uPessoaTest`)
- Referências em `Desktop/ERP2026.lpr`, `Desktop/ERP2026.lpi` e
  `Desktop/src/Tests/uTestRunner.pas`

### 6.3 Consultas que trocam `CLIENTE`/`FORNECEDOR` por `PESSOA`

Todas as referências foram levantadas (54 no código). As principais:

| Arquivo | O que muda |
|---|---|
| `uACBrHelper.pas` | `JOIN PESSOA C ON C.ID = PV.CLIENTE_ID` |
| `uNotaSaidaService.pas` | join do cliente no extrato/impressão |
| `uFrmContasReceber.pas` | `LEFT JOIN PESSOA C`; nome do cliente |
| `uFrmContasPagar.pas` | `LEFT JOIN PESSOA F`; `COALESCE(F.NOME_FANTASIA, F.NOME)` |
| `uFrmListaPedidos.pas` | join do cliente; `C.NOME` |
| `uFrmMapaProducao.pas` | 6 joins de cliente; `C.NOME` |
| `uFrmNFe.pas` | join do cliente |
| `uFrmNotaEntrada.pas` | joins/lookup de fornecedor; `TIPO='F'`; `NOME` no lugar de `RAZAO_SOCIAL`; `CPF_CNPJ` no lugar de `CNPJ` |
| `uFrmNotaSaida.pas` | joins/lookup de cliente; `TIPO='C'` |
| `uFrmCompras.pas` | combo de fornecedor (`TIPO='F'`); corrige a consulta atual `SELECT ID, NOME FROM FORNECEDOR`, que referencia uma coluna `NOME` inexistente |
| `uFrmOrcamento.pas` | combo de cliente (`TIPO='C'`) |
| `uFrmPedidoVenda.pas` | combo de cliente (`TIPO='C'`) |
| `uRotasClientes.pas` | toda a rota filtra `TIPO='C'`; INSERT grava `TIPO='C'` |
| `uRotasFinanceiro.pas` | joins de cliente/fornecedor em `PESSOA` |
| `uRotasVendas.pas` | join do cliente |
| `uRotasOrcamentos.pas` | joins e validação do cliente (`TIPO='C'`) |

**Não mudam:** `CONTA_RECEBER`, `CONTA_PAGAR`, `NOTA_ENTRADA`, `NOTA_SAIDA`,
`PEDIDO_COMPRA`, `PEDIDO_VENDA`, `PRODUTO` e `FINANCEIRO` no que diz respeito a
colunas; apenas os valores de `FORNECEDOR_ID` são remapeados pela migração.
Colunas `CLIENTE_ID`/`FORNECEDOR_ID` continuam com o mesmo nome.

### 6.4 Service `uPessoaService`

- `BuscarPorId(AId): TPessoa`
- `BuscarTodos(ATipo: Char = #0; AFiltro: string = ''): TSQLQuery` — filtra
  `EMPRESA_ID = :EMP` e, se `ATipo` em `C/F`, `TIPO = :TIPO`.
- `Pesquisar(ATermo, ATipo): TSQLQuery` — nome, CPF/CNPJ e cidade,
  parametrizado.
- `Inserir` / `Atualizar` / `Excluir` com `LogOperacao('PESSOA', ...)`.
- Validações:
  - `NOME` obrigatório e `CPF_CNPJ` obrigatório (como hoje);
  - `TIPO` obrigatório e em `C/F`;
  - `CPF_CNPJ` único por `EMPRESA_ID + TIPO` (excluindo o próprio ID);
  - `TIPO` **imutável** na atualização (lê o tipo atual e recusa a troca);
  - exclusão bloqueada se houver referência em qualquer uma das 9 colunas
    (mensagem indicando onde a pessoa é usada).
- `uClienteService` deixa de existir; os testes passam a usar
  `TPessoaService`.

### 6.5 Tela `uFrmPessoas`

- Herda `TfrmCadastroBase` (Novo/Editar/Excluir/Salvar/Cancelar/Fechar e
  pesquisa já existentes).
- Filtro no topo da listagem: **Todos / Clientes / Fornecedores**; o grid
  mostra `TIPO`, `NOME`, `CPF_CNPJ`, `CIDADE`, `UF`, `TELEFONE`, `ATIVO`.
- Formulário:
  - `Tipo` (`Cliente`/`Fornecedor`) — habilitado só na inclusão;
  - `Tipo pessoa` (`Física`/`Jurídica`);
  - rótulos mudam conforme o tipo: `Nome` ↔ `Razão social`,
    `RG/IE` ↔ `IE`;
  - `Contato` habilitado para fornecedor;
  - `Limite de crédito` habilitado para cliente;
  - mesmos campos geográficos (`uGeoCombos`) e validações atuais
    (CPF/CNPJ, e-mail).
- Menu **Cadastros → Pessoas** (substitui Clientes e Fornecedores).
  Alternativa, se preferir: manter os dois itens de menu abrindo a mesma tela
  já filtrada (`Clientes` → filtro `C`; `Fornecedores` → filtro `F`).

---

## 7. API e Android

- `GET /api/clientes` → `SELECT ... FROM PESSOA WHERE TIPO='C'` (sem isso, o
  dashboard passaria a contar 11 pessoas em vez de 9).
- `GET /api/clientes/:id`, `DELETE /api/clientes/:id` → `TIPO='C'`.
- `POST /api/clientes` → grava `TIPO='C'` e usa `GEN_PESSOA_ID`.
- `GET /api/vendas`, `/api/orcamentos`, `/api/financeiro` → joins em `PESSOA`;
  respostas JSON com as mesmas chaves (`cliente`, `fornecedor`, `cliente_id`).
- Android **não precisa de alteração de código**: consome os mesmos endpoints e
  campos. A validação é por build + smoke no emulador.
- Sem endpoint `/api/pessoas` nesta etapa (evita ampliar o contrato do app).

---

## 8. Testes

### 8.1 Suíte desktop

Substituir os 9 testes de `uFrmClientesTest` por `uPessoaTest` com, no mínimo:

1. inserir cliente (`TIPO='C'`) e fornecedor (`TIPO='F'`);
2. listar/filtrar por tipo;
3. pesquisar por nome, CPF/CNPJ e cidade (com apóstrofo);
4. atualizar e excluir;
5. recusar `TIPO` inválido;
6. recusar troca de `TIPO` na atualização;
7. bloquear CPF/CNPJ duplicado no mesmo tipo;
8. permitir o mesmo CPF/CNPJ em cliente e fornecedor;
9. bloquear exclusão de pessoa referenciada;
10. validar a migração: `PESSOA` com 9 clientes e 2 fornecedores, zero órfãos,
    gerador acima do maior ID.

Os testes que hoje inserem direto em `CLIENTE` passam a usar `PESSOA` e/ou o
service. Aproveitar para corrigir os testes frágeis de "sem nome/sem CPF", que
hoje falham por causa de `EMPRESA_ID NOT NULL`, não pela validação pretendida.

**Meta:** 62 testes atuais − 9 antigos + 12 novos = **65/65** (ajustar se algum
teste antigo for mantido).

### 8.2 Migração

- Aplicar em cópia e rodar as validações da seção 4.3.
- Aplicar rollback na cópia e comparar: contagens, somas e referências iguais
  às de antes.
- Rodar `Scripts\testes\schema_roundtrip.ps1` depois de regenerar
  `Banco\schema_canonico.sql`.

### 8.3 Builds e smoke

| Verificação | Critério |
|---|---|
| `Scripts\build_desktop.bat` | 0 erros / 0 warnings |
| `Scripts\run_tests.bat` | todos passam (meta 65/65) |
| `Scripts\build_api.bat` | sucesso |
| `Scripts\build_android.bat` | `BUILD SUCCESSFUL` |
| Android `Pixel_9` | dashboard 9 clientes; lista de clientes; vendas; financeiro R$ 170,00 / R$ 1.595,00; orçamento com cliente |
| Desktop — Pessoas | criar/editar/excluir cliente e fornecedor; busca; filtro |
| Desktop — Nota de Entrada | localizar fornecedor por código/CNPJ/nome; importar XML |
| Desktop — Nota de Saída | localizar cliente; faturar |
| Desktop — Compras | combo de fornecedor preenchido (corrige o bug do `NOME`) |
| Desktop — Contas a Pagar/Receber | nomes de fornecedor/cliente nas listagens |
| Desktop — Mapa de Produção / Pedido / Orçamento | nome do cliente nos relatórios e listas |

---

## 9. Documentação

- Este plano (novo).
- `Documentacao/PLANO_E_LOG.md`: §2 item 10 → concluído; nova seção §3.19 com
  decisões, SQL, validações e resultados.
- `CHECKPOINT.md`: estado, próximo passo e comandos.
- `Documentacao/02_DIAGRAMA_ER.md`: trocar as entidades `CLIENTE` e
  `FORNECEDOR` por `PESSOA` (com `TIPO`).
- `Documentacao/04_PLANO_TESTES.md` e `TESTES_EXECUTADOS.md`: novos testes.
- `Banco/schema_canonico.sql`: regenerar por `Scripts/gerar_schema.bat` e
  validar com `Scripts/testes/schema_roundtrip.ps1`.
- `Documentacao/ARQUITETURA.md` (se citar os dois cadastros).

---

## 10. Riscos e mitigações

| Risco | Mitigação |
|---|---|
| Perda de dados | backup `DADOS_backup_antes_018.fdb` + teste em cópia + rollback testado |
| Consulta esquecida apontando para `CLIENTE`/`FORNECEDOR` | grep obrigatório por `\bCLIENTE\b`/`\bFORNECEDOR\b` antes e depois; smoke de todas as telas que usam os cadastros |
| Colisão de IDs | fornecedores sempre remapeados acima de `MAX(cliente, fornecedor)` |
| Dashboard contar fornecedores como clientes | `TIPO='C'` em todas as consultas de `/api/clientes` |
| Excluir fornecedor pela rota de clientes | `DELETE ... WHERE ID=:ID AND TIPO='C'` |
| CPF/CNPJ duplicado | sem UNIQUE no banco; validação por empresa + TIPO na Service; duplicados antigos documentados |
| Troca de tipo quebrando vínculos | `TIPO` imutável na atualização (Service + combo desabilitado) |
| Firebird não renomear | nova tabela + cópia + DROP (já previsto) |
| Identificador > 31 chars | todos os nomes novos foram conferidos (o maior é `IDX_PESSOA_EMPRESA_TIPO`) |
| Encoding dos scripts | UTF-8 sem BOM e `SET NAMES UTF8` |
| `GEN_ID`/`ROW_NUMBER` no Firebird 5 | validar na cópia antes de aplicar no banco real |
| Relatórios `.lrf` | só usam o alias `CLIENTE`; nenhuma mudança necessária, validar impressão |
| API/Android | contrato JSON inalterado; smoke no emulador |

---

## 11. Ordem de execução (checklist)

1. [x] Aprovar este plano.
2. [x] Criar cópia de teste do `DADOS.FDB`.
3. [x] Escrever `018_unificar_pessoa.sql` e o rollback.
4. [x] Aplicar 018 na cópia; rodar validações 4.3; aplicar rollback e comparar.
5. [x] Fazer o backup real `DADOS_backup_antes_018.fdb`.
6. [x] Aplicar 018 no `DADOS.FDB` real (API/desktop fechados).
7. [x] Rodar validações 4.3 no banco real.
8. [x] Criar `uPessoa`, `uPessoaService`, `uFrmPessoas`; ajustar menu e projeto.
9. [x] Migrar as consultas/joints para `PESSOA` (seção 6.3).
10. [x] Ajustar API (`uRotasClientes`, `uRotasFinanceiro`, `uRotasVendas`,
    `uRotasOrcamentos`).
11. [x] Substituir os testes; rodar build desktop 0/0 e suíte.
12. [x] Build API; build Android; smoke no emulador.
13. [x] Regenerar `schema_canonico.sql`; rodar round-trip.
14. [x] Atualizar docs e checkpoint.
15. [x] Commit único do marco D3.

---

## 12. Critérios de aceite

- `PESSOA` é a única tabela de clientes/fornecedores; `CLIENTE` e `FORNECEDOR`
  não existem mais como tabelas.
- 9 clientes e 2 fornecedores preservados, com todos os vínculos resolvidos
  (zero órfãos).
- Nenhuma mudança de comportamento nas notas, contas, pedidos, mapa, orçamentos
  e Android.
- Build desktop 0 erros / 0 warnings; suíte 100% verde; API e Android compilam.
- `schema_canonico.sql` reproduz o banco real (round-trip sem diferenças).
- Rollback testado em cópia.
- Documentação e checkpoint atualizados; árvore git limpa após o commit.

---

## 13. Pontos que precisam de aprovação explícita

1. **Menu**: um único item **Pessoas** (recomendado) ou manter atalhos
   **Clientes** e **Fornecedores** abrindo a mesma tela já filtrada?
2. **Tipo**: somente `C`/`F` (recomendado, conforme backlog) ou incluir `A`
   (cliente e fornecedor na mesma pessoa)?
3. **IDs de fornecedor**: remapear sempre (recomendado) ou preservar quando não
   houver colisão?
4. **Exclusão**: bloquear quando houver referências (recomendado) ou manter a
   exclusão livre atual?
5. **API**: manter só `/api/clientes` (recomendado) ou já expor
   `/api/pessoas?tipo=C|F`?

Com o "ok" nestes pontos, a execução segue a ordem da seção 11 e só então o
banco real é alterado.
