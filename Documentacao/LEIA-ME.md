# ERP 2026 - Sistema de Gestão Empresarial

## Visão Geral
Sistema ERP completo desenvolvido em Lazarus (Free Pascal) com Firebird 5, incluindo 9 módulos integrados.

## Tecnologias
- **Desktop**: Lazarus / Free Pascal
- **Banco de Dados**: Firebird 5
- **API REST**: Horse Framework (Free Pascal)
- **Mobile**: Flutter (Dart)
- **Fiscal**: ACBr (integração preparada)
- **Arquitetura**: MVC + Services + Repository

## Estrutura do Projeto
```
ProjetoERP/
├── Banco/              ← Scripts SQL (DDL, triggers, dados iniciais)
├── Desktop/            ← Aplicação principal Lazarus
│   ├── ERP2026.lpi     ← Abrir este arquivo no Lazarus
│   ├── ERP2026.lpr     ← Programa principal
│   └── src/
│       ├── Config/     ← Conexão com banco
│       ├── Models/     ← Entidades (TCliente, TProduto, etc.)
│       ├── Repositories/ ← CRUD genérico
│       ├── Services/   ← Regras de negócio + ACBr Helper
│       ├── Utils/      ← Validações, Sessão
│       └── Views/      ← Formulários (.pas + .lfm)
├── API/                ← API REST Horse Framework
│   ├── ERP2026API.lpr  ← Servidor API
│   └── src/
│       ├── Middleware/  ← JWT, CORS
│       └── Rotas/      ← Endpoints REST
├── Android/            ← App Flutter
│   ├── pubspec.yaml
│   └── lib/            ← Código Dart
├── IA/                 ← Motor do Copiloto ERP
├── Documentacao/       ← Este arquivo
└── Scripts/            ← Scripts auxiliares
```

## Módulos (Fases)

### FASE 1 - Fundação
- Banco de dados completo (18+ tabelas)
- Domains, generators, triggers, índices
- Estrutura de pastas e projeto base

### FASE 2 - Cadastros
- Login (admin/admin123)
- Clientes, Fornecedores, Produtos, Categorias, Usuários
- Template de formulário base (TfrmCadastroBase)

### FASE 3 - Estoque
- Movimentação de estoque (Entrada/Saída/Ajuste/Inventário)
- Kardex do produto
- Inventário com filtros

### FASE 4 - Vendas
- Pedidos de Venda com itens
- Orçamentos (convertíveis em pedido)
- Lista de pedidos com filtros

### FASE 5 - PDV
- Frente de caixa com leitura de código de barras
- Abertura/fechamento de caixa
- Sangria e suprimento
- Atalhos de teclado (F2-F6)
- Contas a Receber / Contas a Pagar

### FASE 6 - Fiscal
- Integração ACBr (wrapper preparado)
- Emissão NF-e / NFC-e (simulada sem ACBr)
- Importação de XML
- Cancelamento de NF-e

### FASE 7 - API REST
- Horse Framework (porta 9000)
- JWT Authentication
- CORS Middleware
- Endpoints: /login, /clientes, /produtos, /estoque, /vendas, /financeiro

### FASE 8 - Android (Flutter)
- Login com JWT
- Dashboard com KPIs
- Consulta de clientes, estoque, vendas
- Financeiro com tabs (Resumo, A Receber, A Pagar)

### FASE 9 - IA Copiloto ERP
- Chat com linguagem natural
- Classificação de perguntas por NLP básico
- Geração automática de SQL
- Sugestão de compras
- Alertas financeiros
- Insights de vendas

## Instalação

### Banco de Dados
1. Instale Firebird 5
2. Execute os scripts SQL em ordem (001 a 008)
3. Ou use `executar_banco.bat`

### Desktop
1. Instale Lazarus 3.x
2. Abra `Desktop/ERP2026.lpi`
3. Configure a conexão em `uConexao.pas`
4. Compile (Ctrl+F9) e execute (F9)
5. Login: **admin** / **admin123**

### API
1. Instale Horse Framework no Lazarus
2. Abra `API/ERP2026API.lpr`
3. Compile e execute (escuta na porta 9000)

### Mobile
1. Instale Flutter SDK
2. Configure `baseUrl` em `lib/services/api_service.dart`
3. Execute `flutter run`

## Padrões Aplicados
- MVC + Services + Repository
- Singleton (TConexao, TSessao)
- Template Method (TfrmCadastroBase)
- State Machine (efNavegando, efInserindo, efEditando)
- Clean Code + SOLID
- JWT para autenticação API

## Login Padrão
- **Usuário**: admin
- **Senha**: admin123
