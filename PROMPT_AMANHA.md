# Prompt de retomada — 10/11/2026

Copie o bloco abaixo ao abrir uma nova sessão.

---

Projeto: `C:\Users\Charles\Documents\ProjetoERP_1` (ERP 2026 — Lazarus/FPC + Firebird 5 no desktop, API Horse e app Android).

Regras: responder em português; terminar toda resposta com exatamente 3 linhas **Feito / Falta / Próximo passo**; atualizar `CHECKPOINT.md` e `Documentacao\PLANO_E_LOG.md` por marco (não a cada resposta); preservar todos os `android:id`; avisar antes de instalar pacotes/dependências; Firebird 5 (identificadores ≤31, `DEFAULT` antes de `NOT NULL`, sem `ALTER ... RENAME`); SQL sempre parametrizado; regra de negócio em Services; auditoria com `LogOperacao`; não reescrever/`git checkout` em arquivo não commitado sem ler antes.

Estado em 10/11/2026:

- **HEAD:** `90e583c` (NFe: cenario fiscal de teste completo). Árvore limpa após o commit de docs.
- Suíte desktop **366/366**; build desktop **0/0**; testes Android **5/5** (inalterados).
- Concluído nesta etapa: **cenário fiscal de teste completo** (marco 3.58, §3.58): `Scripts\preparar_cenario_fiscal.sql` cria/reutiliza cliente MG, produto fiscal com CFOP 6102, produto, pedido `CEN-FISCAL-01` e item (pedido 3581), de forma idempotente. `Scripts\validar_nfe.bat 3581` → OK; `... todos` → **2 OK, 3 ERRO**. `TestIntegridade018` passou a exigir ao menos os totais migrados. Antes disso fecharam a **validação em lote** (marco 3.57), a **validação local** (3.56) e a **integração ACBr** (3.55).
- Banco real conferido sem resíduos; a validação não persiste `NUMERO_NFE`/`CHAVE_NFE`.
- **Próximo passo:** usar os pedidos **1003** e **3581** na validação local. Os legados 997/998/1000 ficam fora do cenário fiscal. Quando houver certificado **A1 válido**, desmarcar **Simulado** e emitir em homologação; NFC-e real exige `IdCSC`/`CSC`. Sem A1, manter o modo simulado.

Comandos:

- `Scripts\build_desktop.bat` → esperado 0/0.
- `Scripts\build_tests.bat` + `Scripts\run_tests.bat` → esperado **366/366**.
- `Scripts\run_tests_android.bat` → esperado **5/5**.
- `Scripts\preparar_acbr.bat` → copia schemas/DLLs para `Desktop\bin`.
- `powershell -ExecutionPolicy Bypass -File Scripts\gerar_certificado_teste.ps1` → gera `C:\certificados\teste.pfx` (só para validação local).
- `Scripts\validar_nfe.bat 1003` → valida o XML sem SEFAZ; resultado em `Desktop\bin\nfe\validacao_1003.txt`.
- `Scripts\validar_nfe.bat todos` → valida todos os pedidos; resultado em `Desktop\bin\nfe\validacao_todos.txt`; exit 1 se algum falhar.
- `isql ... -i Scripts\preparar_cenario_fiscal.sql` → cria/reutiliza o cenário fiscal completo (pedido 3581).
- Banco: `Banco\dados.fdb` (SYSDBA/masterkey); Firebird 5 em `C:\Program Files\Firebird\Firebird_5_0`.

Antes de commitar: ler o "Estado atual" do `CHECKPOINT.md` e o §3.58 do `Documentacao\PLANO_E_LOG.md`.

---
