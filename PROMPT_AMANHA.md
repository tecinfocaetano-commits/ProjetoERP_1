# Prompt de retomada — 21/11/2026

Copie o bloco abaixo ao abrir uma nova sessão.

---

Projeto: `C:\Users\Charles\Documents\ProjetoERP_1` (ERP 2026 — Lazarus/FPC + Firebird 5 no desktop, API Horse e app Android).

Regras: responder em português; terminar toda resposta com exatamente 3 linhas **Feito / Falta / Próximo passo**; atualizar `CHECKPOINT.md` e `Documentacao\PLANO_E_LOG.md` por marco (não a cada resposta); preservar todos os `android:id`; avisar antes de instalar pacotes/dependências; Firebird 5 (identificadores ≤31, `DEFAULT` antes de `NOT NULL`, sem `ALTER ... RENAME`); SQL sempre parametrizado; regra de negócio em Services; auditoria com `LogOperacao`; não reescrever/`git checkout` em arquivo não commitado sem ler antes.

Estado em 21/11/2026:

- **HEAD:** `c9bf7f3` ("API: auditoria LOG_SISTEMA nas rotas de escrita (D4)"); logo abaixo, `a30c4c6` (Bipe: histórico do servidor). O commit de docs deste marco vem acima.
- Suíte desktop **384/384**; build desktop **0/0**; `build_api.bat` **OK**; testes Android **OK** e `:bipe` compila; smoke de telas **33/33**; `permissoes_menu.ps1` **0 falhas**; `schema_roundtrip.ps1` e `banco_fresco.ps1` **OK** (585 campos, diff vazio); `api_clientes_crud.ps1` **OK** na 9000 e `api_auditoria.ps1` **OK** (6 logs).
- **Concluído nesta etapa:** **D4** (marco 3.74, §3.74): `LOG_SISTEMA` nas escritas da API com empresa/usuário do JWT e transação atômica; `TPessoaService` audita antes do commit. Antes: **F4 + D9** (3.72), **D3** (3.70), **T4** (3.69), **T1** (3.68) e **F3** (3.65–3.67, fiscal).
- Banco real com índices D9 conferidos; duplicatas sem vínculo removidas (IDs 1237/1246/1247); `LOG_SISTEMA` sem resíduo de `CCE`.
- **Coordenação:** outro agente ativo no app `:bipe`. Ler/escrever `Documentacao\COMUNICACAO_AGENTES.md` antes de mexer em arquivo compartilhado; **não editar `Android\android\bipe\**` sem pedido explícito**. API principal foi reiniciada com autorização e já contém as mudanças dele.
- **Auditorias de completude concluídas** (desktop e API/Android/banco): itens priorizados em `Documentacao\ROADMAP_PRODUCAO.md`, com F3/T1/T4/D3/F4/D9/D4 concluídos. Ordem restante: D5/F5, D7/D8, F6/F9; gestão F5/F6/F9, F4/F13, relatórios/backup.
- **Próximo passo:** bloco da **API** — (a) **D5**: `POST /api/estoque/movimento` usar Service, validar produto da empresa e atualizar saldo; (b) **F5**: numeração de orçamento por empresa; (c) **D7/D8** (banco novo) e **F6/F9** (paginação e erros de sync). Repetir a bateria completa (desktop **384/384**, API, ambos os smokes, Android, telas, permissões, schema e banco fresco) a cada marco.

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
- `isql ... -i Scripts\preparar_cenario_fiscal.sql` → cria/reutiliza o cenário fiscal completo (pedido 3581).
- `Scripts\backup_banco.bat [pasta]` → backup gbak em `Backups\DADOS_AAAAMMDD_HHMMSS.fbk`.
- `Scripts\restaurar_banco.bat <arquivo.fbk> [destino.fdb] [forcar]` → restaura um banco novo.
- Banco: `Banco\dados.fdb` (SYSDBA/masterkey); Firebird 5 em `C:\Program Files\Firebird\Firebird_5_0`.
- Configuração de produção (banco/JWT): ver `Documentacao\CONFIGURACAO_AMBIENTE.md`.

Antes de commitar: ler o "Estado atual" do `CHECKPOINT.md`, o §3.74 do `Documentacao\PLANO_E_LOG.md` e `Documentacao\COMUNICACAO_AGENTES.md`.

---
