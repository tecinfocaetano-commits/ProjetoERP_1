unit uFrmPDV;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 5 - Frente de Caixa / PDV
  Descrição: Ponto de Venda com leitura de código de barras
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, Grids, DB, SQLDB, ComCtrls,
  uConexao, uSessao, uPDVService;

type
  { TfrmPDV }
  TfrmPDV = class(TForm)
    pnlTopo: TPanel;
    lblEmpresa: TLabel;
    lblOperador: TLabel;
    lblCaixa: TLabel;
    pnlBarras: TPanel;
    lblCodigo: TLabel;
    edtCodigo: TEdit;
    lblProdutoDesc: TLabel;
    pnlItens: TPanel;
    sgItens: TStringGrid;
    pnlDireita: TPanel;
    pnlTotal: TPanel;
    lblTotalLabel: TLabel;
    lblTotalValor: TLabel;
    lblSubtotalLabel: TLabel;
    lblSubtotalValor: TLabel;
    lblDescontoLabel: TLabel;
    edtDesconto: TEdit;
    lblItensLabel: TLabel;
    lblItensQtd: TLabel;
    pnlPagamento: TPanel;
    lblFormaPag: TLabel;
    cmbFormaPag: TComboBox;
    lblRecebido: TLabel;
    edtRecebido: TEdit;
    lblTroco: TLabel;
    lblTrocoValor: TLabel;
    pnlAcoes: TPanel;
    btnFinalizar: TBitBtn;
    btnCancelarVenda: TBitBtn;
    btnCancelarItem: TBitBtn;
    btnSangria: TBitBtn;
    btnSuprimento: TBitBtn;
    btnFecharCaixa: TBitBtn;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure edtCodigoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure edtRecebidoExit(Sender: TObject);
    procedure edtDescontoExit(Sender: TObject);
    procedure btnFinalizarClick(Sender: TObject);
    procedure btnCancelarVendaClick(Sender: TObject);
    procedure btnCancelarItemClick(Sender: TObject);
    procedure btnSangriaClick(Sender: TObject);
    procedure btnSuprimentoClick(Sender: TObject);
    procedure btnFecharCaixaClick(Sender: TObject);
  private
    FConexao: TConexao;
    FService: TPDVService;
    FCaixaId: Int64;
    { ID do produto e preço "cru" de cada linha do grid (linha 1 = índice 0) }
    FProdutoIds: TStringList;
    FPrecos: TStringList;
    procedure ConfigurarGrid;
    procedure CarregarFormasPagamento;
    procedure AtualizarCaixaAberto;
    procedure BuscarProduto(const ACodigo: string);
    procedure RenumerarItens;
    procedure RecalcularTotais;
    procedure LimparVenda;
    procedure AbrirCaixa;
  public
    destructor Destroy; override;
  end;

var
  frmPDV: TfrmPDV;

implementation

{$R *.lfm}

destructor TfrmPDV.Destroy;
begin
  FProdutoIds.Free;
  FPrecos.Free;
  FService.Free;
  inherited Destroy;
end;

