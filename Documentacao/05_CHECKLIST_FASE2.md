# ERP 2026 - Checklist FASE 2: Cadastros

## Formulários Entregues

- [x] **uFrmLogin** (pas + lfm) — Autenticação com 3 tentativas, validação de campos, atualiza último acesso
- [x] **uFrmPrincipal** (pas + lfm) — Menu completo (Cadastros, Estoque, Vendas, Financeiro, Relatórios, Sistema), StatusBar, confirmação de saída
- [x] **uFrmCadastroBase** (pas + lfm) — Template reutilizável com botões (Novo, Editar, Excluir, Salvar, Cancelar, Fechar), pesquisa, PageControl (Listagem + Cadastro), DBGrid
- [x] **uFrmClientes** (pas + lfm) — CRUD completo com validação CPF/CNPJ, email, campos obrigatórios, pesquisa
- [x] **uFrmFornecedores** (pas + lfm) — CRUD completo com campo Contato, validação, pesquisa
- [x] **uFrmProdutos** (pas + lfm) — CRUD com cálculo automático preço venda (custo × margem), categorias, unidades, fiscal
- [x] **uFrmCategorias** (pas + lfm) — CRUD simples (Nome, Descrição, Status)
- [x] **uFrmUsuarios** (pas + lfm) — CRUD com validação de senha, confirmação, proteção contra auto-exclusão

## Padrões Aplicados

- **Herança de formulários**: Todos herdam de `TfrmCadastroBase`
- **Template Method**: Métodos abstratos (HabilitarCampos, LimparCampos, Validar, Salvar, Excluir)
- **Estado de formulário**: `TEstadoForm` (efNavegando, efInserindo, efEditando)
- **Singleton de conexão**: Reutilização de `TConexao.GetInstance`
- **Singleton de sessão**: `TSessao.GetInstance` para dados do usuário logado

## Fluxo de Login

```
1. Abre frmLogin (ShowModal)
2. Usuário digita Login + Senha
3. Consulta USUARIO com status 'A'
4. Se válido: carrega TSessao, abre frmPrincipal
5. Se inválido: incrementa tentativas (máx 3)
6. Se 3 falhas: encerra aplicação
```

## Como Testar

1. Abra `ERP2026.lpi` no Lazarus
2. Compile (Ctrl+F9)
3. Execute (F9)
4. Na tela de login: **admin** / **admin123**
5. Navegue pelos menus e teste os CRUDs

## Próximos Passos (FASE 3 - Estoque)

- [ ] Formulário de Movimentação de Estoque (Entrada/Saída/Ajuste)
- [ ] Formulário de Inventário
- [ ] Relatório de posição de estoque
- [ ] Kardex do produto
