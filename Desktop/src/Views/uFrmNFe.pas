unit uFrmNFe;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 6 - Emissão de NF-e
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, DateUtils,
  uConexao, uSessao, uACBrHelper, uPedidoStatus;

type
  TfrmNFe = class(TForm)
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    pnlFiltro: TPanel;
    lblDataInicio: TLabel;
    edtDataInicio: TEdit;
    lblDataFim: TLabel;
    edtDataFim: TEdit;
    btnFiltrar: TBitBtn;
    pnlBotoes: TPanel;
    btnEmitirNFe: TBitBtn;
    btnValidar: TBitBtn;
    btnConsultar: TBitBtn;
    btnCancelar: TBitBtn;
    btnImportarXML: TBitBtn;
    btnFechar: TBitBtn;
    pnlConfig: TPanel;
    lblAmbiente: TLabel;
    cmbAmbiente: TComboBox;
    lblCertificado: TLabel;
    edtCertificado: TEdit;
    btnSelecionarCert: TBitBtn;
    chkSimulado: TCheckBox;
    dbGrid: TDBGrid;
    DataSource1: TDataSource;
    OpenDialog1: TOpenDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnFiltrarClick(Sender: TObject);
    procedure btnEmitirNFeClick(Sender: TObject);
    procedure btnValidarClick(Sender: TObject);
    procedure btnConsultarClick(Sender: TObject);
    procedure btnCancelarClick(Sender: TObject);
    procedure btnImportarXMLClick(Sender: TObject);
    procedure btnSelecionarCertClick(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
  private
    FConexao: TConexao;
    FQuery: TSQLQuery;
    FACBr: TACBrHelper;
    FUF: string;
    procedure CarregarPedidos;
    procedure ConfigurarACBrReal(const ASenha: string);
    function StatusNFeTexto(AStatus: TACBrStatusNFe): string;
  end;

var
  frmNFe: TfrmNFe;

implementation

{$R *.lfm}

procedure TfrmNFe.FormCreate(Sender: TObject);
var
  LBase: string;
begin
  FConexao := TConexao.GetInstance;
  // Iniciar conexão com o banco
  if not FConexao.Conectado then
    FConexao.Conectar;
  FQuery := TSQLQuery.Create(Self);
  FQuery.DataBase := FConexao.Connection;
  FQuery.Transaction := FConexao.Transaction;

  // Criar DataSource1 se não existir
  if DataSource1 = nil then
    DataSource1 := TDataSource.Create(Self);

  FACBr := TACBrHelper.Create;

  // UF do emitente define o serviço da SEFAZ
  FUF := 'SP';
  FQuery.Close;
  FQuery.SQL.Text := 'SELECT UF FROM EMPRESA WHERE ID = :EMP';
  FQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
  FQuery.Open;
  if (not FQuery.IsEmpty) and
     (Trim(FQuery.FieldByName('UF').AsString) <> '') then
    FUF := Trim(FQuery.FieldByName('UF').AsString);
  FQuery.Close;

  LBase := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName));
  FACBr.CaminhoSchemas := LBase + 'schemas';
  FACBr.CaminhoSalvar := LBase + 'nfe';
  FACBr.ModoSimulado := chkSimulado.Checked;

  edtDataInicio.Text := FormatDateTime('dd/mm/yyyy', IncMonth(Now, -1));
  edtDataFim.Text := FormatDateTime('dd/mm/yyyy', Now);
  cmbAmbiente.ItemIndex := 1; // Homologação
  CarregarPedidos;
end;

procedure TfrmNFe.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FACBr);
end;

procedure TfrmNFe.ConfigurarACBrReal(const ASenha: string);
begin
  FACBr.ModoSimulado := False;
  FACBr.CaminhoSchemas := IncludeTrailingPathDelimiter(
    ExtractFilePath(Application.ExeName)) + 'schemas';
  FACBr.CaminhoSalvar := IncludeTrailingPathDelimiter(
    ExtractFilePath(Application.ExeName)) + 'nfe';
  FACBr.Configurar(edtCertificado.Text, ASenha, FUF,
    cmbAmbiente.ItemIndex + 1);
end;

function TfrmNFe.StatusNFeTexto(AStatus: TACBrStatusNFe): string;
begin
  case AStatus of
    ansAutorizada: Result := 'autorizada';
    ansCancelada: Result := 'cancelada';
    ansDenegada: Result := 'denegada';
    ansPendente: Result := 'pendente';
  else
    Result := 'não emitida';
  end;
