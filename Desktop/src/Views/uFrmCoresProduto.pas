unit uFrmCoresProduto;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Cores do produto de produção (item 7 do backlog)
  ------------------------------------------------------------
  Cada produto pode ter várias cores (tabela COR). Cada cor tem
  a sua própria ficha técnica (FICHA_TECNICA.TIPO_BASE = 'COR'
  e ID_BASE = COR.ID) - a tela mostra qual ficha está vinculada.

  Regras de negócio (validação, duplicidade) ficam no
  TCorService; aqui só a UI.
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Grids, SQLDB, uConexao, uCorService, uCor, uSessao;

type
  { TfrmCoresProduto }
  TfrmCoresProduto = class(TForm)
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    lblSubtitulo: TLabel;
    sgCores: TStringGrid;
    pnlEdicao: TPanel;
    lblNome: TLabel;
    edtNome: TEdit;
    lblHex: TLabel;
    edtHex: TEdit;
    chkAtivo: TCheckBox;
    btnAdicionar: TButton;
    btnAtualizar: TButton;
    btnExcluir: TButton;
    btnLimpar: TButton;
    btnFechar: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnAdicionarClick(Sender: TObject);
    procedure btnAtualizarClick(Sender: TObject);
    procedure btnExcluirClick(Sender: TObject);
    procedure btnLimparClick(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
    procedure sgCoresSelectCell(Sender: TObject; aCol, aRow: Integer;
      var CanSelect: Boolean);
  private
    FConexao: TConexao;
    FService: TCorService;
    FProdutoId: Int64;
    FProdutoDescricao: string;
    FCorId: Int64;
    procedure CarregarCores;
    procedure SelecionarCor(ARow: Integer);
    procedure LimparEdicao;
    procedure HabilitarEdicao(AHabilitar: Boolean);
  public
    property ProdutoId: Int64 read FProdutoId write FProdutoId;
    property ProdutoDescricao: string read FProdutoDescricao write FProdutoDescricao;
  end;

var
  frmCoresProduto: TfrmCoresProduto;

implementation

{$R *.lfm}

procedure TfrmCoresProduto.FormCreate(Sender: TObject);
begin
  FConexao := TConexao.GetInstance;
  if not FConexao.Conectado then
    FConexao.Conectar;
  FService := TCorService.Create;
  FCorId := 0;

  sgCores.FixedRows := 1;
  sgCores.FixedCols := 0;
  sgCores.ColCount := 4;
  sgCores.RowCount := 1;
  sgCores.Cells[0, 0] := 'Cor';
  sgCores.Cells[1, 0] := 'HEX';
  sgCores.Cells[2, 0] := 'Ativo';
  sgCores.Cells[3, 0] := 'Ficha técnica da cor';
  sgCores.ColWidths[0] := 150;
  sgCores.ColWidths[1] := 80;
  sgCores.ColWidths[2] := 50;
  sgCores.ColWidths[3] := 260;
  sgCores.Options := sgCores.Options + [goRowSelect];
end;

procedure TfrmCoresProduto.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FService);
end;

procedure TfrmCoresProduto.FormShow(Sender: TObject);
begin
  if Trim(FProdutoDescricao) <> '' then
    lblSubtitulo.Caption := 'Produto: ' + FProdutoDescricao
  else
    lblSubtitulo.Caption := 'Produto ID ' + IntToStr(FProdutoId);
  LimparEdicao;
  CarregarCores;
end;

procedure TfrmCoresProduto.CarregarCores;
var
  LQuery: TSQLQuery;
  LRow: Integer;