procedure TfrmPDV.FormCreate(Sender: TObject);
begin
  try
    FConexao := TConexao.GetInstance;
    // Iniciar conexão com o banco
    if not FConexao.Conectado then
      FConexao.Conectar;

    FService := TPDVService.Create;
    FProdutoIds := TStringList.Create;
    FPrecos := TStringList.Create;
    FCaixaId := 0;

    ConfigurarGrid;
    CarregarFormasPagamento;
    lblOperador.Caption := 'Operador: ' + TSessao.GetInstance.UsuarioNome;

    AtualizarCaixaAberto;
    if FCaixaId <= 0 then
      AbrirCaixa;
  except
    on E: Exception do
      MessageDlg('Erro ao inicializar formulário: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmPDV.FormShow(Sender: TObject);
begin
  // O foco só pode ser aplicado depois que a janela está visível
  if edtCodigo.CanFocus then
    edtCodigo.SetFocus;
end;

procedure TfrmPDV.ConfigurarGrid;
begin
  sgItens.ColCount := 6;
  sgItens.RowCount := 1;
  sgItens.FixedRows := 1;
  sgItens.Cells[0, 0] := 'Item';
  sgItens.Cells[1, 0] := 'Código';
  sgItens.Cells[2, 0] := 'Descrição';
  sgItens.Cells[3, 0] := 'Qtd';
  sgItens.Cells[4, 0] := 'Vlr Unit.';
  sgItens.Cells[5, 0] := 'Total';
  sgItens.ColWidths[0] := 40;
  sgItens.ColWidths[1] := 100;
  sgItens.ColWidths[2] := 280;
  sgItens.ColWidths[3] := 60;
  sgItens.ColWidths[4] := 90;
  sgItens.ColWidths[5] := 90;
end;

procedure TfrmPDV.CarregarFormasPagamento;
begin
  FService.CarregarFormasPagamento(cmbFormaPag.Items);
end;

procedure TfrmPDV.AtualizarCaixaAberto;
begin
  FCaixaId := FService.CaixaAberto;
  if FCaixaId > 0 then
    lblCaixa.Caption := 'Caixa: ' + IntToStr(FCaixaId) + ' (Aberto)'
  else
    lblCaixa.Caption := 'Caixa: fechado';
end;

procedure TfrmPDV.AbrirCaixa;
var
  LValor: string;
begin
  if not InputQuery('Abertura de Caixa', 'Valor inicial:', LValor) then
  begin
    Close;
    Exit;
  end;

  try
    FCaixaId := FService.AbrirCaixa(StrToFloatDef(LValor, 0));
    lblCaixa.Caption := 'Caixa: ' + IntToStr(FCaixaId) + ' (Aberto)';
    MessageDlg('Caixa aberto com sucesso!', mtInformation, [mbOK], 0);
  except
    on E: Exception do
      MessageDlg('Erro: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmPDV.BuscarProduto(const ACodigo: string);
var
  LProdutoId: Int64;
  LCodigoProduto, LDescricao: string;
  LPreco: Double;
  LRow: Integer;
begin
  if not FService.BuscarProduto(ACodigo, LProdutoId, LCodigoProduto,
    LDescricao, LPreco) then
  begin
    lblProdutoDesc.Caption := 'Produto não encontrado!';
    Exit;
  end;

  LRow := sgItens.RowCount;
  sgItens.RowCount := LRow + 1;
  FProdutoIds.Add(IntToStr(LProdutoId));
  FPrecos.Add(FloatToStr(LPreco));

  sgItens.Cells[0, LRow] := IntToStr(LRow);
  sgItens.Cells[1, LRow] := LCodigoProduto;
  sgItens.Cells[2, LRow] := LDescricao;
  sgItens.Cells[3, LRow] := '1';
  sgItens.Cells[4, LRow] := FormatFloat('#,##0.00', LPreco);
  sgItens.Cells[5, LRow] := FormatFloat('#,##0.00', TotalItemPDV(1, LPreco));

  lblProdutoDesc.Caption := LDescricao + ' - R$ ' +
    FormatFloat('#,##0.00', LPreco);

  RecalcularTotais;
end;

procedure TfrmPDV.RenumerarItens;
var
  I: Integer;
begin
  for I := 1 to sgItens.RowCount - 1 do
    sgItens.Cells[0, I] := IntToStr(I);
end;

procedure TfrmPDV.RecalcularTotais;
var
  I: Integer;
  LSub, LDesc, LTotal, LRecebido, LTroco: Double;
begin
  LSub := 0;
  for I := 0 to FPrecos.Count - 1 do
    LSub := LSub + StrToFloatDef(FPrecos[I], 0);

  LDesc := StrToFloatDef(edtDesconto.Text, 0);
  LTotal := TotalVendaPDV(LSub, LDesc);

  lblSubtotalValor.Caption := 'R$ ' + FormatFloat('#,##0.00', LSub);
  lblTotalValor.Caption := 'R$ ' + FormatFloat('#,##0.00', LTotal);
  lblItensQtd.Caption := IntToStr(FProdutoIds.Count);

  // Calcular troco (nunca negativo)
  LRecebido := StrToFloatDef(edtRecebido.Text, 0);
  LTroco := LRecebido - LTotal;
  if LTroco < 0 then
    LTroco := 0;
  if LRecebido > 0 then
    lblTrocoValor.Caption := 'R$ ' + FormatFloat('#,##0.00', LTroco)
  else
    lblTrocoValor.Caption := 'R$ 0,00';
end;

procedure TfrmPDV.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    113: btnFinalizarClick(nil);       // F2 = Finalizar
    114: btnCancelarItemClick(nil);    // F3 = Cancelar item
    115: btnSangriaClick(nil);         // F4 = Sangria
    116: btnSuprimentoClick(nil);      // F5 = Suprimento
    117: btnCancelarVendaClick(nil);   // F6 = Cancelar venda
    27:  edtCodigo.SetFocus;           // ESC = Foco no código
  end;
end;

procedure TfrmPDV.edtCodigoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = 13 then
  begin
    if Trim(edtCodigo.Text) <> '' then
    begin
      BuscarProduto(Trim(edtCodigo.Text));
      edtCodigo.Clear;
    end;
  end;
end;

procedure TfrmPDV.edtRecebidoExit(Sender: TObject);
begin
  RecalcularTotais;
end;

procedure TfrmPDV.edtDescontoExit(Sender: TObject);
begin
  RecalcularTotais;
end;

procedure TfrmPDV.btnFinalizarClick(Sender: TObject);
var
  LItens: TItensPDVEntrada;
  I: Integer;
  LSub, LDesc, LTotal: Double;
  LFormaId: Int64;
begin
  if FProdutoIds.Count = 0 then
  begin
    MessageDlg('Nenhum item na venda.', mtWarning, [mbOK], 0);
    Exit;
  end;

  if cmbFormaPag.ItemIndex < 0 then
  begin
    MessageDlg('Selecione a forma de pagamento.', mtWarning, [mbOK], 0);
    Exit;
  end;

  if FCaixaId <= 0 then
  begin
    MessageDlg('Abra o caixa antes de finalizar a venda.', mtWarning, [mbOK], 0);
    Exit;
  end;

  { monta os itens a partir das listas paralelas (ID e preço "cru"),
    evitando reinterpretar texto formatado do grid }
  LSub := 0;
  SetLength(LItens, FProdutoIds.Count);
  for I := 0 to FProdutoIds.Count - 1 do
  begin
    LItens[I].ProdutoId := StrToInt64Def(FProdutoIds[I], 0);
    LItens[I].Quantidade := 1;
    LItens[I].PrecoUnitario := StrToFloatDef(FPrecos[I], 0);
    LSub := LSub + TotalItemPDV(LItens[I].Quantidade, LItens[I].PrecoUnitario);
  end;

  LDesc := StrToFloatDef(edtDesconto.Text, 0);
  LTotal := TotalVendaPDV(LSub, LDesc);
  LFormaId := Int64(PtrInt(cmbFormaPag.Items.Objects[cmbFormaPag.ItemIndex]));

  try
    FService.SalvarVenda(FCaixaId, LItens, LDesc, LFormaId);
    MessageDlg('Venda finalizada! Total: R$ ' + FormatFloat('#,##0.00', LTotal),
      mtInformation, [mbOK], 0);
    LimparVenda;
  except
    on E: Exception do
      MessageDlg('Erro: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmPDV.btnCancelarItemClick(Sender: TObject);
var
  I: Integer;
begin
  I := sgItens.Row;
  if (I < 1) or (sgItens.RowCount <= 1) then Exit;

  if I - 1 < FProdutoIds.Count then
    FProdutoIds.Delete(I - 1);
  if I - 1 < FPrecos.Count then
    FPrecos.Delete(I - 1);

  for I := sgItens.Row to sgItens.RowCount - 2 do
    sgItens.Rows[I].Assign(sgItens.Rows[I + 1]);
  sgItens.RowCount := sgItens.RowCount - 1;
  RenumerarItens;
  RecalcularTotais;
end;

procedure TfrmPDV.btnCancelarVendaClick(Sender: TObject);
begin
  if FProdutoIds.Count = 0 then Exit;
  if MessageDlg('Cancelar a venda atual?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    LimparVenda;
end;

procedure TfrmPDV.btnSangriaClick(Sender: TObject);
var
  LValor: string;
  LNum: Double;
begin
  if FCaixaId <= 0 then
  begin
    MessageDlg('Abra o caixa antes de lançar a sangria.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if not InputQuery('Sangria de Caixa', 'Valor da sangria:', LValor) then Exit;
  LNum := StrToFloatDef(LValor, 0);
  if LNum <= 0 then
  begin
    MessageDlg('Valor inválido.', mtWarning, [mbOK], 0);
    Exit;
  end;
  try
    FService.RegistrarMovimento(FCaixaId, 'S', LNum, 'Sangria');
    MessageDlg('Sangria registrada: R$ ' + LValor, mtInformation, [mbOK], 0);
  except
    on E: Exception do
      MessageDlg('Erro: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmPDV.btnSuprimentoClick(Sender: TObject);
var
  LValor: string;
  LNum: Double;
begin
  if FCaixaId <= 0 then
  begin
    MessageDlg('Abra o caixa antes de lançar o suprimento.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if not InputQuery('Suprimento de Caixa', 'Valor do suprimento:', LValor) then Exit;
  LNum := StrToFloatDef(LValor, 0);
  if LNum <= 0 then
  begin
    MessageDlg('Valor inválido.', mtWarning, [mbOK], 0);
    Exit;
  end;
  try
    FService.RegistrarMovimento(FCaixaId, 'E', LNum, 'Suprimento');
    MessageDlg('Suprimento registrado: R$ ' + LValor, mtInformation, [mbOK], 0);
  except
    on E: Exception do
      MessageDlg('Erro: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmPDV.btnFecharCaixaClick(Sender: TObject);
var
  LSaldo: Double;
begin
  if FCaixaId <= 0 then
  begin
    MessageDlg('Não há caixa aberto para fechar.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if MessageDlg('Fechar o caixa?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;

  try
    LSaldo := FService.FecharCaixa(FCaixaId);
    MessageDlg('Caixa fechado! Saldo: R$ ' + FormatFloat('#,##0.00', LSaldo),
      mtInformation, [mbOK], 0);
    Close;
  except
    on E: Exception do
      MessageDlg('Erro: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmPDV.LimparVenda;
begin
  sgItens.RowCount := 1;
  FProdutoIds.Clear;
  FPrecos.Clear;
  edtCodigo.Clear;
  edtDesconto.Text := '0,00';
  edtRecebido.Clear;
  lblProdutoDesc.Caption := '';
  lblSubtotalValor.Caption := 'R$ 0,00';
  lblTotalValor.Caption := 'R$ 0,00';
  lblTrocoValor.Caption := 'R$ 0,00';
  lblItensQtd.Caption := '0';
  cmbFormaPag.ItemIndex := -1;
  edtCodigo.SetFocus;
end;

end.