end;

procedure TfrmNFe.CarregarPedidos;
begin
  if FQuery.Active then
    FQuery.Close;
  FQuery.SQL.Text :=
    'SELECT PV.ID, PV.NUMERO, C.NOME AS CLIENTE, PV.TOTAL, ' +
    'PV.DATA_EMISSAO, PV.NUMERO_NFE, PV.CHAVE_NFE, ' +
    SqlCaseStatusPedido('PV.STATUS') + ' AS STATUS ' +
    'FROM PEDIDO_VENDA PV ' +
    'LEFT JOIN PESSOA C ON C.ID = PV.CLIENTE_ID AND C.TIPO = ''C'' ' +
    'WHERE PV.EMPRESA_ID = :EMP ' +
    'AND PV.DATA_EMISSAO BETWEEN :DI AND :DF ' +
    'AND PV.STATUS <> ''O'' ' +
    'ORDER BY PV.NUMERO DESC';
  FQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
  FQuery.ParamByName('DI').AsDate := StrToDateDef(edtDataInicio.Text, Now);
  FQuery.ParamByName('DF').AsDate := StrToDateDef(edtDataFim.Text, Now) + 1;
  FQuery.Open;
  DataSource1.DataSet := FQuery;
end;

procedure TfrmNFe.btnEmitirNFeClick(Sender: TObject);
var
  LDados: TACBrDadosNFe;
  LSenha, LMensagem: string;
