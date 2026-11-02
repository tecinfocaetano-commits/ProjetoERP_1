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
│   │   │   ├── ClientesActivity.java    # Gestão de clientes
│   │   │   ├── EstoqueActivity.java     # Gestão de estoque
│   │   │   ├── VendasActivity.java      # Gestão de vendas
│   │   │   └── FinanceiroActivity.java  # Gestão financeira
│   │   └── res/layout/
│   │       ├── activity_main.xml       # Layout login
│   │       ├── activity_dashboard.xml  # Layout dashboard
│   │       ├── activity_clientes.xml   # Layout clientes
│   │       ├── activity_estoque.xml    # Layout estoque
│   │       ├── activity_vendas.xml     # Layout vendas
│   │       └── activity_financeiro.xml # Layout financeiro
│   └── build.gradle
└── settings.gradle
```

## Funcionalidades

- ✅ Login com autenticação (admin/admin123)
- ✅ Dashboard com botões de navegação
- ✅ Lista de clientes
- ✅ Lista de produtos em estoque
- ✅ Lista de vendas
- ✅ Dashboard financeiro com totais

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
