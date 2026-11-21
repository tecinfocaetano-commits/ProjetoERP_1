# Prompts para os novos apps (Bipagem e PDV Mobile)

Prompts profissionais prontos para colar em novas sessões do agente.
Cada app é um entregável independente; siga na ordem sugerida
(Bipagem primeiro — é menor e a regra de negócio já existe no desktop).

> **Status:** PROMPT 1 (Bipagem) **executado** — módulo `Android/android/bipe`
> + endpoint `POST /api/producao/bipar` + motor compartilhado
> `uProducaoBipagem` (marco 3.71, commits `f651c0f`/`9dee0fd`/`223b85e`).
> Pendente: teste de ponta a ponta num aparelho com a API no ar.
> PROMPT 2 (PDV Mobile) ainda não iniciado.

---

## PROMPT 1 — App mobile de bipagem de talões

```
CONTEXTO
Você vai criar um NOVO aplicativo Android chamado "ERP2026 Bipe" que
convive no mesmo repositório do ERP2026 (C:\Users\Charles\Documents\
ProjetoERP_1). Leia primeiro CHECKPOINT.md, Documentacao/PLANO_E_LOG.md
e Documentacao/INSTRUCOES_AGENTE.md para absorver as convenções do
projeto. O ERP é Lazarus/FPC + Firebird 5.0, com API REST em Pascal
(Horse) em API/ e app Android existente em Android/android (Java,
SQLite local, fila outbox, JWT por empresa).

OBJETIVO
App para o chão de fábrica: o operador bipa o código de barras do
talão (TALAO.CODIGO_BARRAS) com a câmera do celular ou leitor USB/
Bluetooth e o sistema dá baixa na produção — exatamente como o
uFrmBipagem do desktop (Desktop/src/Views/uFrmBipagem.pas +
TProducaoService.BiparTalao).

ESCOPO FUNCIONAL
1. Login com as mesmas credenciais do app ERP2026 (mesmo endpoint
   /api/login, JWT por empresa — reutilize o padrão de Sessao/
   ApiClient/Configuracao do app Android existente).
2. Tela de bipagem: campo para digitar/colar o código + leitura pela
   câmera (ZXing ou ML Kit — escolha a lib mais estável e avise antes
   de adicionar dependência Gradle). Foco automático no campo para
   leitor hardware (que funciona como teclado + Enter).
3. Feedback imediato e sonoro de cada bipagem:
   - OK: talão avança de status (GERADO→IMPRESSO→EM_PRODUCAO→CONCLUIDO
     conforme TProducaoService.BiparTalao);
   - DUPLICADO: aviso de que já foi bipado;
   - INVÁLIDO: código não encontrado.
4. Contador do turno: total de bipes OK/duplicados/inválidos na sessão,
   com botão "Zerar".
5. Últimas 50 bipagens em lista (código, resultado, hora) — útil para
   o operador conferir.

BACKEND (API)
- Criar endpoint POST /api/producao/bipar { "codigo": "..." } na API
  Pascal, protegido pelo middleware JWT existente, derivando
  EMPRESA_ID do token (mesma regra das demais rotas).
- A regra de negócio deve espelhar TProducaoService.BiparTalao
  (Desktop/src/Services/uProducaoService.pas ~linha 1372):
  localizar TALAO por CODIGO_BARRAS + EMPRESA_ID, transicionar o
  STATUS conforme a máquina de estados, gravar TALAO_BIPAGEM
  (auditoria: USUARIO_ID do token, DATA_HORA, ETAPA, RESULTADO
  OK/DUPLICADO/INVALIDO), tudo em transação.
- Criar também GET /api/producao/taloes/recentes?limite=50 se o app
  precisar listar bipes do servidor; caso contrário, o histórico fica
  local no aparelho.
- SQL SEMPRE parametrizado (:PARAM + ParamByName). Nunca concatenar
  valores do usuário.

APP ANDROID
- Novo módulo Android no mesmo repositório (sugestão:
  Android/bipagem/ ou app separado com o mesmo package base).
- Reutilizar o padrão do app existente: Java, SQLite local para
  cache do turno, fila outbox se decidir gravar bipes off-line
  (recomendado para fábrica com Wi-Fi instável — bipes ficam na fila
  e sobem quando houver rede, no padrão de Sincronizacao.java).
- Se optar por off-line: as respostas OK/DUPLICADO/INVÁLIDO só são
  conhecidas no servidor; nesse caso grave localmente como "PENDENTE"
  e mostre badge de sincronização.
- Modo escuro não obrigatório; tela única e grande (botões e fontes
  grandes para uso com luva/ambiente industrial).
- Manter o app leve: sem frameworks pesados.

REGRAS DO PROJETO (obrigatórias)
- Português em código, comentários, mensagens e commits.
- Isolamento por EMPRESA_ID em TODA consulta — bipes de uma empresa
  nunca podem enxergar talões de outra.
- Transação + auditoria (TALAO_BIPAGEM) em toda mutação.
- Android: preserve android:id existentes se reaproveitar layouts;
  novos ids devem ser descritivos (ex.: editCodigoBarras,
  btnBipar, txtUltimoResultado).
- Testes: endpoint novo deve ter cobertura mínima (pode ser teste de
  unidade do service ou teste manual documentado); rodar
  Scripts/build_desktop.bat + run_tests.bat + run_api.bat para não
  quebrar o baseline (349/349 desktop, API compilando).
- NÃO instalar pacotes/bibliotecas sem avisar antes.

ENTREGÁVEIS
1. Endpoint(s) na API + código do app Android.
2. Build do app gerando APK debug (e instruções de build no README
   da pasta do app).
3. CHECKPOINT.md e PLANO_E_LOG.md atualizados com o novo marco.
4. Commits em português + git push para origin (repo privado
   tecinfocaetano-commits/ProjetoERP_1, autor tecinfocaetano@gmail.com).

FAÇA PRIMEIRO UM PLANO CURTO e me mostre antes de codar: estrutura de
pastas do app, endpoints necessários, e se a bipagem será online-only
ou com fila off-line.
```

