unit uFrmOrcamento;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 4 - Orçamento
  Descrição: Formulário de Orçamento (similar ao Pedido)
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, Grids, DateUtils,
  uConexao, uSessao;

type
  { TfrmOrcamento }
  TfrmOrcamento = class(TForm)
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    pnlCabecalho: TPanel;
    lblNumero: TLabel;
    edtNumero: TEdit;
    lblData: TLabel;
    edtData: TEdit;
    lblValidade: TLabel;
    edtValidade: TEdit;
    lblCliente: TLabel;
    cmbCliente: TComboBox;
    lblVendedor: TLabel;
    edtVendedor: TEdit;
    pnlAddItem: TPanel;
    lblProduto: TLabel;
    edtProduto: TEdit;
    btnBuscarProd: TBitBtn;
    lblProdutoDesc: TLabel;
    lblQtd: TLabel;
    edtQtd: TEdit;
    lblVlrUnit: TLabel;
    edtVlrUnit: TEdit;
    lblDescItem: TLabel;
    edtDescItem: TEdit;
    btnAddItem: TBitBtn;
    btnRemoverItem: TBitBtn;
    sgItens: TStringGrid;
    pnlTotais: TPanel;
    lblSubtotal: TLabel;
    edtSubtotal: TEdit;
    lblDesconto: TLabel;
    edtDesconto: TEdit;
    lblTotal: TLabel;
    edtTotal: TEdit;
    pnlBotoes: TPanel;
    btnSalvar: TBitBtn;
    btnGerarPedido: TBitBtn;
    btnCancelar: TBitBtn;
    btnFechar: TBitBtn;
    mmoObs: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure btnBuscarProdClick(Sender: TObject);
    procedure btnAddItemClick(Sender: TObject);
    procedure btnRemoverItemClick(Sender: TObject);
    procedure btnSalvarClick(Sender: TObject);
    procedure btnGerarPedidoClick(Sender: TObject);
    procedure btnCancelarClick(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
    procedure edtDescontoExit(Sender: TObject);
  private
    FConexao: TConexao;
    FProdutoId: Int64;
    FOrcamentoId: Int64;
    procedure CarregarClientes;
    procedure ConfigurarGrid;
    procedure RecalcularTotais;
    procedure LimparFormulario;
  end;

var
  frmOrcamento: TfrmOrcamento;

implementation

{$R *.lfm}

procedure TfrmOrcamento.FormCreate(Sender: TObject);
begin
  FConexao := TConexao.GetInstance;
  // Iniciar conexão com o banco
  if not FConexao.Conectado then
    FConexao.Conectar;
  FProdutoId := 0;
  FOrcamentoId := 0;
  CarregarClientes;
  ConfigurarGrid;
  edtData.Text := FormatDateTime('dd/mm/yyyy', Now);
  edtValidade.Text := FormatDateTime('dd/mm/yyyy', IncMonth(Now, 1));
  edtVendedor.Text := TSessao.GetInstance.UsuarioNome;
end;

procedure TfrmOrcamento.ConfigurarGrid;
begin
  sgItens.ColCount := 6;
  sgItens.RowCount := 1;
  sgItens.FixedRows := 1;
  sgItens.Cells[0, 0] := 'Prod.ID';
  sgItens.Cells[1, 0] := 'Descrição';
  sgItens.Cells[2, 0] := 'Qtd';
  sgItens.Cells[3, 0] := 'Vlr Unit.';
  sgItens.Cells[4, 0] := 'Desconto';
  sgItens.Cells[5, 0] := 'Total';
  sgItens.ColWidths[0] := 60;
  sgItens.ColWidths[1] := 280;
  sgItens.ColWidths[2] := 80;
  sgItens.ColWidths[3] := 100;
  sgItens.ColWidths[4] := 80;
  sgItens.ColWidths[5] := 100;
end;

procedure TfrmOrcamento.CarregarClientes;
var
  LQuery: TSQLQuery;
begin
  cmbCliente.Items.Clear;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := 'SELECT ID, NOME FROM PESSOA WHERE TIPO = ''C'' AND ATIVO = ''A'' ORDER BY NOME';
    LQuery.Open;
    while not LQuery.EOF do
    begin
      cmbCliente.Items.AddObject(LQuery.FieldByName('NOME').AsString,
        TObject(PtrInt(LQuery.FieldByName('ID').AsLargeInt)));
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TfrmOrcamento.btnBuscarProdClick(Sender: TObject);
var
  LQuery: TSQLQuery;
begin
  if Trim(edtProduto.Text) = '' then Exit;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT ID, DESCRICAO, PRECO_VENDA FROM PRODUTO ' +
      'WHERE (CODIGO = :COD OR CODIGO_BARRAS = :COD OR CAST(ID AS VARCHAR(20)) = :COD) AND ATIVO = ''A''';
    LQuery.ParamByName('COD').AsString := Trim(edtProduto.Text);
    LQuery.Open;
    if not LQuery.IsEmpty then
    begin
      FProdutoId := LQuery.FieldByName('ID').AsLargeInt;
      lblProdutoDesc.Caption := LQuery.FieldByName('DESCRICAO').AsString;
      edtVlrUnit.Text := FormatFloat('#,##0.0000', LQuery.FieldByName('PRECO_VENDA').AsFloat);
      edtQtd.Text := '1';
      edtDescItem.Text := '0,00';
    end
    else
    begin
      MessageDlg('Produto não encontrado.', mtWarning, [mbOK], 0);
      FProdutoId := 0;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TfrmOrcamento.btnAddItemClick(Sender: TObject);
var
  LRow: Integer;
  LQtd, LVlr, LDesc: Double;
begin
  if FProdutoId <= 0 then
  begin
    MessageDlg('Selecione um produto.', mtWarning, [mbOK], 0);
    Exit;
  end;
  LQtd := StrToFloatDef(edtQtd.Text, 0);
  LVlr := StrToFloatDef(edtVlrUnit.Text, 0);
  LDesc := StrToFloatDef(edtDescItem.Text, 0);
  if LQtd <= 0 then
  begin
    MessageDlg('Quantidade inválida.', mtWarning, [mbOK], 0);
    Exit;
  end;
  LRow := sgItens.RowCount;
  sgItens.RowCount := LRow + 1;
  sgItens.Cells[0, LRow] := IntToStr(FProdutoId);
  sgItens.Cells[1, LRow] := lblProdutoDesc.Caption;
  sgItens.Cells[2, LRow] := FormatFloat('#,##0.0000', LQtd);
  sgItens.Cells[3, LRow] := FormatFloat('#,##0.0000', LVlr);
  sgItens.Cells[4, LRow] := FormatFloat('#,##0.00', LDesc);
  sgItens.Cells[5, LRow] := FormatFloat('#,##0.00', (LQtd * LVlr) - LDesc);
  edtProduto.Clear;
  lblProdutoDesc.Caption := '';
  FProdutoId := 0;
  edtProduto.SetFocus;
  RecalcularTotais;
end;

procedure TfrmOrcamento.btnRemoverItemClick(Sender: TObject);
var
  I: Integer;
begin
  if (sgItens.Row < 1) or (sgItens.RowCount <= 1) then Exit;
  for I := sgItens.Row to sgItens.RowCount - 2 do
    sgItens.Rows[I].Assign(sgItens.Rows[I + 1]);
  sgItens.RowCount := sgItens.RowCount - 1;
  RecalcularTotais;
end;

procedure TfrmOrcamento.RecalcularTotais;
var
  I: Integer;
  LSub: Double;
begin
  LSub := 0;
  for I := 1 to sgItens.RowCount - 1 do
    LSub := LSub + StrToFloatDef(sgItens.Cells[5, I], 0);
  edtSubtotal.Text := FormatFloat('#,##0.00', LSub);
  edtTotal.Text := FormatFloat('#,##0.00', LSub - StrToFloatDef(edtDesconto.Text, 0));
end;

procedure TfrmOrcamento.edtDescontoExit(Sender: TObject);
begin
  RecalcularTotais;
end;

procedure TfrmOrcamento.btnSalvarClick(Sender: TObject);
var
  LQuery: TSQLQuery;
  I: Integer;
  LClienteId: Int64;
begin
  if cmbCliente.ItemIndex < 0 then
  begin
    MessageDlg('Selecione um cliente.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if sgItens.RowCount <= 1 then
  begin
    MessageDlg('Adicione pelo menos um item.', mtWarning, [mbOK], 0);
    Exit;
  end;

  LClienteId := PtrInt(cmbCliente.Items.Objects[cmbCliente.ItemIndex]);

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FConexao.IniciarTransacao;

    // Salva orçamento como pedido de venda com status 'O' (Orçamento)
    LQuery.SQL.Text :=
      'INSERT INTO PEDIDO_VENDA (EMPRESA_ID, CLIENTE_ID, USUARIO_ID, STATUS, ' +
      'SUBTOTAL, DESCONTO, TOTAL, OBSERVACOES) ' +
      'VALUES (:EMP, :CLI, :USR, ''O'', :SUB, :DESC, :TOT, :OBS)';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.ParamByName('CLI').AsLargeInt := LClienteId;
    LQuery.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
    LQuery.ParamByName('SUB').AsFloat := StrToFloatDef(edtSubtotal.Text, 0);
    LQuery.ParamByName('DESC').AsFloat := StrToFloatDef(edtDesconto.Text, 0);
    LQuery.ParamByName('TOT').AsFloat := StrToFloatDef(edtTotal.Text, 0);
    LQuery.ParamByName('OBS').AsString := mmoObs.Text;
    LQuery.ExecSQL;

    LQuery.SQL.Text := 'SELECT GEN_ID(GEN_PEDIDO_VENDA_ID, 0) FROM RDB$DATABASE';
    LQuery.Open;
    FOrcamentoId := LQuery.Fields[0].AsLargeInt;
    if LQuery.Active then
      LQuery.Close;

    for I := 1 to sgItens.RowCount - 1 do
    begin
      LQuery.SQL.Text :=
        'INSERT INTO ITEM_PEDIDO (PEDIDO_VENDA_ID, PRODUTO_ID, QUANTIDADE, ' +
        'VALOR_UNITARIO, DESCONTO, VALOR_TOTAL) ' +
        'VALUES (:PED, :PROD, :QTD, :VLR, :DESC, :TOT)';
      LQuery.ParamByName('PED').AsLargeInt := FOrcamentoId;
      LQuery.ParamByName('PROD').AsLargeInt := StrToInt64(sgItens.Cells[0, I]);
      LQuery.ParamByName('QTD').AsFloat := StrToFloatDef(sgItens.Cells[2, I], 0);
      LQuery.ParamByName('VLR').AsFloat := StrToFloatDef(sgItens.Cells[3, I], 0);
      LQuery.ParamByName('DESC').AsFloat := StrToFloatDef(sgItens.Cells[4, I], 0);
      LQuery.ParamByName('TOT').AsFloat := StrToFloatDef(sgItens.Cells[5, I], 0);
      LQuery.ExecSQL;
    end;

    FConexao.Confirmar;
    MessageDlg('Orçamento salvo com sucesso!', mtInformation, [mbOK], 0);
    LimparFormulario;
  except
    on E: Exception do
    begin
      FConexao.Cancelar;
      MessageDlg('Erro: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
  LQuery.Free;
end;

procedure TfrmOrcamento.btnGerarPedidoClick(Sender: TObject);
var
  LQuery: TSQLQuery;
begin
  if FOrcamentoId <= 0 then
  begin
    MessageDlg('Salve o orçamento antes de gerar o pedido.', mtWarning, [mbOK], 0);
    Exit;
  end;
  // Converter orçamento em pedido alterando status
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := 'UPDATE PEDIDO_VENDA SET STATUS = ''P'' WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := FOrcamentoId;
    LQuery.ExecSQL;
    FConexao.Confirmar;
    MessageDlg('Orçamento convertido em Pedido!', mtInformation, [mbOK], 0);
  finally
    LQuery.Free;
  end;
end;

procedure TfrmOrcamento.LimparFormulario;
begin
  edtData.Text := FormatDateTime('dd/mm/yyyy', Now);
  edtValidade.Text := FormatDateTime('dd/mm/yyyy', IncMonth(Now, 1));
  cmbCliente.ItemIndex := -1;
  sgItens.RowCount := 1;
  edtSubtotal.Text := '0,00';
  edtDesconto.Text := '0,00';
  edtTotal.Text := '0,00';
  mmoObs.Clear;
  FProdutoId := 0;
  FOrcamentoId := 0;
end;

procedure TfrmOrcamento.btnCancelarClick(Sender: TObject);
begin
  LimparFormulario;
end;

procedure TfrmOrcamento.btnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
