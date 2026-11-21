# Prompt de retomada — 21/11/2026

Copie o bloco abaixo ao abrir uma nova sessão.

---

Projeto: `C:\Users\Charles\Documents\ProjetoERP_1` (ERP 2026 — Lazarus/FPC + Firebird 5 no desktop, API Horse e app Android).

Regras: responder em português; terminar toda resposta com exatamente 3 linhas **Feito / Falta / Próximo passo**; atualizar `CHECKPOINT.md` e `Documentacao\PLANO_E_LOG.md` por marco (não a cada resposta); preservar todos os `android:id`; avisar antes de instalar pacotes/dependências; Firebird 5 (identificadores ≤31, `DEFAULT` antes de `NOT NULL`, sem `ALTER ... RENAME`); SQL sempre parametrizado; regra de negócio em Services; auditoria com `LogOperacao`; não reescrever/`git checkout` em arquivo não commitado sem ler antes.

Estado em 21/11/2026:

- **HEAD:** `462531f` ("Homologacao: preferencia no PDV e NF-e com teste"); logo acima vem o commit de docs do marco 3.81. Antes: `5a3bd7b` (F1) e o marco 3.80 de outro agente (bipe no Samsung A55).
- Suíte desktop **385/385**; build desktop **0/0**; `build_api.bat` **OK** (pare a API antes de compilar); testes Android **9/9** e `:bipe` compila; smoke de telas **33/33**; `permissoes_menu.ps1` **0 falhas**; `schema_roundtrip.ps1` e `banco_fresco.ps1` **OK** (585 campos, diff vazio, acentos conferidos). Na API 9000: `api_clientes_crud.ps1`, `api_auditoria.ps1` (6 logs), `api_estoque_service.ps1`, `api_numeracao_empresa.ps1`, `api_paginacao.ps1` e `api_f1.ps1` (7 logs) **OK**; `/api/health` respondeu `ok`.
- **Concluído nesta etapa:** **preferência de homologação** (marco 3.81, §3.81): checkbox em *Sistema > Configurações* grava `NFE_AMBIENTE=2` + `NFE_MODO=REAL` na `CONFIGURACAO`; desativar volta a `NFE_MODO=SIMULADO`. `TACBrHelper`/PDV já consomem as chaves. Antes: **F1** (3.79), **F9** (3.78), **D7 + D8 + F6** (3.77), **D5 + F5** (3.76), **D4** (3.74), **F4 + D9** (3.72), **D3** (3.70), **T4** (3.69), **T1** (3.68) e **F3** (3.65–3.67, fiscal). Outro agente fechou o marco 3.80 (bipe).
- Banco real com índices D9 conferidos; duplicatas sem vínculo removidas (IDs 1237/1246/1247); `LOG_SISTEMA` sem resíduo de `CCE`.
- **Coordenação:** o app `:bipe` foi **finalizado e testado pelo outro agente** (marco 3.80, Samsung A55 + talão) e agora faz parte da bateria padrão. Ler/escrever `Documentacao\COMUNICACAO_AGENTES.md` antes de mexer em arquivo compartilhado; **código de `Android\android\bipe\**` continua intocável salvo pedido explícito**. `:app` e `:bipe` não compartilham arquivos Java. API principal está na 9000 e não foi reiniciada neste marco (mudança desktop-only).
- **Auditorias de completude concluídas** (desktop e API/Android/banco): itens priorizados em `Documentacao\ROADMAP_PRODUCAO.md`, com F3/T1/T4/D3/F4/D9/D4/D5/F5/D7/D8/F6/F9/F1 + preferência de homologação + bipe concluídos. Ordem restante: **D10/D11**, F3/F2/F8 (Android `:app`), F15/HTTPS/deploy e os itens de gestão/relatórios.
- **Próximo passo:** atacar **D10/D11** e depois o restante do roadmap, preservando o cenário fiscal (talão 533/mapa 1014/pedido 3581) e o app `:bipe` já fechado. Bateria completa a cada marco: desktop **385/385**, `build_bipe.bat` **OK**, API + 6 smokes, Android **9/9**, telas **33/33**, permissões **0 falhas**, schema e banco fresco.

Comandos:

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

Antes de commitar: ler o "Estado atual" do `CHECKPOINT.md`, o §3.81 do `Documentacao\PLANO_E_LOG.md` e `Documentacao\COMUNICACAO_AGENTES.md`.

---
