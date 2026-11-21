unit uFrmMapearProdutoXML;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Marco 3.88
  Diálogo de mapeamento de produto de item importado por XML.

  Quando a importação não encontra correspondência exata por
  código/EAN, este diálogo mostra a descrição original, o CNPJ
  do fornecedor e a classificação fiscal que veio no documento,
  e oferece três saídas:
    - selecionar um produto compatível do cadastro;
    - cadastrar um novo produto pré-preenchido com os dados do
      XML (CATEGORIA/UNIDADE vêm do cadastro, nunca são criadas
      automaticamente);
    - ignorar o item (fica IGNORADO no rastro da importação).

  Uso: Create(nil) -> Carregar(item) -> ShowModal.
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, Grids, SQLDB, uImportacaoXmlMapService;

type
  { TfrmMapearProdutoXML }
  TfrmMapearProdutoXML = class(TForm)
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    pnlDados: TPanel;
    lblDadosXML: TMemo;
    lblBuscar: TLabel;
    edtTermo: TEdit;
    btnBuscar: TBitBtn;
    gridProdutos: TStringGrid;
    pnlBotoes: TPanel;
    btnSelecionar: TBitBtn;
    btnNovo: TBitBtn;
    btnIgnorar: TBitBtn;
    btnCancelar: TBitBtn;
    pnlNovo: TPanel;
    lblNovoTitulo: TLabel;
    lblNovaDescricao: TLabel;
    edtNovaDescricao: TEdit;
    lblNovoCodigo: TLabel;
    edtNovoCodigo: TEdit;
    lblNovaNcm: TLabel;
    edtNovaNcm: TEdit;
    lblNovaUnidade: TLabel;
    edtNovaUnidade: TEdit;
    lblNovoPreco: TLabel;
    edtNovoPreco: TEdit;
    btnConfirmarNovo: TBitBtn;
    btnVoltar: TBitBtn;
    procedure FormCreate(Sender: TObject);
    procedure btnBuscarClick(Sender: TObject);
    procedure gridProdutosDblClick(Sender: TObject);
    procedure btnSelecionarClick(Sender: TObject);
    procedure btnNovoClick(Sender: TObject);
    procedure btnVoltarClick(Sender: TObject);
    procedure btnConfirmarNovoClick(Sender: TObject);
    procedure btnIgnorarClick(Sender: TObject);
    procedure btnCancelarClick(Sender: TObject);
  private
    FItem: TItemMapaXML;
    FIds: array of Int64;
    procedure Buscar;
    procedure MostrarModoEscolha(AVisivel: Boolean);
  public
    { Produto escolhido (0 quando ignorado/cancelado). }
    ProdutoId: Int64;
    { 'XML' | 'CADASTRO_MANUAL' | '' }
    Origem: string;
    { True quando o produto novo ja foi criado e vinculado. }
    JaAplicado: Boolean;
    Ignorado: Boolean;
    procedure Carregar(const AItem: TItemMapaXML);
  end;

var
  frmMapearProdutoXML: TfrmMapearProdutoXML;

implementation

{$R *.lfm}

{ TfrmMapearProdutoXML }

procedure TfrmMapearProdutoXML.FormCreate(Sender: TObject);
begin
  Caption := 'Mapeamento de produto - XML de entrada';
  Position := poScreenCenter;
  BorderStyle := bsDialog;
  SetLength(FIds, 0);
  gridProdutos.ColCount := 5;
  gridProdutos.FixedCols := 0;
  gridProdutos.FixedRows := 1;
  gridProdutos.RowCount := 1;
  gridProdutos.Cells[0, 0] := 'ID';
  gridProdutos.Cells[1, 0] := 'Código';
  gridProdutos.Cells[2, 0] := 'Descrição';
  gridProdutos.Cells[3, 0] := 'NCM';
  gridProdutos.Cells[4, 0] := 'Preço';
  gridProdutos.ColWidths[0] := 60;
  gridProdutos.ColWidths[1] := 120;
  gridProdutos.ColWidths[2] := 290;
  gridProdutos.ColWidths[3] := 80;
  gridProdutos.ColWidths[4] := 80;
  ProdutoId := 0;
  Origem := '';
  JaAplicado := False;
  Ignorado := False;
  pnlNovo.Visible := False;
end;

procedure TfrmMapearProdutoXML.Carregar(const AItem: TItemMapaXML);
var
  LPalavras: TStringList;
