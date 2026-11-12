# Prompt de retomada — 11/11/2026

Copie o bloco abaixo ao abrir uma nova sessão.

---

Projeto: `C:\Users\Charles\Documents\ProjetoERP_1` (ERP 2026 — Lazarus/FPC + Firebird 5 no desktop, API Horse e app Android).

Regras: responder em português; terminar toda resposta com exatamente 3 linhas **Feito / Falta / Próximo passo**; atualizar `CHECKPOINT.md` e `Documentacao\PLANO_E_LOG.md` por marco (não a cada resposta); preservar todos os `android:id`; avisar antes de instalar pacotes/dependências; Firebird 5 (identificadores ≤31, `DEFAULT` antes de `NOT NULL`, sem `ALTER ... RENAME`); SQL sempre parametrizado; regra de negócio em Services; auditoria com `LogOperacao`; não reescrever/`git checkout` em arquivo não commitado sem ler antes.

Estado em 11/11/2026:

- **HEAD:** `66efaa7` (Banco: scripts de backup e restauracao). Árvore limpa após o commit de docs.
- Suíte desktop **366/366**; build desktop **0/0**; testes Android **5/5** (inalterados).
- Concluído nesta etapa: **backup e restauração do banco** (marco 3.59, §3.59): `Scripts\backup_banco.bat` (gbak -b -g, arquivo com timestamp em `Backups/`) e `Scripts\restaurar_banco.bat` (gbak -c, destino novo por padrão, `forcar` para sobrescrever). Testado com backup de 362.496 bytes e restauração em `%TEMP%` (5 pedidos). Antes disso fecharam o **cenário fiscal de teste** (3.58), a **validação em lote** (3.57), a **validação local** (3.56) e a **integração ACBr** (3.55).
- Banco real conferido sem resíduos; a validação não persiste `NUMERO_NFE`/`CHAVE_NFE`.
- **Próximo passo:** levantar as lacunas de produção para comércio/indústria (fiscal, segurança/HTTPS, relatórios, manual, deploy e monitoramento) e priorizar com o usuário. Usar os pedidos **1003** e **3581** na validação local; legados 997/998/1000 ficam fora do cenário fiscal. Quando houver certificado **A1 válido**, desmarcar **Simulado** e emitir em homologação.

Comandos:

- `Scripts\build_desktop.bat` → esperado 0/0.
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

Antes de commitar: ler o "Estado atual" do `CHECKPOINT.md` e o §3.59 do `Documentacao\PLANO_E_LOG.md`.

---
