# Prompt de retomada — 21/11/2026

Copie o bloco abaixo ao abrir uma nova sessão.

---

Projeto: `C:\Users\Charles\Documents\ProjetoERP_1` (ERP 2026 — Lazarus/FPC + Firebird 5 no desktop, API Horse e app Android). **Somos uma equipe de especialistas em programação e nos comunicamos por este prompt e, principalmente, por `Documentacao\COMUNICACAO_AGENTES.md`, mantendo todos informados para evitar conflitos.**

Regras: responder em português; terminar toda resposta com exatamente 3 linhas **Feito / Falta / Próximo passo**; atualizar `CHECKPOINT.md` e `Documentacao\PLANO_E_LOG.md` por marco (não a cada resposta); **ler e escrever `Documentacao\COMUNICACAO_AGENTES.md` no início/fim de cada bloco, antes de mexer em arquivo compartilhado ou reiniciar a API, e de tempos em tempos mesmo que seja só "sem novidades"**; preservar todos os `android:id`; avisar antes de instalar pacotes/dependências; Firebird 5 (identificadores ≤31, `DEFAULT` antes de `NOT NULL`, sem `ALTER ... RENAME`); SQL sempre parametrizado; regra de negócio em Services; auditoria com `LogOperacao`; não reescrever/`git checkout` em arquivo não commitado sem ler antes.

Estado em 21/11/2026:

- **Marco atual: 3.86** — API estável (pool/health) + `PROMPT_TESTES_FISCAIS_GRATUITOS.md`. Commits: `9fa4a87` e os do outro agente acima (`aad7b7c` docs 3.85, `60ee0d9` esqueleto de pagamentos). Antes: 3.84 (cupom PDF), 3.83 (D10), `5da0c7d`/`462531f` (3.81 homologação), `5a3bd7b` (F1) e 3.80 (bipe). **O disco é a verdade: rode `git log --oneline -5`.**
- Suíte desktop **385/385**; build desktop **0/0**; `build_api.bat` **OK** (pare a API antes de compilar); testes Android **9/9** e `:bipe` compila; smoke de telas **33/33**; `permissoes_menu.ps1` **0 falhas**; `schema_roundtrip.ps1` e `banco_fresco.ps1` **OK** (585 campos, diff vazio, acentos conferidos). Na API 9000: `api_clientes_crud.ps1`, `api_auditoria.ps1` (6 logs), `api_estoque_service.ps1`, `api_numeracao_empresa.ps1`, `api_paginacao.ps1` e `api_f1.ps1` (7 logs) **OK**; `/api/health` respondeu `ok`.
- **Concluído nesta etapa:** **D10** (marco 3.83, §3.83): `.github\workflows\bateria.yml` (CI self-hosted) e `Scripts\testes\api_todos.ps1` rodando os 6 smokes com checagem de `/api/health`, sem reiniciar a API. Antes: **preferência de homologação** (3.81), **bipe** (3.80), **F1** (3.79), **F9** (3.78), **D7 + D8 + F6** (3.77), **D5 + F5** (3.76), **D4** (3.74), **F4 + D9** (3.72), **D3** (3.70), **T4** (3.69), **T1** (3.68) e **F3** (3.65–3.67, fiscal). Outro agente está no app PDV mobile (3.82).
- Banco real com índices D9 conferidos; duplicatas sem vínculo removidas (IDs 1237/1246/1247); `LOG_SISTEMA` sem resíduo de `CCE`.
- **Coordenação:** o app `:bipe` foi **finalizado e testado pelo outro agente** (marco 3.80, Samsung A55 + talão) e já está na bateria. Ele segue no **app PDV mobile `:pdv`** e nos pagamentos eletrônicos (marco 3.85, Fase 0 no ar desde o rebuild do marco 3.86) — **não tocar** em `uRotasPDV.pas`, `uMiddlewareJWT.pas`, `uMiddlewareSessao.pas`, `uPagamentoService.pas`, migração `022`/`:pdv/**` nem no manifest dele. Ler/escrever `Documentacao\COMUNICACAO_AGENTES.md` no início/fim de cada bloco e antes de reiniciar a API; código de `Android\android\bipe\**` continua intocável salvo pedido explícito. API na 9000, **PID 18576**, com o fix do pool (3.86) e as rotas PDV/pagamentos.
- **Auditorias de completude concluídas** (desktop e API/Android/banco): itens priorizados em `Documentacao\ROADMAP_PRODUCAO.md`, com F3/T1/T4/D3/F4/D9/D4/D5/F5/D7/D8/F6/F9/F1 + preferência de homologação + bipe + D10 concluídos. Ordem restante: **D11**, inclusão do `:pdv` na bateria quando o outro agente avisar, F3/F2/F8 (Android `:app`), F15/HTTPS/deploy e gestão/relatórios.
- **Próximo passo:** rodar a bateria local/gratuita do `PROMPT_TESTES_FISCAIS_GRATUITOS.md` (pedido 1003, nunca 3581) se o usuário pedir; aguardar o fechamento do `:pdv` para incluí-lo em builds/testes/docs **só com autorização**; sem colidir, atacar **D11** (HTTPS/CORS/token) e depois o restante do roadmap. NFS-e (F16) e nota de entrada de serviços (F17) estão como plano no prompt §5/§6 — não implementar sem decisão de provedor. Preservar cenário fiscal (talão 533/mapa 1014/pedido 3581), `:bipe` e `:pdv`. Bateria a cada marco: desktop **385/385**, `build_bipe.bat` **OK**, `api_todos.ps1` (6 smokes), Android **9/9**, telas **33/33**, permissões **0 falhas**, schema e banco fresco.