begin
  FItem := AItem;
  lblDadosXML.Clear;
  lblDadosXML.Lines.Add('Descrição original: ' + AItem.DescricaoOriginal);
  lblDadosXML.Lines.Add('Código do produto na nota: ' + AItem.CodigoNota);
  lblDadosXML.Lines.Add('CNPJ do fornecedor: ' + AItem.Cnpj);
  lblDadosXML.Lines.Add('Classificação fiscal: ' + AItem.Classificacao);

  edtNovaDescricao.Text := AItem.DescricaoOriginal;
  edtNovoCodigo.Text := AItem.CodigoNota;
  edtNovaNcm.Text := AItem.Ncm;
  edtNovaUnidade.Text := AItem.Unidade;
  edtNovoPreco.Text := '0';

  LPalavras := TStringList.Create;
  try
    LPalavras.Delimiter := ' ';
    LPalavras.StrictDelimiter := True;
    LPalavras.DelimitedText := AItem.DescricaoOriginal;
    if LPalavras.Count > 0 then
      edtTermo.Text := LPalavras[0]
    else
      edtTermo.Text := '';
  finally
    LPalavras.Free;
  end;
  Buscar;
end;

procedure TfrmMapearProdutoXML.Buscar;
var
  LService: TImportacaoXmlMapService;
  LQuery: TSQLQuery;
  LI, LLinha: Integer;
begin
  LService := TImportacaoXmlMapService.Create;
  LQuery := nil;
  try
    LQuery := LService.BuscarCompativeis(edtTermo.Text, FItem.Ncm);
    SetLength(FIds, 0);
    gridProdutos.RowCount := 1;
    LLinha := 1;
    while not LQuery.EOF do
    begin
      gridProdutos.RowCount := LLinha + 1;
      gridProdutos.Cells[0, LLinha] :=
        IntToStr(LQuery.FieldByName('ID').AsLargeInt);
      gridProdutos.Cells[1, LLinha] := LQuery.FieldByName('CODIGO').AsString;
      gridProdutos.Cells[2, LLinha] := LQuery.FieldByName('DESCRICAO').AsString;
      gridProdutos.Cells[3, LLinha] := LQuery.FieldByName('NCM').AsString;
      gridProdutos.Cells[4, LLinha] :=
        FormatFloat('0.00', LQuery.FieldByName('PRECO_VENDA').AsFloat);
      SetLength(FIds, LLinha);
      FIds[LLinha - 1] := LQuery.FieldByName('ID').AsLargeInt;
      Inc(LLinha);
      LQuery.Next;
    end;
    if LLinha = 1 then
      gridProdutos.RowCount := 2;
  finally
    if LQuery <> nil then
      LQuery.Free;
    LService.Free;
  end;
end;

procedure TfrmMapearProdutoXML.btnBuscarClick(Sender: TObject);
begin
  Buscar;
end;

procedure TfrmMapearProdutoXML.gridProdutosDblClick(Sender: TObject);
begin
  btnSelecionarClick(Sender);
end;

procedure TfrmMapearProdutoXML.btnSelecionarClick(Sender: TObject);
begin
  if (gridProdutos.Row <= 0) or (gridProdutos.Row > Length(FIds)) then
  begin
    MessageDlg('Selecione um produto compatível na lista.',
      mtInformation, [mbOK], 0);
    Exit;
  end;
  ProdutoId := FIds[gridProdutos.Row - 1];
  Origem := 'XML';
  ModalResult := mrOk;
end;

procedure TfrmMapearProdutoXML.MostrarModoEscolha(AVisivel: Boolean);
begin
  pnlBotoes.Visible := AVisivel;
  pnlNovo.Visible := not AVisivel;
end;

procedure TfrmMapearProdutoXML.btnNovoClick(Sender: TObject);
begin
  MostrarModoEscolha(False);
  edtNovaDescricao.SetFocus;
end;

procedure TfrmMapearProdutoXML.btnVoltarClick(Sender: TObject);
begin
  MostrarModoEscolha(True);
end;

procedure TfrmMapearProdutoXML.btnConfirmarNovoClick(Sender: TObject);
var
  LService: TImportacaoXmlMapService;
  LPreco: Double;
begin
  if Trim(edtNovaDescricao.Text) = '' then
  begin
    MessageDlg('Informe a descrição do novo produto.',
      mtWarning, [mbOK], 0);
    edtNovaDescricao.SetFocus;
    Exit;
  end;
  LPreco := 0;
  try
    LPreco := StrToFloat(StringReplace(Trim(edtNovoPreco.Text), ',', '.',
      [rfReplaceAll]));
  except
    LPreco := 0;
  end;
  LService := TImportacaoXmlMapService.Create;
  try
    ProdutoId := LService.CriarProdutoDoItem(FItem.Id, LPreco);
  finally
    LService.Free;
  end;
  Origem := 'CADASTRO_MANUAL';
  JaAplicado := True;
  ModalResult := mrOk;
end;

procedure TfrmMapearProdutoXML.btnIgnorarClick(Sender: TObject);
begin
  Ignorado := True;
  ModalResult := mrOk;
end;

procedure TfrmMapearProdutoXML.btnCancelarClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