begin
  sgCores.RowCount := 1;
  if FProdutoId <= 0 then
    Exit;

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT C.ID, C.NOME, COALESCE(C.HEX, '''') AS HEX, C.ATIVO, ' +
      '       F.DESCRICAO AS FICHA_DESCRICAO, F.QUANTIDADE_BASE AS FICHA_BASE ' +
      'FROM COR C ' +
      '  LEFT JOIN FICHA_TECNICA F ON (F.TIPO_BASE = ''COR'') AND (F.ID_BASE = C.ID) ' +
      'WHERE C.PRODUTO_ID = :PROD ORDER BY C.NOME';
    LQuery.ParamByName('PROD').AsLargeInt := FProdutoId;
    LQuery.Open;
    while not LQuery.EOF do
    begin
      LRow := sgCores.RowCount;
      sgCores.RowCount := LRow + 1;
      sgCores.Cells[0, LRow] := Trim(LQuery.FieldByName('NOME').AsString);
      sgCores.Cells[1, LRow] := Trim(LQuery.FieldByName('HEX').AsString);
      if Trim(LQuery.FieldByName('ATIVO').AsString) = 'A' then
        sgCores.Cells[2, LRow] := 'Sim'
      else
        sgCores.Cells[2, LRow] := 'Não';
      sgCores.Objects[0, LRow] := TObject(PtrInt(LQuery.FieldByName('ID').AsLargeInt));
      if LQuery.FieldByName('FICHA_DESCRICAO').IsNull then
        sgCores.Cells[3, LRow] := '(sem ficha técnica)'
      else
        sgCores.Cells[3, LRow] :=
          Trim(LQuery.FieldByName('FICHA_DESCRICAO').AsString) +
          ' (base ' + FormatFloat('#,##0.####', LQuery.FieldByName('FICHA_BASE').AsFloat) + ')';
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TfrmCoresProduto.HabilitarEdicao(AHabilitar: Boolean);
begin
  edtNome.Enabled := AHabilitar;
  edtHex.Enabled := AHabilitar;
  chkAtivo.Enabled := AHabilitar;
end;

procedure TfrmCoresProduto.LimparEdicao;
begin
  FCorId := 0;
  edtNome.Clear;
  edtHex.Text := '#FFFFFF';
  chkAtivo.Checked := True;
  HabilitarEdicao(True);
  edtNome.SetFocus;
end;

procedure TfrmCoresProduto.SelecionarCor(ARow: Integer);
var
  LQuery: TSQLQuery;
begin
  if (ARow < 1) or (sgCores.Objects[0, ARow] = nil) then
    Exit;
  FCorId := PtrInt(sgCores.Objects[0, ARow]);

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT NOME, COALESCE(HEX, '''') AS HEX, ATIVO FROM COR WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := FCorId;
    LQuery.Open;
    if not LQuery.IsEmpty then
    begin
      edtNome.Text := Trim(LQuery.FieldByName('NOME').AsString);
      edtHex.Text := Trim(LQuery.FieldByName('HEX').AsString);
      chkAtivo.Checked := Trim(LQuery.FieldByName('ATIVO').AsString) = 'A';
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TfrmCoresProduto.sgCoresSelectCell(Sender: TObject; aCol,
  aRow: Integer; var CanSelect: Boolean);
begin
  if aRow >= 1 then
    SelecionarCor(aRow);
end;

procedure TfrmCoresProduto.btnAdicionarClick(Sender: TObject);
var
  LCor: TCor;
begin
  if FProdutoId <= 0 then
  begin
    MessageDlg('Grave o produto antes de cadastrar cores.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if Trim(edtNome.Text) = '' then
  begin
    MessageDlg('Informe o nome da cor.', mtWarning, [mbOK], 0);
    edtNome.SetFocus;
    Exit;
  end;

  LCor := TCor.Create;
  try
    LCor.EmpresaId := TSessao.GetInstance.EmpresaId;
    LCor.ProdutoId := FProdutoId;
    LCor.Nome := Trim(edtNome.Text);
    LCor.Hex := Trim(edtHex.Text);
    if chkAtivo.Checked then
      LCor.Ativo := 'A'
    else
      LCor.Ativo := 'I';
    try
      FService.Inserir(LCor);
    except
      on E: Exception do
      begin
        MessageDlg('Erro ao incluir a cor: ' + E.Message, mtError, [mbOK], 0);
        Exit;
      end;
    end;
  finally
    LCor.Free;
  end;

  LimparEdicao;
  CarregarCores;
end;

procedure TfrmCoresProduto.btnAtualizarClick(Sender: TObject);
var
  LCor: TCor;
begin
  if FCorId <= 0 then
  begin
    MessageDlg('Selecione uma cor na lista.', mtInformation, [mbOK], 0);
    Exit;
  end;

  LCor := TCor.Create;
  try
    LCor.Id := FCorId;
    LCor.EmpresaId := TSessao.GetInstance.EmpresaId;
    LCor.ProdutoId := FProdutoId;
    LCor.Nome := Trim(edtNome.Text);
    LCor.Hex := Trim(edtHex.Text);
    if chkAtivo.Checked then
      LCor.Ativo := 'A'
    else
      LCor.Ativo := 'I';
    try
      FService.Atualizar(LCor);
    except
      on E: Exception do
      begin
        MessageDlg('Erro ao atualizar a cor: ' + E.Message, mtError, [mbOK], 0);
        Exit;
      end;
    end;
  finally
    LCor.Free;
  end;

  LimparEdicao;
  CarregarCores;
end;

procedure TfrmCoresProduto.btnExcluirClick(Sender: TObject);
begin
  if FCorId <= 0 then
  begin
    MessageDlg('Selecione uma cor na lista.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if MessageDlg('Excluir a cor selecionada?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;

  try
    FService.Excluir(FCorId);
  except
    on E: Exception do
    begin
      MessageDlg('Erro ao excluir a cor: ' + E.Message, mtError, [mbOK], 0);
      Exit;
    end;
  end;

  LimparEdicao;
  CarregarCores;
end;

procedure TfrmCoresProduto.btnLimparClick(Sender: TObject);
begin
  LimparEdicao;
end;

procedure TfrmCoresProduto.btnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
