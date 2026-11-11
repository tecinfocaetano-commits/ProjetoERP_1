# Prompt de retomada — 10/11/2026

Copie o bloco abaixo ao abrir uma nova sessão.

---

Projeto: `C:\Users\Charles\Documents\ProjetoERP_1` (ERP 2026 — Lazarus/FPC + Firebird 5 no desktop, API Horse e app Android).

Regras: responder em português; terminar toda resposta com exatamente 3 linhas **Feito / Falta / Próximo passo**; atualizar `CHECKPOINT.md` e `Documentacao\PLANO_E_LOG.md` por marco (não a cada resposta); preservar todos os `android:id`; avisar antes de instalar pacotes/dependências; Firebird 5 (identificadores ≤31, `DEFAULT` antes de `NOT NULL`, sem `ALTER ... RENAME`); SQL sempre parametrizado; regra de negócio em Services; auditoria com `LogOperacao`; não reescrever/`git checkout` em arquivo não commitado sem ler antes.

Estado em 10/11/2026:

- **HEAD:** `9937966` (NFe: CLI de validacao retorna 0/1/2 ao shell). Árvore limpa após o commit de docs.
- Suíte desktop **366/366**; build desktop **0/0**; testes Android **5/5** (inalterados).
- Concluído nesta etapa: **validação local da NF-e** (marco 3.56, §3.56): `ValidarNFe`/`EmitirReal(..., ASomenteValidar)`, CLI `--validar-nfe` com `--cert`/`--senha`, botão **Validar dados** na tela, `Scripts\gerar_certificado_teste.ps1`, `Scripts\validar_nfe.bat` e `Scripts\preparar_dados_nfe.sql`. O XML do pedido 1003 foi assinado com certificado autoassinado e validado contra os schemas, sem enviar nada à SEFAZ. Também fechou a **integração real da NF-e com ACBr** (marco 3.55, §3.55).
- Banco real conferido sem resíduos; a validação não persiste `NUMERO_NFE`/`CHAVE_NFE`.
- **Próximo passo:** usar `Scripts\validar_nfe.bat <pedido>` para conferir outros pedidos e corrigir cadastros fiscais (empresa/cliente/produto) antes da emissão real. Quando houver certificado **A1 válido**, desmarcar **Simulado** e emitir em homologação; NFC-e real exige `IdCSC`/`CSC`. Sem A1, manter o modo simulado.

Comandos:

- `Scripts\build_desktop.bat` → esperado 0/0.
- `Scripts\build_tests.bat` + `Scripts\run_tests.bat` → esperado **366/366**.
- `Scripts\run_tests_android.bat` → esperado **5/5**.
- `Scripts\preparar_acbr.bat` → copia schemas/DLLs para `Desktop\bin`.
- `powershell -ExecutionPolicy Bypass -File Scripts\gerar_certificado_teste.ps1` → gera `C:\certificados\teste.pfx` (só para validação local).
- `Scripts\validar_nfe.bat 1003` → valida o XML sem SEFAZ; resultado em `Desktop\bin\nfe\validacao_1003.txt`.
- Banco: `Banco\dados.fdb` (SYSDBA/masterkey); Firebird 5 em `C:\Program Files\Firebird\Firebird_5_0`.

Antes de commitar: ler o "Estado atual" do `CHECKPOINT.md` e o §3.56 do `Documentacao\PLANO_E_LOG.md`.

---
