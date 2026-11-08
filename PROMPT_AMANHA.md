# Prompt de retomada — 08/11/2026

Copie o bloco abaixo ao abrir uma nova sessão.

---

Projeto: `C:\Users\Charles\Documents\ProjetoERP_1` (ERP 2026 — Lazarus/FPC + Firebird 5 no desktop, API Horse e app Android).

Regras: responder em português; terminar toda resposta com exatamente 3 linhas **Feito / Falta / Próximo passo**; atualizar `CHECKPOINT.md` e `Documentacao\PLANO_E_LOG.md` por marco (não a cada resposta); preservar todos os `android:id`; avisar antes de instalar pacotes/dependências; Firebird 5 (identificadores ≤31, `DEFAULT` antes de `NOT NULL`, sem `ALTER ... RENAME`); SQL sempre parametrizado; regra de negócio em Services; auditoria com `LogOperacao`; não reescrever/`git checkout` em arquivo não commitado sem ler antes.

Estado em 08/11/2026:

- **HEAD:** `d7e3304` (Compras: service de pedido de compra e testes). Árvore limpa.
- Suíte desktop **231/231**; build desktop **0/0**; testes Android **5/5**.
- Concluído nesta etapa: testes unitários das **notas fiscais** (`uNotasFiscaisTest`, 34), dos **cadastros** (`uGeograficoTest` 11 + `uCadastrosFase1Test` 23), a **correção do cadastro de produto** (§3.28), os testes do **caixa** (`uCaixaTest`, 17 — §3.29), as **contas a pagar/receber** (`uContasTest`, 16 — §3.30), o **estoque** (`uEstoqueTest`, 18 — §3.31), os **pedidos de venda** (`uPedidoVendaTest`, 25 — §3.32) e as **compras** (`uPedidoCompraTest`, 22 — §3.33).
- Banco real conferido sem resíduos: 1 pedido de compra (`PC-TESTE-8`) e 1 item (pré-existentes), nenhuma pessoa/material de teste e nenhuma linha com empresa `999999`.
- **Próximo passo:** cobrir o **orçamento** (`uFrmOrcamento.pas`), que grava `PEDIDO_VENDA` com `STATUS='O'` e converte para `'P'`; depois PDV, Movimento Financeiro, Inventário/Kardex, Consumo/Ficha/Bipagem/Cores e NFe.

Comandos:

- `Scripts\build_desktop.bat` → esperado 0/0.
- `Scripts\build_tests.bat` + `Scripts\run_tests.bat` → esperado **231/231**.
- `Scripts\run_tests_android.bat` → esperado **5/5**.
- Banco: `Banco\dados.fdb` (SYSDBA/masterkey); Firebird 5 em `C:\Program Files\Firebird\Firebird_5_0`.

Antes de commitar: ler o "Estado atual" do `CHECKPOINT.md` e o §3.33 do `Documentacao\PLANO_E_LOG.md`.

---
