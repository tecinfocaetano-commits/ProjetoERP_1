unit uPedidoCompraService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Service de pedido de compra
  ------------------------------------------------------------
  Regras que antes estavam dentro de uFrmCompras:

    - numeração: maior NUMERO numérico da empresa da sessão + 1
      (valores não numéricos, como "PC-TESTE-8", são ignorados);
    - item: total = quantidade * valor unitário - desconto, nunca
      negativo;
    - pedido: subtotal = soma dos itens, total = subtotal - desconto
      (nunca negativo);
    - gravação: fornecedor ativo do tipo 'F' da empresa, pelo menos
      um material da empresa, quantidade > 0, valor unitário e
      descontos não negativos, observações até 500, status ABERTO/
      CONFIRMADO/CANCELADO (vazio = ABERTO) e número até 20;
      cabeçalho e itens na MESMA transação, com auditoria INSERT;
    - datas de emissão/entrega opcionais (a trigger preenche a
      emissão com a data atual quando nula).

  Diferente da tela antiga, a numeração é por empresa, o ID vem de
  RETURNING ID (não de GEN_ID(..., 0)) e o total do item nunca fica
  negativo.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uConexao;

type
  { Material informado para a gravação do pedido de compra. }
  TItemCompraEntrada = record
    MaterialId: Int64;
    Quantidade: Double;
    ValorUnitario: Double;
    Desconto: Double;
  end;
  TItensCompraEntrada = array of TItemCompraEntrada;

  { TPedidoCompraService }
  TPedidoCompraService = class
  private
    FConexao: TConexao;

    procedure ValidarItens(const AItens: TItensCompraEntrada);
    function FornecedorValido(AFornecedorId: Int64): Boolean;
    function MaterialDaEmpresa(AMaterialId: Int64): Boolean;
    function ResolverNumero(const ANumero: string): string;
    function ResolverStatus(const AStatus: string): string;
  public
    constructor Create;
    destructor Destroy; override;

    { Maior número numérico da empresa + 1; ignora textos. }
    function ProximoNumero: Integer;

    { Subtotal e total a partir dos itens informados. }
    function SubtotalDosItens(const AItens: TItensCompraEntrada): Double;
    function TotalDoPedido(const AItens: TItensCompraEntrada;
      ADesconto: Double): Double;

    { Grava cabeçalho e itens na mesma transação e devolve o ID do
      pedido. ANumero vazio ou '0' usa ProximoNumero. }
    function SalvarPedido(AFornecedorId: Int64; const ANumero: string;
      const AItens: TItensCompraEntrada; ADesconto: Double;
      const AObservacoes: string = ''; const AStatus: string = 'ABERTO';
      ADataEmissao: TDateTime = 0; ADataEntrega: TDateTime = 0): Int64;

    { Quantidade de itens do pedido. }
    function QuantidadeItens(APedidoId: Int64): Integer;
  end;

{ Total de um item: quantidade * valor unitário - desconto, nunca
  negativo. Exportado para a tela usar a mesma regra no grid. }
function TotalItemCompra(AQuantidade, AValorUnitario,
  ADesconto: Double): Double;

{ Total do pedido: subtotal - desconto, nunca negativo. }
function TotalDoPedidoCompra(ASubtotal, ADesconto: Double): Double;

implementation

uses
  uSessao, uAuditoria;

const
  TAMANHO_NUMERO = 20;
  TAMANHO_OBSERVACOES = 500;

function TotalItemCompra(AQuantidade, AValorUnitario,
  ADesconto: Double): Double;
begin
  Result := (AQuantidade * AValorUnitario) - ADesconto;
  if Result < 0 then
    Result := 0;
end;

function TotalDoPedidoCompra(ASubtotal, ADesconto: Double): Double;
begin
  Result := ASubtotal - ADesconto;
  if Result < 0 then
    Result := 0;
end;

constructor TPedidoCompraService.Create;
begin
  inherited Create;
  FConexao := TConexao.GetInstance;
end;

destructor TPedidoCompraService.Destroy;
begin
  inherited Destroy;
end;

function TPedidoCompraService.ProximoNumero: Integer;
var
  LQuery: TSQLQuery;
  LNum, LMax: Integer;
