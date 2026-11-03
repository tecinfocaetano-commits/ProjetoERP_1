unit uFrmNotaSaida;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Módulo 2 - Nota de Saída (faturamento de venda)

  Tela de faturamento:
    - lista as notas de saída já geradas (filtro por período/status);
    - "Nova do Pedido" mostra os pedidos de venda pendentes e gera a
      nota de saída escolhida (itens copiados do pedido);
    - permite ajustar cliente, número/série/modelo, datas,
      natureza/CFOP, condição de pagamento e despesas acessórias;
    - "Faturar" baixa o estoque, gera as parcelas em CONTA_RECEBER,
      apura a chave de acesso e marca o pedido como faturado;
    - "Cancelar / Estornar" cancela uma nota aberta ou estorna uma
      nota já faturada (devolve o estoque e cancela as parcelas);
    - "Exportar XML" grava o XML da NF-e (gancho para o ACBr emitir
      o documento com assinatura e transmissão à SEFAZ).
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, DateUtils,
  uConexao, uSessao, uNotaSaidaService, uPedidoStatus;

type
  { TfrmNotaSaida }
  TfrmNotaSaida = class(TForm)
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
    btnNovaDoPedido: TBitBtn;
    btnAbrirNota: TBitBtn;
    btnGravar: TBitBtn;
    btnFaturar: TBitBtn;
    btnCancelarNota: TBitBtn;
    btnExportarXML: TBitBtn;
    btnFechar: TBitBtn;
    pnlLista: TPanel;
    dbGridNotas: TDBGrid;
    pnlPedidos: TPanel;
    lblPedidosTitulo: TLabel;
    dbGridPedidos: TDBGrid;
    btnGerarNota: TBitBtn;
    btnVoltarPedidos: TBitBtn;
    pnlEdicao: TPanel;
    pnlCabecalho: TPanel;
    lblCliente: TLabel;
    edtCliente: TEdit;
    btnBuscarCliente: TBitBtn;
    lblClienteDesc: TLabel;
    lblNumero: TLabel;
    edtNumero: TEdit;
    lblSerie: TLabel;
    edtSerie: TEdit;
    lblModelo: TLabel;
    edtModelo: TEdit;
    lblDataEmissao: TLabel;
    edtDataEmissao: TEdit;
    lblDataSaida: TLabel;
    edtDataSaida: TEdit;
    lblChave: TLabel;
    edtChave: TEdit;
    lblNatureza: TLabel;
    edtNatureza: TEdit;
    lblCfop: TLabel;
    edtCfop: TEdit;
    lblCondPagto: TLabel;
    cmbCondicaoPagamento: TComboBox;
    lblStatusNota: TLabel;
    lblPedidoOrigem: TLabel;
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
    dbGridItens: TDBGrid;
    DataSourceNotas: TDataSource;
    DataSourceItens: TDataSource;
    DataSourcePedidos: TDataSource;
    SaveDialog1: TSaveDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnFiltrarClick(Sender: TObject);
    procedure btnNovaDoPedidoClick(Sender: TObject);
    procedure btnVoltarPedidosClick(Sender: TObject);
    procedure btnGerarNotaClick(Sender: TObject);
    procedure btnAbrirNotaClick(Sender: TObject);
    procedure btnBuscarClienteClick(Sender: TObject);
    procedure btnGravarClick(Sender: TObject);
    procedure btnFaturarClick(Sender: TObject);
    procedure btnCancelarNotaClick(Sender: TObject);
    procedure btnExportarXMLClick(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
    procedure dbGridNotasDblClick(Sender: TObject);
    procedure dbGridPedidosDblClick(Sender: TObject);
  private
    FConexao: TConexao;
    FNotas: TSQLQuery;
    FItens: TSQLQuery;
    FPedidos: TSQLQuery;
    FService: TNotaSaidaService;
    FNotaId: Int64;
    FClienteId: Int64;
    FPedidoId: Int64;

    procedure CarregarComboStatus;
    procedure CarregarComboCondicao;
    procedure CarregarNotas;
    procedure CarregarPedidos;
    procedure CarregarItens;
    procedure ModoLista;
    procedure ModoPedidos;
    procedure ModoEdicao;
    procedure LimparCabecalho;
    procedure AbrirNota(ANotaId: Int64);
    procedure AtualizarStatusLabel(const AStatus: string);
    procedure AtualizarTotaisTela;
    procedure SetCamposEdicao(AHabilitado: Boolean);
    function  SalvarCabecalho: Boolean;
    function  CondicaoSelecionada: Int64;
  end;

var
  frmNotaSaida: TfrmNotaSaida;

implementation

{$R *.lfm}

{ Converte um campo DATE do banco em texto dd/mm/aaaa ('' quando vazio). }
function DataTexto(AField: TField): string;
begin
  if (AField = nil) or AField.IsNull then
    Result := ''
  else
    Result := FormatDateTime('dd/mm/yyyy', AField.AsDateTime);
end;

procedure TfrmNotaSaida.FormCreate(Sender: TObject);
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

  FPedidos := TSQLQuery.Create(Self);
  FPedidos.DataBase := FConexao.Connection;
  FPedidos.Transaction := FConexao.Transaction;
  DataSourcePedidos.DataSet := FPedidos;

  FService := TNotaSaidaService.Create;
  FNotaId := 0;
  FClienteId := 0;
  FPedidoId := 0;
end;

procedure TfrmNotaSaida.FormShow(Sender: TObject);
begin
  CarregarComboStatus;
  CarregarComboCondicao;
  edtFiltroDe.Text := FormatDateTime('dd/mm/yyyy', IncMonth(Now, -3));
  edtFiltroAte.Text := FormatDateTime('dd/mm/yyyy', Now);
  ModoLista;
  CarregarNotas;
  ModoLista;
end;

procedure TfrmNotaSaida.CarregarComboStatus;
begin
  cmbFiltroStatus.Items.Clear;
  cmbFiltroStatus.Items.Add('Todos');
  cmbFiltroStatus.Items.Add('Aberta (não faturada)');
  cmbFiltroStatus.Items.Add('Faturada');
  cmbFiltroStatus.Items.Add('Cancelada');
  cmbFiltroStatus.ItemIndex := 0;
end;

procedure TfrmNotaSaida.CarregarComboCondicao;
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

function TfrmNotaSaida.CondicaoSelecionada: Int64;
begin
  Result := 0;
  if cmbCondicaoPagamento.ItemIndex >= 0 then
    Result := Int64(PtrInt(cmbCondicaoPagamento.Items.Objects[cmbCondicaoPagamento.ItemIndex]));
end;

procedure TfrmNotaSaida.CarregarNotas;
var
  LStatus: string;
begin
  if FNotas.Active then
    FNotas.Close;

  FNotas.SQL.Text :=
    'SELECT N.ID, N.NUMERO, N.SERIE, N.MODELO, N.DATA_SAIDA, N.VALOR_TOTAL, ' +
    '  N.STATUS, N.CHAVE_ACESSO, COALESCE(C.NOME, ''(sem cliente)'') AS CLIENTE, ' +
    '  CASE N.STATUS WHEN ''A'' THEN ''Aberta'' WHEN ''P'' THEN ''Faturada'' ' +
    '       WHEN ''C'' THEN ''Cancelada'' ELSE N.STATUS END AS STATUS_DESC ' +
    'FROM NOTA_SAIDA N LEFT JOIN PESSOA C ON C.ID = N.CLIENTE_ID AND C.TIPO = ''C'' ' +
    'WHERE N.DATA_SAIDA BETWEEN :DI AND :DF';

  case cmbFiltroStatus.ItemIndex of
    1: LStatus := 'A';
    2: LStatus := 'P';
    3: LStatus := 'C';
  else
    LStatus := '';
  end;
  if LStatus <> '' then
    FNotas.SQL.Text := FNotas.SQL.Text + ' AND N.STATUS = :STATUS';

  FNotas.SQL.Text := FNotas.SQL.Text + ' ORDER BY N.DATA_SAIDA DESC, N.ID DESC';

  FNotas.ParamByName('DI').AsDate := StrToDateDef(edtFiltroDe.Text, IncMonth(Now, -3));
  FNotas.ParamByName('DF').AsDate := StrToDateDef(edtFiltroAte.Text, Now) + 1;
  if LStatus <> '' then
    FNotas.ParamByName('STATUS').AsString := LStatus;
  FNotas.Open;
end;

procedure TfrmNotaSaida.CarregarPedidos;
begin
  if FPedidos.Active then
    FPedidos.Close;
  // Somente pedidos que ainda podem ser faturados (sem nota de saída ativa)
  FPedidos.SQL.Text :=
    'SELECT PV.ID, PV.NUMERO, PV.DATA_EMISSAO, PV.TOTAL, PV.STATUS, ' +
    '  COALESCE(C.NOME, ''(sem cliente)'') AS CLIENTE, ' +
    '  CP.DESCRICAO AS CONDICAO, ' +
    '  (SELECT COUNT(*) FROM ITEM_PEDIDO I WHERE I.PEDIDO_VENDA_ID = PV.ID) AS ITENS, ' +
    '  ' + SqlCaseStatusPedido('PV.STATUS') + ' AS SITUACAO ' +
    'FROM PEDIDO_VENDA PV ' +
    '  LEFT JOIN PESSOA C ON C.ID = PV.CLIENTE_ID AND C.TIPO = ''C'' ' +
    '  LEFT JOIN CONDICAO_PAGAMENTO CP ON CP.ID = PV.CONDICAO_PAGAMENTO_ID ' +
    'WHERE PV.STATUS IN (''P'', ''A'') ' +
    '  AND NOT EXISTS (SELECT 1 FROM NOTA_SAIDA NS ' +
    '                  WHERE NS.PEDIDO_VENDA_ID = PV.ID AND NS.STATUS <> ''C'') ' +
    'ORDER BY PV.ID DESC';
  FPedidos.Open;
end;

procedure TfrmNotaSaida.CarregarItens;
begin
  if FItens.Active then
    FItens.Close;
  FItens.SQL.Text :=
    'SELECT I.ID, I.PRODUTO_ID, COALESCE(P.CODIGO, '''') AS CODIGO, I.DESCRICAO, ' +
    '  COALESCE(I.UNIDADE, '''') AS UNIDADE, I.QUANTIDADE, I.VALOR_UNITARIO, I.DESCONTO, ' +
    // CAST necessário: sem ele a multiplicação vira NUMERIC(18,8) e o SQLDB
    // devolve NULL (ver comentário em uNotaSaidaService.RecalcularTotais)
    '  CAST((I.QUANTIDADE * I.VALOR_UNITARIO) AS NUMERIC(18,4)) AS TOTAL, ' +
    '  I.CFOP, CAST(COALESCE(I.SALDO_APOS, 0) AS NUMERIC(18,4)) AS SALDO_APOS, ' +
    '  CASE WHEN (I.PRODUTO_ID IS NULL OR I.PRODUTO_ID = 0) THEN ''sem produto'' ' +
    '       ELSE '''' END AS AVISO ' +
    'FROM NOTA_SAIDA_ITEM I LEFT JOIN PRODUTO P ON P.ID = I.PRODUTO_ID ' +
    'WHERE I.NOTA_SAIDA_ID = :ID ORDER BY I.ID';
  FItens.ParamByName('ID').AsLargeInt := FNotaId;
  FItens.Open;
  AtualizarTotaisTela;
end;

procedure TfrmNotaSaida.SetCamposEdicao(AHabilitado: Boolean);
begin
  edtCliente.Enabled          := AHabilitado;
  btnBuscarCliente.Enabled    := AHabilitado;
  edtNumero.Enabled           := AHabilitado;
  edtSerie.Enabled            := AHabilitado;
  edtModelo.Enabled           := AHabilitado;
  edtDataEmissao.Enabled      := AHabilitado;
  edtDataSaida.Enabled        := AHabilitado;
  edtNatureza.Enabled         := AHabilitado;
  edtCfop.Enabled             := AHabilitado;
  cmbCondicaoPagamento.Enabled := AHabilitado;
  edtFrete.Enabled            := AHabilitado;
  edtSeguro.Enabled           := AHabilitado;
  edtOutras.Enabled           := AHabilitado;
end;

procedure TfrmNotaSaida.ModoLista;
begin
  pnlLista.Visible := True;
  pnlPedidos.Visible := False;
  pnlEdicao.Visible := False;
  btnNovaDoPedido.Enabled := True;
  btnAbrirNota.Enabled := not FNotas.IsEmpty;
  btnGravar.Enabled := False;
  btnFaturar.Enabled := False;
  btnCancelarNota.Enabled := False;
  btnExportarXML.Enabled := False;
end;

procedure TfrmNotaSaida.ModoPedidos;
begin
  pnlLista.Visible := False;
  pnlPedidos.Visible := True;
  pnlEdicao.Visible := False;
  btnNovaDoPedido.Enabled := False;
  btnAbrirNota.Enabled := False;
  btnGravar.Enabled := False;
  btnFaturar.Enabled := False;
  btnCancelarNota.Enabled := False;
  btnExportarXML.Enabled := False;
  btnGerarNota.Enabled := not FPedidos.IsEmpty;
end;

procedure TfrmNotaSaida.ModoEdicao;
var
  LAberta, LFaturada: Boolean;
begin
  pnlLista.Visible := False;
  pnlPedidos.Visible := False;
  pnlEdicao.Visible := True;

  LAberta := (FNotaId > 0) and (lblStatusNota.Tag = 0);
  LFaturada := (FNotaId > 0) and (lblStatusNota.Tag = 1);

  btnNovaDoPedido.Enabled := True;
  btnAbrirNota.Enabled := False;
  btnGravar.Enabled := LAberta;
  btnFaturar.Enabled := LAberta;
  btnCancelarNota.Enabled := LAberta or LFaturada;
  btnExportarXML.Enabled := FNotaId > 0;
  SetCamposEdicao(LAberta);
end;

procedure TfrmNotaSaida.AtualizarStatusLabel(const AStatus: string);
begin
  if AStatus = '' then
  begin
    lblStatusNota.Caption := 'Status: Aberta (não faturada)';
    lblStatusNota.Tag := 0;
    Exit;
  end;
  case AStatus[1] of
    'A': begin lblStatusNota.Caption := 'Status: Aberta (não faturada)'; lblStatusNota.Tag := 0; end;
    'P': begin lblStatusNota.Caption := 'Status: Faturada'; lblStatusNota.Tag := 1; end;
    'C': begin lblStatusNota.Caption := 'Status: Cancelada'; lblStatusNota.Tag := 2; end;
  else
    begin lblStatusNota.Caption := 'Status: ' + AStatus; lblStatusNota.Tag := 1; end;
  end;
end;

procedure TfrmNotaSaida.LimparCabecalho;
begin
  edtCliente.Clear;
  lblClienteDesc.Caption := '';
  edtNumero.Clear;
  edtSerie.Text := '1';
  edtModelo.Text := '55';
  edtDataEmissao.Text := FormatDateTime('dd/mm/yyyy', Now);
  edtDataSaida.Text := FormatDateTime('dd/mm/yyyy', Now);
  edtChave.Clear;
  edtNatureza.Text := 'VENDA DE MERCADORIA';
  edtCfop.Text := '5102';
  edtFrete.Text := '0,00';
  edtSeguro.Text := '0,00';
  edtOutras.Text := '0,00';
  edtDesconto.Text := '0,00';
  lblTotalProdutos.Caption := 'Produtos: R$ 0,00';
  lblTotalNota.Caption := 'Total da Nota: R$ 0,00';
  lblPedidoOrigem.Caption := '';
  FClienteId := 0;
  FPedidoId := 0;
end;

procedure TfrmNotaSaida.AtualizarTotaisTela;
var
  LProdutos, LDesconto, LFrete, LSeguro, LOutras, LTotal: Double;
begin
  if not FItens.Active then
    Exit;
  if FItens.IsEmpty then
  begin
    edtDesconto.Text := '0,00';
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

  LFrete  := StrToFloatDef(edtFrete.Text, 0);
  LSeguro := StrToFloatDef(edtSeguro.Text, 0);
  LOutras := StrToFloatDef(edtOutras.Text, 0);
  LTotal := LProdutos - LDesconto + LFrete + LSeguro + LOutras;

  // O desconto é a soma dos descontos dos itens (vem do pedido)
  edtDesconto.Text := FormatFloat('#,##0.00', LDesconto);
  lblTotalProdutos.Caption := 'Produtos: R$ ' + FormatFloat('#,##0.00', LProdutos)
    + '   Descontos: R$ ' + FormatFloat('#,##0.00', LDesconto);
  lblTotalNota.Caption := 'Total da Nota: R$ ' + FormatFloat('#,##0.00', LTotal);
end;

procedure TfrmNotaSaida.AbrirNota(ANotaId: Int64);
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
      'SELECT N.*, COALESCE(C.NOME, '''') AS CLIENTE_NOME, PV.NUMERO AS PEDIDO_NUMERO ' +
      'FROM NOTA_SAIDA N ' +
      '  LEFT JOIN PESSOA C ON C.ID = N.CLIENTE_ID AND C.TIPO = ''C'' ' +
      '  LEFT JOIN PEDIDO_VENDA PV ON PV.ID = N.PEDIDO_VENDA_ID ' +
      'WHERE N.ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := ANotaId;
    LQuery.Open;
    if LQuery.IsEmpty then
    begin
      MessageDlg('Nota de saída não encontrada.', mtWarning, [mbOK], 0);
      Exit;
    end;

    FNotaId := ANotaId;
    FClienteId := LQuery.FieldByName('CLIENTE_ID').AsLargeInt;
    FPedidoId := LQuery.FieldByName('PEDIDO_VENDA_ID').AsLargeInt;

    if FClienteId > 0 then
      edtCliente.Text := IntToStr(FClienteId)
    else
      edtCliente.Clear;
    lblClienteDesc.Caption := Trim(LQuery.FieldByName('CLIENTE_NOME').AsString);
    edtNumero.Text := Trim(LQuery.FieldByName('NUMERO').AsString);
    edtSerie.Text := Trim(LQuery.FieldByName('SERIE').AsString);
    edtModelo.Text := Trim(LQuery.FieldByName('MODELO').AsString);
    edtChave.Text := Trim(LQuery.FieldByName('CHAVE_ACESSO').AsString);
    edtDataEmissao.Text := DataTexto(LQuery.FieldByName('DATA_EMISSAO'));
    if Trim(edtDataEmissao.Text) = '' then
      edtDataEmissao.Text := FormatDateTime('dd/mm/yyyy', Now);
    edtDataSaida.Text := DataTexto(LQuery.FieldByName('DATA_SAIDA'));
    if Trim(edtDataSaida.Text) = '' then
      edtDataSaida.Text := FormatDateTime('dd/mm/yyyy', Now);
    edtNatureza.Text := Trim(LQuery.FieldByName('NATUREZA_OPERACAO').AsString);
    edtCfop.Text := Trim(LQuery.FieldByName('CFOP').AsString);
    edtFrete.Text := FormatFloat('#,##0.00', LQuery.FieldByName('VALOR_FRETE').AsFloat);
    edtSeguro.Text := FormatFloat('#,##0.00', LQuery.FieldByName('VALOR_SEGURO').AsFloat);
    edtOutras.Text := FormatFloat('#,##0.00', LQuery.FieldByName('VALOR_OUTRAS').AsFloat);
    edtDesconto.Text := FormatFloat('#,##0.00', LQuery.FieldByName('VALOR_DESCONTO').AsFloat);

    if FPedidoId > 0 then
      lblPedidoOrigem.Caption := 'Pedido de origem: ' + Trim(LQuery.FieldByName('PEDIDO_NUMERO').AsString)
    else
      lblPedidoOrigem.Caption := '';

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

procedure TfrmNotaSaida.btnFiltrarClick(Sender: TObject);
begin
  CarregarNotas;
  ModoLista;
end;

procedure TfrmNotaSaida.btnNovaDoPedidoClick(Sender: TObject);
begin
  CarregarPedidos;
  if FPedidos.IsEmpty then
  begin
    MessageDlg('Não há pedidos de venda pendentes de faturamento.' + LineEnding +
      'Cadastre ou libere um pedido em Vendas > Pedidos de Venda.', mtInformation, [mbOK], 0);
    ModoLista;
    Exit;
  end;
  ModoPedidos;
end;

procedure TfrmNotaSaida.btnVoltarPedidosClick(Sender: TObject);
begin
  CarregarNotas;
  ModoLista;
end;

procedure TfrmNotaSaida.dbGridPedidosDblClick(Sender: TObject);
begin
  btnGerarNotaClick(Sender);
end;

procedure TfrmNotaSaida.btnGerarNotaClick(Sender: TObject);
var
  LPedidoId: Int64;
  LNotaId: Int64;
begin
  if FPedidos.IsEmpty then
    Exit;
  LPedidoId := FPedidos.FieldByName('ID').AsLargeInt;

  if MessageDlg('Gerar a nota de saída do pedido ' +
    Trim(FPedidos.FieldByName('NUMERO').AsString) + '?', mtConfirmation,
    [mbYes, mbNo], 0) <> mrYes then
    Exit;

  try
    LNotaId := FService.CriarDoPedido(LPedidoId);
  except
    on E: Exception do
    begin
      MessageDlg('Não foi possível gerar a nota de saída: ' + E.Message, mtError, [mbOK], 0);
      Exit;
    end;
  end;

  CarregarNotas;
  AbrirNota(LNotaId);
  MessageDlg('Nota de saída ' + edtNumero.Text + ' gerada a partir do pedido.' + LineEnding +
    'Revise os dados e clique em Faturar para baixar o estoque.',
    mtInformation, [mbOK], 0);
end;

procedure TfrmNotaSaida.btnAbrirNotaClick(Sender: TObject);
begin
  if FNotas.IsEmpty then
    Exit;
  AbrirNota(FNotas.FieldByName('ID').AsLargeInt);
end;

procedure TfrmNotaSaida.dbGridNotasDblClick(Sender: TObject);
begin
  btnAbrirNotaClick(Sender);
end;

procedure TfrmNotaSaida.btnBuscarClienteClick(Sender: TObject);
var
  LQuery: TSQLQuery;
  LTexto: string;
begin
  LTexto := Trim(edtCliente.Text);
  if LTexto = '' then
  begin
    MessageDlg('Informe o código, CPF/CNPJ ou nome do cliente.', mtInformation, [mbOK], 0);
    edtCliente.SetFocus;
    Exit;
  end;

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID, NOME FROM PESSOA ' +
      'WHERE TIPO = ''C'' AND (CAST(ID AS VARCHAR(20)) = :T ' +
      '   OR REPLACE(REPLACE(REPLACE(COALESCE(CPF_CNPJ, ''''), ''.'', ''''), ''/'', ''''), ''-'', '''') = ' +
      // CAST obrigatório: sem ele o Firebird infere o parâmetro como CHAR(1)
      '      REPLACE(REPLACE(REPLACE(CAST(:T AS VARCHAR(40)), ''.'', ''''), ''/'', ''''), ''-'', '''') ' +
      '   OR UPPER(NOME) STARTING WITH UPPER(:T)) ' +
      'ORDER BY ID';
    LQuery.ParamByName('T').AsString := LTexto;
    LQuery.Open;
    if LQuery.IsEmpty then
    begin
      MessageDlg('Cliente não encontrado.', mtWarning, [mbOK], 0);
      FClienteId := 0;
      lblClienteDesc.Caption := '';
      Exit;
    end;
    FClienteId := LQuery.FieldByName('ID').AsLargeInt;
    edtCliente.Text := IntToStr(FClienteId);
    lblClienteDesc.Caption := Trim(LQuery.FieldByName('NOME').AsString);
  finally
    LQuery.Free;
  end;
end;

function TfrmNotaSaida.SalvarCabecalho: Boolean;
begin
  Result := False;
  if FNotaId <= 0 then
  begin
    MessageDlg('Gere a nota a partir de um pedido (botão "Nova do Pedido").',
      mtInformation, [mbOK], 0);
    Exit;
  end;
  if FClienteId <= 0 then
  begin
    MessageDlg('Informe o cliente (código, CPF/CNPJ ou nome).', mtWarning, [mbOK], 0);
    edtCliente.SetFocus;
    Exit;
  end;
  if Trim(edtNumero.Text) = '' then
  begin
    MessageDlg('Informe o número da nota.', mtWarning, [mbOK], 0);
    edtNumero.SetFocus;
    Exit;
  end;
  Result := True;
end;

procedure TfrmNotaSaida.btnGravarClick(Sender: TObject);
begin
  if not SalvarCabecalho then
    Exit;
  try
    FService.AtualizarCabecalho(FNotaId, FClienteId,
      Trim(edtNumero.Text), Trim(edtSerie.Text), Trim(edtModelo.Text),
      Trim(edtNatureza.Text), Trim(edtCfop.Text),
      StrToDateDef(edtDataEmissao.Text, Now), StrToDateDef(edtDataSaida.Text, Now),
      CondicaoSelecionada,
      StrToFloatDef(edtFrete.Text, 0), StrToFloatDef(edtSeguro.Text, 0),
      StrToFloatDef(edtOutras.Text, 0));
  except
    on E: Exception do
    begin
      MessageDlg('Não foi possível gravar a nota: ' + E.Message, mtError, [mbOK], 0);
      Exit;
    end;
  end;

  CarregarNotas;
  AbrirNota(FNotaId);
  MessageDlg('Nota de saída gravada.', mtInformation, [mbOK], 0);
end;

procedure TfrmNotaSaida.btnFaturarClick(Sender: TObject);
var
  LDescricao: string;
  LDisp, LSolic: Double;
begin
  if FNotaId <= 0 then
    Exit;

  // Itens sem produto vinculado impedem a baixa de estoque
  LDescricao := FService.PrimeiroItemSemProduto(FNotaId);
  if LDescricao <> '' then
  begin
    MessageDlg('O item "' + LDescricao + '" não está ligado a um produto.' + LineEnding +
      'Ajuste o item no pedido de venda antes de faturar.', mtWarning, [mbOK], 0);
    Exit;
  end;

  if FService.QuantidadeItens(FNotaId) = 0 then
  begin
    MessageDlg('A nota de saída não possui itens.', mtWarning, [mbOK], 0);
    Exit;
  end;

  if not FService.VerificarSaldo(FNotaId, LDescricao, LDisp, LSolic) then
  begin
    MessageDlg('Estoque insuficiente para "' + LDescricao + '".' + LineEnding +
      'Disponível: ' + FormatFloat('#,##0.####', LDisp) +
      '   Solicitado: ' + FormatFloat('#,##0.####', LSolic), mtWarning, [mbOK], 0);
    Exit;
  end;

  if MessageDlg('Faturar a nota de saída?' + LineEnding +
    'O estoque será baixado e as parcelas serão geradas no contas a receber.',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;

  try
    FService.Faturar(FNotaId);
  except
    on E: Exception do
    begin
      MessageDlg('Não foi possível faturar a nota: ' + E.Message, mtError, [mbOK], 0);
      Exit;
    end;
  end;

  CarregarNotas;
  AbrirNota(FNotaId);
  MessageDlg('Nota de saída faturada.' + LineEnding +
    'Estoque baixado, contas a receber geradas e pedido marcado como faturado.',
    mtInformation, [mbOK], 0);
end;

procedure TfrmNotaSaida.btnCancelarNotaClick(Sender: TObject);
var
  LMotivo: string;
  LAberta: Boolean;
begin
  if FNotaId <= 0 then
    Exit;

  LAberta := lblStatusNota.Tag = 0;
  LMotivo := 'Cancelamento solicitado na tela de nota de saída';

  if LAberta then
  begin
    if MessageDlg('Cancelar esta nota de saída?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
      Exit;
  end
  else
  begin
    if not InputQuery('Estornar faturamento', 'Motivo do estorno:', LMotivo) then
      Exit;
    if Trim(LMotivo) = '' then
      LMotivo := 'Estorno solicitado na tela de nota de saída';
    if MessageDlg('Estornar esta nota já faturada?' + LineEnding +
      'O estoque será devolvido e as parcelas em aberto serão canceladas.',
      mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
      Exit;
  end;

  try
    FService.Cancelar(FNotaId, LMotivo);
  except
    on E: Exception do
    begin
      MessageDlg('Não foi possível cancelar: ' + E.Message, mtError, [mbOK], 0);
      Exit;
    end;
  end;

  CarregarNotas;
  AbrirNota(FNotaId);
  if LAberta then
    MessageDlg('Nota de saída cancelada.', mtInformation, [mbOK], 0)
  else
    MessageDlg('Faturamento estornado: estoque devolvido e parcelas canceladas.',
      mtInformation, [mbOK], 0);
end;

procedure TfrmNotaSaida.btnExportarXMLClick(Sender: TObject);
var
  LXml: string;
  LArquivo: TStringList;
begin
  if FNotaId <= 0 then
    Exit;

  if Trim(edtChave.Text) = '' then
    SaveDialog1.FileName := 'nota_saida_' + Trim(edtNumero.Text) + '.xml'
  else
    SaveDialog1.FileName := 'NFe' + Trim(edtChave.Text) + '.xml';

  if not SaveDialog1.Execute then
    Exit;

  try
    LXml := FService.GerarXML(FNotaId);
  except
    on E: Exception do
    begin
      MessageDlg('Não foi possível gerar o XML: ' + E.Message, mtError, [mbOK], 0);
      Exit;
    end;
  end;

  LArquivo := TStringList.Create;
  try
    LArquivo.Text := LXml;
    LArquivo.SaveToFile(SaveDialog1.FileName);
  finally
    LArquivo.Free;
  end;

  MessageDlg('XML gravado em:' + LineEnding + SaveDialog1.FileName + LineEnding + LineEnding +
    'Este arquivo é o gancho para a emissão real: com o certificado digital e o ACBr' +
    ' configurados ele é assinado e transmitido à SEFAZ.', mtInformation, [mbOK], 0);
end;

procedure TfrmNotaSaida.btnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
