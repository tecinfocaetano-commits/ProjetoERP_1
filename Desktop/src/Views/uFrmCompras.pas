unit uFrmCompras;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Fase 1 (redesenho) - Formulário: Compras
  Descrição: Pedido de compra de materiais (cabeçalho + itens).
             Ao confirmar, pode gerar Nota de Entrada.
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, Grids, DateUtils,
  uConexao, uSessao, uNotaEntradaService, uPedidoCompraService;

type
  { TfrmCompras }
  TfrmCompras = class(TForm)
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    pnlCabecalho: TPanel;
    lblNumero: TLabel;
    edtNumero: TEdit;
    lblFornecedor: TLabel;
    cmbFornecedor: TComboBox;
    lblDataEmissao: TLabel;
    edtDataEmissao: TEdit;
    lblDataEntrega: TLabel;
    edtDataEntrega: TEdit;
    lblStatus: TLabel;
    cmbStatus: TComboBox;
    pnlItens: TPanel;
    lblItens: TLabel;
    pnlAddItem: TPanel;
    lblMaterial: TLabel;
    edtMaterial: TEdit;
    btnBuscarMaterial: TBitBtn;
    lblMaterialDesc: TLabel;
    lblQtd: TLabel;
    edtQtd: TEdit;
    lblVlrUnit: TLabel;
    edtVlrUnit: TEdit;
    btnAddItem: TBitBtn;
    sgItens: TStringGrid;
    btnRemoverItem: TBitBtn;
    pnlTotais: TPanel;
    lblSubtotal: TLabel;
    edtSubtotal: TEdit;
    lblTotal: TLabel;
    edtTotal: TEdit;
    pnlBotoes: TPanel;
    btnSalvar: TBitBtn;
    btnConfirmar: TBitBtn;
    btnCancelar: TBitBtn;
    btnFechar: TBitBtn;
    lblObs: TLabel;
    mmoObs: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure btnBuscarMaterialClick(Sender: TObject);
    procedure btnAddItemClick(Sender: TObject);
    procedure btnRemoverItemClick(Sender: TObject);
    procedure btnSalvarClick(Sender: TObject);
    procedure btnConfirmarClick(Sender: TObject);
    procedure btnCancelarClick(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
  private
    FConexao: TConexao;
    FMaterialId: Int64;
    FPedidoId: Int64;
    procedure CarregarFornecedores;
    procedure ConfigurarGridItens;
    procedure RecalcularTotais;
    procedure LimparFormulario;
    function ProximoNumero: Integer;
    function SalvarPedido: Boolean;
  public
    property PedidoId: Int64 read FPedidoId write FPedidoId;
  end;

var
  frmCompras: TfrmCompras;

implementation

{$R *.lfm}

procedure TfrmCompras.FormCreate(Sender: TObject);
begin
  FConexao := TConexao.GetInstance;
  if not FConexao.Conectado then
    FConexao.Conectar;
  FMaterialId := 0;
  FPedidoId := 0;

  CarregarFornecedores;
  ConfigurarGridItens;

  edtDataEmissao.Text := FormatDateTime('dd/mm/yyyy', Now);
  edtDataEntrega.Text := FormatDateTime('dd/mm/yyyy', IncDay(Now, 7));
  edtNumero.Text := IntToStr(ProximoNumero);
  cmbStatus.ItemIndex := 0;
  edtSubtotal.Text := '0,00';
  edtTotal.Text := '0,00';
end;

procedure TfrmCompras.CarregarFornecedores;
var
  LQuery: TSQLQuery;
begin
  cmbFornecedor.Items.Clear;
  cmbFornecedor.Items.AddObject('', TObject(PtrInt(0)));
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT ID, NOME FROM PESSOA ' +
      'WHERE TIPO = ''F'' AND EMPRESA_ID = :EMP AND ATIVO = ''A'' ORDER BY NOME';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    while not LQuery.EOF do
    begin
      cmbFornecedor.Items.AddObject(LQuery.FieldByName('NOME').AsString,
        TObject(PtrInt(LQuery.FieldByName('ID').AsLargeInt)));
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TfrmCompras.ConfigurarGridItens;
begin
  sgItens.ColCount := 6;
  sgItens.RowCount := 1;
  sgItens.FixedRows := 1;
  sgItens.Cells[0, 0] := 'Mat.ID';
  sgItens.Cells[1, 0] := 'Descrição';
  sgItens.Cells[2, 0] := 'Qtd';
  sgItens.Cells[3, 0] := 'Vlr Unit.';
  sgItens.Cells[4, 0] := 'Total';
  sgItens.ColWidths[0] := 60;
  sgItens.ColWidths[1] := 300;
  sgItens.ColWidths[2] := 80;
  sgItens.ColWidths[3] := 90;
  sgItens.ColWidths[4] := 90;
  sgItens.Options := sgItens.Options + [goRowSelect];
end;

function TfrmCompras.ProximoNumero: Integer;
var
  LPedido: TPedidoCompraService;
begin
  LPedido := TPedidoCompraService.Create;
  try
    Result := LPedido.ProximoNumero;
  finally
    LPedido.Free;
  end;
end;

procedure TfrmCompras.btnBuscarMaterialClick(Sender: TObject);
var
  LQuery: TSQLQuery;
  LId: Int64;
begin
  LId := StrToInt64Def(Trim(edtMaterial.Text), 0);
  if LId <= 0 then
  begin
    MessageDlg('Informe o ID do material (ou consulte o cadastro).', mtWarning, [mbOK], 0);
    edtMaterial.SetFocus;
    Exit;
  end;

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := 'SELECT ID, DESCRICAO, PRECO_CUSTO FROM MATERIAL WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := LId;
    LQuery.Open;
    if LQuery.IsEmpty then
    begin
      MessageDlg('Material não encontrado.', mtWarning, [mbOK], 0);
      Exit;
    end;
    lblMaterialDesc.Caption := LQuery.FieldByName('DESCRICAO').AsString;
    FMaterialId := LId;
    edtQtd.Text := '1,0000';
    edtVlrUnit.Text := FormatFloat('#,##0.0000',
      LQuery.FieldByName('PRECO_CUSTO').AsFloat);
    edtQtd.SetFocus;
  finally
    LQuery.Free;
  end;
end;

procedure TfrmCompras.btnAddItemClick(Sender: TObject);
var
  LRow: Integer;
  LQtd, LVlr, LTotal: Double;
begin
  if FMaterialId <= 0 then
  begin
    MessageDlg('Busque um material antes de adicionar.', mtWarning, [mbOK], 0);
    Exit;
  end;

  LQtd := StrToFloatDef(edtQtd.Text, 0);
  if LQtd <= 0 then
  begin
    MessageDlg('Quantidade deve ser maior que zero.', mtWarning, [mbOK], 0);
    edtQtd.SetFocus;
    Exit;
  end;

  LVlr := StrToFloatDef(edtVlrUnit.Text, 0);
  LTotal := TotalItemCompra(LQtd, LVlr, 0);

  LRow := sgItens.RowCount;
  sgItens.RowCount := LRow + 1;
  sgItens.Cells[0, LRow] := IntToStr(FMaterialId);
  sgItens.Cells[1, LRow] := lblMaterialDesc.Caption;
  sgItens.Cells[2, LRow] := FormatFloat('#,##0.0000', LQtd);
  sgItens.Cells[3, LRow] := FormatFloat('#,##0.0000', LVlr);
  sgItens.Cells[4, LRow] := FormatFloat('#,##0.00', LTotal);

  RecalcularTotais;
  edtMaterial.Clear;
  lblMaterialDesc.Caption := '';
  FMaterialId := 0;
  edtQtd.Text := '1,0000';
  edtVlrUnit.Text := '0,0000';
end;

procedure TfrmCompras.btnRemoverItemClick(Sender: TObject);
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

procedure TfrmCompras.RecalcularTotais;
var
  I: Integer;
  LSub: Double;
begin
  LSub := 0;
  for I := 1 to sgItens.RowCount - 1 do
    LSub := LSub + StrToFloatDef(sgItens.Cells[4, I], 0);

  edtSubtotal.Text := FormatFloat('#,##0.00', LSub);
  edtTotal.Text := FormatFloat('#,##0.00', TotalDoPedidoCompra(LSub, 0));
end;

function TfrmCompras.SalvarPedido: Boolean;
var
  LFornId: Int64;
  LStatus: string;
  LItens: TItensCompraEntrada;
  LService: TPedidoCompraService;
  I: Integer;
begin
  Result := False;

  if cmbFornecedor.ItemIndex < 0 then
  begin
    MessageDlg('Selecione um fornecedor.', mtWarning, [mbOK], 0);
    Exit;
  end;

  if sgItens.RowCount <= 1 then
  begin
    MessageDlg('Adicione pelo menos um material.', mtWarning, [mbOK], 0);
    Exit;
  end;

  LFornId := Int64(PtrInt(cmbFornecedor.Items.Objects[cmbFornecedor.ItemIndex]));
  case cmbStatus.ItemIndex of
    1: LStatus := 'CONFIRMADO';
    2: LStatus := 'CANCELADO';
  else
    LStatus := 'ABERTO';
  end;

  { monta os itens do grid para o Service: a regra de total, validação
    e gravação fica toda no TPedidoCompraService }
  LItens := nil;
  SetLength(LItens, sgItens.RowCount - 1);
  for I := 1 to sgItens.RowCount - 1 do
  begin
    LItens[I - 1].MaterialId := StrToInt64Def(sgItens.Cells[0, I], 0);
    LItens[I - 1].Quantidade := StrToFloatDef(sgItens.Cells[2, I], 0);
    LItens[I - 1].ValorUnitario := StrToFloatDef(sgItens.Cells[3, I], 0);
    LItens[I - 1].Desconto := 0;
  end;

  LService := TPedidoCompraService.Create;
  try
    try
      FPedidoId := LService.SalvarPedido(LFornId, edtNumero.Text, LItens, 0,
        mmoObs.Text, LStatus,
        StrToDateDef(edtDataEmissao.Text, 0),
        StrToDateDef(edtDataEntrega.Text, 0));
      Result := True;
    except
      on E: Exception do
        MessageDlg('Erro ao salvar pedido de compra: ' + E.Message, mtError,
          [mbOK], 0);
    end;
  finally
    LService.Free;
  end;
end;

procedure TfrmCompras.btnSalvarClick(Sender: TObject);
begin
  if SalvarPedido then
  begin
    MessageDlg('Pedido de compra salvo com sucesso! Nº ' + edtNumero.Text,
      mtInformation, [mbOK], 0);
    LimparFormulario;
  end;
end;

procedure TfrmCompras.btnConfirmarClick(Sender: TObject);
var
  LService: TNotaEntradaService;
  LNotaId: Int64;
begin
  if not SalvarPedido then Exit;
  if FPedidoId <= 0 then
  begin
    MessageDlg('Não foi possível identificar o pedido salvo para gerar a nota.',
      mtError, [mbOK], 0);
    Exit;
  end;

  LService := TNotaEntradaService.Create;
  try
    try
      LNotaId := LService.CriarDoPedidoCompra(FPedidoId);
      MessageDlg('Pedido de compra confirmado. Nota de entrada nº ' +
        IntToStr(LNotaId) + ' gerada em aberto — processe-a na tela ' +
        '"Nota de Entrada" para dar entrada no estoque e gerar as contas a pagar.',
        mtInformation, [mbOK], 0);
    except
      on E: Exception do
        MessageDlg('O pedido foi salvo, mas a nota de entrada não foi gerada: ' +
          E.Message + sLineBreak + sLineBreak +
          'Ajuste o pedido e confirme novamente.', mtWarning, [mbOK], 0);
    end;
  finally
    LService.Free;
  end;

  LimparFormulario;
end;

procedure TfrmCompras.LimparFormulario;
begin
  edtNumero.Text := IntToStr(ProximoNumero);
  edtDataEmissao.Text := FormatDateTime('dd/mm/yyyy', Now);
  edtDataEntrega.Text := FormatDateTime('dd/mm/yyyy', IncDay(Now, 7));
  cmbFornecedor.ItemIndex := 0;
  cmbStatus.ItemIndex := 0;
  sgItens.RowCount := 1;
  edtSubtotal.Text := '0,00';
  edtTotal.Text := '0,00';
  mmoObs.Clear;
  edtMaterial.Clear;
  lblMaterialDesc.Caption := '';
  FMaterialId := 0;
  FPedidoId := 0;
end;

procedure TfrmCompras.btnCancelarClick(Sender: TObject);
begin
  LimparFormulario;
end;

procedure TfrmCompras.btnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
