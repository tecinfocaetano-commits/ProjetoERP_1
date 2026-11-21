# Prompt de retomada — 21/11/2026

Copie o bloco abaixo ao abrir uma nova sessão.

---

Projeto: `C:\Users\Charles\Documents\ProjetoERP_1` (ERP 2026 — Lazarus/FPC + Firebird 5 no desktop, API Horse e app Android).

Regras: responder em português; terminar toda resposta com exatamente 3 linhas **Feito / Falta / Próximo passo**; atualizar `CHECKPOINT.md` e `Documentacao\PLANO_E_LOG.md` por marco (não a cada resposta); preservar todos os `android:id`; avisar antes de instalar pacotes/dependências; Firebird 5 (identificadores ≤31, `DEFAULT` antes de `NOT NULL`, sem `ALTER ... RENAME`); SQL sempre parametrizado; regra de negócio em Services; auditoria com `LogOperacao`; não reescrever/`git checkout` em arquivo não commitado sem ler antes.

Estado em 21/11/2026:

- **HEAD:** `90f2af2` ("Banco canonico e paginacao opcional na API (D7+D8+F6)"); logo abaixo, `f40b63b` (docs do marco 3.76). O commit de docs deste marco vem acima.
- Suíte desktop **384/384**; build desktop **0/0**; `build_api.bat` **OK** (pare a API antes de compilar); testes Android **OK** e `:bipe` compila; smoke de telas **33/33**; `permissoes_menu.ps1` **0 falhas**; `schema_roundtrip.ps1` e `banco_fresco.ps1` **OK** (585 campos, diff vazio, acentos conferidos). Na API 9000: `api_clientes_crud.ps1`, `api_auditoria.ps1` (6 logs), `api_estoque_service.ps1`, `api_numeracao_empresa.ps1` e `api_paginacao.ps1` **OK**.
- **Concluído nesta etapa:** **D7 + D8 + F6** (marco 3.77, §3.77): banco novo pelo fluxo canônico (script com `INPUT` relativos, `SET NAMES UTF8` + isql `-ch UTF8`) e paginação opcional em vendas/financeiro sem quebrar o array legado. Antes: **D5 + F5** (3.76), **D4** (3.74), **F4 + D9** (3.72), **D3** (3.70), **T4** (3.69), **T1** (3.68) e **F3** (3.65–3.67, fiscal). Outro agente fechou o marco 3.75 com os dois apps Android no emulador.
- Banco real com índices D9 conferidos; duplicatas sem vínculo removidas (IDs 1237/1246/1247); `LOG_SISTEMA` sem resíduo de `CCE`.
- **Coordenação:** outro agente ativo no app `:bipe`. Ler/escrever `Documentacao\COMUNICACAO_AGENTES.md` antes de mexer em arquivo compartilhado; **não editar `Android\android\bipe\**` sem pedido explícito**. API principal foi reiniciada com aviso prévio no canal e já contém as mudanças dele.
- **Auditorias de completude concluídas** (desktop e API/Android/banco): itens priorizados em `Documentacao\ROADMAP_PRODUCAO.md`, com F3/T1/T4/D3/F4/D9/D4/D5/F5/D7/D8/F6 concluídos. Ordem restante: **F9**; gestão F5/F6/F9, F4/F13, relatórios/backup.
- **Próximo passo:** **F9** — visibilidade de erros de sincronização no Android (outbox sem tela, sem dead-letter/retry exponencial). **Coordenar antes pelo canal**: outro agente ativo no `:bipe`, não editar `Android\android\bipe\**` sem pedido explícito. Depois repetir a bateria completa (desktop **384/384**, API + 5 smokes, Android, telas, permissões, schema e banco fresco) a cada marco.

Comandos:

- `Scripts\build_desktop.bat` → esperado 0/0.
- `Scripts\build_api.bat` → compila `API\bin\ERP2026API.exe`.
- `Scripts\build_tests.bat` + `Scripts\run_tests.bat` → esperado **384/384**.
- `Scripts\run_tests_android.bat` → esperado **5/5**.
- `powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\telas_todas_ui.ps1` → smoke das 33 telas.
- `powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\permissoes_menu.ps1` → 0 falhas.
- `Scripts\preparar_acbr.bat` → copia schemas/DLLs para `Desktop\bin`.
- `powershell -ExecutionPolicy Bypass -File Scripts\gerar_certificado_teste.ps1` → gera `C:\certificados\teste.pfx` (só para validação local).
- `Scripts\validar_nfe.bat 1003` → valida o XML sem SEFAZ; resultado em `Desktop\bin\nfe\validacao_1003.txt`.
- `Scripts\validar_nfe.bat todos` → valida todos os pedidos; resultado em `Desktop\bin\nfe\validacao_todos.txt`; exit 1 se algum falhar.
- `powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\api_auditoria.ps1` → smoke D4 (API na 9000): confere 6 registros em `LOG_SISTEMA` e limpa tudo no `finally`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\api_estoque_service.ps1` → smoke D5: 201, saldo pela trigger, 1 log `INSERT` e 400s.
- `powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\api_numeracao_empresa.ps1` → smoke F5: número 990000 de outra empresa não interfere na sequência.
- `powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\api_paginacao.ps1` → smoke F6: contrato legado, total/páginas, página além do fim e isolamento por empresa.
- `isql ... -i Scripts\preparar_cenario_fiscal.sql` → cria/reutiliza o cenário fiscal completo (pedido 3581).
- `Scripts\backup_banco.bat [pasta]` → backup gbak em `Backups\DADOS_AAAAMMDD_HHMMSS.fbk`.
- `Scripts\restaurar_banco.bat <arquivo.fbk> [destino.fdb] [forcar]` → restaura um banco novo.
- Banco: `Banco\dados.fdb` (SYSDBA/masterkey); Firebird 5 em `C:\Program Files\Firebird\Firebird_5_0`.
- Configuração de produção (banco/JWT): ver `Documentacao\CONFIGURACAO_AMBIENTE.md`.

Antes de commitar: ler o "Estado atual" do `CHECKPOINT.md`, o §3.77 do `Documentacao\PLANO_E_LOG.md` e `Documentacao\COMUNICACAO_AGENTES.md`.

---
