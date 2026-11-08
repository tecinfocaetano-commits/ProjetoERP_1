unit uPedidoVendaService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Service de pedido de venda
  ------------------------------------------------------------
  Regras que antes estavam dentro de uFrmPedidoVenda:

    - numeração: maior NUMERO numérico da empresa da sessão + 1
      (valores não numéricos, como "PV-TESTE-5", são ignorados);
    - item: total = quantidade * valor unitário - desconto, nunca
      negativo; quando o item tem grade, a quantidade passa a ser a
      soma das quantidades por tamanho;
    - pedido: subtotal = soma dos itens, total = subtotal - desconto
      (nunca negativo);
    - gravação: cliente ativo do tipo 'C' da empresa, pelo menos um
      item, produto da empresa, quantidade > 0, valor unitário e
      desconto não negativos, CFOP até 5 caracteres, observações até
      255; cabeçalho e itens na MESMA transação, com a grade efetiva
      de cada item (ITEM_PEDIDO_GRADE) e auditoria INSERT;
    - status 'P' por padrão (pedido pendente), como a tela já fazia.

  Diferente da tela antiga, a numeração é por empresa e o
  PRECO_UNITARIO também é gravado no item (a tela deixava nulo).
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uConexao, uGrade, uGradeService;

type
  { Item informado para a gravação do pedido. Tamanhos é opcional:
    quando preenchido, a quantidade do item é a soma das quantidades
    por tamanho. }
  TItemPedidoEntrada = record
    ProdutoId: Int64;
    Quantidade: Double;
    ValorUnitario: Double;
    Desconto: Double;
    Cfop: string;
    Tamanhos: TGradeTamanhos;
  end;
  TItensPedidoEntrada = array of TItemPedidoEntrada;

  { TPedidoVendaService }
  TPedidoVendaService = class
  private
    FConexao: TConexao;
    FGrade: TGradeService;

    procedure ValidarItens(const AItens: TItensPedidoEntrada);
    function ClienteValido(AClienteId: Int64): Boolean;
    function ProdutoDaEmpresa(AProdutoId: Int64): Boolean;
    function ResolverNumero(const ANumero: string): string;
  public
    constructor Create;
    destructor Destroy; override;

    { Maior número numérico da empresa + 1; ignora textos. }
    function ProximoNumero: Integer;

    { Subtotal e total a partir dos itens informados. }
    function SubtotalDosItens(const AItens: TItensPedidoEntrada): Double;
    function TotalDoPedido(const AItens: TItensPedidoEntrada;
      ADesconto: Double): Double;

    { Grava cabeçalho e itens (com grade) na mesma transação e
      devolve o ID do pedido. ANumero vazio ou '0' usa ProximoNumero. }
    function SalvarPedido(AClienteId: Int64; const ANumero: string;
      const AItens: TItensPedidoEntrada; ADesconto: Double;
      AFormaPagamentoId: Int64 = 0; ACondicaoPagamentoId: Int64 = 0;
      const AObservacoes: string = ''; const AStatus: string = 'P';
      ADataEntrega: TDateTime = 0): Int64;

    { Quantidade de itens do pedido. }
    function QuantidadeItens(APedidoId: Int64): Integer;
  end;

{ Total de um item: quantidade * valor unitário - desconto, nunca
  negativo. Exportado para a tela usar a mesma regra no grid. }
function TotalItemPedido(AQuantidade, AValorUnitario,
  ADesconto: Double): Double;

{ Total do pedido: subtotal - desconto, nunca negativo. }
function TotalDoPedidoVenda(ASubtotal, ADesconto: Double): Double;

implementation

uses
  uSessao, uAuditoria;

const
  TAMANHO_NUMERO = 20;
  TAMANHO_CFOP = 5;
  TAMANHO_OBSERVACOES = 255;
  CFOP_PADRAO = '5102';

function TotalItemPedido(AQuantidade, AValorUnitario,
  ADesconto: Double): Double;
begin
  Result := (AQuantidade * AValorUnitario) - ADesconto;
  if Result < 0 then
    Result := 0;
