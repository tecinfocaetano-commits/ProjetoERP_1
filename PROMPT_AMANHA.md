# Prompt de retomada — 15/11/2026

Copie o bloco abaixo ao abrir uma nova sessão.

---

Projeto: `C:\Users\Charles\Documents\ProjetoERP_1` (ERP 2026 — Lazarus/FPC + Firebird 5 no desktop, API Horse e app Android).

Regras: responder em português; terminar toda resposta com exatamente 3 linhas **Feito / Falta / Próximo passo**; atualizar `CHECKPOINT.md` e `Documentacao\PLANO_E_LOG.md` por marco (não a cada resposta); preservar todos os `android:id`; avisar antes de instalar pacotes/dependências; Firebird 5 (identificadores ≤31, `DEFAULT` antes de `NOT NULL`, sem `ALTER ... RENAME`); SQL sempre parametrizado; regra de negócio em Services; auditoria com `LogOperacao`; não reescrever/`git checkout` em arquivo não commitado sem ler antes.

Estado em 15/11/2026:

- **HEAD:** `9d4a445` (PDV: NFC-e na finalizacao da venda). Árvore limpa após o commit de docs.
- Suíte desktop **380/380**; build desktop **0/0** (sem avisos do compilador); API compilada; testes Android **OK**; smoke de telas **33/33**.
- Concluído nesta etapa: **NFC-e no PDV** (marco 3.67, §3.67): checkbox **"Emitir NFC-e ao finalizar"** em `uFrmPDV` (a venda é gravada e só depois a NFC-e é emitida; cupom em PDF aberto no leitor); destinatário **opcional no modelo 65** com regra única em `TACBrHelper.CamposFaltandoDestinatario` (endereço completo continua obrigatório na NF-e); configuração fiscal lida da `CONFIGURACAO` (`NFE_CERTIFICADO`, `NFE_AMBIENTE`, `NFE_MODO`, `NFCE_ID_CSC`, `NFCE_CSC`) — `NFE_MODO=REAL` liga a emissão real e a senha do certificado é pedida na hora (nunca fica no banco). Antes disso: **DANFE/cupom em PDF** (3.66), **CC-e/inutilização/manifestação** (3.65), **materialização da NF-e autorizada** (3.64), **importação real de XML** (3.63), **login por empresa** (3.62), **pool + health check** (3.61) e **configuração por ambiente** (3.60). O **bloco fiscal (F3) está fechado**.
- Banco real conferido sem resíduos (`LOG_SISTEMA` sem `CCE`).
- **Auditorias de completude concluídas** (desktop e API/Android/banco): itens priorizados em `Documentacao\ROADMAP_PRODUCAO.md`. Ordem: acesso T1/T4; API D3, F4+D9, D4, D7/D8, F6/F9; gestão F5/F6/F9, F4/F13, relatórios/backup.
- **Próximo passo:** bloco **T1 + T4** — (a) T1: aplicar checagem de permissão em todas as telas (hoje só 8 checam; usuários, produtos, pessoas, contas, NF-e, PDV e compras não checam), (b) T4: eliminar consultas/gravações que cruzam empresas (bipagem, consumo, produção, copiloto, caixa legado). Manter build 0/0 e suíte **380/380**.

Comandos:

- `Scripts\build_desktop.bat` → esperado 0/0.
- `Scripts\build_api.bat` → compila `API\bin\ERP2026API.exe`.
- `Scripts\build_tests.bat` + `Scripts\run_tests.bat` → esperado **380/380**.
- `Scripts\run_tests_android.bat` → esperado **5/5**.
- `powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\telas_todas_ui.ps1` → smoke das 33 telas.
- `Scripts\preparar_acbr.bat` → copia schemas/DLLs para `Desktop\bin`.
- `powershell -ExecutionPolicy Bypass -File Scripts\gerar_certificado_teste.ps1` → gera `C:\certificados\teste.pfx` (só para validação local).
- `Scripts\validar_nfe.bat 1003` → valida o XML sem SEFAZ; resultado em `Desktop\bin\nfe\validacao_1003.txt`.
- `Scripts\validar_nfe.bat todos` → valida todos os pedidos; resultado em `Desktop\bin\nfe\validacao_todos.txt`; exit 1 se algum falhar.
- `isql ... -i Scripts\preparar_cenario_fiscal.sql` → cria/reutiliza o cenário fiscal completo (pedido 3581).
- `Scripts\backup_banco.bat [pasta]` → backup gbak em `Backups\DADOS_AAAAMMDD_HHMMSS.fbk`.
- `Scripts\restaurar_banco.bat <arquivo.fbk> [destino.fdb] [forcar]` → restaura um banco novo.
- Banco: `Banco\dados.fdb` (SYSDBA/masterkey); Firebird 5 em `C:\Program Files\Firebird\Firebird_5_0`.
- Configuração de produção (banco/JWT): ver `Documentacao\CONFIGURACAO_AMBIENTE.md`.

Antes de commitar: ler o "Estado atual" do `CHECKPOINT.md` e o §3.67 do `Documentacao\PLANO_E_LOG.md`.

---
