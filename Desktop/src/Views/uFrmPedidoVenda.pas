unit uFrmPedidoVenda;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 4 - Pedido de Venda
  Descrição: Formulário de Pedido de Venda com itens
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, Grids, DateUtils,
  uConexao, uSessao;

type
  { TfrmPedidoVenda }
  TfrmPedidoVenda = class(TForm)
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    pnlCabecalho: TPanel;
    lblNumero: TLabel;
    edtNumero: TEdit;
    lblData: TLabel;
    edtData: TEdit;
    lblCliente: TLabel;
    cmbCliente: TComboBox;
    lblFormaPag: TLabel;
    cmbFormaPag: TComboBox;
    lblCondPag: TLabel;
    cmbCondPag: TComboBox;
    lblStatus: TLabel;
    cmbStatus: TComboBox;
    pnlItens: TPanel;
    lblItens: TLabel;
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
    sgItens: TStringGrid;
    btnRemoverItem: TBitBtn;
    pnlTotais: TPanel;
    lblSubtotal: TLabel;
    edtSubtotal: TEdit;
    lblDesconto: TLabel;
    edtDesconto: TEdit;
    lblTotal: TLabel;
    edtTotal: TEdit;
    pnlBotoes: TPanel;
    btnSalvar: TBitBtn;
    btnCancelar: TBitBtn;
    btnFechar: TBitBtn;
    lblObs: TLabel;
    mmoObs: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure btnBuscarProdClick(Sender: TObject);
    procedure btnAddItemClick(Sender: TObject);
    procedure btnRemoverItemClick(Sender: TObject);
    procedure btnSalvarClick(Sender: TObject);
    procedure btnCancelarClick(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
    procedure edtDescontoExit(Sender: TObject);
  private
    FConexao: TConexao;
    FProdutoId: Int64;
    FPedidoId: Int64;
    procedure CarregarClientes;
    procedure CarregarFormasPagamento;
    procedure CarregarCondicoesPagamento;
    procedure ConfigurarGridItens;
    procedure RecalcularTotais;
    procedure LimparFormulario;
    function ProximoNumero: Integer;
  public
    property PedidoId: Int64 read FPedidoId write FPedidoId;
  end;

var
  frmPedidoVenda: TfrmPedidoVenda;

implementation

{$R *.lfm}

procedure TfrmPedidoVenda.FormCreate(Sender: TObject);
begin
  FConexao := TConexao.GetInstance;
  // Iniciar conexão com o banco
  if not FConexao.Conectado then
    FConexao.Conectar;
  FProdutoId := 0;
  FPedidoId := 0;

  CarregarClientes;
  CarregarFormasPagamento;
  CarregarCondicoesPagamento;
  ConfigurarGridItens;

  edtData.Text := FormatDateTime('dd/mm/yyyy', Now);
  edtNumero.Text := IntToStr(ProximoNumero);
  cmbStatus.ItemIndex := 0;
end;

procedure TfrmPedidoVenda.ConfigurarGridItens;
begin
  sgItens.ColCount := 7;
  sgItens.RowCount := 1;
  sgItens.FixedRows := 1;
  sgItens.Cells[0, 0] := 'Prod.ID';
  sgItens.Cells[1, 0] := 'Descrição';
  sgItens.Cells[2, 0] := 'Qtd';
  sgItens.Cells[3, 0] := 'Vlr Unit.';
  sgItens.Cells[4, 0] := 'Desconto';
  sgItens.Cells[5, 0] := 'Total';
  sgItens.Cells[6, 0] := 'CFOP';
  sgItens.ColWidths[0] := 60;
  sgItens.ColWidths[1] := 250;
  sgItens.ColWidths[2] := 70;
  sgItens.ColWidths[3] := 90;
  sgItens.ColWidths[4] := 70;
  sgItens.ColWidths[5] := 90;
  sgItens.ColWidths[6] := 60;
end;

procedure TfrmPedidoVenda.CarregarClientes;
var
  LQuery: TSQLQuery;
begin
  cmbCliente.Items.Clear;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := 'SELECT ID, NOME FROM CLIENTE WHERE ATIVO = ''A'' ORDER BY NOME';
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

procedure TfrmPedidoVenda.CarregarFormasPagamento;
var
  LQuery: TSQLQuery;
begin
  cmbFormaPag.Items.Clear;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := 'SELECT ID, DESCRICAO FROM FORMA_PAGAMENTO WHERE ATIVO = ''A'' ORDER BY DESCRICAO';
    LQuery.Open;
    while not LQuery.EOF do
    begin
      cmbFormaPag.Items.AddObject(LQuery.FieldByName('DESCRICAO').AsString,
        TObject(PtrInt(LQuery.FieldByName('ID').AsLargeInt)));
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TfrmPedidoVenda.CarregarCondicoesPagamento;
var
  LQuery: TSQLQuery;
begin
  cmbCondPag.Items.Clear;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := 'SELECT ID, DESCRICAO FROM CONDICAO_PAGAMENTO WHERE ATIVO = ''A'' ORDER BY DESCRICAO';
    LQuery.Open;
    while not LQuery.EOF do
    begin
      cmbCondPag.Items.AddObject(LQuery.FieldByName('DESCRICAO').AsString,
        TObject(PtrInt(LQuery.FieldByName('ID').AsLargeInt)));
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

function TfrmPedidoVenda.ProximoNumero: Integer;
var
  LQuery: TSQLQuery;
begin
  Result := 1;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := 'SELECT MAX(NUMERO) FROM PEDIDO_VENDA';
    LQuery.Open;
    if not LQuery.Fields[0].IsNull then
      Result := LQuery.Fields[0].AsInteger + 1;
  finally
    LQuery.Free;
  end;
end;

procedure TfrmPedidoVenda.btnBuscarProdClick(Sender: TObject);
var
  LQuery: TSQLQuery;
begin
  if Trim(edtProduto.Text) = '' then Exit;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT ID, DESCRICAO, PRECO_VENDA, CFOP_VENDA FROM PRODUTO ' +
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
      lblProdutoDesc.Caption := '';
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TfrmPedidoVenda.btnAddItemClick(Sender: TObject);
var
  LRow: Integer;
  LQtd, LVlr, LDesc, LTotal: Double;
begin
  if FProdutoId <= 0 then
  begin
    MessageDlg('Selecione um produto.', mtWarning, [mbOK], 0);
    Exit;
  end;

  LQtd := StrToFloatDef(edtQtd.Text, 0);
  LVlr := StrToFloatDef(edtVlrUnit.Text, 0);
  LDesc := StrToFloatDef(edtDescItem.Text, 0);
  LTotal := (LQtd * LVlr) - LDesc;

  if LQtd <= 0 then
  begin
    MessageDlg('Quantidade deve ser maior que zero.', mtWarning, [mbOK], 0);
    Exit;
  end;

  LRow := sgItens.RowCount;
  sgItens.RowCount := LRow + 1;
  sgItens.Cells[0, LRow] := IntToStr(FProdutoId);
  sgItens.Cells[1, LRow] := lblProdutoDesc.Caption;
  sgItens.Cells[2, LRow] := FormatFloat('#,##0.0000', LQtd);
  sgItens.Cells[3, LRow] := FormatFloat('#,##0.0000', LVlr);
  sgItens.Cells[4, LRow] := FormatFloat('#,##0.00', LDesc);
  sgItens.Cells[5, LRow] := FormatFloat('#,##0.00', LTotal);
  sgItens.Cells[6, LRow] := '5102';

  // Limpar campos de item
  edtProduto.Clear;
  lblProdutoDesc.Caption := '';
  edtQtd.Text := '1';
  edtVlrUnit.Text := '0,00';
  edtDescItem.Text := '0,00';
  FProdutoId := 0;
  edtProduto.SetFocus;

  RecalcularTotais;
end;

procedure TfrmPedidoVenda.btnRemoverItemClick(Sender: TObject);
var
  I: Integer;
begin
  if sgItens.Row < 1 then Exit;
  if sgItens.RowCount <= 1 then Exit;

  for I := sgItens.Row to sgItens.RowCount - 2 do
    sgItens.Rows[I].Assign(sgItens.Rows[I + 1]);
  sgItens.RowCount := sgItens.RowCount - 1;
  RecalcularTotais;
end;

procedure TfrmPedidoVenda.RecalcularTotais;
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

procedure TfrmPedidoVenda.edtDescontoExit(Sender: TObject);
begin
  RecalcularTotais;
end;

procedure TfrmPedidoVenda.btnSalvarClick(Sender: TObject);
var
  LQuery: TSQLQuery;
  I: Integer;
  LClienteId, LFormaPagId, LCondPagId: Int64;
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
  if cmbFormaPag.ItemIndex >= 0 then
    LFormaPagId := PtrInt(cmbFormaPag.Items.Objects[cmbFormaPag.ItemIndex])
  else
    LFormaPagId := 0;
  if cmbCondPag.ItemIndex >= 0 then
    LCondPagId := PtrInt(cmbCondPag.Items.Objects[cmbCondPag.ItemIndex])
  else
    LCondPagId := 0;

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;

    FConexao.IniciarTransacao;

    // Salvar cabeçalho
    LQuery.SQL.Text :=
      'INSERT INTO PEDIDO_VENDA (EMPRESA_ID, CLIENTE_ID, USUARIO_ID, NUMERO, ' +
      'STATUS, SUBTOTAL, DESCONTO, TOTAL, FORMA_PAGAMENTO_ID, CONDICAO_PAGAMENTO_ID, OBSERVACOES) ' +
      'VALUES (:EMP, :CLI, :USR, :NUM, :STS, :SUB, :DESC, :TOT, :FP, :CP, :OBS)';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.ParamByName('CLI').AsLargeInt := LClienteId;
    LQuery.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
    LQuery.ParamByName('NUM').AsInteger := StrToIntDef(edtNumero.Text, 0);
    LQuery.ParamByName('STS').AsString := 'P';
    LQuery.ParamByName('SUB').AsFloat := StrToFloatDef(edtSubtotal.Text, 0);
    LQuery.ParamByName('DESC').AsFloat := StrToFloatDef(edtDesconto.Text, 0);
    LQuery.ParamByName('TOT').AsFloat := StrToFloatDef(edtTotal.Text, 0);
    if LFormaPagId > 0 then
      LQuery.ParamByName('FP').AsLargeInt := LFormaPagId
    else
      LQuery.ParamByName('FP').Clear;
    if LCondPagId > 0 then
      LQuery.ParamByName('CP').AsLargeInt := LCondPagId
    else
      LQuery.ParamByName('CP').Clear;
    LQuery.ParamByName('OBS').AsString := mmoObs.Text;
    LQuery.ExecSQL;

    // Obter ID do pedido
    LQuery.SQL.Text := 'SELECT GEN_ID(GEN_PEDIDO_VENDA_ID, 0) FROM RDB$DATABASE';
    LQuery.Open;
    FPedidoId := LQuery.Fields[0].AsLargeInt;
    if LQuery.Active then
      LQuery.Close;

    // Salvar itens
    for I := 1 to sgItens.RowCount - 1 do
    begin
      LQuery.SQL.Text :=
        'INSERT INTO ITEM_PEDIDO (PEDIDO_VENDA_ID, PRODUTO_ID, QUANTIDADE, ' +
        'VALOR_UNITARIO, DESCONTO, VALOR_TOTAL, CFOP) ' +
        'VALUES (:PED, :PROD, :QTD, :VLR, :DESC, :TOT, :CFOP)';
      LQuery.ParamByName('PED').AsLargeInt := FPedidoId;
      LQuery.ParamByName('PROD').AsLargeInt := StrToInt64(sgItens.Cells[0, I]);
      LQuery.ParamByName('QTD').AsFloat := StrToFloatDef(sgItens.Cells[2, I], 0);
      LQuery.ParamByName('VLR').AsFloat := StrToFloatDef(sgItens.Cells[3, I], 0);
      LQuery.ParamByName('DESC').AsFloat := StrToFloatDef(sgItens.Cells[4, I], 0);
      LQuery.ParamByName('TOT').AsFloat := StrToFloatDef(sgItens.Cells[5, I], 0);
      LQuery.ParamByName('CFOP').AsString := sgItens.Cells[6, I];
      LQuery.ExecSQL;
    end;

    FConexao.Confirmar;
    MessageDlg('Pedido salvo com sucesso! Nº ' + edtNumero.Text, mtInformation, [mbOK], 0);
    LimparFormulario;
  except
    on E: Exception do
    begin
      FConexao.Cancelar;
      MessageDlg('Erro ao salvar pedido: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
  LQuery.Free;
end;

procedure TfrmPedidoVenda.LimparFormulario;
begin
  edtNumero.Text := IntToStr(ProximoNumero);
  edtData.Text := FormatDateTime('dd/mm/yyyy', Now);
  cmbCliente.ItemIndex := -1;
  cmbFormaPag.ItemIndex := -1;
  cmbCondPag.ItemIndex := -1;
  cmbStatus.ItemIndex := 0;
  sgItens.RowCount := 1;
  edtSubtotal.Text := '0,00';
  edtDesconto.Text := '0,00';
  edtTotal.Text := '0,00';
  mmoObs.Clear;
  FProdutoId := 0;
  FPedidoId := 0;
end;

procedure TfrmPedidoVenda.btnCancelarClick(Sender: TObject);
begin
  LimparFormulario;
end;

procedure TfrmPedidoVenda.btnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
