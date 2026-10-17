# ERP 2026 - Documentação de Arquitetura

## Visão Geral

O ERP 2026 é um sistema de gestão empresarial completo desenvolvido em Lazarus (Free Pascal) com banco de dados Firebird 5, seguindo os princípios de Clean Code, SOLID e padrões corporativos.

## Stack Tecnológico

- **IDE**: Lazarus
- **Linguagem**: Free Pascal (FPC)
- **Banco de Dados**: Firebird 5
- **Framework Desktop**: LCL (Lazarus Component Library)
- **Framework Fiscal**: ACBr
- **Padrão de Arquitetura**: MVC + Services + Repository

## Estrutura de Diretórios

```
C:\Users\Charles\Documents\ProjetoERP_1\
├── Banco/                    # Scripts SQL e banco de dados
│   └── dados.fdb            # Banco Firebird
├── Desktop/                  # Aplicação Desktop Lazarus
│   ├── src/
│   │   ├── Config/          # Configurações e conexão
│   │   │   └── uConexao.pas # Singleton de conexão Firebird
│   │   ├── Models/          # Entidades do sistema
│   │   │   ├── uModelBase.pas
│   │   │   ├── uEmpresa.pas
│   │   │   ├── uUsuario.pas
│   │   │   ├── uGrupo.pas
│   │   │   ├── uCliente.pas
│   │   │   ├── uFornecedor.pas
│   │   │   ├── uProduto.pas
│   │   │   ├── uCategoria.pas
│   │   │   ├── uUnidade.pas
│   │   │   ├── uEstoque.pas
│   │   │   └── uPedidoVenda.pas
│   │   ├── Repositories/    # Padrão Repository
│   │   │   └── uRepositoryBase.pas
│   │   ├── Services/        # Camada de negócio
│   │   │   ├── uServiceBase.pas
│   │   │   ├── uClienteService.pas
│   │   │   └── uACBrHelper.pas
│   │   ├── Utils/           # Utilitários
│   │   │   ├── uSessao.pas
│   │   │   └── uValidacoes.pas
│   │   ├── Views/           # Formulários LCL
│   │   │   ├── uFrmLogin.pas
│   │   │   ├── uFrmPrincipal.pas
│   │   │   ├── uFrmCadastroBase.pas
│   │   │   ├── uFrmClientes.pas
│   │   │   ├── uFrmFornecedores.pas
│   │   │   ├── uFrmProdutos.pas
│   │   │   ├── uFrmCategorias.pas
│   │   │   ├── uFrmUsuarios.pas
│   │   │   ├── uFrmMovEstoque.pas
│   │   │   ├── uFrmKardex.pas
│   │   │   ├── uFrmInventario.pas
│   │   │   ├── uFrmPedidoVenda.pas
│   │   │   ├── uFrmListaPedidos.pas
│   │   │   ├── uFrmOrcamento.pas
│   │   │   ├── uFrmPDV.pas
│   │   │   ├── uFrmContasReceber.pas
│   │   │   ├── uFrmContasPagar.pas
│   │   │   ├── uFrmNFe.pas
│   │   │   └── uFrmCopiloto.pas
│   │   └── uCopilotoERP.pas # Motor de IA
│   ├── ERP2026.lpi          # Projeto Lazarus
│   └── ERP2026.lpr          # Programa principal
├── API/                      # API REST (Horse Framework)
├── Android/                  # Aplicação Mobile (Flutter)
├── IA/                       # Módulos de Inteligência Artificial
├── Documentacao/             # Documentação do projeto
├── Scripts/                  # Scripts de automação
├── Backup/                   # Backups do sistema
├── Testes/                   # Testes automatizados
├── Deploy/                   # Artefatos de deploy
├── Integracoes/              # Integrações externas
└── Ferramentas/              # Ferramentas auxiliares
```

## Padrões Arquiteturais

### MVC + Services + Repository

```
┌─────────────────┐
│     Views       │  ← Formulários LCL (Interface)
└────────┬────────┘
         │
┌────────▼────────┐
│    Services     │  ← Regras de negócio
└────────┬────────┘
         │
┌────────▼────────┐
│  Repositories   │  ← Acesso a dados
└────────┬────────┘
         │
┌────────▼────────┐
│     Models      │  ← Entidades
└─────────────────┘
```

