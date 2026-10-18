unit uFrmConsumoMaterial;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Módulo 3 - Produção - Consumo de Materiais (Fase 5)

  Tela do consumo de materiais do mapa de produção:
    - gera o consumo a partir das fichas técnicas dos produtos
      concluídos (QTD_PREVISTA já inclui a perda%);
    - permite ajustar a QTD_REAL linha a linha e confirmar a
      baixa no estoque (MOVIMENTO_ESTOQUE 'S');
    - estorna a baixa (devolve ao estoque com 'E'), com motivo.

  A tela não decide nada: gerar/confirmar/estornar estão no
  TProducaoService (GerarConsumoMaterial, ConfirmarConsumo,
  EstornarConsumo). Aqui só se monta a chamada e se mostra o
  resultado. Os botões respeitam as permissões VISUALIZAR /
  INSERIR (gerar e confirmar) / EXCLUIR (estornar).
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Grids, SQLDB,
  uConexao, uSessao, uProducaoService, uPermissao;

type
  { TfrmConsumoMaterial }
  TfrmConsumoMaterial = class(TForm)
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    pnlSel: TPanel;
    lblMapa: TLabel;
    cmbMapas: TComboBox;
    btnAtualizar: TButton;
    lblConsumoTit: TLabel;
    lblConsumo: TLabel;
    pnlAcoes: TPanel;
    btnGerar: TButton;
    btnConfirmar: TButton;
    btnEstornar: TButton;
    pnlItens: TPanel;
    lblItensTitulo: TLabel;
    sgItens: TStringGrid;
    pnlRodape: TPanel;
    lblPermissao: TLabel;
    btnFechar: TButton;
    procedure btnAtualizarClick(Sender: TObject);
    procedure btnConfirmarClick(Sender: TObject);
    procedure btnEstornarClick(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
    procedure btnGerarClick(Sender: TObject);
    procedure cmbMapasChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    FConexao: TConexao;
    FService: TProducaoService;
    FMapaIds: array of Int64;
    FMapaId: Int64;
    FConsumoId: Int64;
    FConsumoStatus: string;
    FItemIds: array of Int64;
    FItemPrev: array of Double;
    FPodeGerar: Boolean;
    FPodeConfirmar: Boolean;
    FPodeEstornar: Boolean;
    procedure CarregarMapas;
    procedure CarregarConsumo;
    procedure CarregarItens;
    procedure MontarCabecalhoGrid;
    procedure AtualizarBotoes;
  end;

var
  frmConsumoMaterial: TfrmConsumoMaterial;

implementation

{$R *.lfm}

{ ------------------------------------------------------------
  Carregamento
  ------------------------------------------------------------ }

procedure TfrmConsumoMaterial.FormCreate(Sender: TObject);
begin
  FConexao := TConexao.GetInstance;
  if not FConexao.Conectado then
    FConexao.Conectar;

  FService := TProducaoService.Create;

  FMapaId := 0;
  FConsumoId := 0;
  FConsumoStatus := '';
  MontarCabecalhoGrid;
end;

procedure TfrmConsumoMaterial.MontarCabecalhoGrid;
begin
  sgItens.ColCount := 6;
  sgItens.RowCount := 2;
  sgItens.Cells[0, 0] := 'Material';
  sgItens.Cells[1, 0] := 'Qtd prevista';
  sgItens.Cells[2, 0] := 'Qtd real';
  sgItens.Cells[3, 0] := 'Custo unit.';
  sgItens.Cells[4, 0] := 'Saldo atual';
  sgItens.Cells[5, 0] := 'Movimento';
  sgItens.ColWidths[0] := 300;
  sgItens.ColWidths[1] := 95;
  sgItens.ColWidths[2] := 95;
  sgItens.ColWidths[3] := 90;
  sgItens.ColWidths[4] := 90;
  sgItens.ColWidths[5] := 110;
end;

procedure TfrmConsumoMaterial.FormShow(Sender: TObject);
begin
  if not TemPermissao(MODULO_PRODUCAO, TELA_CONSUMO, PERM_VISUALIZAR) then
  begin
    MessageDlg('Seu usuário não tem permissão para acessar o Consumo de Materiais.',
      mtError, [mbOK], 0);
    Close;
    Exit;
  end;

  FPodeGerar := TemPermissao(MODULO_PRODUCAO, TELA_CONSUMO, PERM_INSERIR);
  FPodeConfirmar := FPodeGerar;
  FPodeEstornar := TemPermissao(MODULO_PRODUCAO, TELA_CONSUMO, PERM_EXCLUIR);

  if FPodeGerar and FPodeEstornar then
    lblPermissao.Caption := ''
  else
    lblPermissao.Caption :=
      'Permissões restritas: gerar/confirmar e estornar conforme seu grupo.';

  CarregarMapas;
end;

procedure TfrmConsumoMaterial.CarregarMapas;
var
  LQry: TSQLQuery;
  LIdx: Integer;
  LAnterior: Int64;
begin
  LAnterior := FMapaId;

  cmbMapas.Items.BeginUpdate;
  try
    cmbMapas.Items.Clear;
    SetLength(FMapaIds, 0);

    LQry := TSQLQuery.Create(Self);
    try
      LQry.DataBase := FConexao.Connection;
      LQry.Transaction := FConexao.Transaction;
      LQry.SQL.Text :=
        'SELECT M.ID, M.NUMERO, M.STATUS ' +
        'FROM MAPA_PRODUCAO M ' +
        'ORDER BY M.ID DESC';
      LQry.Open;
      while not LQry.EOF do
      begin
        LIdx := Length(FMapaIds);
        SetLength(FMapaIds, LIdx + 1);
        FMapaIds[LIdx] := LQry.FieldByName('ID').AsLargeInt;
        cmbMapas.Items.Add(Format('Mapa nº %d - %s',
          [LQry.FieldByName('NUMERO').AsInteger,
           Trim(LQry.FieldByName('STATUS').AsString)]));
        LQry.Next;
      end;
    finally
      LQry.Free;
    end;
  finally
    cmbMapas.Items.EndUpdate;
  end;

  { mantém o mapa que já estava selecionado; senão, o mais recente }
  cmbMapas.ItemIndex := -1;
  if LAnterior > 0 then
    for LIdx := 0 to High(FMapaIds) do
      if FMapaIds[LIdx] = LAnterior then
      begin
        cmbMapas.ItemIndex := LIdx;
        Break;
      end;
  if cmbMapas.ItemIndex < 0 then
    if cmbMapas.Items.Count > 0 then
      cmbMapas.ItemIndex := 0;

  cmbMapasChange(Self);
end;

procedure TfrmConsumoMaterial.cmbMapasChange(Sender: TObject);
begin
  if (cmbMapas.ItemIndex >= 0) and (cmbMapas.ItemIndex <= High(FMapaIds)) then
    FMapaId := FMapaIds[cmbMapas.ItemIndex]
  else
    FMapaId := 0;

  CarregarConsumo;
end;

procedure TfrmConsumoMaterial.CarregarConsumo;
var
  LQry: TSQLQuery;
begin
  FConsumoId := 0;
  FConsumoStatus := '';

  if FMapaId > 0 then
  begin
    LQry := TSQLQuery.Create(Self);
    try
      LQry.DataBase := FConexao.Connection;
      LQry.Transaction := FConexao.Transaction;
      { o último consumo do mapa (inclusive estornado, para histórico) }
      LQry.SQL.Text :=
        'SELECT FIRST 1 C.ID, C.STATUS, C.DATA_CONSUMO, ' +
        '  C.DATA_CONFIRMACAO, C.DATA_ESTORNO ' +
        'FROM CONSUMO_MATERIAL C ' +
        'WHERE C.MAPA_PRODUCAO_ID = :MAPA ' +
        'ORDER BY C.ID DESC';
      LQry.ParamByName('MAPA').AsLargeInt := FMapaId;
      LQry.Open;
      if not LQry.IsEmpty then
      begin
        FConsumoId := LQry.FieldByName('ID').AsLargeInt;
        FConsumoStatus := Trim(LQry.FieldByName('STATUS').AsString);
        lblConsumo.Caption := Format('Consumo #%d - %s - gerado em %s',
          [FConsumoId, FConsumoStatus,
           FormatDateTime('dd/mm/yyyy',
             LQry.FieldByName('DATA_CONSUMO').AsDateTime)]);
      end
      else
        lblConsumo.Caption := 'Nenhum consumo gerado para este mapa.';
    finally
      LQry.Free;
    end;
  end
  else
    lblConsumo.Caption := 'Selecione um mapa de produção.';

  CarregarItens;
  AtualizarBotoes;
end;

procedure TfrmConsumoMaterial.CarregarItens;
var
  LQry: TSQLQuery;
  LLinha: Integer;
begin
  SetLength(FItemIds, 0);
  SetLength(FItemPrev, 0);

  sgItens.BeginUpdate;
  try
    for LLinha := 1 to sgItens.RowCount - 1 do
      sgItens.Rows[LLinha].Clear;
    sgItens.RowCount := 2;
    if FConsumoId <= 0 then
    begin
      sgItens.Cells[0, 1] := 'Sem consumo para exibir.';
      Exit;
    end;

    LQry := TSQLQuery.Create(Self);
    try
      LQry.DataBase := FConexao.Connection;
      LQry.Transaction := FConexao.Transaction;
      LQry.SQL.Text :=
        'SELECT I.ID, P.CODIGO, P.DESCRICAO, I.QTD_PREVISTA, I.QTD_REAL, ' +
        '  I.CUSTO_UNITARIO, COALESCE(E.QUANTIDADE, 0) AS SALDO, ' +
        '  I.MOVIMENTO_ESTOQUE_ID ' +
        'FROM CONSUMO_MATERIAL_ITEM I ' +
        '  JOIN PRODUTO P ON P.ID = I.MATERIAL_ID ' +
        '  LEFT JOIN ESTOQUE E ON E.PRODUTO_ID = I.MATERIAL_ID ' +
        '       AND E.EMPRESA_ID = :EMP ' +
        'WHERE I.CONSUMO_MATERIAL_ID = :CONS ' +
        'ORDER BY P.CODIGO';
      LQry.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQry.ParamByName('CONS').AsLargeInt := FConsumoId;
      LQry.Open;

      LLinha := 0;
      while not LQry.EOF do
      begin
        Inc(LLinha);
        if LLinha >= sgItens.RowCount then
          sgItens.RowCount := LLinha + 1;

        SetLength(FItemIds, LLinha);
        SetLength(FItemPrev, LLinha);
        FItemIds[LLinha - 1] := LQry.FieldByName('ID').AsLargeInt;
        FItemPrev[LLinha - 1] := LQry.FieldByName('QTD_PREVISTA').AsFloat;

        sgItens.Cells[0, LLinha] :=
          Trim(LQry.FieldByName('CODIGO').AsString) + ' - ' +
          Trim(LQry.FieldByName('DESCRICAO').AsString);
        sgItens.Cells[1, LLinha] :=
          FormatFloat('0.####', LQry.FieldByName('QTD_PREVISTA').AsFloat);
        { QTD_REAL já preenchido com o que foi baixado; quando ainda
          não há baixa, começa no valor previsto }
        if LQry.FieldByName('MOVIMENTO_ESTOQUE_ID').IsNull then
          sgItens.Cells[2, LLinha] := FormatFloat('0.####',
            LQry.FieldByName('QTD_PREVISTA').AsFloat)
        else
          sgItens.Cells[2, LLinha] := FormatFloat('0.####',
            LQry.FieldByName('QTD_REAL').AsFloat);
        sgItens.Cells[3, LLinha] :=
          FormatFloat('#,##0.00', LQry.FieldByName('CUSTO_UNITARIO').AsFloat);
        sgItens.Cells[4, LLinha] :=
          FormatFloat('0.####', LQry.FieldByName('SALDO').AsFloat);
        if LQry.FieldByName('MOVIMENTO_ESTOQUE_ID').IsNull then
          sgItens.Cells[5, LLinha] := '-'
        else
          sgItens.Cells[5, LLinha] :=
            IntToStr(LQry.FieldByName('MOVIMENTO_ESTOQUE_ID').AsLargeInt);

        LQry.Next;
      end;

      if LLinha = 0 then
        sgItens.Cells[0, 1] := 'Consumo sem itens.';
    finally
      LQry.Free;
    end;
  finally
    sgItens.EndUpdate;
  end;
end;

procedure TfrmConsumoMaterial.AtualizarBotoes;
begin
  { gerar substitui um consumo PENDENTE (ainda não movimentou estoque);
    só o CONFIRMADO trava a geração (exige estorno prévio) }
  btnGerar.Enabled := FPodeGerar and (FMapaId > 0)
    and (FConsumoStatus <> 'CONFIRMADO');
  btnConfirmar.Enabled := FPodeConfirmar and (FConsumoStatus = 'PENDENTE')
    and (Length(FItemIds) > 0);
  btnEstornar.Enabled := FPodeEstornar and (FConsumoStatus = 'CONFIRMADO')
    and (Length(FItemIds) > 0);
end;

{ ------------------------------------------------------------
  Ações
  ------------------------------------------------------------ }

procedure TfrmConsumoMaterial.btnAtualizarClick(Sender: TObject);
begin
  CarregarMapas;
end;

procedure TfrmConsumoMaterial.btnGerarClick(Sender: TObject);
var
  LJustificativa: string;
begin
  if FMapaId <= 0 then
  begin
    MessageDlg('Selecione um mapa de produção.', mtWarning, [mbOK], 0);
    Exit;
  end;

  LJustificativa := '';
  if not InputQuery('Gerar consumo de materiais',
    'Justificativa (opcional):', LJustificativa) then
    Exit;

  Screen.Cursor := crHourGlass;
  try
    try
      FService.GerarConsumoMaterial(FMapaId, LJustificativa);
      MessageDlg(
        'Consumo gerado.' + sLineBreak +
        'Ajuste as quantidades reais, se necessário, e confirme a baixa.',
        mtInformation, [mbOK], 0);
    except
      on E: Exception do
        MessageDlg('Não foi possível gerar o consumo.' + sLineBreak + E.Message,
          mtError, [mbOK], 0);
    end;
  finally
    Screen.Cursor := crDefault;
  end;

  { a transação fecha os cursores: recarrega sempre }
  CarregarConsumo;
end;

procedure TfrmConsumoMaterial.btnConfirmarClick(Sender: TObject);
var
  LItens: TItensConsumoConfirmar;
  LIndice: Integer;
  LTexto: string;
  LValor: Double;
begin
  if (FConsumoId <= 0) or (FConsumoStatus <> 'PENDENTE') then
  begin
    MessageDlg('Apenas um consumo PENDENTE pode ser confirmado.',
      mtWarning, [mbOK], 0);
    Exit;
  end;

  { monta as quantidades reais a partir da grade: célula vazia usa
    a prevista; o serviço valida de novo (não confia na tela) }
  SetLength(LItens, Length(FItemIds));
  for LIndice := 0 to High(FItemIds) do
  begin
    LTexto := Trim(sgItens.Cells[2, LIndice + 1]);
    if LTexto = '' then
      LValor := FItemPrev[LIndice]
    else
    begin
      { TryStrToFloat usa o mesmo separador do FormatFloat da grade }
      if not TryStrToFloat(LTexto, LValor) then
      begin
        MessageDlg(Format('Quantidade real inválida na linha %d: "%s".',
          [LIndice + 1, LTexto]), mtError, [mbOK], 0);
        Exit;
      end;
      if LValor <= 0 then
      begin
        MessageDlg(Format('A quantidade real da linha %d deve ser maior que zero.',
          [LIndice + 1]), mtError, [mbOK], 0);
        Exit;
      end;
    end;
    LItens[LIndice].ItemId := FItemIds[LIndice];
    LItens[LIndice].QtdReal := LValor;
  end;

  if MessageDlg(
    'Confirmar a baixa dos materiais no estoque?' + sLineBreak +
    'O movimento de saída será gerado e não poderá ser desfeito ' +
    'sem um estorno.', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;

  Screen.Cursor := crHourGlass;
  try
    try
      FService.ConfirmarConsumo(FConsumoId, LItens);
      MessageDlg('Baixa de estoque confirmada com sucesso.',
        mtInformation, [mbOK], 0);
    except
      on E: Exception do
        MessageDlg('Não foi possível confirmar a baixa.' + sLineBreak +
          E.Message, mtError, [mbOK], 0);
    end;
  finally
    Screen.Cursor := crDefault;
  end;

  CarregarConsumo;
end;

procedure TfrmConsumoMaterial.btnEstornarClick(Sender: TObject);
var
  LMotivo: string;
begin
  if (FConsumoId <= 0) or (FConsumoStatus <> 'CONFIRMADO') then
  begin
    MessageDlg('Apenas um consumo CONFIRMADO pode ser estornado.',
      mtWarning, [mbOK], 0);
    Exit;
  end;

  LMotivo := '';
  if not InputQuery('Estornar consumo de materiais',
    'Motivo do estorno (obrigatório):', LMotivo) then
    Exit;

  if Trim(LMotivo) = '' then
  begin
    MessageDlg('Informe o motivo do estorno.', mtWarning, [mbOK], 0);
    Exit;
  end;

  if MessageDlg(
    Format('Estornar o consumo #%d?' + sLineBreak +
      'Os materiais baixados voltarão para o estoque.',
      [FConsumoId]), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;

  Screen.Cursor := crHourGlass;
  try
    try
      FService.EstornarConsumo(FConsumoId, LMotivo);
      MessageDlg('Consumo estornado. Estoque devolvido.', mtInformation,
        [mbOK], 0);
    except
      on E: Exception do
        MessageDlg('Não foi possível estornar o consumo.' + sLineBreak +
          E.Message, mtError, [mbOK], 0);
    end;
  finally
    Screen.Cursor := crDefault;
  end;

  CarregarConsumo;
end;

procedure TfrmConsumoMaterial.btnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
