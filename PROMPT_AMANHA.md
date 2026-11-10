# Prompt de retomada — 09/11/2026

Copie o bloco abaixo ao abrir uma nova sessão.

---

Projeto: `C:\Users\Charles\Documents\ProjetoERP_1` (ERP 2026 — Lazarus/FPC + Firebird 5 no desktop, API Horse e app Android).

Regras: responder em português; terminar toda resposta com exatamente 3 linhas **Feito / Falta / Próximo passo**; atualizar `CHECKPOINT.md` e `Documentacao\PLANO_E_LOG.md` por marco (não a cada resposta); preservar todos os `android:id`; avisar antes de instalar pacotes/dependências; Firebird 5 (identificadores ≤31, `DEFAULT` antes de `NOT NULL`, sem `ALTER ... RENAME`); SQL sempre parametrizado; regra de negócio em Services; auditoria com `LogOperacao`; não reescrever/`git checkout` em arquivo não commitado sem ler antes.

Estado em 09/11/2026:

- **HEAD:** `162be42` (Testes: suite da NF-e/ACBrHelper com banco real). Árvore limpa.
- Suíte desktop **366/366**; build desktop **0/0**; testes Android **5/5** (inalterados).
- Concluído nesta etapa: testes da **NF-e** (`uNFeTest`, 17 — §3.54), fechando a fila de testes desktop (PDV, Movimento Financeiro, Inventário, Kardex, Produção/Consumo e NFe).
- Banco real conferido sem resíduos: nenhuma pessoa/pedido/log dos testes da NF-e; `MOVIMENTO_FINANCEIRO` vazia.
- **Próximo passo:** a definir com o usuário. O backlog documentado (§2 do `PLANO_E_LOG.md`) está concluído. O único item fiscal ainda simulado é a integração real da NF-e com ACBr/SEFAZ (blocos comentados em `uACBrHelper.pas`); instalar o ACBr exige aviso prévio.

Comandos:

- `Scripts\build_desktop.bat` → esperado 0/0.
- `Scripts\build_tests.bat` + `Scripts\run_tests.bat` → esperado **366/366**.
- `Scripts\run_tests_android.bat` → esperado **5/5**.
- Banco: `Banco\dados.fdb` (SYSDBA/masterkey); Firebird 5 em `C:\Program Files\Firebird\Firebird_5_0`.

Antes de commitar: ler o "Estado atual" do `CHECKPOINT.md` e o §3.54 do `Documentacao\PLANO_E_LOG.md`.

---
