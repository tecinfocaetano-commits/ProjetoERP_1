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
  uConexao, uSessao, uGrade, uGradeService, uFrmGradeQuantidades,
  uPedidoVendaService;

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
    btnGradeItem: TBitBtn;
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
    procedure FormDestroy(Sender: TObject);
    procedure btnBuscarProdClick(Sender: TObject);
    procedure btnAddItemClick(Sender: TObject);
    procedure btnRemoverItemClick(Sender: TObject);
    procedure btnGradeItemClick(Sender: TObject);
    procedure btnSalvarClick(Sender: TObject);
    procedure btnCancelarClick(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
    procedure edtDescontoExit(Sender: TObject);
  private
    FConexao: TConexao;
    FGradeService: TGradeService;
    FUsaGrade: Boolean;
    FGrades: array of TGradeTamanhos;
    FProdutoId: Int64;
    FPedidoId: Int64;
    procedure CarregarClientes;
    procedure CarregarFormasPagamento;
    procedure CarregarCondicoesPagamento;
    procedure ConfigurarGridItens;
    procedure RecalcularTotais;
    procedure LimparFormulario;
    function ProximoNumero: Integer;
    procedure AjustarGrades;
    procedure RemoverGradeDaLinha(ARow: Integer);
    procedure AplicarGradeNaLinha(ARow: Integer;
      const ATamanhos: TGradeTamanhos);
    function GradeDaLinha(ARow: Integer): TGradeTamanhos;
    function GradePadraoDoProduto(AProdutoId: Int64): TGradeTamanhos;
    function EditarGrade(const ATitulo: string; const AEntrada: TGradeTamanhos;
      out ASaida: TGradeTamanhos; AExigirQuantidade: Boolean = True): Boolean;
    function AbrirGradeDaLinha(ARow: Integer): Boolean;
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

  FGradeService := TGradeService.Create;
  FUsaGrade := FGradeService.UsaGrade;
  btnGradeItem.Visible := FUsaGrade;
  SetLength(FGrades, 1);
  FGrades[0] := nil;

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
  sgItens.ColCount := 8;
  sgItens.RowCount := 1;
  sgItens.FixedRows := 1;
  sgItens.Cells[0, 0] := 'Prod.ID';
  sgItens.Cells[1, 0] := 'Descrição';
  sgItens.Cells[2, 0] := 'Qtd';
  sgItens.Cells[3, 0] := 'Vlr Unit.';
  sgItens.Cells[4, 0] := 'Desconto';
  sgItens.Cells[5, 0] := 'Total';
  sgItens.Cells[6, 0] := 'CFOP';
  sgItens.Cells[7, 0] := 'Grade';
  sgItens.ColWidths[0] := 60;
  sgItens.ColWidths[1] := 220;
  sgItens.ColWidths[2] := 70;
  sgItens.ColWidths[3] := 90;
  sgItens.ColWidths[4] := 70;
  sgItens.ColWidths[5] := 90;
  sgItens.ColWidths[6] := 60;
  sgItens.ColWidths[7] := 180;

  { USA_GRADE desmarcada: a coluna da grade não aparece }
  if not FUsaGrade then
  begin
    sgItens.Cells[7, 0] := '';
    sgItens.ColWidths[7] := 0;
  end;
end;

procedure TfrmPedidoVenda.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FGradeService);
end;

procedure TfrmPedidoVenda.AjustarGrades;
var
  I, LAntes: Integer;
begin
  LAntes := Length(FGrades);
  if LAntes = sgItens.RowCount then
    Exit;

  SetLength(FGrades, sgItens.RowCount);
  for I := LAntes to High(FGrades) do
    FGrades[I] := nil;
end;

function TfrmPedidoVenda.GradeDaLinha(ARow: Integer): TGradeTamanhos;
begin
  if (ARow >= 0) and (ARow < Length(FGrades)) then
    Result := FGrades[ARow]
  else
    Result := nil;
end;

procedure TfrmPedidoVenda.RemoverGradeDaLinha(ARow: Integer);
var
  I: Integer;
begin
  AjustarGrades;
  if (ARow < 1) or (ARow > High(FGrades)) then
    Exit;

  { mantém FGrades alinhado às linhas do grid }
  for I := ARow to High(FGrades) - 1 do
    FGrades[I] := FGrades[I + 1];
  if Length(FGrades) > 0 then
    SetLength(FGrades, Length(FGrades) - 1);
end;

procedure TfrmPedidoVenda.AplicarGradeNaLinha(ARow: Integer;
  const ATamanhos: TGradeTamanhos);
