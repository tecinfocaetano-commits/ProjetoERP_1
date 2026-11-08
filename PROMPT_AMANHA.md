# Prompt de retomada — 08/11/2026

Copie o bloco abaixo ao abrir uma nova sessão.

---

Projeto: `C:\Users\Charles\Documents\ProjetoERP_1` (ERP 2026 — Lazarus/FPC + Firebird 5 no desktop, API Horse e app Android).

Regras: responder em português; terminar toda resposta com exatamente 3 linhas **Feito / Falta / Próximo passo**; atualizar `CHECKPOINT.md` e `Documentacao\PLANO_E_LOG.md` por marco (não a cada resposta); preservar todos os `android:id`; avisar antes de instalar pacotes/dependências; Firebird 5 (identificadores ≤31, `DEFAULT` antes de `NOT NULL`, sem `ALTER ... RENAME`); SQL sempre parametrizado; regra de negócio em Services; auditoria com `LogOperacao`; não reescrever/`git checkout` em arquivo não commitado sem ler antes.

Estado em 08/11/2026:

- **HEAD:** `ae86f28` (Orcamento: service com conversao em pedido e testes). Árvore limpa.
- Suíte desktop **254/254**; build desktop **0/0**; testes Android **5/5**.
- Concluído nesta etapa: testes unitários das **notas fiscais** (`uNotasFiscaisTest`, 34), dos **cadastros** (`uGeograficoTest` 11 + `uCadastrosFase1Test` 23), a **correção do cadastro de produto** (§3.28), os testes do **caixa** (`uCaixaTest`, 17 — §3.29), as **contas a pagar/receber** (`uContasTest`, 16 — §3.30), o **estoque** (`uEstoqueTest`, 18 — §3.31), os **pedidos de venda** (`uPedidoVendaTest`, 25 — §3.32), as **compras** (`uPedidoCompraTest`, 22 — §3.33) e o **orçamento** (`uOrcamentoTest`, 23 — §3.34).
- Banco real conferido sem resíduos: 4 pedidos de venda e 6 itens (pré-existentes), nenhuma linha em `ITEM_PEDIDO_GRADE`, nenhuma pessoa/produto de teste, nenhuma linha com empresa `999999` e nenhum log de `CONVERSAO`.
- **Próximo passo:** cobrir o **PDV** (`uFrmPDV.pas`, 547 linhas e 12 SQL); depois Movimento Financeiro, Inventário/Kardex, Consumo/Ficha/Bipagem/Cores e NFe.

Comandos:

- `Scripts\build_desktop.bat` → esperado 0/0.
- `Scripts\build_tests.bat` + `Scripts\run_tests.bat` → esperado **254/254**.
- `Scripts\run_tests_android.bat` → esperado **5/5**.
- Banco: `Banco\dados.fdb` (SYSDBA/masterkey); Firebird 5 em `C:\Program Files\Firebird\Firebird_5_0`.

Antes de commitar: ler o "Estado atual" do `CHECKPOINT.md` e o §3.34 do `Documentacao\PLANO_E_LOG.md`.

---
