# Prompt de retomada — 07/11/2026

Copie o bloco abaixo ao abrir uma nova sessão.

---

Projeto: `C:\Users\Charles\Documents\ProjetoERP_1` (ERP 2026 — Lazarus/FPC + Firebird 5 no desktop, API Horse e app Android).

Regras: responder em português; terminar toda resposta com exatamente 3 linhas **Feito / Falta / Próximo passo**; atualizar `CHECKPOINT.md` e `Documentacao\PLANO_E_LOG.md` por marco (não a cada resposta); preservar todos os `android:id`; avisar antes de instalar pacotes/dependências; Firebird 5 (identificadores ≤31, `DEFAULT` antes de `NOT NULL`, sem `ALTER ... RENAME`); SQL sempre parametrizado; regra de negócio em Services; auditoria com `LogOperacao`; não reescrever/`git checkout` em arquivo não commitado sem ler antes.

Estado em 07/11/2026:

- **HEAD:** `2f0e3f7` (Estoque: service de movimentacao e testes). Árvore limpa.
- Suíte desktop **184/184**; build desktop **0/0**; testes Android **5/5**.
- Concluído nesta etapa: testes unitários das **notas fiscais** (`uNotasFiscaisTest`, 34), dos **cadastros** (`uGeograficoTest` 11 + `uCadastrosFase1Test` 23), a **correção do cadastro de produto** (§3.28), os testes do **caixa** (`uCaixaTest`, 17 — §3.29), as **contas a pagar/receber** (`uContasTest`, 16 — §3.30) e o **estoque** (`uEstoqueTest`, 18 — §3.31), que moveu as regras da tela para `uEstoqueService`, corrigiu o escopo da empresa na listagem e o `string right truncation` do filtro de texto.
- Banco real conferido sem resíduos: 10 movimentos e 4 linhas de `ESTOQUE` (pré-existentes), nenhum produto de teste, nenhuma linha com empresa `999999` e nenhum log `MOVIMENTO_ESTOQUE` sobrando.
- **Próximo passo (a definir):** testar **pedidos de venda** (`Views\uFrmPedidoVenda.pas`, 698 linhas: numeração, itens, grades, totais e gravação de `PEDIDO_VENDA`/`ITEM_PEDIDO`) no desktop — verificar antes se convém extrair as regras para um `uPedidoVendaService`.

Comandos:

- `Scripts\build_desktop.bat` → esperado 0/0.
- `Scripts\build_tests.bat` + `Scripts\run_tests.bat` → esperado **184/184**.
- `Scripts\run_tests_android.bat` → esperado **5/5**.
- Banco: `Banco\dados.fdb` (SYSDBA/masterkey); Firebird 5 em `C:\Program Files\Firebird\Firebird_5_0`.

Antes de commitar: ler o "Estado atual" do `CHECKPOINT.md` e o §3.31 do `Documentacao\PLANO_E_LOG.md`.

---