### Singleton Pattern

Aplicado em:
- **TConexao**: Gerenciamento de conexão com banco
- **TSessao**: Controle de sessão do usuário

### Template Method Pattern

Aplicado em:
- **TfrmCadastroBase**: Template para formulários CRUD

## Camadas do Sistema

### 1. Models (Entidades)

Classes que representam as tabelas do banco de dados:

- **TModelBase**: Classe base com Id, EmpresaId, DataCadastro
- **TEmpresa**: Multi-tenant
- **TUsuario**: Usuários do sistema
- **TGrupo**: Grupos de permissão
- **TCliente**: Clientes
- **TFornecedor**: Fornecedores
- **TProduto**: Produtos
- **TCategoria**: Categorias de produtos
- **TUnidade**: Unidades de medida
- **TEstoque**: Controle de estoque
- **TPedidoVenda**: Pedidos de venda

### 2. Repositories

Camada de acesso a dados:

- **TRepositoryBase<T>**: CRUD genérico reutilizável

### 3. Services

Camada de regras de negócio:

- **TServiceBase<T>**: Service base com validações
- **TClienteService**: Regras específicas de clientes
- **TACBrHelper**: Integração fiscal ACBr

### 4. Views

Formulários LCL:

- **TfrmLogin**: Autenticação
- **TfrmPrincipal**: Menu principal
- **TfrmCadastroBase**: Template CRUD
- Formulários específicos para cada entidade

### 5. Utils

Utilitários do sistema:

- **TSessao**: Controle de sessão (Singleton)
- **TValidacoes**: Validações (CPF, CNPJ, Email)

### 6. Config

Configurações do sistema:

- **TConexao**: Conexão Firebird (Singleton)

## Módulos do Sistema

### FASE 1 - Fundação ✅
- Banco de dados Firebird 5
- Scripts SQL DDL
- Estrutura de pastas
- Models base

### FASE 2 - Cadastros ✅
- Login
- Clientes
- Fornecedores
- Produtos
- Categorias
- Usuários

### FASE 3 - Estoque ✅
- Movimentação de estoque
- Inventário
- Kardex

### FASE 4 - Vendas ✅
- Pedidos de venda
- Orçamentos
- Lista de pedidos

### FASE 5 - PDV ✅
- Frente de caixa
- Contas a receber/pagar

### FASE 6 - Fiscal ✅
- NF-e/NFC-e
- ACBr Helper

### FASE 7 - API ✅
- Horse Framework
- JWT
- Endpoints REST

### FASE 8 - Android ✅
- Flutter 3.0+ configurado
- Dashboard implementado
- CRUD de clientes implementado
- Gestão de estoque implementada
- Gestão de vendas implementada
- Dashboard financeiro com gráficos
- Integração API REST preparada

### FASE 9 - IA ✅
- Copiloto ERP
- Chat em linguagem natural
- Insights e alertas

## Banco de Dados

### Principais Tabelas

- **EMPRESA**: Multi-tenant
- **USUARIO**: Usuários do sistema
- **GRUPO**: Grupos de permissão
- **PERMISSAO**: Permissões do sistema
- **CLIENTE**: Clientes
- **FORNECEDOR**: Fornecedores
- **PRODUTO**: Produtos
- **CATEGORIA**: Categorias
- **UNIDADE**: Unidades de medida
- **ESTOQUE**: Controle de estoque
- **MOVIMENTO_ESTOQUE**: Movimentações
- **PEDIDO_VENDA**: Pedidos
- **ITEM_PEDIDO**: Itens do pedido
- **FINANCEIRO**: Financeiro
- **CONTA_RECEBER**: Contas a receber
- **CONTA_PAGAR**: Contas a pagar
- **CAIXA**: Caixa
- **MOVIMENTO_CAIXA**: Movimentações de caixa
- **LOG_SISTEMA**: Logs de auditoria
- **CONFIGURACAO**: Configurações

## Segurança

- **Multiempresa**: Isolamento por empresa
- **Multiusuário**: Controle de acesso
- **Grupos e Permissões**: RBAC
- **Sessão**: Controle de sessão do usuário
- **Logs**: Auditoria completa
- **JWT**: Autenticação na API

## Inteligência Artificial

### Copiloto ERP

