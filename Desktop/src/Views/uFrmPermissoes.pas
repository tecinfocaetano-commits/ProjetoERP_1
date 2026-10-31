unit uFrmPermissoes;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Sistema > Permissões
  Descrição: editor da matriz PERMISSAO (grupo x módulo/tela e as
  ações PODE_*). A leitura em execução continua sendo a de
  uPermissao.TemPermissao (fail-closed); aqui só se cadastra.

  A tela abre com permissão VISUALIZAR do módulo SISTEMA; gravar e
  exigem INSERIR e EXCLUIR respectivamente (uPermissao). Toda a
  gravação fica no TPermissaoService.
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, ComCtrls,
  uConexao, uPermissao, uPermissaoService;

type
  { TfrmPermissoes }
  TfrmPermissoes = class(TForm)
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    pnlGrupo: TPanel;
    lblGrupo: TLabel;
    cmbGrupo: TComboBox;
    lblDica: TLabel;
    dbGrid: TDBGrid;
    pnlEdicao: TPanel;
    lblModulo: TLabel;
    edtModulo: TEdit;
    lblTela: TLabel;
    edtTela: TEdit;
    chkVisualizar: TCheckBox;
    chkInserir: TCheckBox;
    chkEditar: TCheckBox;
    chkExcluir: TCheckBox;
    chkImprimir: TCheckBox;
    btnNovo: TBitBtn;
    btnSalvar: TBitBtn;
    btnExcluir: TBitBtn;
    btnFechar: TBitBtn;
    DataSource1: TDataSource;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure cmbGrupoChange(Sender: TObject);
    procedure dbGridCellClick(Column: TColumn);
    procedure btnNovoClick(Sender: TObject);
    procedure btnSalvarClick(Sender: TObject);
    procedure btnExcluirClick(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
  private
    FConexao: TConexao;
    FService: TPermissaoService;
    FQueryGrupos: TSQLQuery;
    FQueryPermissoes: TSQLQuery;
    FGrupoIds: array of Int64;
    FIdSelecionado: Int64;
    function  GrupoSelecionado: Int64;
    procedure PreencherGrupos;
    procedure CarregarPermissoes;
    procedure LimparEdicao;
    procedure MarcarSelecaoNaEdicao;
    procedure ConfigurarGrid;
  end;

var
  frmPermissoes: TfrmPermissoes;

implementation

{$R *.lfm}

{ TfrmPermissoes }

procedure TfrmPermissoes.FormCreate(Sender: TObject);
begin
  try
    FConexao := TConexao.GetInstance;
    if not FConexao.Conectado then
      FConexao.Conectar;

    FService := TPermissaoService.Create;

    FQueryGrupos := TSQLQuery.Create(Self);
    FQueryGrupos.DataBase := FConexao.Connection;
    FQueryGrupos.Transaction := FConexao.Transaction;

    FQueryPermissoes := TSQLQuery.Create(Self);
    FQueryPermissoes.DataBase := FConexao.Connection;
    FQueryPermissoes.Transaction := FConexao.Transaction;

    if DataSource1 = nil then
      DataSource1 := TDataSource.Create(Self);
    DataSource1.DataSet := FQueryPermissoes;

    lblTitulo.Caption := 'Permissões por Grupo';
    Caption := 'Permissões';
    ConfigurarGrid;

    FIdSelecionado := 0;
    Position := poScreenCenter;
    BorderStyle := bsSizeable;

    PreencherGrupos;
    CarregarPermissoes;
    LimparEdicao;
  except
    on E: Exception do
      MessageDlg('Erro ao inicializar formulário: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmPermissoes.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FService);
end;

procedure TfrmPermissoes.ConfigurarGrid;
begin
  { As colunas são persistentes no .lfm (mesmo padrão da tela do Mapa);
    aqui só se garante que a grade é somente leitura. }
  dbGrid.ReadOnly := True;
end;

function TfrmPermissoes.GrupoSelecionado: Int64;
begin
  Result := 0;
  if (cmbGrupo.ItemIndex >= 0) and (cmbGrupo.ItemIndex <= High(FGrupoIds)) then
    Result := FGrupoIds[cmbGrupo.ItemIndex];
end;

procedure TfrmPermissoes.PreencherGrupos;
var
  LIdx: Integer;
begin
  SetLength(FGrupoIds, 0);
  cmbGrupo.Items.BeginUpdate;
  try
    cmbGrupo.Items.Clear;
    FService.CarregarGrupos(FQueryGrupos);
    while not FQueryGrupos.EOF do
    begin
      LIdx := cmbGrupo.Items.Add(FQueryGrupos.FieldByName('NOME').AsString);
      SetLength(FGrupoIds, LIdx + 1);
      FGrupoIds[LIdx] := FQueryGrupos.FieldByName('ID').AsLargeInt;
      FQueryGrupos.Next;
    end;
  finally
    cmbGrupo.Items.EndUpdate;
  end;
  if cmbGrupo.Items.Count > 0 then
    cmbGrupo.ItemIndex := 0;
end;

procedure TfrmPermissoes.CarregarPermissoes;
var
  LGrupo: Int64;
begin
  LGrupo := GrupoSelecionado;
  if LGrupo <= 0 then
  begin
    if FQueryPermissoes.Active then
      FQueryPermissoes.Close;
    Exit;
  end;
  FService.CarregarPermissoes(FQueryPermissoes, LGrupo);
  DataSource1.DataSet := FQueryPermissoes;
end;

procedure TfrmPermissoes.LimparEdicao;
begin
  edtModulo.Clear;
  edtTela.Clear;
  chkVisualizar.Checked := False;
  chkInserir.Checked := False;
  chkEditar.Checked := False;
  chkExcluir.Checked := False;
  chkImprimir.Checked := False;
  FIdSelecionado := 0;
end;

procedure TfrmPermissoes.MarcarSelecaoNaEdicao;
begin
  if (DataSource1.DataSet = nil) or DataSource1.DataSet.IsEmpty then
    Exit;
  with DataSource1.DataSet do
  begin
    FIdSelecionado := FieldByName('ID').AsLargeInt;
    edtModulo.Text := FieldByName('MODULO').AsString;
    edtTela.Text := FieldByName('TELA').AsString;
    chkVisualizar.Checked := UpperCase(Trim(FieldByName('PODE_VISUALIZAR').AsString)) = 'S';
    chkInserir.Checked := UpperCase(Trim(FieldByName('PODE_INSERIR').AsString)) = 'S';
    chkEditar.Checked := UpperCase(Trim(FieldByName('PODE_EDITAR').AsString)) = 'S';
    chkExcluir.Checked := UpperCase(Trim(FieldByName('PODE_EXCLUIR').AsString)) = 'S';
    chkImprimir.Checked := UpperCase(Trim(FieldByName('PODE_IMPRIMIR').AsString)) = 'S';
  end;
end;

procedure TfrmPermissoes.cmbGrupoChange(Sender: TObject);
begin
  try
    CarregarPermissoes;
    LimparEdicao;
  except
    on E: Exception do
      MessageDlg('Erro ao carregar as permissões do grupo: ' + E.Message,
        mtError, [mbOK], 0);
  end;
end;

procedure TfrmPermissoes.dbGridCellClick(Column: TColumn);
begin
  MarcarSelecaoNaEdicao;
end;

procedure TfrmPermissoes.btnNovoClick(Sender: TObject);
begin
  LimparEdicao;
  edtModulo.SetFocus;
end;

procedure TfrmPermissoes.btnSalvarClick(Sender: TObject);
begin
  if not TemPermissao(MODULO_SISTEMA, TELA_PERMISSOES, PERM_INSERIR) then
  begin
    MessageDlg('Seu usuário não tem permissão para alterar permissões.',
      mtWarning, [mbOK], 0);
    Exit;
  end;

  if GrupoSelecionado <= 0 then
  begin
    MessageDlg('Selecione um grupo.', mtWarning, [mbOK], 0);
    cmbGrupo.SetFocus;
    Exit;
  end;
  if Trim(edtModulo.Text) = '' then
  begin
    MessageDlg('O campo Módulo é obrigatório.', mtWarning, [mbOK], 0);
    edtModulo.SetFocus;
    Exit;
  end;
  if Trim(edtTela.Text) = '' then
  begin
    MessageDlg('O campo Tela é obrigatório.', mtWarning, [mbOK], 0);
    edtTela.SetFocus;
    Exit;
  end;

  try
    FService.Gravar(GrupoSelecionado, edtModulo.Text, edtTela.Text,
      chkVisualizar.Checked, chkInserir.Checked, chkEditar.Checked,
      chkExcluir.Checked, chkImprimir.Checked);

    { o COMMIT invalida o cursor aberto: recarrega a lista }
    CarregarPermissoes;
    LimparEdicao;
    MessageDlg('Permissão salva com sucesso!', mtInformation, [mbOK], 0);
  except
    on E: Exception do
      MessageDlg('Erro ao salvar a permissão: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmPermissoes.btnExcluirClick(Sender: TObject);
begin
  if not TemPermissao(MODULO_SISTEMA, TELA_PERMISSOES, PERM_EXCLUIR) then
  begin
    MessageDlg('Seu usuário não tem permissão para excluir permissões.',
      mtWarning, [mbOK], 0);
    Exit;
  end;

  if FIdSelecionado <= 0 then
  begin
    MessageDlg('Selecione uma permissão na lista para excluir.', mtWarning, [mbOK], 0);
    Exit;
  end;

  if MessageDlg('Deseja realmente excluir esta permissão?',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;

  try
    FService.Excluir(FIdSelecionado);
    CarregarPermissoes;
    LimparEdicao;
    MessageDlg('Permissão excluída com sucesso!', mtInformation, [mbOK], 0);
  except
    on E: Exception do
      MessageDlg('Erro ao excluir a permissão: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmPermissoes.btnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
