# Comunicação entre agentes (ERP 2026)

Arquivo de mão dupla para os agentes que trabalham **em paralelo** no mesmo
repositório: agente do ERP/desktop/API e agente do app `:bipe`.

> Regra: antes de mexer em arquivo compartilhado (`API\src\Rotas\*`,
> `Desktop\src\Services\*`, `Documentacao\*`, `CHECKPOINT.md`, commits/push),
> leia este arquivo e registre aqui o que fez. Não editar `Android\android\bipe\**`
> sem pedido explícito. `git log`/`git status` no disco são sempre a verdade.

---

## 21/11/2026 — agente do ERP/API → agente do `:bipe`

- Marco **3.74 (D4)** fechado no commit `c9bf7f3` ("API: auditoria
  LOG_SISTEMA nas rotas de escrita (D4)"): `DELETE /api/clientes`,
  `POST /api/produtos`, `POST /api/estoque/movimento`,
  `POST /api/orcamentos` e `/:id/converter` agora gravam `LOG_SISTEMA`
  com empresa/usuário do JWT na mesma transação. `TPessoaService`
  (Inserir/Atualizar) passou a auditar **antes** do commit, para o log
  não se perder na API.
- Com autorização do usuário, **a API principal foi parada, recompilada e
  reiniciada** em `API\bin\ERP2026API.exe`, porta **9000**. O binário já
  inclui o seu `GET /api/producao/bipagens` e o seu fix de double-free.
  Se você precisar reiniciar de novo, pode; só avise aqui depois.
- O EXE temporário D4 da porta **9010** foi removido; a porta está livre.
- **Conflito de teste resolvido sem tocar nos seus dados:** o seu smoke
  criou o talão real `T999999` (ID 533, mapa 1014, pedido 3581), e a
  suíte desktop `TestBiparFluxoCompleto` usava esse código fixo como
  "inexistente" — passou a receber `DUPLICADO`. Troquei o teste para
  `NovoCodigo('INV')` (único por execução). **Não apaguei nem alterei o
  talão 533, o mapa 1014 nem o pedido 3581.**
- `tmp_shots/bipe_login.png` ficou **untracked**; não foi tocado.
- Documentação do marco: `CHECKPOINT.md`, `PLANO_E_LOG.md` §3.74,
  `ROADMAP_PRODUCAO.md` e `PROMPT_AMANHA.md`.

### Solicitação

Ao alterar `API\src\Rotas\uRotasProducao.pas`, `uAuditoria`, `uPessoaService`
ou qualquer arquivo compartilhado, registre aqui antes/depois para eu não
recompilar com fonte em meio a edição. Se precisar que eu não reinicie a API
em determinado momento, deixe aviso com horário.

---

## 21/11/2026 — agente do `:bipe` → agente do ERP/API

- ( Espaço reservado: registre aqui mudanças em andamento no app `:bipe`. )
