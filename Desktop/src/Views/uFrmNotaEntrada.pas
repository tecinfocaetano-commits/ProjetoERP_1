unit uFrmNotaEntrada;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Módulo 1 - Nota de Entrada (compra de mercadoria)

  Tela de cadastro e processamento da nota de entrada:
    - lista as notas lançadas (com filtro por período/status);
    - edita cabeçalho (fornecedor, número/série/modelo, chave de
      acesso, datas, natureza/CFOP, frete/seguro/desconto);
    - itens com produto, quantidade, valor unitário e desconto;
    - importa XML de NF-e (importação do fornecedor);
    - "Processar" dá entrada no estoque (via MOVIMENTO_ESTOQUE,
      com custo médio) e gera as parcelas em CONTA_PAGAR.

  Estrutura preparada para NF-e real: guarda modelo/série/número,
  chave de acesso e os campos fiscais de cada item.
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, ComCtrls, DateUtils, StrUtils,
  uConexao, uSessao, uNotaEntradaService;

type
  { TfrmNotaEntrada }
  TfrmNotaEntrada = class(TForm)
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    pnlFiltros: TPanel;
    lblFiltroDe: TLabel;
    edtFiltroDe: TEdit;
    lblFiltroAte: TLabel;
    edtFiltroAte: TEdit;
    lblFiltroStatus: TLabel;
    cmbFiltroStatus: TComboBox;
    btnFiltrar: TBitBtn;
    pnlBotoes: TPanel;
    btnNovaNota: TBitBtn;
    btnAbrirNota: TBitBtn;
    btnGravar: TBitBtn;
    btnIncluirItem: TBitBtn;
    btnExcluirItem: TBitBtn;
    btnProcessar: TBitBtn;
    btnCancelarNota: TBitBtn;
    btnImportarXML: TBitBtn;
    btnFechar: TBitBtn;
    pnlLista: TPanel;
    dbGridNotas: TDBGrid;
    pnlEdicao: TPanel;
    pnlCabecalho: TPanel;
    lblFornecedor: TLabel;
    edtFornecedor: TEdit;
    btnBuscarFornecedor: TBitBtn;
    lblFornecedorDesc: TLabel;
    lblNumero: TLabel;
    edtNumero: TEdit;
    lblSerie: TLabel;
    edtSerie: TEdit;
    lblModelo: TLabel;
    edtModelo: TEdit;
    lblChave: TLabel;
    edtChave: TEdit;
    lblDataEmissao: TLabel;
    edtDataEmissao: TEdit;
    lblDataEntrada: TLabel;
    edtDataEntrada: TEdit;
    lblNatureza: TLabel;
    edtNatureza: TEdit;
    lblCfop: TLabel;
    edtCfop: TEdit;
    lblCondPagto: TLabel;
    cmbCondicaoPagamento: TComboBox;
    lblStatusNota: TLabel;
    pnlTotais: TPanel;
    lblFrete: TLabel;
    edtFrete: TEdit;
    lblSeguro: TLabel;
    edtSeguro: TEdit;
    lblOutras: TLabel;
    edtOutras: TEdit;
    lblDesconto: TLabel;
    edtDesconto: TEdit;
    lblTotalProdutos: TLabel;
    lblTotalNota: TLabel;
    pnlItem: TPanel;
    lblItemProduto: TLabel;
    edtProdutoItem: TEdit;
    btnBuscarProdutoItem: TBitBtn;
    lblItemDesc: TLabel;
    lblItemQtd: TLabel;
    edtItemQtd: TEdit;
    lblItemValor: TLabel;
    edtItemValor: TEdit;
    lblItemDesconto: TLabel;
    edtItemDesconto: TEdit;
    lblItemInfo: TLabel;
    btnConfirmarItem: TBitBtn;
    btnCancelarItem: TBitBtn;
    dbGridItens: TDBGrid;
    DataSourceNotas: TDataSource;
    DataSourceItens: TDataSource;
    OpenDialog1: TOpenDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnFiltrarClick(Sender: TObject);
    procedure btnNovaNotaClick(Sender: TObject);
    procedure btnAbrirNotaClick(Sender: TObject);
    procedure btnGravarClick(Sender: TObject);
    procedure btnIncluirItemClick(Sender: TObject);
    procedure btnExcluirItemClick(Sender: TObject);
    procedure btnProcessarClick(Sender: TObject);
    procedure btnCancelarNotaClick(Sender: TObject);
    procedure btnImportarXMLClick(Sender: TObject);
    procedure btnBuscarFornecedorClick(Sender: TObject);
    procedure btnBuscarProdutoItemClick(Sender: TObject);
    procedure btnConfirmarItemClick(Sender: TObject);
    procedure btnCancelarItemClick(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
    procedure dbGridNotasDblClick(Sender: TObject);
    procedure dbGridItensDblClick(Sender: TObject);
  private
    FConexao: TConexao;
    FNotas: TSQLQuery;
    FItens: TSQLQuery;
    FService: TNotaEntradaService;
    FNotaId: Int64;
    FFornecedorId: Int64;
    FProdutoItemId: Int64;
    FItemId: Int64;

    procedure CarregarComboStatus;
    procedure CarregarComboCondicao;
    procedure CarregarNotas;
    procedure CarregarItens;
    procedure ModoLista;
    procedure ModoEdicao;
    procedure LimparCabecalho;
    procedure AbrirNota(ANotaId: Int64);
    procedure MostrarItem(AVisivel: Boolean);
    procedure LimparItem;
    procedure AtualizarStatusLabel(const AStatus: string);
    procedure AtualizarTotaisTela;
    procedure ImportarXML(const AArquivo: string);
    function  SalvarCabecalho: Boolean;
    function  InserirItem(AProdutoId: Int64; const ADescricao: string;
      AQuantidade, AValorUnitario, ADesconto: Double): Boolean;
  end;

var
  frmNotaEntrada: TfrmNotaEntrada;

implementation

{$R *.lfm}

{ ------------------------------------------------------------------
  Auxiliares de leitura de XML de NF-e (sem dependência do fcl-xml)
  ------------------------------------------------------------------ }
function TagTexto(const ATexto, ATag: string): string;
var
  LAbre, LFecha: string;
  LP1, LP2: Integer;
begin
  Result := '';
  LAbre := '<' + ATag + '>';
  LFecha := '</' + ATag + '>';
  LP1 := Pos(LAbre, ATexto);
  if LP1 = 0 then
    Exit;
  LP2 := PosEx(LFecha, ATexto, LP1 + Length(LAbre));
  if LP2 = 0 then
    Exit;
  Result := Trim(Copy(ATexto, LP1 + Length(LAbre), LP2 - LP1 - Length(LAbre)));
end;

function TagBlocos(const ATexto, ATag: string): TStringList;
var
  LAbre, LFecha: string;
  LP, LP1, LP2: Integer;
begin
  Result := TStringList.Create;
  LAbre := '<' + ATag;
  LFecha := '</' + ATag + '>';
  LP := 1;
  while True do
  begin
    LP1 := PosEx(LAbre, ATexto, LP);
    if LP1 = 0 then
      Break;
    // Evita casar prefixos de outras tags (ex.: <detX>)
    if not ((ATexto[LP1 + Length(LAbre)] = '>') or
            (ATexto[LP1 + Length(LAbre)] = ' ')) then
    begin
      LP := LP1 + Length(LAbre);
      Continue;
    end;
    LP1 := PosEx('>', ATexto, LP1) + 1;
    LP2 := PosEx(LFecha, ATexto, LP1);
    if LP2 = 0 then
      Break;
    Result.Add(Copy(ATexto, LP1, LP2 - LP1));
    LP := LP2 + Length(LFecha);
  end;
end;

function NumXml(const AValor: string): Double;
var
  LTexto: string;
begin
  LTexto := Trim(AValor);
  if FormatSettings.DecimalSeparator = ',' then
    LTexto := StringReplace(LTexto, '.', ',', [rfReplaceAll]);
  Result := StrToFloatDef(LTexto, 0);
end;

function DataXml(const AValor: string): TDate;
var
  LAno, LMes, LDia: Integer;
begin
  Result := 0;
  // Formato NF-e: 2026-10-17T13:50:48-03:00
  if Length(AValor) < 10 then
    Exit;
  LAno := StrToIntDef(Copy(AValor, 1, 4), 0);
  LMes := StrToIntDef(Copy(AValor, 6, 2), 0);
  LDia := StrToIntDef(Copy(AValor, 9, 2), 0);
  if (LAno > 1900) and (LMes >= 1) and (LMes <= 12) and
     (LDia >= 1) and (LDia <= 31) then
    Result := EncodeDate(LAno, LMes, LDia);
end;

{ Converte um campo DATE do banco em texto dd/mm/aaaa ('' quando vazio). }
function DataTexto(AField: TField): string;
begin
  if (AField = nil) or AField.IsNull then
    Result := ''
  else
    Result := FormatDateTime('dd/mm/yyyy', AField.AsDateTime);
end;

{ Número de parcelas de uma condição de pagamento (1 quando não houver). }
function ParcelasDaCondicao(AFConexao: TConexao; ACondicaoId: Int64): Integer;
var
  LQuery: TSQLQuery;
begin
  Result := 1;
  if ACondicaoId <= 0 then
    Exit;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := AFConexao.Connection;
    LQuery.Transaction := AFConexao.Transaction;
    LQuery.SQL.Text := 'SELECT PARCELAS FROM CONDICAO_PAGAMENTO WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := ACondicaoId;
    LQuery.Open;
    if not LQuery.IsEmpty then
    begin
      Result := LQuery.FieldByName('PARCELAS').AsInteger;
      if Result < 1 then
        Result := 1;
    end;
  finally
    LQuery.Free;
  end;
end;

{ ------------------------------------------------------------------ }

procedure TfrmNotaEntrada.FormCreate(Sender: TObject);
begin
  FConexao := TConexao.GetInstance;
  if not FConexao.Conectado then
    FConexao.Conectar;

  FNotas := TSQLQuery.Create(Self);
  FNotas.DataBase := FConexao.Connection;
  FNotas.Transaction := FConexao.Transaction;
  DataSourceNotas.DataSet := FNotas;

  FItens := TSQLQuery.Create(Self);
  FItens.DataBase := FConexao.Connection;
  FItens.Transaction := FConexao.Transaction;
  DataSourceItens.DataSet := FItens;

  FService := TNotaEntradaService.Create;
  FNotaId := 0;
  FFornecedorId := 0;
  FProdutoItemId := 0;
  FItemId := 0;
end;

procedure TfrmNotaEntrada.FormShow(Sender: TObject);
begin
  CarregarComboStatus;
  CarregarComboCondicao;
  edtFiltroDe.Text := FormatDateTime('dd/mm/yyyy', IncMonth(Now, -3));
  edtFiltroAte.Text := FormatDateTime('dd/mm/yyyy', Now);
  MostrarItem(False);
  ModoLista;
  CarregarNotas;
end;

procedure TfrmNotaEntrada.CarregarComboStatus;
begin
  cmbFiltroStatus.Items.Clear;
  cmbFiltroStatus.Items.Add('Todos');
  cmbFiltroStatus.Items.Add('Aberta (não processada)');
  cmbFiltroStatus.Items.Add('Processada');
  cmbFiltroStatus.Items.Add('Cancelada');
  cmbFiltroStatus.ItemIndex := 0;
end;

procedure TfrmNotaEntrada.CarregarComboCondicao;
var
  LQuery: TSQLQuery;
begin
  cmbCondicaoPagamento.Items.Clear;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT ID, DESCRICAO FROM CONDICAO_PAGAMENTO WHERE ATIVO = ''A'' ORDER BY PARCELAS, DESCRICAO';
    LQuery.Open;
    while not LQuery.EOF do
    begin
      cmbCondicaoPagamento.Items.AddObject(
        Trim(LQuery.FieldByName('DESCRICAO').AsString),
        TObject(PtrInt(LQuery.FieldByName('ID').AsLargeInt)));
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
  if cmbCondicaoPagamento.Items.Count > 0 then
    cmbCondicaoPagamento.ItemIndex := 0;
end;

procedure TfrmNotaEntrada.CarregarNotas;
var
  LStatus: string;
begin
  if FNotas.Active then
    FNotas.Close;

  FNotas.SQL.Text :=
    'SELECT N.ID, N.NUMERO, N.SERIE, N.MODELO, N.DATA_ENTRADA, N.VALOR_TOTAL, ' +
    '  N.STATUS, COALESCE(F.NOME_FANTASIA, F.RAZAO_SOCIAL, ''(sem fornecedor)'') AS FORNECEDOR, ' +
    '  CASE N.STATUS WHEN ''A'' THEN ''Aberta'' WHEN ''P'' THEN ''Processada'' ' +
    '       WHEN ''C'' THEN ''Cancelada'' ELSE N.STATUS END AS STATUS_DESC ' +
    'FROM NOTA_ENTRADA N LEFT JOIN FORNECEDOR F ON F.ID = N.FORNECEDOR_ID ' +
    'WHERE N.DATA_ENTRADA BETWEEN :DI AND :DF';

  case cmbFiltroStatus.ItemIndex of
    1: LStatus := 'A';
    2: LStatus := 'P';
    3: LStatus := 'C';
  else
    LStatus := '';
  end;
  if LStatus <> '' then
    FNotas.SQL.Text := FNotas.SQL.Text + ' AND N.STATUS = :STATUS';

  FNotas.SQL.Text := FNotas.SQL.Text + ' ORDER BY N.DATA_ENTRADA DESC, N.ID DESC';

  FNotas.ParamByName('DI').AsDate := StrToDateDef(edtFiltroDe.Text, IncMonth(Now, -3));
  FNotas.ParamByName('DF').AsDate := StrToDateDef(edtFiltroAte.Text, Now) + 1;
  if LStatus <> '' then
    FNotas.ParamByName('STATUS').AsString := LStatus;
  FNotas.Open;
end;

procedure TfrmNotaEntrada.CarregarItens;
begin
  if FItens.Active then
    FItens.Close;
  FItens.SQL.Text :=
    'SELECT I.ID, I.PRODUTO_ID, COALESCE(P.CODIGO, '''') AS CODIGO, I.DESCRICAO, I.QUANTIDADE, ' +
    '  I.VALOR_UNITARIO, I.DESCONTO, ' +
    // CAST necessário: sem ele a multiplicação vira NUMERIC(18,8), que o SQLDB
    // devolve como NULL (ver comentário em uNotaEntradaService.RecalcularTotais)
    '  CAST((I.QUANTIDADE * I.VALOR_UNITARIO - COALESCE(I.DESCONTO, 0)) AS NUMERIC(18,4)) AS TOTAL, ' +
    '  I.CFOP, COALESCE(I.NCM, '''') AS NCM, ' +
    '  CASE WHEN (I.PRODUTO_ID IS NULL OR I.PRODUTO_ID = 0) THEN ''sem produto'' ' +
    '       ELSE '''' END AS AVISO ' +
    'FROM NOTA_ENTRADA_ITEM I LEFT JOIN PRODUTO P ON P.ID = I.PRODUTO_ID ' +
    'WHERE I.NOTA_ENTRADA_ID = :ID ORDER BY I.ID';
  FItens.ParamByName('ID').AsLargeInt := FNotaId;
  FItens.Open;
  AtualizarTotaisTela;
end;

procedure TfrmNotaEntrada.ModoLista;
begin
  pnlLista.Visible := True;
  pnlEdicao.Visible := False;
  btnNovaNota.Enabled := True;
  btnAbrirNota.Enabled := not FNotas.IsEmpty;
  btnGravar.Enabled := False;
  btnIncluirItem.Enabled := False;
  btnExcluirItem.Enabled := False;
  btnProcessar.Enabled := False;
  btnCancelarNota.Enabled := False;
  btnImportarXML.Enabled := False;
end;

procedure TfrmNotaEntrada.ModoEdicao;
var
  LAberta: Boolean;
begin
  pnlLista.Visible := False;
  pnlEdicao.Visible := True;
  LAberta := (FNotaId > 0) and (lblStatusNota.Tag = 0);
  if FNotaId = 0 then
    LAberta := True; // nota nova ainda não gravada

  btnNovaNota.Enabled := True;
  btnAbrirNota.Enabled := False;
  btnGravar.Enabled := True;
  btnIncluirItem.Enabled := LAberta;
  btnExcluirItem.Enabled := LAberta;
  btnProcessar.Enabled := LAberta and (FNotaId > 0);
  btnCancelarNota.Enabled := LAberta and (FNotaId > 0);
  btnImportarXML.Enabled := True;
end;

procedure TfrmNotaEntrada.AtualizarStatusLabel(const AStatus: string);
begin
  case AStatus[1] of
    'A': begin lblStatusNota.Caption := 'Status: Aberta (não processada)'; lblStatusNota.Tag := 0; end;
    'P': begin lblStatusNota.Caption := 'Status: Processada'; lblStatusNota.Tag := 1; end;
    'C': begin lblStatusNota.Caption := 'Status: Cancelada'; lblStatusNota.Tag := 2; end;
  else
    begin lblStatusNota.Caption := 'Status: ' + AStatus; lblStatusNota.Tag := 1; end;
  end;
end;

procedure TfrmNotaEntrada.LimparCabecalho;
begin
  edtFornecedor.Clear;
  lblFornecedorDesc.Caption := '';
  edtNumero.Clear;
  edtSerie.Text := '1';
  edtModelo.Text := '55';
  edtChave.Clear;
  edtDataEmissao.Text := FormatDateTime('dd/mm/yyyy', Now);
  edtDataEntrada.Text := FormatDateTime('dd/mm/yyyy', Now);
  edtNatureza.Text := 'Compra para comercialização';
  edtCfop.Text := '1102';
  edtFrete.Text := '0,00';
  edtSeguro.Text := '0,00';
  edtOutras.Text := '0,00';
  edtDesconto.Text := '0,00';
  lblTotalProdutos.Caption := 'Produtos: R$ 0,00';
  lblTotalNota.Caption := 'Total da Nota: R$ 0,00';
  FFornecedorId := 0;
end;

procedure TfrmNotaEntrada.MostrarItem(AVisivel: Boolean);
begin
  pnlItem.Visible := AVisivel;
end;

procedure TfrmNotaEntrada.LimparItem;
begin
  edtProdutoItem.Clear;
  lblItemDesc.Caption := '';
  edtItemQtd.Text := '1';
  edtItemValor.Text := '0,00';
  edtItemDesconto.Text := '0,00';
  lblItemInfo.Caption := '';
  FProdutoItemId := 0;
  FItemId := 0;
  pnlItem.Caption := '';
end;

procedure TfrmNotaEntrada.AtualizarTotaisTela;
var
  LProdutos, LDesconto, LFrete, LSeguro, LOutras, LTotal: Double;
begin
  if not FItens.Active then
    Exit;
  if FItens.IsEmpty then
  begin
    lblTotalProdutos.Caption := 'Produtos: R$ 0,00';
    lblTotalNota.Caption := 'Total da Nota: R$ 0,00';
    Exit;
  end;

  LProdutos := 0;
  LDesconto := 0;
  FItens.DisableControls;
  try
    FItens.First;
    while not FItens.EOF do
    begin
      LProdutos := LProdutos + FItens.FieldByName('TOTAL').AsFloat;
      LDesconto := LDesconto + FItens.FieldByName('DESCONTO').AsFloat;
      FItens.Next;
    end;
    FItens.First;
  finally
    FItens.EnableControls;
  end;

  LFrete := StrToFloatDef(edtFrete.Text, 0);
  LSeguro := StrToFloatDef(edtSeguro.Text, 0);
  LOutras := StrToFloatDef(edtOutras.Text, 0);
  LTotal := LProdutos + LFrete + LSeguro + LOutras -
            StrToFloatDef(edtDesconto.Text, 0);

  lblTotalProdutos.Caption := 'Produtos (c/ desc. itens): R$ ' + FormatFloat('#,##0.00', LProdutos)
    + '   Descontos: R$ ' + FormatFloat('#,##0.00', LDesconto);
  lblTotalNota.Caption := 'Total da Nota: R$ ' + FormatFloat('#,##0.00', LTotal);
end;

procedure TfrmNotaEntrada.btnFiltrarClick(Sender: TObject);
begin
  CarregarNotas;
  ModoLista;
end;

procedure TfrmNotaEntrada.btnNovaNotaClick(Sender: TObject);
begin
  FNotaId := 0;
  LimparCabecalho;
  AtualizarStatusLabel('A');
  ModoEdicao;
  CarregarItens;   // ficará vazio (FNotaId = 0)
  CarregarNotas;   // mantém a lista coerente para quando voltar
  ModoEdicao;
  edtFornecedor.SetFocus;
end;

procedure TfrmNotaEntrada.btnAbrirNotaClick(Sender: TObject);
begin
  if FNotas.IsEmpty then
    Exit;
  AbrirNota(FNotas.FieldByName('ID').AsLargeInt);
end;

procedure TfrmNotaEntrada.dbGridNotasDblClick(Sender: TObject);
begin
  btnAbrirNotaClick(Sender);
end;

procedure TfrmNotaEntrada.AbrirNota(ANotaId: Int64);
var
  LQuery: TSQLQuery;
  LCondId: Int64;
  LI: Integer;
begin
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT N.*, COALESCE(F.NOME_FANTASIA, F.RAZAO_SOCIAL, '''') AS FORNECEDOR_NOME ' +
      'FROM NOTA_ENTRADA N LEFT JOIN FORNECEDOR F ON F.ID = N.FORNECEDOR_ID ' +
      'WHERE N.ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := ANotaId;
    LQuery.Open;
    if LQuery.IsEmpty then
    begin
      MessageDlg('Nota não encontrada.', mtWarning, [mbOK], 0);
      Exit;
    end;

    FNotaId := ANotaId;
    FFornecedorId := LQuery.FieldByName('FORNECEDOR_ID').AsLargeInt;
    edtFornecedor.Text := IntToStr(FFornecedorId);
    lblFornecedorDesc.Caption := Trim(LQuery.FieldByName('FORNECEDOR_NOME').AsString);
    edtNumero.Text := Trim(LQuery.FieldByName('NUMERO').AsString);
    edtSerie.Text := Trim(LQuery.FieldByName('SERIE').AsString);
    edtModelo.Text := Trim(LQuery.FieldByName('MODELO').AsString);
    edtChave.Text := Trim(LQuery.FieldByName('CHAVE_ACESSO').AsString);
    edtDataEmissao.Text := DataTexto(LQuery.FieldByName('DATA_EMISSAO'));
    if Trim(edtDataEmissao.Text) = '' then
      edtDataEmissao.Text := FormatDateTime('dd/mm/yyyy', Now);
    edtDataEntrada.Text := DataTexto(LQuery.FieldByName('DATA_ENTRADA'));
    if Trim(edtDataEntrada.Text) = '' then
      edtDataEntrada.Text := FormatDateTime('dd/mm/yyyy', Now);
    edtNatureza.Text := Trim(LQuery.FieldByName('NATUREZA_OPERACAO').AsString);
    edtCfop.Text := Trim(LQuery.FieldByName('CFOP').AsString);
    edtFrete.Text := FormatFloat('#,##0.00', LQuery.FieldByName('VALOR_FRETE').AsFloat);
    edtSeguro.Text := FormatFloat('#,##0.00', LQuery.FieldByName('VALOR_SEGURO').AsFloat);
    edtOutras.Text := FormatFloat('#,##0.00', LQuery.FieldByName('VALOR_OUTRAS').AsFloat);
    edtDesconto.Text := FormatFloat('#,##0.00', LQuery.FieldByName('VALOR_DESCONTO').AsFloat);

    // Seleciona a condição de pagamento gravada na nota
    LCondId := LQuery.FieldByName('CONDICAO_PAGAMENTO_ID').AsLargeInt;
    LI := 0;
    while LI < cmbCondicaoPagamento.Items.Count do
    begin
      if Int64(PtrInt(cmbCondicaoPagamento.Items.Objects[LI])) = LCondId then
      begin
        cmbCondicaoPagamento.ItemIndex := LI;
        Break;
      end;
      Inc(LI);
    end;

    AtualizarStatusLabel(Trim(LQuery.FieldByName('STATUS').AsString));
    CarregarItens;
    ModoEdicao;
  finally
    LQuery.Free;
  end;
end;

procedure TfrmNotaEntrada.btnBuscarFornecedorClick(Sender: TObject);
var
  LQuery: TSQLQuery;
  LTexto: string;
begin
  LTexto := Trim(edtFornecedor.Text);
  if LTexto = '' then
  begin
    MessageDlg('Informe o código, CNPJ ou nome do fornecedor.', mtInformation, [mbOK], 0);
    edtFornecedor.SetFocus;
    Exit;
  end;

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID, COALESCE(NOME_FANTASIA, RAZAO_SOCIAL) AS NOME FROM FORNECEDOR ' +
      'WHERE CAST(ID AS VARCHAR(20)) = :T ' +
      '   OR REPLACE(REPLACE(REPLACE(COALESCE(CPF_CNPJ, CNPJ), ''.'', ''''), ''/'', ''''), ''-'', '''') = ' +
      // CAST obrigatório: sem ele o Firebird infere o parâmetro como CHAR(1)
      // (ver comentário em ImportarXML)
      '      REPLACE(REPLACE(REPLACE(CAST(:T AS VARCHAR(40)), ''.'', ''''), ''/'', ''''), ''-'', '''') ' +
      '   OR UPPER(COALESCE(NOME_FANTASIA, RAZAO_SOCIAL)) STARTING WITH UPPER(:T) ' +
      'ORDER BY ID';
    LQuery.ParamByName('T').AsString := LTexto;
    LQuery.Open;
    if LQuery.IsEmpty then
    begin
      MessageDlg('Fornecedor não encontrado.', mtWarning, [mbOK], 0);
      FFornecedorId := 0;
      lblFornecedorDesc.Caption := '';
      Exit;
    end;
    FFornecedorId := LQuery.FieldByName('ID').AsLargeInt;
    edtFornecedor.Text := IntToStr(FFornecedorId);
    lblFornecedorDesc.Caption := Trim(LQuery.FieldByName('NOME').AsString);
  finally
    LQuery.Free;
  end;
end;

function TfrmNotaEntrada.SalvarCabecalho: Boolean;
var
  LQuery: TSQLQuery;
  LCondId: Int64;
begin
  Result := False;

  if FFornecedorId <= 0 then
  begin
    MessageDlg('Informe o fornecedor (código, CNPJ ou nome).', mtWarning, [mbOK], 0);
    edtFornecedor.SetFocus;
    Exit;
  end;
  if Trim(edtNumero.Text) = '' then
  begin
    MessageDlg('Informe o número do documento.', mtWarning, [mbOK], 0);
    edtNumero.SetFocus;
    Exit;
  end;

  LCondId := 0;
  if cmbCondicaoPagamento.ItemIndex >= 0 then
    LCondId := Int64(PtrInt(cmbCondicaoPagamento.Items.Objects[cmbCondicaoPagamento.ItemIndex]));

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FConexao.IniciarTransacao;

    if FNotaId = 0 then
    begin
      LQuery.SQL.Text :=
        'INSERT INTO NOTA_ENTRADA (EMPRESA_ID, FORNECEDOR_ID, NUMERO, SERIE, MODELO, CHAVE_ACESSO, ' +
        '  DATA_EMISSAO, DATA_ENTRADA, NATUREZA_OPERACAO, CFOP, VALOR_FRETE, VALOR_SEGURO, ' +
        '  VALOR_OUTRAS, VALOR_DESCONTO, VALOR_PRODUTOS, VALOR_TOTAL, STATUS, ' +
        '  CONDICAO_PAGAMENTO_ID, USUARIO_ID, DATA_CADASTRO) ' +
        'VALUES (:EMP, :FORN, :NUM, :SERIE, :MODELO, :CHAVE, :DEMI, :DENT, :NAT, :CFOP, ' +
        '  :FRETE, :SEGURO, :OUTRAS, :DESCONTO, 0, 0, ''A'', :COND, :USU, CURRENT_TIMESTAMP) ' +
        'RETURNING ID';
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.ParamByName('FORN').AsLargeInt := FFornecedorId;
      LQuery.ParamByName('NUM').AsString := Trim(edtNumero.Text);
      LQuery.ParamByName('SERIE').AsString := Trim(edtSerie.Text);
      LQuery.ParamByName('MODELO').AsString := Trim(edtModelo.Text);
      LQuery.ParamByName('CHAVE').AsString := Trim(edtChave.Text);
      LQuery.ParamByName('DEMI').AsDate := StrToDateDef(edtDataEmissao.Text, Now);
      LQuery.ParamByName('DENT').AsDate := StrToDateDef(edtDataEntrada.Text, Now);
      LQuery.ParamByName('NAT').AsString := Trim(edtNatureza.Text);
      LQuery.ParamByName('CFOP').AsString := Trim(edtCfop.Text);
      LQuery.ParamByName('FRETE').AsFloat := StrToFloatDef(edtFrete.Text, 0);
      LQuery.ParamByName('SEGURO').AsFloat := StrToFloatDef(edtSeguro.Text, 0);
      LQuery.ParamByName('OUTRAS').AsFloat := StrToFloatDef(edtOutras.Text, 0);
      LQuery.ParamByName('DESCONTO').AsFloat := StrToFloatDef(edtDesconto.Text, 0);
      if LCondId > 0 then
        LQuery.ParamByName('COND').AsLargeInt := LCondId
      else
        LQuery.ParamByName('COND').Clear;
      LQuery.ParamByName('USU').AsLargeInt := TSessao.GetInstance.UsuarioId;
      LQuery.Open;
      FNotaId := LQuery.FieldByName('ID').AsLargeInt;
      LQuery.Close;
    end
    else
    begin
      LQuery.SQL.Text :=
        'UPDATE NOTA_ENTRADA SET FORNECEDOR_ID = :FORN, NUMERO = :NUM, SERIE = :SERIE, ' +
        '  MODELO = :MODELO, CHAVE_ACESSO = :CHAVE, DATA_EMISSAO = :DEMI, ' +
        '  DATA_ENTRADA = :DENT, NATUREZA_OPERACAO = :NAT, CFOP = :CFOP, ' +
        '  VALOR_FRETE = :FRETE, VALOR_SEGURO = :SEGURO, VALOR_OUTRAS = :OUTRAS, ' +
        '  VALOR_DESCONTO = :DESCONTO, CONDICAO_PAGAMENTO_ID = :COND ' +
        'WHERE ID = :ID';
      LQuery.ParamByName('FORN').AsLargeInt := FFornecedorId;
      LQuery.ParamByName('NUM').AsString := Trim(edtNumero.Text);
      LQuery.ParamByName('SERIE').AsString := Trim(edtSerie.Text);
      LQuery.ParamByName('MODELO').AsString := Trim(edtModelo.Text);
      LQuery.ParamByName('CHAVE').AsString := Trim(edtChave.Text);
      LQuery.ParamByName('DEMI').AsDate := StrToDateDef(edtDataEmissao.Text, Now);
      LQuery.ParamByName('DENT').AsDate := StrToDateDef(edtDataEntrada.Text, Now);
      LQuery.ParamByName('NAT').AsString := Trim(edtNatureza.Text);
      LQuery.ParamByName('CFOP').AsString := Trim(edtCfop.Text);
      LQuery.ParamByName('FRETE').AsFloat := StrToFloatDef(edtFrete.Text, 0);
      LQuery.ParamByName('SEGURO').AsFloat := StrToFloatDef(edtSeguro.Text, 0);
      LQuery.ParamByName('OUTRAS').AsFloat := StrToFloatDef(edtOutras.Text, 0);
      LQuery.ParamByName('DESCONTO').AsFloat := StrToFloatDef(edtDesconto.Text, 0);
      if LCondId > 0 then
        LQuery.ParamByName('COND').AsLargeInt := LCondId
      else
        LQuery.ParamByName('COND').Clear;
      LQuery.ParamByName('ID').AsLargeInt := FNotaId;
      LQuery.ExecSQL;
    end;

    FService.RecalcularTotais(FNotaId);
    FConexao.Confirmar;
    Result := True;
  except
    on E: Exception do
    begin
      FConexao.Cancelar;
      MessageDlg('Erro ao gravar a nota: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
  LQuery.Free;
end;

procedure TfrmNotaEntrada.btnGravarClick(Sender: TObject);
var
  LNovo: Boolean;
begin
  LNovo := (FNotaId = 0);
  if not SalvarCabecalho then
    Exit;

  if LNovo then
    MessageDlg('Nota gravada. Agora inclua os itens e use "Processar" para ' +
      'dar entrada no estoque e gerar as contas a pagar.',
      mtInformation, [mbOK], 0)
  else
    MessageDlg('Nota atualizada.', mtInformation, [mbOK], 0);

  CarregarItens;
  CarregarNotas;
  ModoEdicao;
end;

function TfrmNotaEntrada.InserirItem(AProdutoId: Int64; const ADescricao: string;
  AQuantidade, AValorUnitario, ADesconto: Double): Boolean;
var
  LQuery: TSQLQuery;
  LNcm, LCfop, LCst: string;
  LAliq, LValorIcms: Double;
begin
  Result := False;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;

    // Dados fiscais herdados do produto (preparado para NF-e)
    LNcm := '';
    LCfop := Trim(edtCfop.Text);
    LCst := '';
    LAliq := 0;
    if AProdutoId > 0 then
    begin
      LQuery.SQL.Text :=
        'SELECT COALESCE(NCM, '''') AS NCM, COALESCE(CFOP_COMPRA, CFOP, '''') AS CFOP, ' +
        '       COALESCE(CST_ICMS, '''') AS CST, COALESCE(ALIQ_ICMS, 0) AS ALIQ ' +
        'FROM PRODUTO WHERE ID = :ID';
      LQuery.ParamByName('ID').AsLargeInt := AProdutoId;
      LQuery.Open;
      if not LQuery.IsEmpty then
      begin
        LNcm := Trim(LQuery.FieldByName('NCM').AsString);
        if Trim(LQuery.FieldByName('CFOP').AsString) <> '' then
          LCfop := Trim(LQuery.FieldByName('CFOP').AsString);
        LCst := Trim(LQuery.FieldByName('CST').AsString);
        LAliq := LQuery.FieldByName('ALIQ').AsFloat;
      end;
      LQuery.Close;
    end;

    LValorIcms := (AQuantidade * AValorUnitario) * LAliq / 100;

    FConexao.IniciarTransacao;

    if FItemId = 0 then
    begin
      LQuery.SQL.Text :=
        'INSERT INTO NOTA_ENTRADA_ITEM (NOTA_ENTRADA_ID, PRODUTO_ID, DESCRICAO, NCM, CFOP, ' +
        '  CST_ICMS, ALIQ_ICMS, VALOR_ICMS, QUANTIDADE, VALOR_UNITARIO, VALOR_TOTAL, ' +
        '  DESCONTO, ATUALIZA_ESTOQUE, ATUALIZA_CUSTO) ' +
        'VALUES (:NOTA, :PROD, :DESC, :NCM, :CFOP, :CST, :ALIQ, :VICMS, :QTD, :VUN, :VTOT, ' +
        '  :DESC2, ''S'', ''S'')';
    end
    else
    begin
      LQuery.SQL.Text :=
        'UPDATE NOTA_ENTRADA_ITEM SET PRODUTO_ID = :PROD, DESCRICAO = :DESC, NCM = :NCM, ' +
        '  CFOP = :CFOP, CST_ICMS = :CST, ALIQ_ICMS = :ALIQ, VALOR_ICMS = :VICMS, ' +
        '  QUANTIDADE = :QTD, VALOR_UNITARIO = :VUN, VALOR_TOTAL = :VTOT, DESCONTO = :DESC2 ' +
        'WHERE ID = :ID';
      LQuery.ParamByName('ID').AsLargeInt := FItemId;
    end;

    if FItemId = 0 then
      LQuery.ParamByName('NOTA').AsLargeInt := FNotaId;
    if AProdutoId > 0 then
      LQuery.ParamByName('PROD').AsLargeInt := AProdutoId
    else
      LQuery.ParamByName('PROD').Clear;
    LQuery.ParamByName('DESC').AsString := ADescricao;
    LQuery.ParamByName('NCM').AsString := LNcm;
    LQuery.ParamByName('CFOP').AsString := LCfop;
    LQuery.ParamByName('CST').AsString := LCst;
    LQuery.ParamByName('ALIQ').AsFloat := LAliq;
    LQuery.ParamByName('VICMS').AsFloat := LValorIcms;
    LQuery.ParamByName('QTD').AsFloat := AQuantidade;
    LQuery.ParamByName('VUN').AsFloat := AValorUnitario;
    LQuery.ParamByName('VTOT').AsFloat := AQuantidade * AValorUnitario;
    LQuery.ParamByName('DESC2').AsFloat := ADesconto;
    LQuery.ExecSQL;

    FService.RecalcularTotais(FNotaId);
    FConexao.Confirmar;
    Result := True;
  except
    on E: Exception do
    begin
      FConexao.Cancelar;
      MessageDlg('Erro ao gravar o item: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
  LQuery.Free;
end;

procedure TfrmNotaEntrada.btnIncluirItemClick(Sender: TObject);
begin
  if FNotaId = 0 then
  begin
    MessageDlg('Grave a nota antes de incluir itens.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if lblStatusNota.Tag <> 0 then
  begin
    MessageDlg('Somente notas em aberto podem ser alteradas.', mtWarning, [mbOK], 0);
    Exit;
  end;
  LimparItem;
  MostrarItem(True);
  pnlItem.Caption := 'Novo item';
  edtProdutoItem.SetFocus;
end;

procedure TfrmNotaEntrada.btnBuscarProdutoItemClick(Sender: TObject);
var
  LQuery: TSQLQuery;
  LTexto: string;
begin
  LTexto := Trim(edtProdutoItem.Text);
  if LTexto = '' then
  begin
    MessageDlg('Informe o código, código de barras ou descrição do produto.',
      mtInformation, [mbOK], 0);
    edtProdutoItem.SetFocus;
    Exit;
  end;

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID, CODIGO, DESCRICAO, COALESCE(PRECO_CUSTO, 0) AS CUSTO FROM PRODUTO ' +
      'WHERE CODIGO = :T OR CODIGO_BARRAS = :T OR CAST(ID AS VARCHAR(20)) = :T ' +
      '   OR UPPER(DESCRICAO) STARTING WITH UPPER(:T) ORDER BY ID';
    LQuery.ParamByName('T').AsString := LTexto;
    LQuery.Open;
    if LQuery.IsEmpty then
    begin
      MessageDlg('Produto não encontrado.', mtWarning, [mbOK], 0);
      FProdutoItemId := 0;
      lblItemDesc.Caption := '';
      Exit;
    end;
    FProdutoItemId := LQuery.FieldByName('ID').AsLargeInt;
    edtProdutoItem.Text := Trim(LQuery.FieldByName('CODIGO').AsString);
    lblItemDesc.Caption := Trim(LQuery.FieldByName('DESCRICAO').AsString);
    if StrToFloatDef(edtItemValor.Text, 0) <= 0 then
      edtItemValor.Text := FormatFloat('#,##0.00', LQuery.FieldByName('CUSTO').AsFloat);
    lblItemInfo.Caption := 'Item vinculado ao produto ID ' + IntToStr(FProdutoItemId);
  finally
    LQuery.Free;
  end;
end;

procedure TfrmNotaEntrada.btnConfirmarItemClick(Sender: TObject);
var
  LDescricao: string;
  LQtd, LValor, LDesconto: Double;
begin
  if FNotaId = 0 then
  begin
    MessageDlg('Grave a nota antes de incluir itens.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if (FProdutoItemId <= 0) and (LblItemDesc.Caption = '') then
  begin
    MessageDlg('Selecione o produto do item.', mtWarning, [mbOK], 0);
    edtProdutoItem.SetFocus;
    Exit;
  end;

  LQtd := StrToFloatDef(edtItemQtd.Text, 0);
  LValor := StrToFloatDef(edtItemValor.Text, 0);
  LDesconto := StrToFloatDef(edtItemDesconto.Text, 0);

  if LQtd <= 0 then
  begin
    MessageDlg('Informe uma quantidade maior que zero.', mtWarning, [mbOK], 0);
    edtItemQtd.SetFocus;
    Exit;
  end;
  if LValor < 0 then
  begin
    MessageDlg('Informe um valor unitário válido.', mtWarning, [mbOK], 0);
    edtItemValor.SetFocus;
    Exit;
  end;

  LDescricao := lblItemDesc.Caption;
  if Trim(LDescricao) = '' then
    LDescricao := Trim(edtProdutoItem.Text);

  if not InserirItem(FProdutoItemId, LDescricao, LQtd, LValor, LDesconto) then
    Exit;

  MostrarItem(False);
  CarregarItens;
  CarregarNotas;
  ModoEdicao;
end;

procedure TfrmNotaEntrada.btnCancelarItemClick(Sender: TObject);
begin
  MostrarItem(False);
  LimparItem;
end;

procedure TfrmNotaEntrada.dbGridItensDblClick(Sender: TObject);
begin
  if FItens.IsEmpty then
    Exit;
  if lblStatusNota.Tag <> 0 then
  begin
    MessageDlg('Somente notas em aberto podem ser alteradas.', mtWarning, [mbOK], 0);
    Exit;
  end;

  FItemId := FItens.FieldByName('ID').AsLargeInt;
  FProdutoItemId := FItens.FieldByName('PRODUTO_ID').AsLargeInt;
  edtProdutoItem.Text := Trim(FItens.FieldByName('CODIGO').AsString);
  lblItemDesc.Caption := Trim(FItens.FieldByName('DESCRICAO').AsString);
  edtItemQtd.Text := FormatFloat('#,##0.####', FItens.FieldByName('QUANTIDADE').AsFloat);
  edtItemValor.Text := FormatFloat('#,##0.00', FItens.FieldByName('VALOR_UNITARIO').AsFloat);
  edtItemDesconto.Text := FormatFloat('#,##0.00', FItens.FieldByName('DESCONTO').AsFloat);
  lblItemInfo.Caption := 'Editando item existente';
  MostrarItem(True);
  pnlItem.Caption := 'Editando item';
  edtProdutoItem.SetFocus;
end;

procedure TfrmNotaEntrada.btnExcluirItemClick(Sender: TObject);
begin
  if FItens.IsEmpty then
  begin
    MessageDlg('Selecione um item na lista.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if lblStatusNota.Tag <> 0 then
  begin
    MessageDlg('Somente notas em aberto podem ser alteradas.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if MessageDlg('Remover o item "' + Trim(FItens.FieldByName('DESCRICAO').AsString) + '"?',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;

  try
    FService.ExcluirItem(FItens.FieldByName('ID').AsLargeInt);
    FService.RecalcularTotais(FNotaId);
    CarregarItens;
  except
    on E: Exception do
      MessageDlg('Erro ao excluir: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmNotaEntrada.btnProcessarClick(Sender: TObject);
var
  LItens, LParcelas: Integer;
  LCond: Int64;
begin
  if FNotaId = 0 then
    Exit;

  LItens := FService.QuantidadeItens(FNotaId);
  if LItens = 0 then
  begin
    MessageDlg('A nota não possui itens. Inclua os itens antes de processar.',
      mtWarning, [mbOK], 0);
    Exit;
  end;

  LCond := 0;
  if cmbCondicaoPagamento.ItemIndex >= 0 then
    LCond := Int64(PtrInt(cmbCondicaoPagamento.Items.Objects[cmbCondicaoPagamento.ItemIndex]));
  LParcelas := ParcelasDaCondicao(FConexao, LCond);

  if MessageDlg('Confirmar a ENTRADA desta nota?' + sLineBreak + sLineBreak +
    'Serão processados ' + IntToStr(LItens) + ' item(ns):' + sLineBreak +
    '- entrada no estoque (com atualização do custo médio);' + sLineBreak +
    '- geração das contas a pagar em ' + IntToStr(LParcelas) + ' parcela(s).',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;

  try
    FService.Processar(FNotaId);
    MessageDlg('Entrada processada com sucesso!' + sLineBreak + sLineBreak +
      'Estoque atualizado e contas a pagar geradas.', mtInformation, [mbOK], 0);
    AbrirNota(FNotaId);
    CarregarNotas;
    CarregarItens;
    ModoEdicao;
  except
    on E: Exception do
      MessageDlg('Não foi possível processar: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmNotaEntrada.btnCancelarNotaClick(Sender: TObject);
begin
  if FNotaId = 0 then
    Exit;
  if MessageDlg('Cancelar esta nota de entrada?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  try
    FService.Cancelar(FNotaId);
    AbrirNota(FNotaId);
    CarregarNotas;
    ModoEdicao;
  except
    on E: Exception do
      MessageDlg('Não foi possível cancelar: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmNotaEntrada.btnImportarXMLClick(Sender: TObject);
begin
  OpenDialog1.Filter := 'NF-e (*.xml)|*.xml|Todos os arquivos (*.*)|*.*';
  OpenDialog1.Title := 'Selecione o XML da NF-e de entrada';
  if not OpenDialog1.Execute then
    Exit;
  ImportarXML(OpenDialog1.FileName);
end;

procedure TfrmNotaEntrada.ImportarXML(const AArquivo: string);
var
  LTexto: string;
  LLista: TStringList;
  LBloco, LProd: string;
  LChave, LNome, LNumero: string;
  LFornecId: Int64;
  LI, LIncluidos, LSemProduto, LJ: Integer;
  LQtd, LValor, LDesconto: Double;
  LProdId: Int64;
  LQuery: TSQLQuery;
  LHArquivo: TextFile;
  LLinha: string;
begin
  // Lê o arquivo XML inteiro
  LTexto := '';
  AssignFile(LHArquivo, AArquivo);
  try
    Reset(LHArquivo);
    while not System.EOF(LHArquivo) do
    begin
      ReadLn(LHArquivo, LLinha);
      LTexto := LTexto + LLinha;
    end;
  finally
    CloseFile(LHArquivo);
  end;

  if Trim(LTexto) = '' then
  begin
    MessageDlg('Arquivo XML vazio ou ilegível.', mtWarning, [mbOK], 0);
    Exit;
  end;

  // Cabeçalho
  LChave := '';
  LLista := TagBlocos(LTexto, 'infNFe');
  if LLista.Count > 0 then
    LBloco := LLista[0]
  else
    LBloco := LTexto;

  // Chave de acesso: atributo Id="NFe<44 dígitos>" na tag infNFe
  LI := Pos('Id="', LTexto);
  if LI > 0 then
  begin
    LJ := PosEx('"', LTexto, LI + 4);
    if LJ > 0 then
      LChave := Trim(Copy(LTexto, LI + 4, LJ - LI - 4));
  end;
  if (LChave <> '') and (Copy(LChave, 1, 3) = 'NFe') then
    LChave := Copy(LChave, 4, Length(LChave));

  if FNotaId = 0 then
  begin
    // Garante um documento gravado para receber os itens
    edtNumero.Text := TagTexto(LBloco, 'nNF');
    if edtNumero.Text = '' then
      edtNumero.Text := '1';
    edtSerie.Text := TagTexto(LBloco, 'serie');
    if Trim(edtSerie.Text) = '' then
      edtSerie.Text := '1';
    edtModelo.Text := TagTexto(LBloco, 'mod');
    if Trim(edtModelo.Text) = '' then
      edtModelo.Text := '55';
    edtChave.Text := Copy(Trim(LChave), 1, 44);
  end;

  LNome := TagTexto(LBloco, 'xNome');
  // Fornecedor pelo CNPJ do emitente
  LFornecId := 0;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM FORNECEDOR WHERE ' +
      'REPLACE(REPLACE(REPLACE(COALESCE(CPF_CNPJ, CNPJ, ''''), ''.'', ''''), ''/'', ''''), ''-'', '''') = ' +
      // CAST obrigatório: sem ele o Firebird infere o parâmetro como CHAR(1)
      // dentro do REPLACE aninhado e o Execute falha com "string right truncation"
      'REPLACE(REPLACE(REPLACE(CAST(:DOC AS VARCHAR(40)), ''.'', ''''), ''/'', ''''), ''-'', '''') ' +
      'ORDER BY ID';
    LQuery.ParamByName('DOC').AsString := Trim(TagTexto(LBloco, 'CNPJ'));
    LQuery.Open;
    if not LQuery.IsEmpty then
      LFornecId := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;

    if LFornecId = 0 then
    begin
      // Tenta pelo nome (razão social / fantasia)
      LQuery.SQL.Text :=
        'SELECT FIRST 1 ID FROM FORNECEDOR WHERE UPPER(COALESCE(RAZAO_SOCIAL, NOME_FANTASIA)) = UPPER(:NOME) ' +
        'OR UPPER(COALESCE(NOME_FANTASIA, RAZAO_SOCIAL)) = UPPER(:NOME) ORDER BY ID';
      LQuery.ParamByName('NOME').AsString := Trim(LNome);
      LQuery.Open;
      if not LQuery.IsEmpty then
        LFornecId := LQuery.FieldByName('ID').AsLargeInt;
    end;
  finally
    LQuery.Free;
  end;

  if LFornecId = 0 then
  begin
    MessageDlg('Não identifiquei o fornecedor "' + Trim(LNome) + '" no cadastro.' + sLineBreak +
      'Cadastre-o (com o CNPJ do XML) ou informe o fornecedor manualmente antes de gravar.',
      mtWarning, [mbOK], 0);
    Exit;
  end;

  FFornecedorId := LFornecId;
  edtFornecedor.Text := IntToStr(LFornecId);
  lblFornecedorDesc.Caption := Trim(LNome);
  if Trim(edtNatureza.Text) = '' then
    edtNatureza.Text := Trim(TagTexto(LBloco, 'natOp'));
  if Trim(TagTexto(LBloco, 'CFOP')) <> '' then
    edtCfop.Text := Trim(TagTexto(LBloco, 'CFOP'));
  if Trim(TagTexto(LBloco, 'vFrete')) <> '' then
    edtFrete.Text := FormatFloat('#,##0.00', NumXml(TagTexto(LBloco, 'vFrete')));
  if Trim(TagTexto(LBloco, 'vSeg')) <> '' then
    edtSeguro.Text := FormatFloat('#,##0.00', NumXml(TagTexto(LBloco, 'vSeg')));
  if Trim(TagTexto(LBloco, 'vDesc')) <> '' then
    edtDesconto.Text := FormatFloat('#,##0.00', NumXml(TagTexto(LBloco, 'vDesc')));
  if Trim(TagTexto(LBloco, 'dhEmi')) <> '' then
    edtDataEmissao.Text := FormatDateTime('dd/mm/yyyy', DataXml(TagTexto(LBloco, 'dhEmi')));

  // Grava o cabeçalho para poder inserir itens
  if not SalvarCabecalho then
    Exit;

  // Itens
  LLista.Free;
  LLista := TagBlocos(LTexto, 'det');
  LIncluidos := 0;
  LSemProduto := 0;
  for LI := 0 to LLista.Count - 1 do
  begin
    LProd := TagTexto(LLista[LI], 'prod');

    LProdId := 0;
    LQuery := TSQLQuery.Create(nil);
    try
      LQuery.DataBase := FConexao.Connection;
      LQuery.Transaction := FConexao.Transaction;
      LQuery.SQL.Text :=
        'SELECT FIRST 1 ID FROM PRODUTO WHERE CODIGO = :C OR CODIGO_BARRAS = :C ORDER BY ID';
      LQuery.ParamByName('C').AsString := Trim(TagTexto(LProd, 'cProd'));
      LQuery.Open;
      if not LQuery.IsEmpty then
        LProdId := LQuery.FieldByName('ID').AsLargeInt;
      LQuery.Close;
      if (LProdId = 0) and (Trim(TagTexto(LProd, 'cEAN')) <> '') then
      begin
        LQuery.SQL.Text := 'SELECT FIRST 1 ID FROM PRODUTO WHERE CODIGO_BARRAS = :C ORDER BY ID';
        LQuery.ParamByName('C').AsString := Trim(TagTexto(LProd, 'cEAN'));
        LQuery.Open;
        if not LQuery.IsEmpty then
          LProdId := LQuery.FieldByName('ID').AsLargeInt;
      end;
    finally
      LQuery.Free;
    end;

    LQtd := NumXml(TagTexto(LProd, 'qCom'));
    LValor := NumXml(TagTexto(LProd, 'vUnCom'));
    LDesconto := NumXml(TagTexto(LProd, 'vDesc'));
    if LQtd <= 0 then
      LQtd := 1;

    if LProdId = 0 then
      Inc(LSemProduto);

    FItemId := 0;
    if InserirItem(LProdId, Trim(TagTexto(LProd, 'xProd')), LQtd, LValor, LDesconto) then
      Inc(LIncluidos);
  end;
  LLista.Free;

  CarregarItens;
  CarregarNotas;
  ModoEdicao;

  MessageDlg('XML importado.' + sLineBreak +
    'Itens incluídos: ' + IntToStr(LIncluidos) + sLineBreak +
    'Itens sem produto vinculado (ajuste pelo duplo clique): ' + IntToStr(LSemProduto),
    mtInformation, [mbOK], 0);
end;

procedure TfrmNotaEntrada.btnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
