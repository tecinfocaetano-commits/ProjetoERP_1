# Módulo Produção — FASE 1: Modelo de dados (aplicado)

Script: **`Banco\012_producao.sql`** — Rollback: **`Banco\012_producao_rollback.sql`**
Backup do banco antes da migração: `Banco\DADOS_backup_antes_012.fdb` (não versionado).

Aplicado em 17/10/2026 com:
```
isql -u SYSDBA -p masterkey Banco\DADOS.FDB -i Banco\012_producao.sql
```

## O que foi criado

| Objeto | Detalhes |
|---|---|
| **8 tabelas** | FICHA_TECNICA, FICHA_TECNICA_ITEM, MAPA_PRODUCAO, MAPA_PRODUCAO_ITEM, TALAO, TALAO_BIPAGEM, CONSUMO_MATERIAL, CONSUMO_MATERIAL_ITEM |
| **8 generators** | um por tabela (`GEN_FICHA_TECNICA_ID`, `GEN_MAPA_PRODUCAO_ID`, `GEN_TALAO_ID`, `GEN_CONSUMO_MATERIAL_ID` e itens) |
| **9 triggers** | auto-incremento (`*_BI`) + `TRG_FICHA_TECNICA_BU` (DATA_ATUALIZACAO) |
| **18 índices** | todas as colunas de ligação, status e datas; 3 únicos (ficha por produto, número do mapa, número do talão) |
| **9 CHECKs** | validação de status, quantidade > 0, perda >= 0, ativo A/I |
| **3 configurações** | PRODUCAO_TALAO_MODO, PRODUCAO_TALAO_LOTE, PRODUCAO_PERMITE_ESTOQUE_NEGATIVO |
| **4 permissões** | MODULO='PRODUCAO', TELAS: MAPA_PRODUCAO, FICHA_TECNICA, BIPAGEM, CONSUMO (grupo 1 – Administradores) |

## Status

**Mapa de produção** (`MAPA_PRODUCAO.STATUS`): `ABERTO` → `EM_PRODUCAO` → `CONCLUIDO`
(ou `CANCELADO` com motivo).
**Item do mapa**: `PENDENTE` → `EM_PRODUCAO` → `CONCLUIDO` (ou `CANCELADO`).
**Talão**: `GERADO` → `IMPRESSO` → `EM_PRODUCAO` → `CONCLUIDO` (ou `CANCELADO`).
**Consumo**: `PENDENTE` → `CONFIRMADO` → `ESTORNADO`.
**Pedido de venda** (`CHAR(1)`, já existente): `P` Pendente, `A` Aprovado, **`E` Em produção**,
**`D` Produzido**, `F` Faturado, `C` Cancelado — os dois novos códigos foram testados no
banco (o `CHAR(1)` não possui CHECK que os bloqueie) e nenhum fluxo existente deixa de
funcionar.

## Decisões de modelagem

1. **Sem chaves estrangeiras** — o banco inteiro (30 tabelas) não usa FKs; a integridade é
   garantida no Service. Índices em todas as colunas de ligação.
2. **`EMPRESA_ID NOT NULL`** nas tabelas de documento (MAPA, TALAO, CONSUMO), diferente das
   tabelas antigas: garante que o `UNIQUE (EMPRESA_ID, NUMERO)` realmente proteja a
   numeração.
3. **`MOVIMENTO_ESTOQUE_ID` no item do consumo** (e não no cabeçalho): cada material gera o
   seu próprio movimento de saída.
4. `FICHA_TECNICA.QUANTIDADE_BASE` = rendimento da receita; o consumo do insumo é *por
   unidade base* — permite “3 kg de farinha para cada 10 pães”.
5. `TALAO.QUANTIDADE` guarda quantas peças o talão representa (1 no modo por unidade,
   N no modo por lote) — o consumo e o progresso do mapa não dependem do modo escolhido.

## Validação executada

```
INSERT em MAPA_PRODUCAO  → ID 1 gerado pelo trigger, STATUS 'ABERTO', DATA_CRIACAO preenchida
INSERT em MAPA_PRODUCAO_ITEM → ID 1, STATUS 'PENDENTE'
INSERT em TALAO → ID 1, STATUS 'GERADO', DATA_GERACAO preenchida
INSERT com STATUS 'XXX' → bloqueado: "Operation violates CHECK constraint CKB_MAPA_STATUS"
ROLLBACK → nenhuma linha remanescente
```
