# Prompt de retomada — 07/11/2026

Copie o bloco abaixo ao abrir uma nova sessão.

---

Projeto: `C:\Users\Charles\Documents\ProjetoERP_1` (ERP 2026 — Lazarus/FPC + Firebird 5 no desktop, API Horse e app Android).

Regras: responder em português; terminar toda resposta com exatamente 3 linhas **Feito / Falta / Próximo passo**; atualizar `CHECKPOINT.md` e `Documentacao\PLANO_E_LOG.md` por marco (não a cada resposta); preservar todos os `android:id`; avisar antes de instalar pacotes/dependências; Firebird 5 (identificadores ≤31, `DEFAULT` antes de `NOT NULL`, sem `ALTER ... RENAME`); SQL sempre parametrizado; regra de negócio em Services; auditoria com `LogOperacao`; não reescrever/`git checkout` em arquivo não commitado sem ler antes.

Estado em 07/11/2026:

- **HEAD:** `fed1cbd` (Produtos: gravar categoria e unidade no cadastro). Árvore limpa.
- Suíte desktop **133/133**; build desktop **0/0**; testes Android **5/5**.
- Concluído nesta etapa: testes unitários das **notas fiscais de entrada/saída** (`Desktop\src\Tests\uNotasFiscaisTest.pas`, 34 testes), dos **cadastros** (`uGeograficoTest` 11 + `uCadastrosFase1Test` 23) e a **correção do cadastro de produto** (§3.28): categoria e unidade agora são obrigatórias, gravadas no `INSERT`/`UPDATE` e reselecionadas ao abrir o registro.
- Banco real conferido sem resíduos: zero órfãos e nenhuma linha com o sufixo da rodada.
- **Próximo passo (a definir):** testar estoque, financeiro ou pedidos no desktop — verificar antes os Services disponíveis.

Comandos:

- `Scripts\build_desktop.bat` → esperado 0/0.
- `Scripts\build_tests.bat` + `Scripts\run_tests.bat` → esperado **133/133**.
- `Scripts\run_tests_android.bat` → esperado **5/5**.
- Banco: `Banco\dados.fdb` (SYSDBA/masterkey); Firebird 5 em `C:\Program Files\Firebird\Firebird_5_0`.

Antes de commitar: ler o "Estado atual" do `CHECKPOINT.md` e o §3.28 do `Documentacao\PLANO_E_LOG.md`.

---
