# ERP 2026 - Aplicativo Mobile Android

Aplicativo Android nativo para o sistema ERP 2026.

## Pré-requisitos

- Android Studio
- Android SDK API 21+

## Como Abrir no Android Studio

1. **Abra o projeto no Android Studio:**
   - No Android Studio, vá em File → Open
   - Navegue até: `C:\Users\Charles\Documents\ProjetoERP_1\Android\android`
   - Clique em "OK"

2. **Sincronize o Gradle:**
   - O Android Studio deve sincronizar automaticamente
   - Se não, clique em "Sync Now" quando solicitado

3. **Execute o aplicativo:**
   - Clique no botão "Run" (triângulo verde)
   - Ou pressione Shift + F10

## Estrutura do Projeto

```
android/
├── app/
│   ├── src/main/
│   │   ├── java/com/example/erp2026_mobile/
│   │   │   ├── MainActivity.java        # Tela de login
│   │   │   ├── DashboardActivity.java   # Dashboard principal
│   │   │   ├── BaseListaActivity.java   # Base das telas de lista
│   │   │   ├── Navegacao.java           # Menu inferior (5 itens)
│   │   │   ├── ClientesActivity.java    # Gestão de clientes
│   │   │   ├── EstoqueActivity.java     # Gestão de estoque
│   │   │   ├── VendasActivity.java      # Gestão de vendas
│   │   │   ├── OrcamentosActivity.java  # Orçamentos em aberto
│   │   │   ├── InserirOrcamentoActivity.java # Novo orçamento
│   │   │   └── FinanceiroActivity.java  # Gestão financeira
│   │   ├── res/layout/
│   │   │   ├── activity_main.xml       # Layout login
│   │   │   ├── activity_dashboard.xml  # Layout dashboard
│   │   │   ├── include_bottom_nav.xml  # Menu inferior reutilizável
│   │   │   ├── activity_clientes.xml   # Layout clientes
│   │   │   ├── activity_estoque.xml    # Layout estoque
│   │   │   ├── activity_vendas.xml     # Layout vendas
│   │   │   ├── activity_orcamentos.xml # Layout orçamentos
│   │   │   ├── activity_inserir_orcamento.xml # Layout novo orçamento
│   │   │   └── activity_financeiro.xml # Layout financeiro
│   │   └── res/menu/
│   │       └── menu_bottom_nav.xml     # Itens do menu inferior
│   └── build.gradle
└── settings.gradle
```

## Funcionalidades

- ✅ Login com autenticação (admin/admin123)
- ✅ Dashboard com resumo de vendas (sem botões de navegação)
- ✅ Menu inferior com Início, Clientes, Estoque, Vendas e Financeiro
- ✅ Configuração do servidor/empresa e saída no menu de três pontinhos
- ✅ Lista de clientes
- ✅ Lista de produtos em estoque
- ✅ Lista de vendas
- ✅ Orçamentos: lista os abertos (`STATUS = 'O'`), cria novo e converte em pedido
- ✅ Dashboard financeiro com totais

## Dashboard

A tela inicial (`DashboardActivity`) deixou de ser uma lista de botões e virou
um resumo do movimento da empresa. Os números vêm da API ao abrir a tela e ao
escolher **Atualizar resumo** no menu de três pontinhos.

| Bloco | Conteúdo | Toque abre |
| --- | --- | --- |
| Faturamento do mês | total faturado e quantidade de vendas do mês | — |
| A receber / A pagar | contas em aberto | — |
| Orçamentos abertos | quantidade de orçamentos em aberto | `OrcamentosActivity` |
| Clientes | total de clientes cadastrados | `ClientesActivity` |
| Últimas vendas | 3 pedidos mais recentes (cliente, valor, emissão, status) | `VendasActivity` |

O menu **⋮** da barra superior tem:

- **Atualizar resumo** — recarrega os números;
- **Configuração (servidor e empresa)** — abre a tela de configuração;
- **Sair** — encerra a sessão (com confirmação).

O menu inferior (Início/Clientes/Estoque/Vendas/Financeiro) continua sendo a
navegação principal. A seta de voltar aparece em todas as telas, e Clientes e
Vendas têm a barra de pesquisa ao lado dela.

## Orçamentos

Telas: `OrcamentosActivity` (lista) e `InserirOrcamentoActivity` (formulário).
Acessíveis pelo card **Orçamentos abertos** no Dashboard e pelo botão
**Orçamentos** na tela de Vendas.

- A lista mostra os orçamentos em aberto (`PEDIDO_VENDA.STATUS = 'O'`)
  com número, cliente, total, emissão e quantidade de itens.
- O formulário carrega clientes e produtos ativos da API; o valor unitário
  é preenchido ao escolher o produto e pode ser ajustado.
- Subtotais, desconto e total são recalculados **no servidor**; o app só
  envia quantidade, valor unitário e desconto.
- Tocar em um orçamento abre a confirmação para convertê-lo em pedido
  (`STATUS = 'P'`). A API recusa (HTTP 409) se ele já não estiver aberto.

Endpoints usados:

| Método | Rota | Uso |
| --- | --- | --- |
| GET | `/api/orcamentos` | Lista os orçamentos abertos |
| GET | `/api/orcamentos/:id` | Cabeçalho + itens |
| POST | `/api/orcamentos` | Cria o orçamento (201) |
| POST | `/api/orcamentos/:id/converter` | Converte em pedido |

## Login Padrão

- Usuário: `admin`
- Senha: `admin123`

## Tecnologias

- Java
- Android SDK
- Material Design
- AndroidX AppCompat

## Build para Produção

No Android Studio:
1. Build → Generate Signed Bundle/APK
2. Escolha APK ou Bundle
3. Assine com sua chave ou use debug

## Customização

- **Nome do app**: Altere em `AndroidManifest.xml` (android:label)
- **Ícone**: Substitua os arquivos em `mipmap-*` folders
- **Cores**: Modifique no arquivo `colors.xml` (se criar)
- **Dados**: Modifique as listas nas Activities Java

## Configuração por empresa (servidor e código de usuário)

Cada empresa guarda a sua URL da API e o seu código de usuário: veja
`CONFIGURACAO_POR_EMPRESA.md`.
