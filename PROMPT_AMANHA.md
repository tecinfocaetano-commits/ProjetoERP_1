# Prompt de retomada — 07/11/2026

Copie o bloco abaixo ao abrir uma nova sessão.

---

Projeto: `C:\Users\Charles\Documents\ProjetoERP_1` (ERP 2026 — Lazarus/FPC + Firebird 5 no desktop, API Horse e app Android).

Regras: responder em português; terminar toda resposta com exatamente 3 linhas **Feito / Falta / Próximo passo**; atualizar `CHECKPOINT.md` e `Documentacao\PLANO_E_LOG.md` por marco (não a cada resposta); preservar todos os `android:id`; avisar antes de instalar pacotes/dependências; Firebird 5 (identificadores ≤31, `DEFAULT` antes de `NOT NULL`, sem `ALTER ... RENAME`); SQL sempre parametrizado; regra de negócio em Services; auditoria com `LogOperacao`; não reescrever/`git checkout` em arquivo não commitado sem ler antes.

Estado em 07/11/2026:

- **HEAD:** `f0d947d` (Financeiro: service de contas a pagar/receber e testes). Árvore limpa.
- Suíte desktop **166/166**; build desktop **0/0**; testes Android **5/5**.
- Concluído nesta etapa: testes unitários das **notas fiscais** (`uNotasFiscaisTest`, 34), dos **cadastros** (`uGeograficoTest` 11 + `uCadastrosFase1Test` 23), a **correção do cadastro de produto** (§3.28), os testes do **caixa** (`uCaixaTest`, 17 — §3.29) e as **contas a pagar/receber** (`uContasTest`, 16 — §3.30), que moveram as regras das telas para `uContasService` e corrigiram a inclusão de conta a receber (não gravava `FINANCEIRO_ID`, `DM_ID NOT NULL`).
- Banco real conferido sem resíduos: 3 contas a pagar e 2 a receber (pré-existentes), 2 planos financeiros, nenhuma linha com o sufixo da rodada e nenhum log `CONTA_PAGAR`/`CONTA_RECEBER` sobrando.
- **Próximo passo (a definir):** testar **estoque** (`Views\uFrmMovEstoque.pas`, `Models\uEstoque.pas`, trigger `TRG_MOVEST_AI`) ou **pedidos** (`Views\uFrmPedidoVenda.pas`) no desktop — verificar antes se convém extrair as regras para um Service.

Comandos:

- `Scripts\build_desktop.bat` → esperado 0/0.
- `Scripts\build_tests.bat` + `Scripts\run_tests.bat` → esperado **166/166**.
- `Scripts\run_tests_android.bat` → esperado **5/5**.
- Banco: `Banco\dados.fdb` (SYSDBA/masterkey); Firebird 5 em `C:\Program Files\Firebird\Firebird_5_0`.

Antes de commitar: ler o "Estado atual" do `CHECKPOINT.md` e o §3.30 do `Documentacao\PLANO_E_LOG.md`.

---
