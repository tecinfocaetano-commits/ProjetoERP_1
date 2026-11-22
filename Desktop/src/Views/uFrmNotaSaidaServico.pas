unit uFrmNotaSaidaServico;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Marco 3.93
  Tela resumida de nota de serviço (NFS-e nacional 1.01).

  O documento não nasce de pedido, não movimenta estoque e não
  gera conta a receber: ele apenas registra os dados resumidos do
  serviço, gera/valida a DPS localmente e permite cancelamento.
  A senha do certificado é usada somente em memória e nunca é gravada.

  Regras de negócio, transação e auditoria ficam em
  TNotaSaidaServicoService; aqui só há digitação e listagem.
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Buttons, Grids, SQLDB, uConexao, uSessao, uConfiguracaoService,
  uNotaSaidaServicoService, uPermissao, uPermissaoUI;

type
  { TfrmNotaSaidaServico }
  TfrmNotaSaidaServico = class(TForm)
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    lblModo: TLabel;
    pnlCadastro: TPanel;
    lblMunicipio: TLabel;
    edtMunicipio: TEdit;
    lblCodigoServico: TLabel;
    edtCodigoServico: TEdit;
    lblDescricao: TLabel;
    edtDescricao: TEdit;
    lblValor: TLabel;
    edtValor: TEdit;
    lblDesconto: TLabel;
    edtDesconto: TEdit;
    lblAliquota: TLabel;
    edtAliquota: TEdit;
    lblRetencao: TLabel;
    cboRetencao: TComboBox;
    lblTomador: TLabel;
    cboTomador: TComboBox;
    lblSenha: TLabel;
    edtSenhaCertificado: TEdit;
    lblRetPis: TLabel;
    edtRetPis: TEdit;
    lblRetCofins: TLabel;
    edtRetCofins: TEdit;
    lblRetInss: TLabel;
    edtRetInss: TEdit;
    lblAviso: TLabel;
    gridNotas: TStringGrid;
    pnlBotoes: TPanel;
    btnNovo: TBitBtn;
    btnGravar: TBitBtn;
    btnGerarXML: TBitBtn;
    btnCancelarNota: TBitBtn;
    btnAtualizar: TBitBtn;
    btnFechar: TBitBtn;
    lblSelecionada: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnNovoClick(Sender: TObject);
    procedure btnGravarClick(Sender: TObject);
    procedure btnGerarXMLClick(Sender: TObject);
    procedure btnCancelarNotaClick(Sender: TObject);
    procedure btnAtualizarClick(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
    procedure gridNotasSelectCell(Sender: TObject; aCol, aRow: Integer;
      var CanSelect: Boolean);
  private
    FConexao: TConexao;
    FQuery: TSQLQuery;
    FService: TNotaSaidaServicoService;
    FIds: array of Int64;
    FTomadorIds: array of Int64;
    FNotaId: Int64;
    function Numero(const ATexto: string): Double;
    procedure CarregarModo;
    procedure CarregarTomadores;
    procedure CarregarNotas;
    procedure LimparCampos;
    procedure SelecionarNota(ARow: Integer);
  end;

var
  frmNotaSaidaServico: TfrmNotaSaidaServico;

implementation

{$R *.lfm}

{ TfrmNotaSaidaServico }

function TfrmNotaSaidaServico.Numero(const ATexto: string): Double;
var
  LTexto: string;
  LFS: TFormatSettings;
begin
  LTexto := Trim(ATexto);
  if (Pos(',', LTexto) > 0) and (Pos('.', LTexto) > 0) then
  begin
    if Pos(',', LTexto) > Pos('.', LTexto) then
    begin
      LTexto := StringReplace(LTexto, '.', '', [rfReplaceAll]);
      LTexto := StringReplace(LTexto, ',', '.', [rfReplaceAll]);
    end
    else
      LTexto := StringReplace(LTexto, ',', '', [rfReplaceAll]);
  end
  else if Pos(',', LTexto) > 0 then
    LTexto := StringReplace(LTexto, ',', '.', [rfReplaceAll]);

  LFS := DefaultFormatSettings;
  LFS.DecimalSeparator := '.';
  LFS.ThousandSeparator := ',';
  Result := StrToFloatDef(LTexto, 0, LFS);
end;

procedure TfrmNotaSaidaServico.FormCreate(Sender: TObject);
begin
  FConexao := TConexao.GetInstance;
  if not FConexao.Conectado then
    FConexao.Conectar;

  FQuery := TSQLQuery.Create(Self);
  FQuery.DataBase := FConexao.Connection;
  FQuery.Transaction := FConexao.Transaction;
  FService := TNotaSaidaServicoService.Create;

  gridNotas.ColCount := 7;
  gridNotas.FixedCols := 0;
  gridNotas.FixedRows := 1;
  gridNotas.RowCount := 1;
  gridNotas.Cells[0, 0] := 'ID';
  gridNotas.Cells[1, 0] := 'Série';
  gridNotas.Cells[2, 0] := 'Número';
  gridNotas.Cells[3, 0] := 'Descrição do serviço';
  gridNotas.Cells[4, 0] := 'Valor';
  gridNotas.Cells[5, 0] := 'Situação';
  gridNotas.Cells[6, 0] := 'XML';
  gridNotas.ColWidths[0] := 60;
  gridNotas.ColWidths[1] := 70;
  gridNotas.ColWidths[2] := 80;
  gridNotas.ColWidths[3] := 420;
  gridNotas.ColWidths[4] := 110;
  gridNotas.ColWidths[5] := 110;
  gridNotas.ColWidths[6] := 240;

  cboRetencao.Items.Clear;
  cboRetencao.Items.Add('1 - Sem retenção de ISS');
  cboRetencao.Items.Add('2 - ISS retido pelo tomador');
  cboRetencao.Items.Add('3 - ISS retido por substituição');

  CarregarModo;
  CarregarTomadores;
  LimparCampos;
  CarregarNotas;
end;

procedure TfrmNotaSaidaServico.FormShow(Sender: TObject);
begin
  AplicarPermissaoAcao(Self, PERM_INSERIR, ['btnNovo', 'btnGravar']);
  AplicarPermissaoAcao(Self, PERM_EDITAR,
    ['btnGerarXML', 'btnCancelarNota']);
end;

procedure TfrmNotaSaidaServico.CarregarModo;
var
  LCfg: TConfiguracaoService;
  LModo: string;
begin
  LCfg := TConfiguracaoService.Create;
  try
    LModo := UpperCase(Trim(LCfg.LerValor('NFSE_MODO')));
  finally
    LCfg.Free;
  end;
  if LModo = '' then
    LModo := 'SIMULADO';
  if LModo = 'REAL' then
    lblModo.Caption := 'Modo REAL: requer certificado A1; nenhum envio automático.'
  else
    lblModo.Caption := 'Modo SIMULADO: gera e valida localmente, sem envio.';
end;

procedure TfrmNotaSaidaServico.CarregarTomadores;
var
  LQuery: TSQLQuery;
  LIndice: Integer;
begin
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT ID, NOME FROM PESSOA ' +
      'WHERE EMPRESA_ID = :EMP AND ATIVO = ''A'' ORDER BY NOME';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;

    cboTomador.Items.Clear;
    SetLength(FTomadorIds, 1);
    FTomadorIds[0] := 0;
    cboTomador.Items.Add('(sem tomador)');
    while not LQuery.EOF do
    begin
      LIndice := cboTomador.Items.Add(
        IntToStr(LQuery.FieldByName('ID').AsLargeInt) + ' - ' +
        LQuery.FieldByName('NOME').AsString);
      SetLength(FTomadorIds, LIndice + 1);
      FTomadorIds[LIndice] := LQuery.FieldByName('ID').AsLargeInt;
      LQuery.Next;
    end;
    cboTomador.ItemIndex := 0;
  finally
    LQuery.Free;
  end;
end;

procedure TfrmNotaSaidaServico.CarregarNotas;
var
  LLinha: Integer;
begin
  FQuery.Close;
  FQuery.SQL.Text :=
    'SELECT ID, SERIE, NUMERO, DESCRICAO_SERVICO, VALOR_SERVICO, ' +
    '  SITUACAO, COALESCE(XML_ARQUIVO, '''') AS XML_ARQUIVO ' +
    'FROM NOTA_SAIDA_SERVICO WHERE EMPRESA_ID = :EMP ORDER BY ID DESC';
  FQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
  FQuery.Open;

  SetLength(FIds, 0);
  gridNotas.RowCount := 1;
  LLinha := 1;
  while not FQuery.EOF do
  begin
    gridNotas.RowCount := LLinha + 1;
    gridNotas.Cells[0, LLinha] := FQuery.FieldByName('ID').AsString;
    gridNotas.Cells[1, LLinha] := FQuery.FieldByName('SERIE').AsString;
    gridNotas.Cells[2, LLinha] := FQuery.FieldByName('NUMERO').AsString;
    gridNotas.Cells[3, LLinha] :=
      FQuery.FieldByName('DESCRICAO_SERVICO').AsString;
    gridNotas.Cells[4, LLinha] := FloatToStrF(
      FQuery.FieldByName('VALOR_SERVICO').AsFloat, ffNumber, 15, 2);
    gridNotas.Cells[5, LLinha] := FQuery.FieldByName('SITUACAO').AsString;
    gridNotas.Cells[6, LLinha] := FQuery.FieldByName('XML_ARQUIVO').AsString;
    SetLength(FIds, LLinha);
    FIds[LLinha - 1] := FQuery.FieldByName('ID').AsLargeInt;
    Inc(LLinha);
    FQuery.Next;
  end;
  FNotaId := 0;
  lblSelecionada.Caption := 'Nenhuma nota selecionada';
end;

procedure TfrmNotaSaidaServico.LimparCampos;
begin
  FNotaId := 0;
  edtMunicipio.Clear;
  edtCodigoServico.Text := '010101';
  edtDescricao.Clear;
  edtValor.Text := '0';
  edtDesconto.Text := '0';
  edtAliquota.Text := '2';
  cboRetencao.ItemIndex := 0;
  if cboTomador.Items.Count > 0 then
    cboTomador.ItemIndex := 0;
  edtSenhaCertificado.Clear;
  edtRetPis.Text := '0';
  edtRetCofins.Text := '0';
  edtRetInss.Text := '0';
  lblSelecionada.Caption := 'Nenhuma nota selecionada';
end;

procedure TfrmNotaSaidaServico.SelecionarNota(ARow: Integer);
begin
  if (ARow <= 0) or (ARow > Length(FIds)) then
    Exit;
  FNotaId := FIds[ARow - 1];
  lblSelecionada.Caption := 'Selecionada: ' + gridNotas.Cells[1, ARow] +
    '/' + gridNotas.Cells[2, ARow] + '  ' + gridNotas.Cells[5, ARow];
end;

procedure TfrmNotaSaidaServico.btnNovoClick(Sender: TObject);
begin
  LimparCampos;
end;

procedure TfrmNotaSaidaServico.btnGravarClick(Sender: TObject);
var
  LId: Int64;
  LTipoRet: string;
  LTomadorId: Int64;
begin
  LTipoRet := Copy(cboRetencao.Text, 1, 1);
  if LTipoRet = '' then
    LTipoRet := '1';
  LTomadorId := 0;
  if (cboTomador.ItemIndex >= 0) and
     (cboTomador.ItemIndex <= High(FTomadorIds)) then
    LTomadorId := FTomadorIds[cboTomador.ItemIndex];
  try
    LId := FService.Criar(
      edtMunicipio.Text, edtCodigoServico.Text, edtDescricao.Text,
      Numero(edtValor.Text), Numero(edtDesconto.Text), Numero(edtAliquota.Text),
      LTipoRet, LTomadorId, Numero(edtRetPis.Text),
      Numero(edtRetCofins.Text), Numero(edtRetInss.Text));
    MessageDlg('Nota de serviço ' + IntToStr(LId) +
      ' gravada como GERADA.' + #13#10 +
      'Use "Gerar XML" para validar a DPS localmente.',
      mtInformation, [mbOK], 0);
    LimparCampos;
    CarregarNotas;
  except
    on E: Exception do
      MessageDlg('Não foi possível gravar a nota de serviço:' + #13#10 +
        E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmNotaSaidaServico.btnGerarXMLClick(Sender: TObject);
var
  LXml, LCaminho, LMensagem: string;
begin
  if FNotaId <= 0 then
  begin
    MessageDlg('Selecione uma nota na lista antes de gerar o XML.',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  try
    if FService.GerarXML(FNotaId, edtSenhaCertificado.Text,
      LXml, LCaminho, LMensagem) then
    begin
      MessageDlg('DPS gerada/validada com sucesso.' + #13#10 +
        'Arquivo: ' + LCaminho + #13#10 + LMensagem,
        mtInformation, [mbOK], 0);
      edtSenhaCertificado.Clear;
    end
    else
      MessageDlg('A DPS não passou na validação:' + #13#10 + LMensagem,
        mtWarning, [mbOK], 0);
    CarregarNotas;
  except
    on E: Exception do
      MessageDlg('Não foi possível gerar o XML:' + #13#10 + E.Message,
        mtError, [mbOK], 0);
  end;
end;

procedure TfrmNotaSaidaServico.btnCancelarNotaClick(Sender: TObject);
begin
  if FNotaId <= 0 then
  begin
    MessageDlg('Selecione uma nota na lista antes de cancelar.',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  if MessageDlg('Cancelar a nota de serviço selecionada?',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  try
    if FService.Cancelar(FNotaId, 'Cancelamento solicitado na tela') then
      MessageDlg('Nota de serviço cancelada.', mtInformation, [mbOK], 0)
    else
      MessageDlg('A nota já estava cancelada ou não foi encontrada.',
        mtWarning, [mbOK], 0);
    CarregarNotas;
  except
    on E: Exception do
      MessageDlg('Não foi possível cancelar a nota:' + #13#10 + E.Message,
        mtError, [mbOK], 0);
  end;
end;

procedure TfrmNotaSaidaServico.btnAtualizarClick(Sender: TObject);
begin
  CarregarNotas;
end;

procedure TfrmNotaSaidaServico.btnFecharClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmNotaSaidaServico.gridNotasSelectCell(Sender: TObject; aCol,
  aRow: Integer; var CanSelect: Boolean);
begin
  SelecionarNota(aRow);
end;

end.
