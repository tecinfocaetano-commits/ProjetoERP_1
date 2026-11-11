# Prompt de retomada — 10/11/2026

Copie o bloco abaixo ao abrir uma nova sessão.

---

Projeto: `C:\Users\Charles\Documents\ProjetoERP_1` (ERP 2026 — Lazarus/FPC + Firebird 5 no desktop, API Horse e app Android).

Regras: responder em português; terminar toda resposta com exatamente 3 linhas **Feito / Falta / Próximo passo**; atualizar `CHECKPOINT.md` e `Documentacao\PLANO_E_LOG.md` por marco (não a cada resposta); preservar todos os `android:id`; avisar antes de instalar pacotes/dependências; Firebird 5 (identificadores ≤31, `DEFAULT` antes de `NOT NULL`, sem `ALTER ... RENAME`); SQL sempre parametrizado; regra de negócio em Services; auditoria com `LogOperacao`; não reescrever/`git checkout` em arquivo não commitado sem ler antes.

Estado em 10/11/2026:

- **HEAD:** `eceb35c` (NFe: integração real com ACBr, modo simulado preservado). Árvore limpa após o commit de docs.
- Suíte desktop **366/366**; build desktop **0/0**; testes Android **5/5** (inalterados).
- Concluído nesta etapa: **integração real da NF-e com ACBr** (marco 3.55, §3.55): helper com `ModoSimulado`, emissão/consulta/cancelamento/manifestação reais, tela com `chkSimulado`, `ERP2026.lpi` com `ACBr_NFe`/`-dACBR`, `Tests.lpi` sem ACBr e com saída própria, e `Scripts\preparar_acbr.bat`.
- Banco real conferido sem resíduos.
- **Próximo passo:** para emitir de verdade, preencher dados fiscais/endereço de `EMPRESA`, `PESSOA` e `PRODUTO`/`PRODUTO_FISCAL`, rodar `Scripts\preparar_acbr.bat` e usar um certificado A1 válido. Sem certificado, manter **Modo simulado** marcado. NFC-e real exige `IdCSC`/`CSC`.

Comandos:

- `Scripts\build_desktop.bat` → esperado 0/0.
- `Scripts\build_tests.bat` + `Scripts\run_tests.bat` → esperado **366/366**.
- `Scripts\run_tests_android.bat` → esperado **5/5**.
- `Scripts\preparar_acbr.bat` → copia schemas/DLLs para `Desktop\bin`.
- Banco: `Banco\dados.fdb` (SYSDBA/masterkey); Firebird 5 em `C:\Program Files\Firebird\Firebird_5_0`.

Antes de commitar: ler o "Estado atual" do `CHECKPOINT.md` e o §3.55 do `Documentacao\PLANO_E_LOG.md`.

---
