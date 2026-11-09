# INSTRUÇÕES PARA O AGENTE — como manter o checkpoint

> Cole este texto (ou diga "leia `Documentacao\INSTRUCOES_AGENTE.md`") no outro
> agente antes de ele começar. Projeto: `C:\Users\Charles\Documents\ProjetoERP_1`.

Você está assumindo o **ERP 2026** (Desktop Lazarus/FPC + Firebird 5 + API).
Antes de qualquer coisa, **leia `CHECKPOINT.md` inteiro**. Ele é a fonte de
verdade do estado — não a conversa anterior, nem a sua memória.

## Regra principal: checkpoint por MARCO, não por resposta

Atualize `CHECKPOINT.md` e `Documentacao\PLANO_E_LOG.md` **somente quando**:

1. concluir um item/feature;
2. fizer um commit;
3. mudar o plano (decisão nova, bloqueio, item adiado).

Não atualize a cada resposta (gasta token sem ganho). No chat, termine cada
resposta com **3 linhas**: `Feito` / `Falta` / `Próximo passo`.

## Formato do bloco "Estado atual" no CHECKPOINT.md

Mantenha no topo, sempre com estes campos:

```markdown
## Estado atual da sessão (data)

**HEAD:** <hash> (<mensagem>). Árvore: limpa | suja.
Build: 0 erros · suíte 65/65 (última verificação).

### Em andamento (não commitado)
- <arquivo exato> — o que já está pronto e o que falta (seja específico).

### Próximo passo (executável)
1. <ação concreta: criar/editar arquivo X, função Y>
2. <como validar: build_desktop.bat + run_tests.bat>
```

Regras do bloco:
- **cite arquivos pelo caminho** (`Desktop\src\...`), não por descrição vaga;
- **diga o estado do git** (HEAD + o que está sujo/untracked);
- o "Próximo passo" tem que ser executável por quem nunca viu a conversa;
- se algo estiver **quebrado de propósito/no meio**, escreva isso explicitamente.

## Ordem de trabalho ao retomar

1. `cd C:\Users\Charles\Documents\ProjetoERP_1`
2. `git log --oneline -3` e `git status --short` — **o disco é a verdade**.
3. Ler `CHECKPOINT.md` e abrir os arquivos citados em "Em andamento".
4. Rodar a base: `Scripts\build_desktop.bat` e `Scripts\run_tests.bat`.
5. Executar o "Próximo passo".
6. Só considerar pronto com **build 0/0** e **suíte 65/65**.
7. Atualizar `CHECKPOINT.md` + `PLANO_E_LOG.md` e **commitar**.
8. **Dar `git push`** para o `origin` (GitHub privado) — commit sem push
   não está salvo de verdade; faça push a cada marco commitado.

## Regras do projeto (não negociáveis)

- **Nunca commite sem push:** todo commit de marco deve ser seguido de
  `git push` para `origin` (`https://github.com/tecinfocaetano-commits/ProjetoERP_1.git`).
- **Português** em código, mensagens, commits e documentação.
- **Regra de negócio em Services** (`Desktop\src\Services`); a tela só monta e
  valida campos.
- **SQL sempre parametrizado** (`:PARAM` + `ParamByName`), nunca concatenado.
- Alterações de dados em **transação** (`IniciarTransacao` / `Confirmar` /
  `Cancelar`) com **auditoria** (`LogOperacao`).
- **65/65** na suíte é o piso; se cair, não commite.
- Relatórios: **somente LazReport**; teste de impressão só em **PDF**.
- **Avise antes de instalar pacotes.**
- Firebird 5: identificador máximo **31 caracteres**; no `CREATE TABLE` o
  `DEFAULT` vem **antes** do `NOT NULL`; não existe `ALTER ... RENAME`
  (use ADD + cópia + DROP).
- **Android:** preserve todos os `android:id` existentes.
- Nunca reescreva/`git checkout` em arquivo não commitado sem ler antes: pode
  ser trabalho do usuário ou de outra sessão.

## Comandos úteis

```powershell
# build
& "C:\Users\Charles\Documents\ProjetoERP_1\Scripts\build_desktop.bat"
# suíte (esperado: Total: 65 | Passou: 65 | Falhou: 0)
& "C:\Users\Charles\Documents\ProjetoERP_1\Scripts\run_tests.bat"
# isql (acentos exigem SET NAMES UTF8)
& "C:\Program Files\Firebird\Firebird_5_0\isql.exe" -user SYSDBA -password masterkey -charset UTF8 <banco.fdb> -i <arquivo.sql>
```

Ruído conhecido e inofensivo: `InitializeFppkg failed: Could not find a fpc
executable in the PATH`.

## Antes de mexer no que é grande

Peça aprovação (e registre a decisão no `PLANO_E_LOG.md`) antes de:
unificação CLIENTE+FORNECEDOR, mudanças de schema destrutivas, troca de
biblioteca/pacote, ou qualquer refactor que toque mais de ~5 telas.

## Backlog atual

Sempre consulte `Documentacao\PLANO_E_LOG.md` §2 (tabela de itens com status).
No momento **não há item aberto**: D3 (`PESSOA`), os filtros de
Estoque/Financeiro e o "incluir cliente" no Android estão concluídos
(§3.19/§3.20). O próximo passo é o que o usuário pedir.
