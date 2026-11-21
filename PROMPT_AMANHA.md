# Prompt de retomada — 21/11/2026

Copie o bloco abaixo ao abrir uma nova sessão.

---

Projeto: `C:\Users\Charles\Documents\ProjetoERP_1` (ERP 2026 — Lazarus/FPC + Firebird 5 no desktop, API Horse e app Android).

Regras: responder em português; terminar toda resposta com exatamente 3 linhas **Feito / Falta / Próximo passo**; atualizar `CHECKPOINT.md` e `Documentacao\PLANO_E_LOG.md` por marco (não a cada resposta); preservar todos os `android:id`; avisar antes de instalar pacotes/dependências; Firebird 5 (identificadores ≤31, `DEFAULT` antes de `NOT NULL`, sem `ALTER ... RENAME`); SQL sempre parametrizado; regra de negócio em Services; auditoria com `LogOperacao`; não reescrever/`git checkout` em arquivo não commitado sem ler antes.

Estado em 21/11/2026:

- **HEAD:** `5d17e17` (Isolamento por empresa nas consultas (T4)). Árvore limpa após o commit de docs.
- Suíte desktop **384/384**; build desktop **0/0** (sem avisos do compilador); API compilada; testes Android **OK**; smoke de telas **33/33**; `permissoes_menu.ps1` **0 falhas**.
- **Concluído nesta etapa:** **T4 — isolamento por empresa** (marco 3.69, §3.69): copiloto com 12 consultas filtrando `:EMP`, produção recusando mapa/pedido/talão de outra empresa, bipagem isolada via `TALAO`/`USUARIO` e caixa via `JOIN CAIXA`; novo `TestIsolamentoEmpresaProducao` (limpeza no `finally`). Antes: **T1 — permissões em todas as telas** (marco 3.68, §3.68): catálogo canônico de 33 telas, falha fechada na abertura, menu/ações por permissão e seed idempotente. O **bloco de acesso (T1/T4/F7) está fechado**, assim como o **bloco fiscal (F3)**.
- Banco real conferido sem resíduos (`LOG_SISTEMA` sem `CCE`).
- **Auditorias de completude concluídas** (desktop e API/Android/banco): itens priorizados em `Documentacao\ROADMAP_PRODUCAO.md`, com T1/T4 marcados como concluídos. Ordem restante: API D3, F4+D9, D4, D7/D8, F6/F9; gestão F5/F6/F9, F4/F13, relatórios/backup.
- **Próximo passo:** bloco da **API** — (a) **D3**: linkar `Desktop\src\Services` em `Scripts\build_api.bat` para acabar com SQL/regra duplicados; (b) **F4+D9**: devolver ID em `POST /api/clientes`, criar `PUT /api/clientes` e índices únicos; (c) **D4**: auditoria `LOG_SISTEMA` nas rotas; depois D5/F5, D7/D8 e F6/F9. Repetir a bateria completa (desktop, **384/384**, API, Android, smoke e permissões de menu) a cada marco.

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
- `isql ... -i Scripts\preparar_cenario_fiscal.sql` → cria/reutiliza o cenário fiscal completo (pedido 3581).
- `Scripts\backup_banco.bat [pasta]` → backup gbak em `Backups\DADOS_AAAAMMDD_HHMMSS.fbk`.
- `Scripts\restaurar_banco.bat <arquivo.fbk> [destino.fdb] [forcar]` → restaura um banco novo.
- Banco: `Banco\dados.fdb` (SYSDBA/masterkey); Firebird 5 em `C:\Program Files\Firebird\Firebird_5_0`.
- Configuração de produção (banco/JWT): ver `Documentacao\CONFIGURACAO_AMBIENTE.md`.

Antes de commitar: ler o "Estado atual" do `CHECKPOINT.md` e o §3.69 do `Documentacao\PLANO_E_LOG.md`.

---