begin
  LMax := 0;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    { NUMERO é VARCHAR: valores como "PC-TESTE-8" são ignorados }
    LQuery.SQL.Text :=
      'SELECT NUMERO FROM PEDIDO_COMPRA WHERE EMPRESA_ID = :EMP';
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

function TPedidoCompraService.SubtotalDosItens(
  const AItens: TItensCompraEntrada): Double;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(AItens) do
    Result := Result + TotalItemCompra(AItens[I].Quantidade,
      AItens[I].ValorUnitario, AItens[I].Desconto);
end;

function TPedidoCompraService.TotalDoPedido(
  const AItens: TItensCompraEntrada; ADesconto: Double): Double;
begin
  Result := TotalDoPedidoCompra(SubtotalDosItens(AItens), ADesconto);
end;

function TPedidoCompraService.FornecedorValido(AFornecedorId: Int64): Boolean;
var
  LQuery: TSQLQuery;
begin
  Result := False;
  if AFornecedorId <= 0 then
    Exit;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM PESSOA ' +
      'WHERE ID = :ID AND EMPRESA_ID = :EMP AND TIPO = ''F'' AND ATIVO = ''A''';
    LQuery.ParamByName('ID').AsLargeInt := AFornecedorId;
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    Result := not LQuery.IsEmpty;
  finally
    LQuery.Free;
  end;
end;

function TPedidoCompraService.MaterialDaEmpresa(AMaterialId: Int64): Boolean;
var
  LQuery: TSQLQuery;
begin
  Result := False;
  if AMaterialId <= 0 then
    Exit;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM MATERIAL WHERE ID = :ID AND EMPRESA_ID = :EMP';
    LQuery.ParamByName('ID').AsLargeInt := AMaterialId;
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    Result := not LQuery.IsEmpty;
  finally
    LQuery.Free;
  end;
end;

procedure TPedidoCompraService.ValidarItens(
  const AItens: TItensCompraEntrada);
var
  I: Integer;
begin
  if Length(AItens) = 0 then
    raise Exception.Create('Adicione pelo menos um material ao pedido.');

  for I := 0 to High(AItens) do
  begin
    if AItens[I].MaterialId <= 0 then
      raise Exception.Create('Selecione um material para o item.');
    if not MaterialDaEmpresa(AItens[I].MaterialId) then
      raise Exception.Create('Material do item não encontrado.');
    if AItens[I].Quantidade <= 0 then
      raise Exception.Create('A quantidade do item deve ser maior que zero.');
    if AItens[I].ValorUnitario < 0 then
      raise Exception.Create('O valor unitário do item não pode ser negativo.');
    if AItens[I].Desconto < 0 then
      raise Exception.Create('O desconto do item não pode ser negativo.');
  end;
end;

function TPedidoCompraService.ResolverNumero(const ANumero: string): string;
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

function TPedidoCompraService.ResolverStatus(const AStatus: string): string;
var
  LStatus: string;
begin
  LStatus := UpperCase(Trim(AStatus));
  if LStatus = '' then
    LStatus := 'ABERTO';
  if (LStatus <> 'ABERTO') and (LStatus <> 'CONFIRMADO') and
     (LStatus <> 'CANCELADO') then
    raise Exception.Create('Status do pedido de compra inválido.');
  Result := LStatus;
end;

function TPedidoCompraService.SalvarPedido(AFornecedorId: Int64;
  const ANumero: string; const AItens: TItensCompraEntrada;
  ADesconto: Double; const AObservacoes: string; const AStatus: string;
  ADataEmissao: TDateTime; ADataEntrega: TDateTime): Int64;
var
  LQuery: TSQLQuery;
  LNumero, LStatus: string;
  LSubtotal, LTotal, LTotalItem: Double;
  I: Integer;