Comandos:

- `.github\workflows\bateria.yml` → CI `self-hosted`; exige runner na máquina de dev e API já na 9000. Não recompila a API.
- `powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\api_todos.ps1` → roda os 6 smokes com `/api/health`; esperado **API-TODOS CONCLUIDO**.
- `Scripts\build_desktop.bat` → esperado 0/0.
- `Scripts\build_api.bat` → compila `API\bin\ERP2026API.exe`.
- `Scripts\build_tests.bat` + `Scripts\run_tests.bat` → esperado **385/385** (`build_tests.bat` usa `-B`).
- `Scripts\run_tests_android.bat` → esperado **9/9** (compila `:app` e `:bipe`).
- `Scripts\build_bipe.bat` → gera `Android\android\bipe\build\outputs\apk\debug\bipe-debug.apk` (app de bipagem de talão, já validado no Samsung A55).
- `powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\telas_todas_ui.ps1` → smoke das 33 telas.
- `powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\permissoes_menu.ps1` → 0 falhas.
- Preferência de homologação: em *Sistema > Configurações*, marque "Modo homologação (NF-e/NFC-e e PDV)". Grava `NFE_AMBIENTE=2` + `NFE_MODO=REAL` na `CONFIGURACAO`; desmarcar volta a `NFE_MODO=SIMULADO`. Ver §3.81.
- `Scripts\preparar_acbr.bat` → copia schemas/DLLs para `Desktop\bin`.
- `powershell -ExecutionPolicy Bypass -File Scripts\gerar_certificado_teste.ps1` → gera `C:\certificados\teste.pfx` (só para validação local).
- `Scripts\validar_nfe.bat 1003` → valida o XML sem SEFAZ; resultado em `Desktop\bin\nfe\validacao_1003.txt`.
- `Scripts\validar_nfe.bat todos` → valida todos os pedidos; resultado em `Desktop\bin\nfe\validacao_todos.txt`; exit 1 se algum falhar.
- `PROMPT_TESTES_FISCAIS_GRATUITOS.md` → bateria fiscal **local/gratuita, sem MEI e sem SEFAZ** (copiar como instrução de trabalho). Certificado autoassinado só assina/valida localmente; nada é enviado. Inclui planos futuros de NFS-e e nota de entrada de serviços.
- Carga da API (marco 3.86): 60 logins com 20 simultâneos e `KeepAlive=false`; esperado `200=60 ... excecoes=0`, PID estável e `/api/health` com `"banco":"ok"`. Se usar `KeepAlive=true`, podem aparecer exceções de keep-alive no cliente — não é erro do pool.
- `powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\api_auditoria.ps1` → smoke D4 (API na 9000): confere 6 registros em `LOG_SISTEMA` e limpa tudo no `finally`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\api_estoque_service.ps1` → smoke D5: 201, saldo pela trigger, 1 log `INSERT` e 400s.
- `powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\api_numeracao_empresa.ps1` → smoke F5: número 990000 de outra empresa não interfere na sequência.
- `powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\api_paginacao.ps1` → smoke F6: contrato legado, total/páginas, página além do fim e isolamento por empresa.
- `powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\api_f1.ps1` → smoke F1: 5 endpoints novos + 7 auditorias, com limpeza no `finally`.
- `isql ... -i Scripts\preparar_cenario_fiscal.sql` → cria/reutiliza o cenário fiscal completo (pedido 3581).
- `Scripts\backup_banco.bat [pasta]` → backup gbak em `Backups\DADOS_AAAAMMDD_HHMMSS.fbk`.
- `Scripts\restaurar_banco.bat <arquivo.fbk> [destino.fdb] [forcar]` → restaura um banco novo.
- Banco: `Banco\dados.fdb` (SYSDBA/masterkey); Firebird 5 em `C:\Program Files\Firebird\Firebird_5_0`.
- Configuração de produção (banco/JWT): ver `Documentacao\CONFIGURACAO_AMBIENTE.md`.

Antes de commitar: ler o "Estado atual" do `CHECKPOINT.md`, o §3.86 do `Documentacao\PLANO_E_LOG.md` e `Documentacao\COMUNICACAO_AGENTES.md`. Parar a API antes de `build_api.bat` e avisar no canal; commit de marco sempre seguido de `git push origin master`.

---