var
  LQtd, LVlr, LDesc, LTotal: Double;
  LResumo: string;
  I: Integer;
begin
  AjustarGrades;
  if (ARow < 1) or (ARow > High(FGrades)) then
    Exit;

  FGrades[ARow] := Copy(ATamanhos, 0, Length(ATamanhos));

  { regra do item: a quantidade é a soma das quantidades da grade }
  LQtd := SomarQuantidades(ATamanhos);
  LVlr := StrToFloatDef(sgItens.Cells[3, ARow], 0);
  LDesc := StrToFloatDef(sgItens.Cells[4, ARow], 0);
  LTotal := TotalItemPedido(LQtd, LVlr, LDesc);

  sgItens.Cells[2, ARow] := FormatFloat('#,##0.####', LQtd);
  sgItens.Cells[5, ARow] := FormatFloat('#,##0.00', LTotal);

  LResumo := '';
  for I := 0 to High(ATamanhos) do
    if ATamanhos[I].Quantidade > 0 then
      LResumo := LResumo + Format('%s:%s  ', [ATamanhos[I].Tamanho,
        FormatFloat('0.####', ATamanhos[I].Quantidade)]);
  if LResumo = '' then
    LResumo := Format('%d tamanho(s)', [Length(ATamanhos)]);
  sgItens.Cells[7, ARow] := Trim(LResumo);

  RecalcularTotais;
end;

function TfrmPedidoVenda.GradePadraoDoProduto(
  AProdutoId: Int64): TGradeTamanhos;
var
  LGradeId: Int64;
  LOrigem: TGradeTamanhos;
  I: Integer;
begin
  Result := nil;
  if (not FUsaGrade) or (AProdutoId <= 0) then
    Exit;

  LGradeId := FGradeService.GradeDoProduto(AProdutoId);
  if LGradeId <= 0 then
    Exit;

  LOrigem := FGradeService.ListarTamanhos(LGradeId);
  for I := 0 to High(LOrigem) do
    if LOrigem[I].Ativo <> 'I' then
    begin
      SetLength(Result, Length(Result) + 1);
      with Result[High(Result)] do
      begin
        Id := 0;
        Tamanho := LOrigem[I].Tamanho;
        Ordem := Length(Result) - 1;
        Quantidade := 0;
        Ativo := 'A';
      end;
    end;
end;

function TfrmPedidoVenda.EditarGrade(const ATitulo: string;
  const AEntrada: TGradeTamanhos; out ASaida: TGradeTamanhos;
  AExigirQuantidade: Boolean): Boolean;
begin
  ASaida := nil;
  with TfrmGradeQuantidades.Create(nil) do
  try
    Carregar(AEntrada, ATitulo, AExigirQuantidade);
    Result := ShowModal = mrOk;
    if Result then
      ASaida := Tamanhos;
  finally
    Free;
  end;
end;

function TfrmPedidoVenda.AbrirGradeDaLinha(ARow: Integer): Boolean;
var
  LTamanhos: TGradeTamanhos;
begin
  Result := False;
  if (ARow < 1) or (ARow > sgItens.RowCount - 1) then
  begin
    MessageDlg('Selecione um item na lista para editar a grade.',
      mtInformation, [mbOK], 0);
    Exit;
  end;

  LTamanhos := GradeDaLinha(ARow);
  if Length(LTamanhos) = 0 then
    LTamanhos := GradePadraoDoProduto(
      StrToInt64Def(sgItens.Cells[0, ARow], 0));

  if Length(LTamanhos) = 0 then
  begin
    MessageDlg('Este item não tem grade e o produto não possui grade padrão.' +
      sLineBreak + sLineBreak +
      'Defina a grade padrão em Cadastros > Produtos (campo Grade) ou ' +
      'cadastre a grade em Cadastros > Grades.',
      mtInformation, [mbOK], 0);
    Exit;
  end;

  if EditarGrade('Grade do item - ' + sgItens.Cells[1, ARow],
    LTamanhos, LTamanhos, True) then
  begin
    AplicarGradeNaLinha(ARow, LTamanhos);
    Result := True;
  end;
end;

procedure TfrmPedidoVenda.btnGradeItemClick(Sender: TObject);
begin
  if not FUsaGrade then
    Exit;
  AbrirGradeDaLinha(sgItens.Row);
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
  LPedido: TPedidoVendaService;
begin
  LPedido := TPedidoVendaService.Create;
  try
    Result := LPedido.ProximoNumero;
  finally
    LPedido.Free;
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
      'WHERE (CODIGO = :COD OR CODIGO_BARRAS = :COD OR CAST(ID AS VARCHAR(20)) = :COD) AND ATIVO = ''A'' ' +
      'AND EMPRESA_ID = :EMP';
    LQuery.ParamByName('COD').AsString := Trim(edtProduto.Text);
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
  LTamanhos, LTamPadrao: TGradeTamanhos;