begin
  if FQuery.IsEmpty then Exit;

  try
    if chkSimulado.Checked then
    begin
      if Trim(edtCertificado.Text) <> '' then
        FACBr.Configurar(edtCertificado.Text, 'simulado', FUF,
          cmbAmbiente.ItemIndex + 1)
      else
        FACBr.Configurar('simulado.pfx', 'simulado', FUF,
          cmbAmbiente.ItemIndex + 1);
      FACBr.ModoSimulado := True;
    end
    else
    begin
      if Trim(edtCertificado.Text) = '' then
      begin
        MessageDlg('Selecione o certificado digital A1 (.pfx/.p12).',
          mtWarning, [mbOK], 0);
        Exit;
      end;
      if not InputQuery('Certificado digital', 'Senha do certificado:',
        LSenha) then
        Exit;
      ConfigurarACBrReal(LSenha);
    end;

    LDados := FACBr.GerarNFe(FQuery.FieldByName('ID').AsLargeInt);

    LMensagem :=
      'NF-e ' + StatusNFeTexto(LDados.Status) + '!' + #13#10 +
      'Número: ' + IntToStr(LDados.Numero) + #13#10 +
      'Série: ' + IntToStr(LDados.Serie) + #13#10 +
      'Chave: ' + LDados.ChaveAcesso + #13#10 +
      'Protocolo: ' + LDados.Protocolo;
    if LDados.NotaSaidaId > 0 then
      LMensagem := LMensagem + #13#10 +
        'Nota de saída: ' + IntToStr(LDados.NotaSaidaId) +
        ' (estoque e contas a receber gerados)';
    if LDados.Motivo <> '' then
      LMensagem := LMensagem + #13#10 + 'Retorno: ' + LDados.Motivo;

    MessageDlg(LMensagem, mtInformation, [mbOK], 0);
    CarregarPedidos;
  except
    on E: Exception do
      MessageDlg('Erro: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmNFe.btnValidarClick(Sender: TObject);
var
  LDados: TACBrDadosNFe;
  LSenha: string;
begin
  if FQuery.IsEmpty then
    Exit;

  if Trim(edtCertificado.Text) = '' then
  begin
    MessageDlg(
      'Selecione um certificado (.pfx/.p12) para validar o XML completo.' +
      #13#10 + 'Um certificado autoassinado de teste serve: nada será ' +
      'enviado à SEFAZ.',
      mtWarning, [mbOK], 0);
    Exit;
  end;

  if not InputQuery('Validação local da NF-e', 'Senha do certificado:',
    LSenha) then
    Exit;

  try
    ConfigurarACBrReal(LSenha);
    LDados := FACBr.ValidarNFe(FQuery.FieldByName('ID').AsLargeInt);

    MessageDlg(
      'XML da NF-e válido!' + #13#10 +
      'Número: ' + IntToStr(LDados.Numero) + #13#10 +
      'Série: ' + IntToStr(LDados.Serie) + #13#10 +
      'Chave: ' + LDados.ChaveAcesso + #13#10#13#10 +
      'Nada foi enviado à SEFAZ. O XML está em bin\nfe.',
      mtInformation, [mbOK], 0);
  except
    on E: Exception do
      MessageDlg('Validação falhou: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmNFe.btnConsultarClick(Sender: TObject);
var
  LChave, LSenha: string;
  LDados: TACBrDadosNFe;
begin
  if FQuery.IsEmpty then Exit;
  LChave := Trim(FQuery.FieldByName('CHAVE_NFE').AsString);
  if LChave = '' then
  begin
    MessageDlg('Este pedido não possui NF-e emitida.', mtWarning, [mbOK], 0);
    Exit;
  end;

  if chkSimulado.Checked then
  begin
    MessageDlg('Consulta simulada.' + #13#10 + 'Chave: ' + LChave,
      mtInformation, [mbOK], 0);
    Exit;
  end;

  if Trim(edtCertificado.Text) = '' then
  begin
    MessageDlg('Selecione o certificado digital A1 (.pfx/.p12).',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  if not InputQuery('Certificado digital', 'Senha do certificado:', LSenha) then
    Exit;

  try
    ConfigurarACBrReal(LSenha);
    LDados := FACBr.ConsultarNFe(LChave);
    MessageDlg(
      'Consulta da NF-e' + #13#10 +
      'Chave: ' + LDados.ChaveAcesso + #13#10 +
      'Situação: ' + StatusNFeTexto(LDados.Status) + #13#10 +
      'cStat: ' + IntToStr(LDados.cStat) + #13#10 +
      'Protocolo: ' + LDados.Protocolo + #13#10 +
      'Motivo: ' + LDados.Motivo,
      mtInformation, [mbOK], 0);
  except
    on E: Exception do
      MessageDlg('Erro: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmNFe.btnCancelarClick(Sender: TObject);
var
  LJust, LChave, LSenha: string;
begin
  if FQuery.IsEmpty then Exit;
  LChave := Trim(FQuery.FieldByName('CHAVE_NFE').AsString);
  if LChave = '' then
  begin
    MessageDlg('NF-e não emitida para este pedido.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if not InputQuery('Cancelar NF-e', 'Justificativa (mín. 15 caracteres):',
    LJust) then
    Exit;
  if Length(Trim(LJust)) < 15 then
  begin
    MessageDlg('Justificativa deve ter no mínimo 15 caracteres.',
      mtWarning, [mbOK], 0);
    Exit;
  end;

  if chkSimulado.Checked then
  begin
    MessageDlg('Cancelamento simulado (não enviado à SEFAZ).',
      mtInformation, [mbOK], 0);
    Exit;
  end;

  if Trim(edtCertificado.Text) = '' then
  begin
    MessageDlg('Selecione o certificado digital A1 (.pfx/.p12).',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  if not InputQuery('Certificado digital', 'Senha do certificado:', LSenha) then
    Exit;

  try
    ConfigurarACBrReal(LSenha);
    if FACBr.CancelarNFe(LChave, LJust) then
      MessageDlg('Cancelamento homologado pela SEFAZ.',
        mtInformation, [mbOK], 0)
    else
      MessageDlg('Cancelamento não confirmado pela SEFAZ.',
        mtWarning, [mbOK], 0);
    CarregarPedidos;
  except
    on E: Exception do
      MessageDlg('Erro: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmNFe.btnImportarXMLClick(Sender: TObject);
begin
  OpenDialog1.Filter := 'Arquivos XML|*.xml';
  if OpenDialog1.Execute then
  begin
    try
      FACBr.ImportarXML(OpenDialog1.FileName);
      MessageDlg('XML importado com sucesso!', mtInformation, [mbOK], 0);
    except
      on E: Exception do
        MessageDlg('Erro: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TfrmNFe.btnSelecionarCertClick(Sender: TObject);
begin
  OpenDialog1.Filter := 'Certificados|*.pfx;*.p12|Todos|*.*';
  if OpenDialog1.Execute then
    edtCertificado.Text := OpenDialog1.FileName;
end;

procedure TfrmNFe.btnFiltrarClick(Sender: TObject);
begin
  CarregarPedidos;
end;

procedure TfrmNFe.btnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
