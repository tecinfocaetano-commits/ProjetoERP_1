# Prompt de continuação — App Android de Bipagem de Talões

> Cole este texto no início de uma nova sessão do agente para dar
> contexto completo sobre o projeto de bipagem e o que já foi feito.

---

```
CONTEXTO DO PROJETO

Você vai continuar o desenvolvimento do "ERP2026 Bipe", um aplicativo
Android de bipagem de código de barras de talões de produção, que vive
dentro do repositório do ERP2026 em C:\Users\Charles\Documents\
ProjetoERP_1 (GitHub privado: tecinfocaetano-commits/ProjetoERP_1,
branch master, autor tecinfocaetano@gmail.com).

ANTES DE QUALQUER COISA, leia:
- CHECKPOINT.md (estado atual e regras do projeto)
- Documentacao\PLANO_E_LOG.md (marcos 3.70 e 3.71 têm o histórico
  completo desta feature)
- Documentacao\INSTRUCOES_AGENTE.md (regras de condução)
- Documentacao\PROMPTS_NOVOS_APPS.md (PROMPT 1 já foi executado —
  este é o projeto dele; PROMPT 2 é o futuro app PDV Mobile)
- Android\android\bipe\README.md (documentação do app)

TECNOLOGIAS DO ECOSSISTEMA
- ERP desktop: Lazarus/FPC + Firebird 5.0, SQL sempre parametrizado,
  regra de negócio em Desktop\src\Services, auditoria via LogOperacao.
- API REST: Pascal/Horse em API\, JWT + middleware uMiddlewareSessao
  que preenche TSessao por thread (empresa/usuário vêm do token).
- Android: Java, módulo Gradle :bipe em Android\android\bipe
  (package com.example.erp2026_bipe), compileSdk 34, minSdk 21,
  Java 17, dependências: appcompat + zxing-android-embedded 4.3.0.

O QUE JÁ FOI FEITO (marco 3.71 — não refaça, apenas mantenha)

1. Motor único de bipagem — Desktop\src\Utils\uProducaoBipagem.pas:
   ExecutarBipagemTalao faz a máquina de estados do talão
   (GERADO/IMPRESSO→EM_PRODUCAO→CONCLUIDO), grava TALAO_BIPAGEM
   (auditoria) e LOG_SISTEMA, tudo em transação. É chamado tanto pelo
   desktop (TProducaoService.BiparTalao em
   Desktop\src\Services\uProducaoService.pas) quanto pela API —
   NUNCA duplique essa regra em outro lugar.

2. Endpoint da API — POST /api/producao/bipar em
   API\src\Rotas\uRotasProducao.pas (registrado em ERP2026API.lpr).
   Body: {"codigo": "...", "origem": "opcional"}. Requer JWT; o
   middleware já injeta EMPRESA_ID/USUARIO_ID do token. Resposta:
   resultado OK / DUPLICADO / INVALIDO + dados do talão + novo status.

3. App Android :bipe — módulo completo e compilando:
   - LoginActivity: URL do servidor + login/senha (+ campo opcional
     "Empresa (ID)" para quando o login existe em mais de uma empresa —
     a API exige empresa_id nesse caso) contra /api/login; token JWT,
     URL e empresa_id em SharedPreferences (Sessao.java). Troca de
     empresa zera o histórico local.
   - BipagemActivity: formas de bipar — leitor USB/Bluetooth
     (teclado; Enter, Tab ou DPAD_CENTER disparam), digitação manual e
     câmera (ZXing ScanContract). Erros HTTP {"error": ...} da API são
     exibidos com a mensagem real. Bipe sonoro distinto por resultado
     (ToneGenerator), contadores do turno e histórico SQLite
     (BipeDb.java, últimas 50 bipagens em bipe.db).
   - ApiClient.java: POST JSON mínimo com header Bearer.
   - Sessao expirada → volta ao login automaticamente.
   - Layouts: activity_login.xml, activity_bipagem.xml
     (telas grandes, uso industrial).
   - README completo em Android\android\bipe\README.md.
   - Build: cd Android\android && gradlew.bat :bipe:assembleDebug
     → APK em bipe\build\outputs\apk\debug\bipe-debug.apk

VERIFICAÇÃO JÁ FEITA
- :bipe:assembleDebug compila e gera o APK debug.
- run_tests_android.bat (app base) OK; desktop 0 erros / suíte 384/384;
  API compilada via Scripts\build_api.bat.

O QUE FALTA / PRÓXIMOS PASSOS POSSÍVEIS (em ordem de prioridade)

1. TESTE DE CAMPO (pendente, depende do usuário): instalar o APK num
   aparelho/emulador com a API no ar (ERP2026API.exe na porta 9000),
   login com usuário real e bipar um TALAO.CODIGO_BARRAS existente.
   Verificar os 3 resultados (OK, DUPLICADO, INVALIDO) e a persistência
   do histórico após fechar o app. O contrato já foi revisado contra
   uRotasProducao.pas e uRotasLogin.pas (campos batem; empresa_id
   opcional coberto) — se houver defeito, corrigir no app; a regra de
   negócio NÃO se toca, ela já está testada (384/384).

2. MODO OFFLINE / FILA (melhoria opcional): hoje a bipagem é
   online-only — se o Wi-Fi da fábrica cair, o operador fica sem
   bipar. Se o usuário pedir, implementar fila local (tabela outbox
   no BipeDb ou padrão Sincronizacao.java do app base) que grava o
   código como PENDENTE e reenvia quando houver rede; o servidor é a
   fonte da verdade do status, então o app deve mostrar badge de
   "aguardando sincronização" e reconciliar o resultado depois.

3. LISTA DE TALÕES DO TURNO / RELATÓRIO: se pedido, GET na API para
   listar bipagens do dia por usuário/empresa (TALAO_BIPAGEM já
   registra tudo) e tela de resumo no app.

4. APP PDV MOBILE (projeto separado — PROMPT 2 do arquivo de prompts):
   NÃO misturar com este. Se o usuário pedir PDV, é outro módulo e
   outro prompt.

REGRAS INEGOCIÁVEIS
- Português em código, comentários, mensagens e commits.
- EMPRESA_ID em TODA consulta — bipes de uma empresa nunca veem talões
  de outra (o motor já garante; não enfraqueça).
- SQL sempre parametrizado (:PARAM + ParamByName); mutações com
  transação + auditoria.
- android:id existentes preservados; novos ids descritivos.
- NÃO instalar dependências Gradle sem avisar o usuário antes.
- Ao fechar cada marco: atualizar CHECKPOINT.md + PLANO_E_LOG.md,
  commit em português e git push para origin (obrigatório).
- Baseline a não quebrar: desktop 384/384, Android OK, API compilando.

COMO COMEÇAR
1. git log --oneline -5 e git status — o disco é a verdade.
2. Leia os arquivos listados acima.
3. Pergunte ao usuário o que ele quer: testar no aparelho, modo
   offline, ou outra melhoria. Não assuma escopo novo sem confirmar.
```

---

## Observações para quem colar o prompt

- O app **compila e gera APK**, mas nunca foi testado em aparelho
  físico/emulador com a API no ar — o primeiro contato real pode
  revelar ajustes de UX ou de leitura de câmera.
- Se o objetivo for só **validar** o que existe, peça ao agente para
  revisar `BipagemActivity.java` contra o contrato real da API
  (`uRotasProducao.pas`) antes do teste de campo.
- O próximo projeto grande é o **PDV Mobile** (PROMPT 2) — não comece
  sem o usuário pedir explicitamente.