end;

function TotalDoPedidoVenda(ASubtotal, ADesconto: Double): Double;
begin
  Result := ASubtotal - ADesconto;
  if Result < 0 then
    Result := 0;
end;

constructor TPedidoVendaService.Create;
begin
  inherited Create;
  FConexao := TConexao.GetInstance;
  FGrade := TGradeService.Create;
end;

destructor TPedidoVendaService.Destroy;
begin
  FGrade.Free;
  inherited Destroy;
end;

function TPedidoVendaService.ProximoNumero: Integer;
var
  LQuery: TSQLQuery;
  LNum, LMax: Integer;
begin
  LMax := 0;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    { NUMERO é VARCHAR: valores como "PV-TESTE-5" são ignorados }
    LQuery.SQL.Text :=
      'SELECT NUMERO FROM PEDIDO_VENDA WHERE EMPRESA_ID = :EMP';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    while not LQuery.EOF do
    begin
      LNum := StrToIntDef(Trim(LQuery.FieldByName('NUMERO').AsString), 0);
      if LNum > LMax then
        LMax := LNum;
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
  Result := LMax + 1;
end;

function TPedidoVendaService.SubtotalDosItens(
  const AItens: TItensPedidoEntrada): Double;
var
  I: Integer;
  LQtd: Double;
begin
  Result := 0;
  for I := 0 to High(AItens) do
  begin
    LQtd := AItens[I].Quantidade;
    if Length(AItens[I].Tamanhos) > 0 then
      LQtd := SomarQuantidades(AItens[I].Tamanhos);
    Result := Result + TotalItemPedido(LQtd, AItens[I].ValorUnitario,
      AItens[I].Desconto);
  end;
end;

function TPedidoVendaService.TotalDoPedido(
  const AItens: TItensPedidoEntrada; ADesconto: Double): Double;
begin
  Result := TotalDoPedidoVenda(SubtotalDosItens(AItens), ADesconto);
end;

function TPedidoVendaService.ClienteValido(AClienteId: Int64): Boolean;
var
  LQuery: TSQLQuery;
begin
  Result := False;
  if AClienteId <= 0 then
    Exit;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM PESSOA ' +
      'WHERE ID = :ID AND EMPRESA_ID = :EMP AND TIPO = ''C'' AND ATIVO = ''A''';
    LQuery.ParamByName('ID').AsLargeInt := AClienteId;
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    Result := not LQuery.IsEmpty;
  finally
    LQuery.Free;
  end;
end;

function TPedidoVendaService.ProdutoDaEmpresa(AProdutoId: Int64): Boolean;
var
  LQuery: TSQLQuery;
begin
  Result := False;
  if AProdutoId <= 0 then
    Exit;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM PRODUTO WHERE ID = :ID AND EMPRESA_ID = :EMP';
    LQuery.ParamByName('ID').AsLargeInt := AProdutoId;
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    Result := not LQuery.IsEmpty;
  finally
    LQuery.Free;
  end;
end;

procedure TPedidoVendaService.ValidarItens(
  const AItens: TItensPedidoEntrada);
var
  I, J: Integer;
  LQtd: Double;
