# Prompt de retomada — 10/11/2026

Copie o bloco abaixo ao abrir uma nova sessão.

---

Projeto: `C:\Users\Charles\Documents\ProjetoERP_1` (ERP 2026 — Lazarus/FPC + Firebird 5 no desktop, API Horse e app Android).

Regras: responder em português; terminar toda resposta com exatamente 3 linhas **Feito / Falta / Próximo passo**; atualizar `CHECKPOINT.md` e `Documentacao\PLANO_E_LOG.md` por marco (não a cada resposta); preservar todos os `android:id`; avisar antes de instalar pacotes/dependências; Firebird 5 (identificadores ≤31, `DEFAULT` antes de `NOT NULL`, sem `ALTER ... RENAME`); SQL sempre parametrizado; regra de negócio em Services; auditoria com `LogOperacao`; não reescrever/`git checkout` em arquivo não commitado sem ler antes.

Estado em 10/11/2026:

- **HEAD:** `3a475cf` (NFe: validacao em lote no CLI). Árvore limpa após o commit de docs.
- Suíte desktop **366/366**; build desktop **0/0**; testes Android **5/5** (inalterados).
- Concluído nesta etapa: **validação da NF-e em lote** (marco 3.57, §3.57): `--validar-nfe=todos` valida cada pedido isoladamente, grava `Desktop\bin\nfe\validacao_todos.txt` e retorna 0/1; `Scripts\validar_nfe.bat` aceita `todos` e propaga o exit code. Resultado atual: **1 OK, 3 ERRO** (1003 OK; 997/998/1000 são pedidos legados sem `NUMERO`/`BAIRRO` no destinatário). Antes disso fecharam a **validação local da NF-e** (marco 3.56, §3.56) e a **integração real da NF-e com ACBr** (marco 3.55, §3.55).
- Banco real conferido sem resíduos; a validação não persiste `NUMERO_NFE`/`CHAVE_NFE`.
- **Próximo passo:** decidir com o usuário entre corrigir os cadastros dos pedidos legados 997/998/1000 ou criar um cenário fiscal novo (pedido/produto/cliente próprios, sem alterar o produto 1 dos testes). Quando houver certificado **A1 válido**, desmarcar **Simulado** e emitir em homologação; NFC-e real exige `IdCSC`/`CSC`. Sem A1, manter o modo simulado.

Comandos:

- `Scripts\build_desktop.bat` → esperado 0/0.
- `Scripts\build_tests.bat` + `Scripts\run_tests.bat` → esperado **366/366**.
- `Scripts\run_tests_android.bat` → esperado **5/5**.
- `Scripts\preparar_acbr.bat` → copia schemas/DLLs para `Desktop\bin`.
- `powershell -ExecutionPolicy Bypass -File Scripts\gerar_certificado_teste.ps1` → gera `C:\certificados\teste.pfx` (só para validação local).
- `Scripts\validar_nfe.bat 1003` → valida o XML sem SEFAZ; resultado em `Desktop\bin\nfe\validacao_1003.txt`.
- `Scripts\validar_nfe.bat todos` → valida todos os pedidos; resultado em `Desktop\bin\nfe\validacao_todos.txt`; exit 1 se algum falhar.
- Banco: `Banco\dados.fdb` (SYSDBA/masterkey); Firebird 5 em `C:\Program Files\Firebird\Firebird_5_0`.

Antes de commitar: ler o "Estado atual" do `CHECKPOINT.md` e o §3.57 do `Documentacao\PLANO_E_LOG.md`.

---