begin
  if not FornecedorValido(AFornecedorId) then
    raise Exception.Create('Selecione um fornecedor ativo.');
  ValidarItens(AItens);
  if ADesconto < 0 then
    raise Exception.Create('O desconto do pedido não pode ser negativo.');
  if Length(AObservacoes) > TAMANHO_OBSERVACOES then
    raise Exception.CreateFmt('As observações devem ter no máximo %d caracteres.',
      [TAMANHO_OBSERVACOES]);
  LStatus := ResolverStatus(AStatus);
  LNumero := ResolverNumero(ANumero);
  LSubtotal := SubtotalDosItens(AItens);
  LTotal := TotalDoPedidoCompra(LSubtotal, ADesconto);

  FConexao.IniciarTransacao;
  LQuery := TSQLQuery.Create(nil);
  try
    try
      LQuery.DataBase := FConexao.Connection;
      LQuery.Transaction := FConexao.Transaction;

      LQuery.SQL.Text :=
        'INSERT INTO PEDIDO_COMPRA (EMPRESA_ID, FORNECEDOR_ID, USUARIO_ID, ' +
        '  NUMERO, DATA_EMISSAO, DATA_ENTREGA, STATUS, SUBTOTAL, DESCONTO, ' +
        '  TOTAL, OBSERVACOES) ' +
        'VALUES (:EMP, :FORN, :USR, :NUM, :DEMI, :DENT, :STS, :SUB, :DESC, ' +
        '  :TOT, :OBS) RETURNING ID';
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.ParamByName('FORN').AsLargeInt := AFornecedorId;
      LQuery.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
      LQuery.ParamByName('NUM').AsString := LNumero;
      LQuery.ParamByName('STS').AsString := LStatus;
      LQuery.ParamByName('SUB').AsFloat := LSubtotal;
      LQuery.ParamByName('DESC').AsFloat := ADesconto;
      LQuery.ParamByName('TOT').AsFloat := LTotal;
      LQuery.ParamByName('OBS').AsString := Trim(AObservacoes);
      if ADataEmissao > 0 then
        LQuery.ParamByName('DEMI').AsDateTime := ADataEmissao
      else
        LQuery.ParamByName('DEMI').Clear;
      if ADataEntrega > 0 then
        LQuery.ParamByName('DENT').AsDateTime := ADataEntrega
      else
        LQuery.ParamByName('DENT').Clear;
      LQuery.Open;
      Result := LQuery.FieldByName('ID').AsLargeInt;
      LQuery.Close;

      for I := 0 to High(AItens) do
      begin
        LTotalItem := TotalItemCompra(AItens[I].Quantidade,
          AItens[I].ValorUnitario, AItens[I].Desconto);
        LQuery.SQL.Text :=
          'INSERT INTO PEDIDO_COMPRA_ITEM (PEDIDO_COMPRA_ID, MATERIAL_ID, ' +
          '  QUANTIDADE, VALOR_UNITARIO, DESCONTO, VALOR_TOTAL) ' +
          'VALUES (:PED, :MAT, :QTD, :VLR, :DESC, :TOT)';
        LQuery.ParamByName('PED').AsLargeInt := Result;
        LQuery.ParamByName('MAT').AsLargeInt := AItens[I].MaterialId;
        LQuery.ParamByName('QTD').AsFloat := AItens[I].Quantidade;
        LQuery.ParamByName('VLR').AsFloat := AItens[I].ValorUnitario;
        LQuery.ParamByName('DESC').AsFloat := AItens[I].Desconto;
        LQuery.ParamByName('TOT').AsFloat := LTotalItem;
        LQuery.ExecSQL;
      end;

      RegistrarAuditoriaSegura('PEDIDO_COMPRA', 'INSERT', Result, '',
        ResumoAuditoria([
          'NUMERO=' + LNumero,
          'FORNECEDOR_ID=' + IntToStr(AFornecedorId),
          'ITENS=' + IntToStr(Length(AItens)),
          'SUBTOTAL=' + FloatToStr(LSubtotal),
          'DESCONTO=' + FloatToStr(ADesconto),
          'TOTAL=' + FloatToStr(LTotal),
          'STATUS=' + LStatus]));

      FConexao.Confirmar;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

function TPedidoCompraService.QuantidadeItens(APedidoId: Int64): Integer;
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
      'SELECT COUNT(*) FROM PEDIDO_COMPRA_ITEM WHERE PEDIDO_COMPRA_ID = :PED';
    LQuery.ParamByName('PED').AsLargeInt := APedidoId;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
  finally
    LQuery.Free;
  end;
end;

end.