begin
  if Length(AItens) = 0 then
    raise Exception.Create('Adicione pelo menos um item ao pedido.');

  for I := 0 to High(AItens) do
  begin
    if AItens[I].ProdutoId <= 0 then
      raise Exception.Create('Selecione um produto para o item.');
    if not ProdutoDaEmpresa(AItens[I].ProdutoId) then
      raise Exception.Create('Produto do item não encontrado.');
    if AItens[I].Quantidade <= 0 then
      raise Exception.Create('A quantidade do item deve ser maior que zero.');
    if AItens[I].ValorUnitario < 0 then
      raise Exception.Create('O valor unitário do item não pode ser negativo.');
    if AItens[I].Desconto < 0 then
      raise Exception.Create('O desconto do item não pode ser negativo.');
    if Length(AItens[I].Cfop) > TAMANHO_CFOP then
      raise Exception.CreateFmt('O CFOP do item deve ter no máximo %d caracteres.',
        [TAMANHO_CFOP]);

    for J := 0 to High(AItens[I].Tamanhos) do
    begin
      if AItens[I].Tamanhos[J].Quantidade < 0 then
        raise Exception.CreateFmt(
          'Quantidade negativa no tamanho "%s".',
          [Trim(AItens[I].Tamanhos[J].Tamanho)]);
      if Length(Trim(AItens[I].Tamanhos[J].Tamanho)) > 10 then
        raise Exception.CreateFmt(
          'O tamanho "%s" tem mais de 10 caracteres.',
          [Trim(AItens[I].Tamanhos[J].Tamanho)]);
    end;

    if Length(AItens[I].Tamanhos) > 0 then
    begin
      LQtd := SomarQuantidades(AItens[I].Tamanhos);
      if LQtd <= 0 then
        raise Exception.Create(
          'A soma das quantidades da grade deve ser maior que zero.');
    end;
  end;
end;

function TPedidoVendaService.ResolverNumero(const ANumero: string): string;
var
  LNumero: string;
begin
  LNumero := Trim(ANumero);
  if (LNumero = '') or (LNumero = '0') then
    LNumero := IntToStr(ProximoNumero);
  if Length(LNumero) > TAMANHO_NUMERO then
    raise Exception.CreateFmt('O número do pedido deve ter no máximo %d caracteres.',
      [TAMANHO_NUMERO]);
  Result := LNumero;
end;

function TPedidoVendaService.SalvarPedido(AClienteId: Int64;
  const ANumero: string; const AItens: TItensPedidoEntrada;
  ADesconto: Double; AFormaPagamentoId, ACondicaoPagamentoId: Int64;
  const AObservacoes: string; const AStatus: string;
  ADataEntrega: TDateTime): Int64;
var
  LQuery: TSQLQuery;
  LNumero, LStatus: string;
  LSubtotal, LTotal, LQtd, LTotalItem: Double;
  LItemId: Int64;
  I: Integer;
