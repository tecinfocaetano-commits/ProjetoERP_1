# Prompt de retomada — 14/11/2026

Copie o bloco abaixo ao abrir uma nova sessão.

---

Projeto: `C:\Users\Charles\Documents\ProjetoERP_1` (ERP 2026 — Lazarus/FPC + Firebird 5 no desktop, API Horse e app Android).

Regras: responder em português; terminar toda resposta com exatamente 3 linhas **Feito / Falta / Próximo passo**; atualizar `CHECKPOINT.md` e `Documentacao\PLANO_E_LOG.md` por marco (não a cada resposta); preservar todos os `android:id`; avisar antes de instalar pacotes/dependências; Firebird 5 (identificadores ≤31, `DEFAULT` antes de `NOT NULL`, sem `ALTER ... RENAME`); SQL sempre parametrizado; regra de negócio em Services; auditoria com `LogOperacao`; não reescrever/`git checkout` em arquivo não commitado sem ler antes.

Estado em 11/11/2026:

- **HEAD:** `7bffb94` (API: devolver conexao ao pool e health check). Árvore limpa após o commit de docs.
- Suíte desktop **366/366**; build desktop **0/0**; testes Android **OK**.
- Concluído nesta etapa: **API com pool limpo e health check** (marco 3.61, §3.61): middleware devolve a conexão da thread ao fim de cada requisição, `GET /api/health` é público e o teste de conexão do Android exige 2xx. Antes disso fechou a **configuração por ambiente** (3.60): `ERP_DB_HOST/PATH/USER/PASSWORD/PORT`, `ERP_JWT_SECRET` e `ERP_JWT_EXPIRACAO_HORAS`; ver `Documentacao\CONFIGURACAO_AMBIENTE.md`. Também fecharam o **backup/restauração** (3.59), o **cenário fiscal de teste** (3.58), a **validação em lote** (3.57), a **validação local** (3.56) e a **integração ACBr** (3.55).
- Banco real conferido sem resíduos; a validação não persiste `NUMERO_NFE`/`CHAVE_NFE`.
- **Auditorias de completude concluídas** (desktop e API/Android/banco): 40 itens priorizados em `Documentacao\ROADMAP_PRODUCAO.md`. Ordem: fiscal F1/F2/F3; acesso T1/T2/T3/T4 e F7; API D3, F4+D9, D4, D7/D8, F6/F9; gestão F5/F6/F9, F4/F13, F7/F15.
- **Próximo passo:** atacar o primeiro bloco do roadmap — importação real de XML (F1), materialização de `NOTA_SAIDA`/estoque/financeiro após autorizar (F2) e DANFE/NFC-e (F3) — mantendo build 0/0 e suíte 366/366. Usar os pedidos **1003** e **3581** na validação local; legados 997/998/1000 ficam fora do cenário fiscal.

Comandos:

- `Scripts\build_desktop.bat` → esperado 0/0.
- `Scripts\build_api.bat` → compila `API\bin\ERP2026API.exe`.
- `Scripts\build_tests.bat` + `Scripts\run_tests.bat` → esperado **366/366**.
- `Scripts\run_tests_android.bat` → esperado **5/5**.
- `Scripts\preparar_acbr.bat` → copia schemas/DLLs para `Desktop\bin`.
- `powershell -ExecutionPolicy Bypass -File Scripts\gerar_certificado_teste.ps1` → gera `C:\certificados\teste.pfx` (só para validação local).
- `Scripts\validar_nfe.bat 1003` → valida o XML sem SEFAZ; resultado em `Desktop\bin\nfe\validacao_1003.txt`.
- `Scripts\validar_nfe.bat todos` → valida todos os pedidos; resultado em `Desktop\bin\nfe\validacao_todos.txt`; exit 1 se algum falhar.
- `isql ... -i Scripts\preparar_cenario_fiscal.sql` → cria/reutiliza o cenário fiscal completo (pedido 3581).
- `Scripts\backup_banco.bat [pasta]` → backup gbak em `Backups\DADOS_AAAAMMDD_HHMMSS.fbk`.
- `Scripts\restaurar_banco.bat <arquivo.fbk> [destino.fdb] [forcar]` → restaura um banco novo.
- Banco: `Banco\dados.fdb` (SYSDBA/masterkey); Firebird 5 em `C:\Program Files\Firebird\Firebird_5_0`.
- Configuração de produção (banco/JWT): ver `Documentacao\CONFIGURACAO_AMBIENTE.md`.

Antes de commitar: ler o "Estado atual" do `CHECKPOINT.md` e o §3.61 do `Documentacao\PLANO_E_LOG.md`.

---
