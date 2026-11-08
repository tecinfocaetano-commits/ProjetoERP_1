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
  uConexao, uSessao, uPedidoVendaService, uOrcamentoService;

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
    LQuery.SQL.Text :=
      'SELECT ID, NOME FROM PESSOA ' +
      'WHERE TIPO = ''C'' AND ATIVO = ''A'' AND EMPRESA_ID = :EMP ORDER BY NOME';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
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
    { no SQLDB um parâmetro nomeado repetido só é ligado na primeira
      ocorrência: usar :COD1/:COD2/:COD3 para buscar por código,
      código de barras e ID }
    LQuery.SQL.Text :=
      'SELECT ID, DESCRICAO, PRECO_VENDA FROM PRODUTO ' +
      'WHERE (CODIGO = :COD1 OR CODIGO_BARRAS = :COD2 ' +
      '  OR CAST(ID AS VARCHAR(20)) = :COD3) ' +
      'AND ATIVO = ''A'' AND EMPRESA_ID = :EMP';
    LQuery.ParamByName('COD1').AsString := Trim(edtProduto.Text);
    LQuery.ParamByName('COD2').AsString := Trim(edtProduto.Text);
    LQuery.ParamByName('COD3').AsString := Trim(edtProduto.Text);
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
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
  sgItens.Cells[5, LRow] := FormatFloat('#,##0.00', TotalItemPedido(LQtd, LVlr, LDesc));
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
  edtTotal.Text := FormatFloat('#,##0.00',
    TotalDoPedidoVenda(LSub, StrToFloatDef(edtDesconto.Text, 0)));
end;

procedure TfrmOrcamento.edtDescontoExit(Sender: TObject);
begin
  RecalcularTotais;
end;

procedure TfrmOrcamento.btnSalvarClick(Sender: TObject);
var
  I: Integer;
  LClienteId: Int64;
  LItens: TItensPedidoEntrada;
  LService: TOrcamentoService;
  LNumero: string;
  LDesconto: Double;
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

  LClienteId := Int64(PtrInt(cmbCliente.Items.Objects[cmbCliente.ItemIndex]));

  { monta os itens do grid para o Service: validação, totais, gravação
    dos itens e auditoria ficam em TOrcamentoService/TPedidoVendaService }
  LItens := nil;
  SetLength(LItens, sgItens.RowCount - 1);
  for I := 1 to sgItens.RowCount - 1 do
  begin
    LItens[I - 1].ProdutoId := StrToInt64Def(sgItens.Cells[0, I], 0);
    LItens[I - 1].Quantidade := StrToFloatDef(sgItens.Cells[2, I], 0);
    LItens[I - 1].ValorUnitario := StrToFloatDef(sgItens.Cells[3, I], 0);
    LItens[I - 1].Desconto := StrToFloatDef(sgItens.Cells[4, I], 0);
    LItens[I - 1].Cfop := '';
    LItens[I - 1].Tamanhos := nil;
  end;

  LDesconto := StrToFloatDef(edtDesconto.Text, 0);
  LService := TOrcamentoService.Create;
  try
    try
      { o número exibido é o mesmo que será gravado }
      LNumero := Trim(edtNumero.Text);
      if (LNumero = '') or (LNumero = '0') then
        LNumero := IntToStr(LService.ProximoNumero);

      FOrcamentoId := LService.SalvarOrcamento(LClienteId, LNumero, LItens,
        LDesconto, mmoObs.Text);
      edtNumero.Text := LNumero;

      { mantém o ID para o botão "Gerar Pedido"; limpa só o que já foi
        gravado, para não salvar o mesmo orçamento duas vezes }
      cmbCliente.ItemIndex := -1;
      sgItens.RowCount := 1;
      edtSubtotal.Text := '0,00';
      edtDesconto.Text := '0,00';
      edtTotal.Text := '0,00';
      mmoObs.Clear;

      MessageDlg('Orçamento salvo com sucesso! Use "Gerar Pedido" para convertê-lo.',
        mtInformation, [mbOK], 0);
    except
      on E: Exception do
        MessageDlg('Erro ao salvar orçamento: ' + E.Message, mtError, [mbOK], 0);
    end;
  finally
    LService.Free;
  end;
end;

procedure TfrmOrcamento.btnGerarPedidoClick(Sender: TObject);
var
  LService: TOrcamentoService;
begin
  if FOrcamentoId <= 0 then
  begin
    MessageDlg('Salve o orçamento antes de gerar o pedido.', mtWarning, [mbOK], 0);
    Exit;
  end;

  { valida empresa e status ('O') antes de mudar para 'P', com auditoria }
  LService := TOrcamentoService.Create;
  try
    try
      LService.ConverterEmPedido(FOrcamentoId);
      MessageDlg('Orçamento convertido em Pedido!', mtInformation, [mbOK], 0);
      LimparFormulario;
    except
      on E: Exception do
        MessageDlg('Erro ao converter orçamento: ' + E.Message, mtError, [mbOK], 0);
    end;
  finally
    LService.Free;
  end;
end;

procedure TfrmOrcamento.LimparFormulario;
begin
  edtNumero.Clear;
  edtData.Text := FormatDateTime('dd/mm/yyyy', Now);
  edtValidade.Text := FormatDateTime('dd/mm/yyyy', IncMonth(Now, 1));
  cmbCliente.ItemIndex := -1;
  edtProduto.Clear;
  lblProdutoDesc.Caption := '';
  edtQtd.Clear;
  edtVlrUnit.Clear;
  edtDescItem.Text := '0,00';
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