begin
  if not ClienteValido(AClienteId) then
    raise Exception.Create('Selecione um cliente ativo.');
  ValidarItens(AItens);
  if ADesconto < 0 then
    raise Exception.Create('O desconto do pedido não pode ser negativo.');
  if Length(AObservacoes) > TAMANHO_OBSERVACOES then
    raise Exception.CreateFmt('As observações devem ter no máximo %d caracteres.',
      [TAMANHO_OBSERVACOES]);
  LStatus := Trim(AStatus);
  if LStatus = '' then
    LStatus := 'P';
  if Length(LStatus) <> 1 then
    raise Exception.Create('Status do pedido inválido.');

  LNumero := ResolverNumero(ANumero);
  LSubtotal := SubtotalDosItens(AItens);
  LTotal := TotalDoPedidoVenda(LSubtotal, ADesconto);

  FConexao.IniciarTransacao;
  LQuery := TSQLQuery.Create(nil);
  try
    try
      LQuery.DataBase := FConexao.Connection;
      LQuery.Transaction := FConexao.Transaction;

      LQuery.SQL.Text :=
        'INSERT INTO PEDIDO_VENDA (EMPRESA_ID, CLIENTE_ID, USUARIO_ID, ' +
        '  NUMERO, STATUS, SUBTOTAL, DESCONTO, TOTAL, FORMA_PAGAMENTO_ID, ' +
        '  CONDICAO_PAGAMENTO_ID, OBSERVACOES, DATA_ENTREGA) ' +
        'VALUES (:EMP, :CLI, :USR, :NUM, :STS, :SUB, :DESC, :TOT, :FP, ' +
        '  :CP, :OBS, :ENTREGA) RETURNING ID';
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.ParamByName('CLI').AsLargeInt := AClienteId;
      LQuery.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
      LQuery.ParamByName('NUM').AsString := LNumero;
      LQuery.ParamByName('STS').AsString := LStatus;
      LQuery.ParamByName('SUB').AsFloat := LSubtotal;
      LQuery.ParamByName('DESC').AsFloat := ADesconto;
      LQuery.ParamByName('TOT').AsFloat := LTotal;
      if AFormaPagamentoId > 0 then
        LQuery.ParamByName('FP').AsLargeInt := AFormaPagamentoId
      else
        LQuery.ParamByName('FP').Clear;
      if ACondicaoPagamentoId > 0 then
        LQuery.ParamByName('CP').AsLargeInt := ACondicaoPagamentoId
      else
        LQuery.ParamByName('CP').Clear;
      LQuery.ParamByName('OBS').AsString := Trim(AObservacoes);
      if ADataEntrega > 0 then
        LQuery.ParamByName('ENTREGA').AsDateTime := ADataEntrega
      else
        LQuery.ParamByName('ENTREGA').Clear;
      LQuery.Open;
      Result := LQuery.FieldByName('ID').AsLargeInt;
      LQuery.Close;

      for I := 0 to High(AItens) do
      begin
        LQtd := AItens[I].Quantidade;
        if Length(AItens[I].Tamanhos) > 0 then
          LQtd := SomarQuantidades(AItens[I].Tamanhos);
        LTotalItem := TotalItemPedido(LQtd, AItens[I].ValorUnitario,
          AItens[I].Desconto);

        LQuery.SQL.Text :=
          'INSERT INTO ITEM_PEDIDO (PEDIDO_VENDA_ID, PRODUTO_ID, QUANTIDADE, ' +
          '  PRECO_UNITARIO, VALOR_UNITARIO, DESCONTO, VALOR_TOTAL, CFOP) ' +
          'VALUES (:PED, :PROD, :QTD, :PRECO, :VLR, :DESC, :TOT, :CFOP) ' +
          'RETURNING ID';
        LQuery.ParamByName('PED').AsLargeInt := Result;
        LQuery.ParamByName('PROD').AsLargeInt := AItens[I].ProdutoId;
        LQuery.ParamByName('QTD').AsFloat := LQtd;
        LQuery.ParamByName('PRECO').AsFloat := AItens[I].ValorUnitario;
        LQuery.ParamByName('VLR').AsFloat := AItens[I].ValorUnitario;
        LQuery.ParamByName('DESC').AsFloat := AItens[I].Desconto;
        LQuery.ParamByName('TOT').AsFloat := LTotalItem;
        if Trim(AItens[I].Cfop) <> '' then
          LQuery.ParamByName('CFOP').AsString := Trim(AItens[I].Cfop)
        else
          LQuery.ParamByName('CFOP').AsString := CFOP_PADRAO;
        LQuery.Open;
        LItemId := LQuery.FieldByName('ID').AsLargeInt;
        LQuery.Close;

        { grade efetiva entra na MESMA transação do pedido }
        if Length(AItens[I].Tamanhos) > 0 then
          FGrade.SalvarGradeItemPedido(LItemId, AItens[I].Tamanhos);
      end;

      RegistrarAuditoriaSegura('PEDIDO_VENDA', 'INSERT', Result, '',
        ResumoAuditoria([
          'NUMERO=' + LNumero,
          'CLIENTE_ID=' + IntToStr(AClienteId),
          'ITENS=' + IntToStr(Length(AItens)),
          'SUBTOTAL=' + FloatToStr(LSubtotal),
          'DESCONTO=' + FloatToStr(ADesconto),
          'TOTAL=' + FloatToStr(LTotal)]));

      FConexao.Confirmar;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

function TPedidoVendaService.QuantidadeItens(APedidoId: Int64): Integer;
var
  LQuery: TSQLQuery;
begin
  Result := 0;
  if APedidoId <= 0 then
    Exit;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT COUNT(*) FROM ITEM_PEDIDO WHERE PEDIDO_VENDA_ID = :PED';
    LQuery.ParamByName('PED').AsLargeInt := APedidoId;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
  finally
    LQuery.Free;
  end;
end;

end.
