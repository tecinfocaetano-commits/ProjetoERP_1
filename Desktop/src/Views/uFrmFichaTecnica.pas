unit uFrmFichaTecnica;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Módulo 3 - Produção - Ficha Técnica (Fase 5)

  Cadastro da ficha técnica (BOM) do produto acabado:
    - QUANTIDADE_BASE = rendimento (quanto o produto rende);
    - cada linha diz quanto de material consome por base,
      com o percentual de perda esperado.

  Uma ficha por produto (índice único EMPRESA+PRODUTO): salvar
  substitui cabeçalho e itens de uma vez, na mesma transação
  (TProducaoService.GravarFichaTecnica faz o upsert). A tela só
  monta o array de itens e mostra o resultado.
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Grids, SQLDB,
  uConexao, uSessao, uProducaoService, uPermissao;

type
  { TfrmFichaTecnica }
  TfrmFichaTecnica = class(TForm)
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    pnlProduto: TPanel;
    lblProduto: TLabel;
    cmbProduto: TComboBox;
    btnCarregar: TButton;
    lblBase: TLabel;
    edtBase: TEdit;
    edtDescricao: TEdit;
    lblDesc: TLabel;
    pnlItem: TPanel;
    lblMaterial: TLabel;
    cmbMaterial: TComboBox;
    lblQtd: TLabel;
    edtQtd: TEdit;
    lblPerda: TLabel;
    edtPerda: TEdit;
    btnAdicionar: TButton;
    btnRemover: TButton;
    pnlItens: TPanel;
    lblItensTitulo: TLabel;
    sgItens: TStringGrid;
    pnlRodape: TPanel;
    lblPermissao: TLabel;
    btnSalvar: TButton;
    btnLimpar: TButton;
    btnFechar: TButton;
    procedure btnAdicionarClick(Sender: TObject);
    procedure btnCarregarClick(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
    procedure btnLimparClick(Sender: TObject);
    procedure btnRemoverClick(Sender: TObject);
    procedure btnSalvarClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    FConexao: TConexao;
    FService: TProducaoService;
    FProdIds: array of Int64;        { produtos no combo do produto acabado }
    FMatIds: array of Int64;         { produtos no combo de material }
    FProdutoId: Int64;               { produto selecionado (0 = novo) }
    FPodeEditar: Boolean;
    procedure CarregarProdutos;
    procedure CarregarFicha;
    procedure MontarCabecalhoGrid;
    procedure LimparTudo;
    procedure AtualizarBotoes;
    function LinhaSelecionada: Integer;
  end;

var
  frmFichaTecnica: TfrmFichaTecnica;

implementation

{$R *.lfm}

{ ------------------------------------------------------------
  Carregamento
  ------------------------------------------------------------ }

procedure TfrmFichaTecnica.FormCreate(Sender: TObject);
begin
  FConexao := TConexao.GetInstance;
  if not FConexao.Conectado then
    FConexao.Conectar;

  FService := TProducaoService.Create;
  FProdutoId := 0;

  MontarCabecalhoGrid;
  CarregarProdutos;
end;

procedure TfrmFichaTecnica.MontarCabecalhoGrid;
begin
  sgItens.ColCount := 3;
  sgItens.RowCount := 2;
  sgItens.Cells[0, 0] := 'Material';
  sgItens.Cells[1, 0] := 'Quantidade por base';
  sgItens.Cells[2, 0] := 'Perda %';
  sgItens.ColWidths[0] := 420;
  sgItens.ColWidths[1] := 170;
  sgItens.ColWidths[2] := 110;
end;

procedure TfrmFichaTecnica.CarregarProdutos;
var
  LQry: TSQLQuery;
  LIndice: Integer;
begin
  SetLength(FProdIds, 0);
  SetLength(FMatIds, 0);

  cmbProduto.Items.BeginUpdate;
  cmbMaterial.Items.BeginUpdate;
  try
    cmbProduto.Items.Clear;
    cmbMaterial.Items.Clear;

    LQry := TSQLQuery.Create(Self);
    try
      LQry.DataBase := FConexao.Connection;
      LQry.Transaction := FConexao.Transaction;
      LQry.SQL.Text :=
        'SELECT P.ID, P.CODIGO, P.DESCRICAO ' +
        'FROM PRODUTO P ' +
        'WHERE P.ATIVO = ''A'' ' +
        'ORDER BY P.CODIGO';
      LQry.Open;
      while not LQry.EOF do
      begin
        LIndice := Length(FProdIds);
        SetLength(FProdIds, LIndice + 1);
        SetLength(FMatIds, LIndice + 1);
        FProdIds[LIndice] := LQry.FieldByName('ID').AsLargeInt;
        FMatIds[LIndice] := LQry.FieldByName('ID').AsLargeInt;
        cmbProduto.Items.Add(Trim(LQry.FieldByName('CODIGO').AsString) + ' - ' +
          Trim(LQry.FieldByName('DESCRICAO').AsString));
        cmbMaterial.Items.Add(Trim(LQry.FieldByName('CODIGO').AsString) + ' - ' +
          Trim(LQry.FieldByName('DESCRICAO').AsString));
        LQry.Next;
      end;
    finally
      LQry.Free;
    end;
  finally
    cmbProduto.Items.EndUpdate;
    cmbMaterial.Items.EndUpdate;
  end;

  { combobox de produto vazio seleciona nada; o de material começa no 1º }
  cmbProduto.ItemIndex := -1;
  if cmbMaterial.Items.Count > 0 then
    cmbMaterial.ItemIndex := 0;
end;

procedure TfrmFichaTecnica.FormShow(Sender: TObject);
begin
  if not TemPermissao(MODULO_PRODUCAO, TELA_FICHA_TECNICA, PERM_VISUALIZAR) then
  begin
    MessageDlg('Seu usuário não tem permissão para acessar a Ficha Técnica.',
      mtError, [mbOK], 0);
    Close;
    Exit;
  end;

  FPodeEditar := TemPermissao(MODULO_PRODUCAO, TELA_FICHA_TECNICA, PERM_INSERIR)
    or TemPermissao(MODULO_PRODUCAO, TELA_FICHA_TECNICA, PERM_EDITAR);

  if FPodeEditar then
    lblPermissao.Caption := ''
  else
    lblPermissao.Caption :=
      'Somente consulta: seu usuário não pode alterar fichas técnicas.';

  AtualizarBotoes;

  if cmbProduto.CanFocus then
    cmbProduto.SetFocus;
end;

procedure TfrmFichaTecnica.btnCarregarClick(Sender: TObject);
begin
  if (cmbProduto.ItemIndex < 0) or (cmbProduto.ItemIndex > High(FProdIds)) then
  begin
    MessageDlg('Selecione o produto acabado.', mtWarning, [mbOK], 0);
    Exit;
  end;

  FProdutoId := FProdIds[cmbProduto.ItemIndex];
  CarregarFicha;
end;

procedure TfrmFichaTecnica.CarregarFicha;
var
  LItens: TItensFichaTecnica;
  LDescricao: string;
  LBase: Double;
  LIndice: Integer;
  LMaterial: string;
  LLinha: Integer;
begin
  if FProdutoId <= 0 then
    Exit;

  Screen.Cursor := crHourGlass;
  try
    try
      LItens := FService.FichaTecnicaDoProduto(FProdutoId, LDescricao, LBase);
    except
      on E: Exception do
      begin
        MessageDlg('Não foi possível carregar a ficha técnica.' + sLineBreak +
          E.Message, mtError, [mbOK], 0);
        Exit;
      end;
    end;
  finally
    Screen.Cursor := crDefault;
  end;

  if Length(LItens) = 0 then
  begin
    edtDescricao.Text := '';
    edtBase.Text := '1';
    MessageDlg('Este produto ainda não tem ficha técnica.' + sLineBreak +
      'Preencha a descrição, o rendimento e os materiais, e salve.',
      mtInformation, [mbOK], 0);
  end
  else
  begin
    edtDescricao.Text := LDescricao;
    edtBase.Text := FormatFloat('0.####', LBase);
  end;

  sgItens.BeginUpdate;
  try
    for LLinha := 1 to sgItens.RowCount - 1 do
      sgItens.Rows[LLinha].Clear;
    sgItens.RowCount := Length(LItens) + 1;
    if Length(LItens) = 0 then
      sgItens.RowCount := 2;

    for LIndice := 0 to High(LItens) do
    begin
      LMaterial := '';
      for LLinha := 0 to High(FMatIds) do
        if FMatIds[LLinha] = LItens[LIndice].MaterialId then
        begin
          LMaterial := cmbMaterial.Items[LLinha];
          Break;
        end;
      if LMaterial = '' then
        LMaterial := 'ID ' + IntToStr(LItens[LIndice].MaterialId);

      sgItens.Cells[0, LIndice + 1] := LMaterial;
      sgItens.Cells[1, LIndice + 1] :=
        FormatFloat('0.####', LItens[LIndice].Quantidade);
      sgItens.Cells[2, LIndice + 1] :=
        FormatFloat('0.##', LItens[LIndice].PerdaPercentual);
    end;
  finally
    sgItens.EndUpdate;
  end;
end;

procedure TfrmFichaTecnica.AtualizarBotoes;
begin
  btnSalvar.Enabled := FPodeEditar;
  btnLimpar.Enabled := FPodeEditar;
  btnAdicionar.Enabled := FPodeEditar;
  btnRemover.Enabled := FPodeEditar;
  edtBase.Enabled := FPodeEditar;
  edtDescricao.Enabled := FPodeEditar;
  edtQtd.Enabled := FPodeEditar;
  edtPerda.Enabled := FPodeEditar;
  cmbMaterial.Enabled := FPodeEditar;
end;

{ ------------------------------------------------------------
  Ações na grade
  ------------------------------------------------------------ }

function TfrmFichaTecnica.LinhaSelecionada: Integer;
begin
  Result := sgItens.Row;
  if (Result < 1) or (Result > sgItens.RowCount - 1) then
    Result := -1;
end;

procedure TfrmFichaTecnica.btnAdicionarClick(Sender: TObject);
var
  LLinha: Integer;
  LQtd, LPerda: Double;
begin
  if (cmbMaterial.ItemIndex < 0) or (cmbMaterial.ItemIndex > High(FMatIds)) then
  begin
    MessageDlg('Selecione o material.', mtWarning, [mbOK], 0);
    Exit;
  end;

  if FMatIds[cmbMaterial.ItemIndex] = FProdutoId then
  begin
    MessageDlg('A ficha técnica não pode usar o próprio produto como material.',
      mtWarning, [mbOK], 0);
    Exit;
  end;

  if not TryStrToFloat(Trim(edtQtd.Text), LQtd) or (LQtd <= 0) then
  begin
    MessageDlg('Informe a quantidade do material (maior que zero).',
      mtWarning, [mbOK], 0);
    edtQtd.SetFocus;
    Exit;
  end;

  if Trim(edtPerda.Text) = '' then
    LPerda := 0
  else if not TryStrToFloat(Trim(edtPerda.Text), LPerda) or (LPerda < 0) then
  begin
    MessageDlg('Percentual de perda inválido (use valor maior ou igual a zero).',
      mtWarning, [mbOK], 0);
    edtPerda.SetFocus;
    Exit;
  end;

  { material repetido: soma na linha existente, evita BOM duplicado }
  for LLinha := 1 to sgItens.RowCount - 1 do
    if sgItens.Cells[0, LLinha] = cmbMaterial.Items[cmbMaterial.ItemIndex] then
    begin
      LQtd := LQtd + StrToFloatDef(sgItens.Cells[1, LLinha], 0);
      sgItens.Cells[1, LLinha] := FormatFloat('0.####', LQtd);
      sgItens.Cells[2, LLinha] := FormatFloat('0.##', LPerda);
      Exit;
    end;

  LLinha := sgItens.RowCount;
  if (LLinha = 2) and (Trim(sgItens.Cells[0, 1]) = '') then
    LLinha := 1
  else
    sgItens.RowCount := LLinha + 1;

  sgItens.Cells[0, LLinha] := cmbMaterial.Items[cmbMaterial.ItemIndex];
  sgItens.Cells[1, LLinha] := FormatFloat('0.####', LQtd);
  sgItens.Cells[2, LLinha] := FormatFloat('0.##', LPerda);

  edtQtd.Clear;
  edtPerda.Text := '0';
  if cmbMaterial.CanFocus then
    cmbMaterial.SetFocus;
end;

procedure TfrmFichaTecnica.btnRemoverClick(Sender: TObject);
var
  LLinha: Integer;
begin
  LLinha := LinhaSelecionada;
  if LLinha < 0 then
  begin
    MessageDlg('Selecione o material a remover na grade.', mtWarning,
      [mbOK], 0);
    Exit;
  end;

  sgItens.Rows[LLinha].Clear;
  if LLinha < sgItens.RowCount - 1 then
    sgItens.DeleteRow(LLinha)
  else
  begin
    sgItens.RowCount := sgItens.RowCount - 1;
    if sgItens.RowCount < 2 then
      sgItens.RowCount := 2;
  end;
end;

{ ------------------------------------------------------------
  Salvar / limpar
  ------------------------------------------------------------ }

procedure TfrmFichaTecnica.btnSalvarClick(Sender: TObject);
var
  LItens: TItensFichaTecnica;
  LBase: Double;
  LLinha, LTotal: Integer;
  LQtd, LPerda: Double;
  LFichaId: Int64;
  LMaterialId: Int64;
  LIndice: Integer;
  LDuplicado: Boolean;
begin
  if (cmbProduto.ItemIndex < 0) or (cmbProduto.ItemIndex > High(FProdIds)) then
  begin
    MessageDlg('Selecione o produto acabado.', mtWarning, [mbOK], 0);
    Exit;
  end;
  FProdutoId := FProdIds[cmbProduto.ItemIndex];

  if not TryStrToFloat(Trim(edtBase.Text), LBase) or (LBase <= 0) then
  begin
    MessageDlg('Informe o rendimento (QUANTIDADE BASE) maior que zero.',
      mtWarning, [mbOK], 0);
    edtBase.SetFocus;
    Exit;
  end;

  { monta os itens a partir da grade, validando linha a linha }
  SetLength(LItens, 0);
  LTotal := 0;
  for LLinha := 1 to sgItens.RowCount - 1 do
  begin
    if Trim(sgItens.Cells[0, LLinha]) = '' then
      Continue;

    LMaterialId := 0;
    for LIndice := 0 to High(FMatIds) do
      if cmbMaterial.Items[LIndice] = sgItens.Cells[0, LLinha] then
      begin
        LMaterialId := FMatIds[LIndice];
        Break;
      end;
    if LMaterialId = 0 then
    begin
      MessageDlg(Format('Material inválido na linha %d: %s',
        [LLinha, sgItens.Cells[0, LLinha]]), mtError, [mbOK], 0);
      Exit;
    end;

    if not TryStrToFloat(Trim(sgItens.Cells[1, LLinha]), LQtd) or (LQtd <= 0) then
    begin
      MessageDlg(Format('Quantidade inválida na linha %d.', [LLinha]),
        mtError, [mbOK], 0);
      Exit;
    end;

    if Trim(sgItens.Cells[2, LLinha]) = '' then
      LPerda := 0
    else if not TryStrToFloat(Trim(sgItens.Cells[2, LLinha]), LPerda)
      or (LPerda < 0) then
    begin
      MessageDlg(Format('Perda inválida na linha %d.', [LLinha]),
        mtError, [mbOK], 0);
      Exit;
    end;

    { reforça a unicidade do material (a grade já agrupa, mas não
      confia na tela ) }
    LDuplicado := False;
    for LIndice := 0 to High(LItens) do
      if LItens[LIndice].MaterialId = LMaterialId then
      begin
        LDuplicado := True;
        Break;
      end;
    if LDuplicado then
    begin
      MessageDlg(Format('Material repetido na linha %d.', [LLinha]),
        mtError, [mbOK], 0);
      Exit;
    end;

    Inc(LTotal);
    SetLength(LItens, LTotal);
    LItens[LTotal - 1].MaterialId := LMaterialId;
    LItens[LTotal - 1].Quantidade := LQtd;
    LItens[LTotal - 1].PerdaPercentual := LPerda;
  end;

  if Length(LItens) = 0 then
  begin
    MessageDlg('Adicione ao menos um material à ficha técnica.',
      mtWarning, [mbOK], 0);
    Exit;
  end;

  if MessageDlg(
    'Salvar a ficha técnica deste produto?' + sLineBreak +
    'Os itens atuais serão substituídos pelos da grade.',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;

  Screen.Cursor := crHourGlass;
  try
    try
      LFichaId := FService.GravarFichaTecnica(FProdutoId,
        Trim(edtDescricao.Text), LBase, LItens);
      MessageDlg(Format('Ficha técnica #%d salva com %d material(is).',
        [LFichaId, Length(LItens)]), mtInformation, [mbOK], 0);
    except
      on E: Exception do
        MessageDlg('Não foi possível salvar a ficha técnica.' + sLineBreak +
          E.Message, mtError, [mbOK], 0);
    end;
  finally
    Screen.Cursor := crDefault;
  end;

  { recarrega do banco: mostra o que ficou gravado de fato }
  CarregarFicha;
end;

procedure TfrmFichaTecnica.btnLimparClick(Sender: TObject);
begin
  if MessageDlg('Limpar a ficha técnica da tela (sem gravar)?',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  LimparTudo;
end;

procedure TfrmFichaTecnica.LimparTudo;
var
  LLinha: Integer;
begin
  FProdutoId := 0;
  cmbProduto.ItemIndex := -1;
  edtDescricao.Text := '';
  edtBase.Text := '1';
  edtQtd.Clear;
  edtPerda.Text := '0';
  for LLinha := 1 to sgItens.RowCount - 1 do
    sgItens.Rows[LLinha].Clear;
  sgItens.RowCount := 2;
end;

procedure TfrmFichaTecnica.btnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
