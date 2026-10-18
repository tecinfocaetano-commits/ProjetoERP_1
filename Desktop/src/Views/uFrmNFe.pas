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
    edtInicio: TEdit;
    lblDataFim: TLabel;
    edtFim: TEdit;
    btnFiltrar: TBitBtn;
    pnlBotoes: TPanel;
    btnEmitirNFe: TBitBtn;
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
    dbGrid: TDBGrid;
    DataSource1: TDataSource;
    OpenDialog1: TOpenDialog;
    procedure FormCreate(Sender: TObject);
    procedure btnFiltrarClick(Sender: TObject);
    procedure btnEmitirNFeClick(Sender: TObject);
    procedure btnConsultarClick(Sender: TObject);
    procedure btnCancelarClick(Sender: TObject);
    procedure btnImportarXMLClick(Sender: TObject);
    procedure btnSelecionarCertClick(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
  private
    FConexao: TConexao;
    FQuery: TSQLQuery;
    FACBr: TACBrHelper;
    procedure CarregarPedidos;
  end;

var
  frmNFe: TfrmNFe;

implementation

{$R *.lfm}

procedure TfrmNFe.FormCreate(Sender: TObject);
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
  edtInicio.Text := FormatDateTime('dd/mm/yyyy', IncMonth(Now, -1));
  edtFim.Text := FormatDateTime('dd/mm/yyyy', Now);
  cmbAmbiente.ItemIndex := 1; // Homologação
  CarregarPedidos;
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
    'LEFT JOIN CLIENTE C ON C.ID = PV.CLIENTE_ID ' +
    'WHERE PV.DATA_EMISSAO BETWEEN :DI AND :DF ' +
    'AND PV.STATUS <> ''O'' ' +
    'ORDER BY PV.NUMERO DESC';
  FQuery.ParamByName('DI').AsDate := StrToDateDef(edtInicio.Text, Now);
  FQuery.ParamByName('DF').AsDate := StrToDateDef(edtFim.Text, Now) + 1;
  FQuery.Open;
  DataSource1.DataSet := FQuery;
end;

procedure TfrmNFe.btnEmitirNFeClick(Sender: TObject);
var
  LDados: TACBrDadosNFe;
begin
  if FQuery.IsEmpty then Exit;

  try
    FACBr.Configurar(edtCertificado.Text, '', 'SP', cmbAmbiente.ItemIndex + 1);
    LDados := FACBr.GerarNFe(FQuery.FieldByName('ID').AsLargeInt);
    MessageDlg(
      'NF-e gerada!' + #13#10 +
      'Número: ' + IntToStr(LDados.Numero) + #13#10 +
      'Chave: ' + LDados.ChaveAcesso + #13#10 +
      'Protocolo: ' + LDados.Protocolo + #13#10#13#10 +
      'Nota: Configure o ACBr para emissão real.',
      mtInformation, [mbOK], 0);
    CarregarPedidos;
  except
    on E: Exception do
      MessageDlg('Erro: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmNFe.btnConsultarClick(Sender: TObject);
var
  LChave: string;
begin
  if FQuery.IsEmpty then Exit;
  LChave := FQuery.FieldByName('CHAVE_NFE').AsString;
  if LChave = '' then
  begin
    MessageDlg('Este pedido não possui NF-e emitida.', mtWarning, [mbOK], 0);
    Exit;
  end;
  MessageDlg('Chave NF-e: ' + LChave + #13#10 +
    'Configure ACBr para consultar na SEFAZ.', mtInformation, [mbOK], 0);
end;

procedure TfrmNFe.btnCancelarClick(Sender: TObject);
var
  LJust: string;
begin
  if FQuery.IsEmpty then Exit;
  if FQuery.FieldByName('CHAVE_NFE').AsString = '' then
  begin
    MessageDlg('NF-e não emitida para este pedido.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if not InputQuery('Cancelar NF-e', 'Justificativa (mín. 15 caracteres):', LJust) then Exit;
  if Length(LJust) < 15 then
  begin
    MessageDlg('Justificativa deve ter no mínimo 15 caracteres.', mtWarning, [mbOK], 0);
    Exit;
  end;
  MessageDlg('Cancelamento registrado. Configure ACBr para efetivar na SEFAZ.',
    mtInformation, [mbOK], 0);
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
  FACBr.Free;
  Close;
end;

end.