begin
  if FProdutoId <= 0 then
  begin
    MessageDlg('Selecione um produto.', mtWarning, [mbOK], 0);
    Exit;
  end;

  LQtd := StrToFloatDef(edtQtd.Text, 0);
  LVlr := StrToFloatDef(edtVlrUnit.Text, 0);
  LDesc := StrToFloatDef(edtDescItem.Text, 0);
  LTotal := TotalItemPedido(LQtd, LVlr, LDesc);

  if LQtd <= 0 then
  begin
    MessageDlg('Quantidade deve ser maior que zero.', mtWarning, [mbOK], 0);
    Exit;
  end;

  { USA_GRADE: produto com grade padrão -> a quantidade do item passa a
    ser a soma das quantidades por tamanho (regra do total pela grade) }
  LTamanhos := nil;
  if FUsaGrade then
  begin
    LTamPadrao := GradePadraoDoProduto(FProdutoId);
    if Length(LTamPadrao) > 0 then
    begin
      if not EditarGrade('Grade do item - ' + lblProdutoDesc.Caption,
        LTamPadrao, LTamanhos, True) then
        Exit;
      LQtd := SomarQuantidades(LTamanhos);
      LTotal := TotalItemPedido(LQtd, LVlr, LDesc);
    end;
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
  sgItens.Cells[7, LRow] := '';

  AjustarGrades;
  if Length(LTamanhos) > 0 then
    AplicarGradeNaLinha(LRow, LTamanhos);

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

  RemoverGradeDaLinha(sgItens.Row);
  for I := sgItens.Row to sgItens.RowCount - 2 do
    sgItens.Rows[I].Assign(sgItens.Rows[I + 1]);
  sgItens.RowCount := sgItens.RowCount - 1;
  RecalcularTotais;
end;

procedure TfrmPedidoVenda.RecalcularTotais;
var
  I: Integer;
  LSub, LDesc: Double;
begin
  LSub := 0;
  for I := 1 to sgItens.RowCount - 1 do
    LSub := LSub + StrToFloatDef(sgItens.Cells[5, I], 0);

  LDesc := StrToFloatDef(edtDesconto.Text, 0);
  edtSubtotal.Text := FormatFloat('#,##0.00', LSub);
  edtTotal.Text := FormatFloat('#,##0.00', TotalDoPedidoVenda(LSub, LDesc));
end;

procedure TfrmPedidoVenda.edtDescontoExit(Sender: TObject);
begin
  RecalcularTotais;
end;

procedure TfrmPedidoVenda.btnSalvarClick(Sender: TObject);
var
  LClienteId, LFormaPagId, LCondPagId: Int64;
  LItens: TItensPedidoEntrada;
  LPedido: TPedidoVendaService;
  LNumero: string;
  I: Integer;
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

  { monta os itens do grid para o Service: a regra de total, de grade
    e de gravação fica toda no TPedidoVendaService }
  LItens := nil;
  SetLength(LItens, sgItens.RowCount - 1);
  for I := 1 to sgItens.RowCount - 1 do
  begin
    LItens[I - 1].ProdutoId := StrToInt64Def(sgItens.Cells[0, I], 0);
    LItens[I - 1].Quantidade := StrToFloatDef(sgItens.Cells[2, I], 0);
    LItens[I - 1].ValorUnitario := StrToFloatDef(sgItens.Cells[3, I], 0);
    LItens[I - 1].Desconto := StrToFloatDef(sgItens.Cells[4, I], 0);
    LItens[I - 1].Cfop := sgItens.Cells[6, I];
    LItens[I - 1].Tamanhos := GradeDaLinha(I);
  end;

  LNumero := Trim(edtNumero.Text);
  LPedido := TPedidoVendaService.Create;
  try
    try
      FPedidoId := LPedido.SalvarPedido(LClienteId, LNumero, LItens,
        StrToFloatDef(edtDesconto.Text, 0), LFormaPagId, LCondPagId,
        mmoObs.Text, 'P');
      MessageDlg('Pedido salvo com sucesso! Nº ' + LNumero,
        mtInformation, [mbOK], 0);
      LimparFormulario;
    except
      on E: Exception do
        MessageDlg('Erro ao salvar pedido: ' + E.Message, mtError, [mbOK], 0);
    end;
  finally
    LPedido.Free;
  end;
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
  SetLength(FGrades, 1);
  FGrades[0] := nil;
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