---

## PROMPT 2 — App mobile de PDV (fase seguinte)

```
CONTEXTO
Mesmo repositório e mesmas convenções do prompt anterior
(C:\Users\Charles\Documents\ProjetoERP_1 — leia CHECKPOINT.md e
Documentacao/INSTRUCOES_AGENTE.md). Já existe app "ERP2026 Bipe"
(opcional) e o app ERP2026 Android base em Android/android. O PDV
desktop é Desktop/src/Views/uFrmPDV.pas + Services/uPDVService.pas —
leia-os para extrair as regras de negócio.

OBJETIVO
App Android "ERP2026 PDV Mobile": frente de caixa no celular/tablet —
venda de produtos, pagamento e fechamento de caixa, integrado à API
e ao banco Firebird via JWT/EMPRESA_ID.

ESCOPO FUNCIONAL (fases sugeridas — confirme comigo antes de codar)
Fase 1 — Venda:
1. Login igual aos demais apps (mesmo /api/login e empresa).
2. Catálogo de produtos com busca por descrição/código e saldo de
   estoque (offline via cache local como no app ERP2026).
3. Carrinho de venda: adicionar itens, quantidade, desconto,
   cliente opcional (consumidor final padrão, como uPDVService).
4. Pagamento: dinheiro (com cálculo de troco) e registro de
   formas de pagamento existentes; emitir "cupom" interno (não
   fiscal — NFC-e fica para fase posterior, confirmar).
5. Fechamento de venda → grava PEDIDO_VENDA via API (reusar ou
   espelhar regras de uPDVService: numeração por empresa, movimentos
   de caixa MOVIMENTO_CAIXA, baixa de estoque).

Fase 2 — Caixa:
6. Abrir/fechar caixa, suprimento/sangria e sangria de fechamento
   com valor apurado — mesmas regras de TPDVService/TCaixaService.

BACKEND (API)
- Novos endpoints em Pascal/Horse: POST /api/pdv/vendas,
  GET /api/pdv/produtos, GET/POST /api/pdv/caixa (abrir/fechar),
  GET /api/pdv/caixa/saldo. Todos com JWT + EMPRESA_ID do token,
  SQL parametrizado, transação e auditoria.
- Regras idênticas a uPDVService/uCaixaService (numeração por
  empresa, caixa aberto por usuário, baixa de estoque via
  MOVIMENTO_ESTOQUE).

APP ANDROID
- Novo módulo Android (sugestão Android/pdv/), Java, SQLite local +
  outbox no padrão do app existente.
- UI de PDV otimizada para toque: grid de produtos + carrinho lateral,
  botões grandes, fluxo de pagamento em telas curtas.
- Offline-first para consulta de produtos; vendas exigem rede (ou
  outbox se eu aprovar).

REGRAS DO PROJETO (obrigatórias)
- Português em tudo; regra de negócio no backend/Service — o app só
  coleta e envia dados validados.
- EMPRESA_ID em toda query; transação + auditoria nas mutações.
- Não quebrar baseline: desktop 349/349, testes Android, API compilada.
- Não instalar dependências sem avisar.
- android:id novos descritivos; layouts novos podem ser criados.
- CHECKPOINT.md + PLANO_E_LOG.md + commits em português + git push.

FAÇA PRIMEIRO UM PLANO CURTO e me mostre antes de codar: endpoints,
telas do app, o que é online vs off-line, e o que fica fora da fase 1
(ex.: NFC-e, TEF, impressão de cupom fiscal).
```

---

## Observações

- **Ordem sugerida:** Bipagem primeiro (menor, regra já existe em
  `TProducaoService.BiparTalao` e a tabela `TALAO_BIPAGEM` já foi
  pensada para auditoria). PDV mobile é maior — caixa, pagamento,
  estoque e possíveis integrações fiscais.
- **Decisões pendentes para o PDV** (o prompt pede confirmação no
  plano inicial): impressão de cupom (Bluetooth? nenhum?), NFC-e
  (escopo fiscal grande) e TEF.