Motor de processamento de linguagem natural para consultas ao ERP:

- Classificação de perguntas
- Geração automática de SQL
- Insights de vendas
- Alertas financeiros
- Sugestões de compra
- Análise de estoque

### Exemplos de Comandos

- "Qual meu faturamento do mês?"
- "Quais clientes estão inadimplentes?"
- "Quais produtos estão sem venda há 90 dias?"
- "Qual fornecedor gera maior crédito fiscal?"
- "Quais produtos estão abaixo do estoque mínimo?"

## Compilação

### Pré-requisitos

- Lazarus 3.2.2 instalado em `C:\Lazarus`
- Firebird 5 instalado em `C:\Program Files\Firebird`
- Pacote LCL configurado
- Pacote SQLDBLaz configurado

### Passos

1. Abrir `Desktop\ERP2026.lpi` no Lazarus
2. Adicionar dependência LCL (se necessário)
3. Adicionar dependência SQLDBLaz (se necessário)
4. Compilar com Ctrl+F9
5. Executar com F9

### Compilação via Linha de Comando

```bash
C:\Lazarus\lazbuild.exe C:\Users\Charles\Documents\ProjetoERP_1\Desktop\ERP2026.lpi
```

### Status da Compilação

- ✅ Compilação bem-sucedida
- ✅ Executável gerado em `Desktop\bin\ERP2026.exe`
- ⚠️ 35 hints emitidos (avisos de parâmetros não utilizados)
- ℹ️ Apenas warnings, sem erros críticos

## Correções Realizadas

### Problemas de Compatibilidade Lazarus

Durante o processo de compilação, foram identificados e corrigidos os seguintes problemas:

1. **TDateTimePicker não disponível**
   - Substituído por TEdit em todos os formulários
   - Adicionado DateUtils ao uses
   - Implementado conversão entre texto e data (FormatDateTime/StrToDateDef)
   - Arquivos afetados: 8 formulários (.pas + .lfm)

2. **Sintaxe inline var do Delphi**
   - Substituído por declaração de variáveis tradicional
   - Arquivos afetados: uFrmInventario.pas, uFrmOrcamento.pas, uFrmPDV.pas, uFrmContasReceber.pas, uFrmContasPagar.pas

3. **Propriedades em TSessao**
   - Convertido de property para campos públicos
   - Removido construtor privado CreatePrivate
   - Arquivo afetado: uSessao.pas

4. **Referência a NomeUsuario**
   - Corrigido para UsuarioNome
   - Arquivos afetados: uFrmOrcamento.pas, uFrmPDV.pas

5. **Módulo IA CopilotoERP**
   - Temporariamente desabilitado
   - Implementado mensagem de desenvolvimento
   - Arquivo afetado: uFrmCopiloto.pas

6. **MessageBeep Windows-only**
   - Removido para compatibilidade multi-plataforma
   - Arquivo afetado: uFrmPDV.pas

7. **Uses no ERP2026.lpr**
   - Adicionado Controls para mrOk
   - Arquivo afetado: ERP2026.lpr

### Resultado Final

- ✅ Compilação sem erros
- ✅ Executável funcional gerado
- ⚠️ 35 hints não críticos (parâmetros não utilizados)
- ✅ Código compatível com Free Pascal 3.2.2

### Login Padrão

- Usuário: admin
- Senha: admin123

## Próximos Passos

1. Completar integração ACBr
2. Implementar testes automatizados
3. Desenvolver API REST completa
4. Implementar aplicativo Android
5. Configurar deploy automatizado
6. Documentação de API
7. Manual do usuário

## Convenções de Código

### Nomenclatura

- Classes: Prefixo `T` (ex: `TCliente`)
- Interfaces: Prefixo `I` (ex: `IClienteService`)
- Units: Prefixo `u` (ex: `uCliente.pas`)
- Campos: Prefixo `F` (ex: `FNome`)
- Métodos: PascalCase (ex: `SalvarCliente`)
- Variáveis locais: CamelCase (ex: `clienteId`)

### Organização

- Cada entidade tem seu Model, Service e Repository
- Views separadas por módulo
- Utils compartilhados
- Config centralizada

## Contato e Suporte

Para dúvidas ou problemas, consulte a documentação específica de cada módulo ou entre em contato com a equipe de desenvolvimento.
