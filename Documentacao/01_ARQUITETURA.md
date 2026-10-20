# ERP 2026 - Documentação de Arquitetura

## Visão Geral

Sistema ERP completo com módulos de Cadastros, Estoque, Vendas, PDV, Fiscal, Financeiro, API REST e aplicação Android.

## Stack Tecnológica

| Camada       | Tecnologia           |
|-------------|---------------------|
| Desktop     | Lazarus / Free Pascal |
| Mobile      | Flutter (futuro)     |
| API         | Horse Framework      |
| Banco       | Firebird 5           |
| Fiscal      | ACBr                 |
| IA          | Copiloto ERP         |

## Padrão Arquitetural: MVC + Services + Repository

```
┌─────────────────────────────────────────────────┐
│                    VIEW (Forms)                   │
│         Formulários VCL / Interface              │
├─────────────────────────────────────────────────┤
│                 CONTROLLER                        │
│      Orquestra View ↔ Service                    │
├─────────────────────────────────────────────────┤
│                  SERVICE                          │
│      Regras de negócio / Validações              │
├─────────────────────────────────────────────────┤
│                REPOSITORY                         │
│      Acesso a dados / CRUD genérico              │
├─────────────────────────────────────────────────┤
│              BANCO DE DADOS                       │
│            Firebird 5 (.fdb)                     │
└─────────────────────────────────────────────────┘
```

## Estrutura de Pastas

```
C:\Users\Charles\Documents\ProjetoERP_1\
├── Banco/                    # DDL, scripts, migrations
│   ├── schema_canonico.sql   # FONTE UNICA de DDL (gerada do banco real)
│   ├── 001_create_database.sql
│   ├── 002_domains.sql
│   ├── 003_generators.sql
│   ├── 004_tables.sql        # [SUPERADO] historico do build incremental
│   ├── 005_triggers.sql
│   ├── 006_indexes.sql
│   ├── 007_initial_data.sql  # sementes (admin/admin123, permissoes)
│   └── dados.fdb
├── Desktop/                  # Aplicação principal Lazarus
│   ├── src/
│   │   ├── Config/          # Conexão, configurações
│   │   ├── Models/          # Entidades (TCliente, TProduto...)
│   │   ├── Views/           # Formulários (.pas + .lfm)
│   │   ├── Controllers/     # Orquestradores
│   │   ├── Services/        # Regras de negócio
│   │   ├── Repositories/    # Acesso a dados
│   │   ├── DTOs/            # Objetos de transferência
│   │   └── Utils/           # Validações, formatações, sessão
│   ├── forms/               # Formulários visuais
│   └── packages/            # Pacotes externos
├── API/                      # Horse REST API
│   ├── src/
│   │   ├── Routes/
│   │   ├── Controllers/
│   │   ├── Services/
│   │   └── Middlewares/
│   └── config/
├── Android/                  # App Flutter/FMX
├── Documentacao/             # Esta pasta
├── Scripts/                  # Scripts auxiliares
├── Backup/                   # Backups do banco
├── Testes/                   # Testes unitários
├── IA/                       # Módulo Copiloto ERP
├── Deploy/                   # Builds e deploy
├── Integracoes/              # ACBr, NFe, etc
└── Ferramentas/              # Utilitários
```

## Decisões Técnicas

### 1. Banco de Dados
- **Firebird 5**: Gratuito, robusto, suporte a BLOB, triggers, stored procedures
- **Multiempresa**: Todas as tabelas possuem `EMPRESA_ID` como filtro
- **Auditoria**: Tabela `LOG_SISTEMA` com trigger de registro
- **Domínios**: Tipos customizados para consistência (DM_VALOR, DM_NOME, etc.)

### 2. Padrão Repository
- `TRepositoryBase`: CRUD genérico reutilizável
- Cada entidade pode ter seu Repository específico quando necessário
- Eliminação de SQL duplicado nos Services

### 3. Padrão Service
- `TServiceBase`: Validações comuns + logging
- Cada módulo tem seu Service com regras de negócio
- Services nunca acessam o banco diretamente (sempre via Repository)

### 4. Sessão
- `TSessao`: Singleton com dados do usuário logado
- Empresa, Grupo, Permissões carregados no login

### 5. Segurança
- Senhas com hash (SHA-256 mínimo)
- JWT para API
- Controle de permissões por Grupo/Módulo/Tela
- Log de todas as operações

## Nomenclatura

| Tipo        | Prefixo/Formato      | Exemplo               |
|------------|---------------------|----------------------|
| Unit       | u + NomeModulo       | uCliente.pas          |
| Classe     | T + Nome             | TCliente              |
| Service    | T + Nome + Service   | TClienteService       |
| Repository | T + Nome + Repository | TClienteRepository   |
| DTO        | T + Nome + DTO       | TClienteDTO           |
| Form       | frm + Nome           | frmClientes           |
| DataModule | dm + Nome            | dmConexao             |

## Fases do Projeto

| Fase | Módulo         | Status      |
|------|---------------|-------------|
| 1    | Fundação      | ✅ Completa  |
| 2    | Cadastros     | Próxima     |
| 3    | Estoque       | Pendente    |
| 4    | Vendas        | Pendente    |
| 5    | PDV           | Pendente    |
| 6    | Fiscal        | Pendente    |
| 7    | API           | Pendente    |
| 8    | Android       | Pendente    |
| 9    | IA (Copiloto) | Pendente    |
