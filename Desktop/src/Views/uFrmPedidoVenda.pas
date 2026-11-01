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
  uConexao, uSessao, uGrade, uGradeService, uFrmGradeQuantidades;

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
  LTotal := (LQtd * LVlr) - LDesc;
  if LTotal < 0 then
    LTotal := 0;

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
  LNum, LMax: Integer;
begin
  LMax := 0;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    // NUMERO é VARCHAR no banco; ignorar valores não numéricos
    LQuery.SQL.Text := 'SELECT NUMERO FROM PEDIDO_VENDA';
    LQuery.Open;
    while not LQuery.EOF do
    begin
      LNum := StrToIntDef(Trim(LQuery.FieldByName('NUMERO').AsString), 0);
      if LNum > LMax then
        LMax := LNum;
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
  Result := LMax + 1;
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
  LTotal := (LQtd * LVlr) - LDesc;

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
      LTotal := (LQtd * LVlr) - LDesc;
      if LTotal < 0 then
        LTotal := 0;
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
  LItemId: Int64;
  LTamanhos: TGradeTamanhos;
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

      { grade efetiva do item: entra na MESMA transação do pedido }
      if FUsaGrade then
      begin
        LTamanhos := GradeDaLinha(I);
        if Length(LTamanhos) > 0 then
        begin
          LQuery.Close;
          LQuery.SQL.Text :=
            'SELECT GEN_ID(GEN_ITEM_PEDIDO_ID, 0) AS ID FROM RDB$DATABASE';
          LQuery.Open;
          LItemId := LQuery.FieldByName('ID').AsLargeInt;
          LQuery.Close;
          FGradeService.SalvarGradeItemPedido(LItemId, LTamanhos);
        end;
      end;
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
