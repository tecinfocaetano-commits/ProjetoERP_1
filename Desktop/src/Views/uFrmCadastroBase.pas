unit uFrmCadastroBase;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 2 - Formulário Base de Cadastro
  Descrição: Template reutilizável para todos os CRUDs
  Padrão: Template Method
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, ComCtrls, uConexao;

type
  TEstadoForm = (efNavegando, efInserindo, efEditando);

  { TfrmCadastroBase }
  TfrmCadastroBase = class(TForm)
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    pnlBotoes: TPanel;
    btnNovo: TBitBtn;
    btnEditar: TBitBtn;
    btnExcluir: TBitBtn;
    btnSalvar: TBitBtn;
    btnCancelar: TBitBtn;
    btnFechar: TBitBtn;
    pnlPesquisa: TPanel;
    edtPesquisa: TEdit;
    btnPesquisar: TBitBtn;
    lblPesquisa: TLabel;
    PageControl1: TPageControl;
    tsListagem: TTabSheet;
    tsCadastro: TTabSheet;
    dbGrid: TDBGrid;
    DataSource1: TDataSource;
    procedure FormCreate(Sender: TObject);
    procedure btnNovoClick(Sender: TObject);
    procedure btnEditarClick(Sender: TObject);
    procedure btnExcluirClick(Sender: TObject);
    procedure btnSalvarClick(Sender: TObject);
    procedure btnCancelarClick(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
    procedure btnPesquisarClick(Sender: TObject);
    procedure dbGridDblClick(Sender: TObject);
    procedure edtPesquisaKeyPress(Sender: TObject; var Key: char);
  protected
    FEstado: TEstadoForm;
    FIdSelecionado: Int64;
    FConexao: TConexao;

    procedure ConfigurarEstado(AEstado: TEstadoForm); virtual;
    procedure HabilitarCampos(AHabilitar: Boolean); virtual; abstract;
    procedure LimparCampos; virtual; abstract;
    procedure PreencherCampos; virtual; abstract;
    procedure PreencherObjeto; virtual; abstract;
    function Validar: Boolean; virtual; abstract;
    procedure CarregarDados(const AFiltro: string = ''); virtual; abstract;
    function Salvar: Boolean; virtual; abstract;
    function Excluir: Boolean; virtual; abstract;
    function ObterIdGrid: Int64; virtual;
  public
    property Estado: TEstadoForm read FEstado;
  end;

var
  frmCadastroBase: TfrmCadastroBase;

implementation

{$R *.lfm}

{ TfrmCadastroBase }

procedure TfrmCadastroBase.FormCreate(Sender: TObject);
begin
  FConexao := TConexao.GetInstance;
  Position := poScreenCenter;
  BorderStyle := bsSizeable;
  ConfigurarEstado(efNavegando);
  CarregarDados;
end;

procedure TfrmCadastroBase.ConfigurarEstado(AEstado: TEstadoForm);
begin
  FEstado := AEstado;

  case AEstado of
    efNavegando:
    begin
      btnNovo.Enabled := True;
      btnEditar.Enabled := True;
      btnExcluir.Enabled := True;
      btnSalvar.Enabled := False;
      btnCancelar.Enabled := False;
      HabilitarCampos(False);
      PageControl1.ActivePage := tsListagem;
    end;
    efInserindo, efEditando:
    begin
      btnNovo.Enabled := False;
      btnEditar.Enabled := False;
      btnExcluir.Enabled := False;
      btnSalvar.Enabled := True;
      btnCancelar.Enabled := True;
      HabilitarCampos(True);
      PageControl1.ActivePage := tsCadastro;
    end;
  end;
end;

procedure TfrmCadastroBase.btnNovoClick(Sender: TObject);
begin
  LimparCampos;
  FIdSelecionado := 0;
  ConfigurarEstado(efInserindo);
end;

procedure TfrmCadastroBase.btnEditarClick(Sender: TObject);
begin
  FIdSelecionado := ObterIdGrid;
  if FIdSelecionado <= 0 then
  begin
    MessageDlg('Selecione um registro para editar.', mtWarning, [mbOK], 0);
    Exit;
  end;
  PreencherCampos;
  ConfigurarEstado(efEditando);
end;

procedure TfrmCadastroBase.btnExcluirClick(Sender: TObject);
begin
  FIdSelecionado := ObterIdGrid;
  if FIdSelecionado <= 0 then
  begin
    MessageDlg('Selecione um registro para excluir.', mtWarning, [mbOK], 0);
    Exit;
  end;

  if MessageDlg('Deseja realmente excluir este registro?', mtConfirmation,
    [mbYes, mbNo], 0) = mrYes then
  begin
    if Excluir then
    begin
      MessageDlg('Registro excluído com sucesso!', mtInformation, [mbOK], 0);
      CarregarDados;
    end;
  end;
end;

procedure TfrmCadastroBase.btnSalvarClick(Sender: TObject);
begin
  if not Validar then Exit;

  PreencherObjeto;

  if Salvar then
  begin
    MessageDlg('Registro salvo com sucesso!', mtInformation, [mbOK], 0);
    ConfigurarEstado(efNavegando);
    CarregarDados;
  end;
end;

procedure TfrmCadastroBase.btnCancelarClick(Sender: TObject);
begin
  LimparCampos;
  ConfigurarEstado(efNavegando);
end;

procedure TfrmCadastroBase.btnFecharClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmCadastroBase.btnPesquisarClick(Sender: TObject);
begin
  CarregarDados(Trim(edtPesquisa.Text));
end;

procedure TfrmCadastroBase.dbGridDblClick(Sender: TObject);
begin
  btnEditarClick(Sender);
end;

procedure TfrmCadastroBase.edtPesquisaKeyPress(Sender: TObject; var Key: char);
begin
  if Key = #13 then
  begin
    Key := #0;
    btnPesquisarClick(Sender);
  end;
end;

function TfrmCadastroBase.ObterIdGrid: Int64;
begin
  Result := 0;
  if (DataSource1.DataSet <> nil) and (not DataSource1.DataSet.IsEmpty) then
    Result := DataSource1.DataSet.FieldByName('ID').AsLargeInt;
end;

end.
