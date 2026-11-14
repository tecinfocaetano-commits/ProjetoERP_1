# Prompt de retomada — 14/11/2026

Copie o bloco abaixo ao abrir uma nova sessão.

---

Projeto: `C:\Users\Charles\Documents\ProjetoERP_1` (ERP 2026 — Lazarus/FPC + Firebird 5 no desktop, API Horse e app Android).

Regras: responder em português; terminar toda resposta com exatamente 3 linhas **Feito / Falta / Próximo passo**; atualizar `CHECKPOINT.md` e `Documentacao\PLANO_E_LOG.md` por marco (não a cada resposta); preservar todos os `android:id`; avisar antes de instalar pacotes/dependências; Firebird 5 (identificadores ≤31, `DEFAULT` antes de `NOT NULL`, sem `ALTER ... RENAME`); SQL sempre parametrizado; regra de negócio em Services; auditoria com `LogOperacao`; não reescrever/`git checkout` em arquivo não commitado sem ler antes.

Estado em 14/11/2026:

- **HEAD:** `0c539c3` (NF-e: importacao real de XML vira Service). Árvore limpa após o commit de docs.
- Suíte desktop **368/368**; build desktop **0/0**; testes Android **OK**.
- Concluído nesta etapa: **importação real de XML de NF-e** (marco 3.63, §3.63): `uNFeXmlService` lê o XML (BOM/namespace/entidades), localiza fornecedor por CNPJ e produto por código, grava a nota via `TNotaEntradaService`, usa NCM/CFOP/CST do documento, recusa chave repetida e remove nota parcial em falha; `uFrmNotaEntrada` e `TACBrHelper.ImportarXML` usam o Service. Antes disso fechou o **login por empresa** (3.62), a **API com pool limpo e health check** (3.61) e a **configuração por ambiente** (3.60: `ERP_DB_*`, `ERP_JWT_SECRET`; ver `Documentacao\CONFIGURACAO_AMBIENTE.md`), além de **backup/restauração** (3.59) e do ciclo fiscal de teste (3.55–3.58).
- Banco real conferido sem resíduos; a validação não persiste `NUMERO_NFE`/`CHAVE_NFE` e o teste de importação limpa nota/itens/produto/fornecedor.
- **Auditorias de completude concluídas** (desktop e API/Android/banco): itens priorizados em `Documentacao\ROADMAP_PRODUCAO.md`. Ordem: fiscal F2/F3; acesso T1/T4; API D3, F4+D9, D4, D7/D8, F6/F9; gestão F5/F6/F9, F4/F13, relatórios/backup.
- **Próximo passo:** materialização de `NOTA_SAIDA`/estoque/financeiro após autorizar (F2) e DANFE/NFC-e (F3), mantendo build 0/0 e suíte 368/368. Usar os pedidos **1003** e **3581** na validação local; legados 997/998/1000 ficam fora do cenário fiscal.

Comandos:

- `Scripts\build_desktop.bat` → esperado 0/0.
- `Scripts\build_api.bat` → compila `API\bin\ERP2026API.exe`.
- `Scripts\build_tests.bat` + `Scripts\run_tests.bat` → esperado **368/368**.
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

Antes de commitar: ler o "Estado atual" do `CHECKPOINT.md` e o §3.63 do `Documentacao\PLANO_E_LOG.md`.

---
