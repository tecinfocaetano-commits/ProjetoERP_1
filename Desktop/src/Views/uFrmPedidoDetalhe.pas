unit uFrmPedidoDetalhe;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Visualização de Pedido de Venda (somente leitura)
  Descrição: mostra o cabeçalho e os itens de um pedido já
  gravado. Aberto pela Lista de Pedidos (botão Visualizar).
  A consulta filtra EMPRESA_ID da sessão: pedido de outra
  empresa aparece como "não encontrado".
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, DateUtils,
  uConexao, uSessao, uPedidoStatus;

type
  { TfrmPedidoDetalhe }
  TfrmPedidoDetalhe = class(TForm)
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    pnlDados: TPanel;
    lblNumValor: TLabel;
    lblClienteValor: TLabel;
    lblEmissaoValor: TLabel;
    lblStatusValor: TLabel;
    lblSubtotalValor: TLabel;
    lblDescontoValor: TLabel;
    lblTotalValor: TLabel;
    lblObsValor: TLabel;
    pnlGrade: TPanel;
    dbGridItens: TDBGrid;
    DataSourceItens: TDataSource;
    pnlBotoes: TPanel;
    btnFechar: TBitBtn;
    procedure FormCreate(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
  private
    FConexao: TConexao;
    FQueryCab: TSQLQuery;
    FQueryItens: TSQLQuery;
    FPedidoId: Int64;
    procedure Carregar;
    function DataHoraTexto(AValor: TDateTime): string;
    function DataTexto(AValor: TDateTime): string;
  public
    property PedidoId: Int64 read FPedidoId write FPedidoId;
  end;

var
  frmPedidoDetalhe: TfrmPedidoDetalhe;

implementation

{$R *.lfm}

procedure TfrmPedidoDetalhe.FormCreate(Sender: TObject);
begin
  try
    FConexao := TConexao.GetInstance;
    if FConexao = nil then
      raise Exception.Create('FConexao não foi inicializado');
    if not FConexao.Conectado then
      FConexao.Conectar;

    FQueryCab := TSQLQuery.Create(Self);
    FQueryCab.DataBase := FConexao.Connection;
    FQueryCab.Transaction := FConexao.Transaction;

    FQueryItens := TSQLQuery.Create(Self);
    FQueryItens.DataBase := FConexao.Connection;
    FQueryItens.Transaction := FConexao.Transaction;
    if DataSourceItens <> nil then
      DataSourceItens.DataSet := FQueryItens;

    Carregar;
  except
    on E: Exception do
      MessageDlg('Erro ao inicializar formulário: ' + E.Message,
        mtError, [mbOK], 0);
  end;
end;

function TfrmPedidoDetalhe.DataHoraTexto(AValor: TDateTime): string;
begin
  if AValor <= 0 then
    Result := '-'
  else
    Result := FormatDateTime('dd/mm/yyyy hh:nn', AValor);
end;

function TfrmPedidoDetalhe.DataTexto(AValor: TDateTime): string;
begin
  if AValor <= 0 then
    Result := '-'
  else
    Result := FormatDateTime('dd/mm/yyyy', AValor);
end;

procedure TfrmPedidoDetalhe.Carregar;
begin
  if FPedidoId <= 0 then
  begin
    MessageDlg('Nenhum pedido selecionado.', mtWarning, [mbOK], 0);
    Close;
    Exit;
  end;

  FQueryCab.Close;
  FQueryCab.SQL.Text :=
    'SELECT PV.NUMERO, PV.DATA_EMISSAO, PV.DATA_ENTREGA, PV.STATUS, ' +
    'PV.SUBTOTAL, PV.DESCONTO, PV.TOTAL, PV.OBSERVACOES, ' +
    'C.NOME AS CLIENTE ' +
    'FROM PEDIDO_VENDA PV ' +
    'JOIN PESSOA C ON C.ID = PV.CLIENTE_ID AND C.TIPO = ''C'' ' +
    'WHERE PV.ID = :ID AND PV.EMPRESA_ID = :EMP';
  FQueryCab.ParamByName('ID').AsLargeInt := FPedidoId;
  FQueryCab.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
  FQueryCab.Open;

  if FQueryCab.IsEmpty then
  begin
    MessageDlg('Pedido não encontrado nesta empresa.', mtError, [mbOK], 0);
    Close;
    Exit;
  end;

  lblNumValor.Caption := 'Pedido Nº ' +
    FQueryCab.FieldByName('NUMERO').AsString;
  lblClienteValor.Caption := 'Cliente: ' +
    FQueryCab.FieldByName('CLIENTE').AsString;
  lblEmissaoValor.Caption := 'Emissão: ' + DataHoraTexto(
    FQueryCab.FieldByName('DATA_EMISSAO').AsDateTime) +
    '   Entrega: ' + DataTexto(
    FQueryCab.FieldByName('DATA_ENTREGA').AsDateTime);
  lblStatusValor.Caption := 'Status: ' + DescricaoDoStatus(
    FQueryCab.FieldByName('STATUS').AsString);
  lblSubtotalValor.Caption := 'Subtotal: R$ ' + FormatFloat('#,##0.00',
    FQueryCab.FieldByName('SUBTOTAL').AsFloat);
  lblDescontoValor.Caption := 'Desconto: R$ ' + FormatFloat('#,##0.00',
    FQueryCab.FieldByName('DESCONTO').AsFloat);
  lblTotalValor.Caption := 'Total: R$ ' + FormatFloat('#,##0.00',
    FQueryCab.FieldByName('TOTAL').AsFloat);
  lblObsValor.Caption := 'Observações: ' +
    FQueryCab.FieldByName('OBSERVACOES').AsString;
  if Trim(FQueryCab.FieldByName('OBSERVACOES').AsString) = '' then
    lblObsValor.Caption := 'Observações: -';
  FQueryCab.Close;

  FQueryItens.Close;
  FQueryItens.SQL.Text :=
    'SELECT P.DESCRICAO AS PRODUTO, P.CODIGO, I.QUANTIDADE, ' +
    'COALESCE(NULLIF(I.VALOR_UNITARIO, 0), I.PRECO_UNITARIO) AS VALOR_UNIT, ' +
    'I.DESCONTO, I.VALOR_TOTAL, I.CFOP ' +
    'FROM ITEM_PEDIDO I ' +
    'JOIN PRODUTO P ON P.ID = I.PRODUTO_ID ' +
    'WHERE I.PEDIDO_VENDA_ID = :PED ' +
    'ORDER BY I.ID';
  FQueryItens.ParamByName('PED').AsLargeInt := FPedidoId;
  FQueryItens.Open;
end;

procedure TfrmPedidoDetalhe.btnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
