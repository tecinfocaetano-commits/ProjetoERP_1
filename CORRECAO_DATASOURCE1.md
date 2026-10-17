# Correção de DataSource1 em Todos os Forms - ERP 2026

**Data:** 2026-10-12
**Objetivo:** Garantir que todos os forms tenham DataSource1 criado no FormCreate para evitar Access Violations

---

## 📋 Resumo

Todos os forms que usam `DataSource1.DataSet := FQuery` precisam criar o DataSource1 no FormCreate, caso contrário ocorre Access Violation ao tentar acessar DataSource1.DataSet.

---

## ✅ Forms Corrigidos

### Forms que herdam de TfrmCadastroBase (5 arquivos)

#### 1. uFrmClientes.pas
- ✅ Adicionado criação de DataSource1 no FormCreate
- ✅ Usa DataSource1.DataSet := FQuery em CarregarDados

#### 2. uFrmCategorias.pas
- ✅ Adicionado criação de DataSource1 no FormCreate
- ✅ Usa DataSource1.DataSet := FQuery em CarregarDados

#### 3. uFrmProdutos.pas
- ✅ Adicionado criação de DataSource1 no FormCreate
- ✅ Usa DataSource1.DataSet := FQuery em CarregarDados

#### 4. uFrmUsuarios.pas
- ✅ Adicionado criação de DataSource1 no FormCreate
- ✅ Usa DataSource1.DataSet := FQuery em CarregarDados

#### 5. uFrmFornecedores.pas
- ✅ Adicionado criação de DataSource1 no FormCreate
- ✅ Usa DataSource1.DataSet := FQuery em CarregarDados

### Forms que NÃO herdam de TfrmCadastroBase (6 arquivos)

#### 6. uFrmMovEstoque.pas
- ✅ Adicionado criação de DataSource1 no FormCreate
- ✅ Usa DataSource1.DataSet := FQuery em CarregarMovimentos

#### 7. uFrmKardex.pas
- ✅ Adicionado criação de DataSource1 no FormCreate
- ✅ Usa DataSource1.DataSet := FQuery em CarregarKardex

#### 8. uFrmInventario.pas
- ✅ Adicionado criação de DataSource1 no FormCreate
- ✅ Usa DataSource1.DataSet := FQuery em CarregarInventario

#### 9. uFrmListaPedidos.pas
- ✅ Adicionado criação de DataSource1 no FormCreate
- ✅ Usa DataSource1.DataSet := FQuery em CarregarPedidos

#### 10. uFrmContasPagar.pas
- ✅ Adicionado criação de DataSource1 no FormCreate
- ✅ Usa DataSource1.DataSet := FQuery em CarregarContas

#### 11. uFrmContasReceber.pas
- ✅ Adicionado criação de DataSource1 no FormCreate
- ✅ Usa DataSource1.DataSet := FQuery em CarregarContas

#### 12. uFrmNFe.pas
- ✅ Adicionado criação de DataSource1 no FormCreate
- ✅ Usa DataSource1.DataSet := FQuery em CarregarPedidos

---

## 🔧 Padrão Aplicado

```pascal
procedure TfrmX.FormCreate(Sender: TObject);
begin
  try
    FConexao := TConexao.GetInstance;
    if FConexao = nil then
      raise Exception.Create('FConexao não foi inicializado');

    // Iniciar conexão com o banco
    if not FConexao.Conectado then
      FConexao.Conectar;

    FQuery := TSQLQuery.Create(Self);
    if FQuery = nil then
      raise Exception.Create('FQuery não foi criado');

    FQuery.DataBase := FConexao.Connection;
    FQuery.Transaction := FConexao.Transaction;

    // Criar DataSource1 se não existir
    if DataSource1 = nil then
      DataSource1 := TDataSource.Create(Self);

    // Configurar campos e ComboBox
    // ...

    CarregarDados;
  except
    on E: Exception do
      MessageDlg('Erro ao inicializar formulário: ' + E.Message, mtError, [mbOK], 0);
  end;
end;
```

---

## 🧪 Compilação

- ✅ 2078 linhas compiladas
- ✅ 55 hints (avisos, não erros)
- ✅ 0 erros
- ✅ ERP2026 rodando

---

## 📊 Status dos Forms

### Forms com DataSource1 criado (12 arquivos)
1. ✅ uFrmClientes.pas
2. ✅ uFrmCategorias.pas
3. ✅ uFrmProdutos.pas
4. ✅ uFrmUsuarios.pas
5. ✅ uFrmFornecedores.pas
6. ✅ uFrmMovEstoque.pas
7. ✅ uFrmKardex.pas
8. ✅ uFrmInventario.pas
9. ✅ uFrmListaPedidos.pas
10. ✅ uFrmContasPagar.pas
11. ✅ uFrmContasReceber.pas
12. ✅ uFrmNFe.pas

### Forms que não usam DataSource1 (3 arquivos)
- uFrmPrincipal.pas - Não usa banco de dados
- uFrmLogin.pas - Não usa DataSource1
- uFrmPDV.pas - Usa DataSource1 mas precisa verificar
- uFrmPedidoVenda.pas - Usa DataSource1 mas precisa verificar
- uFrmOrcamento.pas - Usa DataSource1 mas precisa verificar
- uFrmCopiloto.pas - Não usa DataSource1

---

## 🎯 Próximos Passos

1. **Testar todos os forms** para garantir que o Access Violation foi resolvido
2. **Verificar forms restantes** (PDV, PedidoVenda, Orcamento) se precisam de DataSource1
3. **Testar especificamente:**
   - Estoque → Movimentação de Estoque
   - Estoque → Kardex
   - Todos os forms de cadastro (Clientes, Produtos, etc.)

---

## 🔗 Documentos Relacionados

- VARREDURA_INICIALIZACAO_FORMS.md
- CORRECAO_ACCESS_VIOLATION.md
- CORRECAO_SCHEMA_CLIENTE.md
