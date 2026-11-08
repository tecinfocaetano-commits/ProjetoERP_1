unit uPDVService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Service do PDV (frente de caixa)
  ------------------------------------------------------------
  Regras que antes estavam dentro de uFrmPDV:

    - caixa: um caixa aberto por empresa/usuário; abertura com
      valor não negativo e número por empresa; fechamento grava
      VALOR_FECHAMENTO e auditoria;
    - saldo do caixa = abertura + entradas ('E' e 'V') - saídas
      ('S'), com CAST numérico (sem ele o Firebird devolve
      ftUnknown e o valor vem 0);
    - venda: grava PEDIDO_VENDA com STATUS 'F', número por empresa,
      cliente (informado ou "Consumidor Final" da empresa), itens em
      ITEM_PEDIDO e um movimento de caixa 'V' na MESMA transação,
      com auditoria INSERT;
    - item: total = quantidade * preço unitário (nunca negativo);
      venda: total = subtotal - desconto (nunca negativo);
    - movimento avulso: somente 'E' (suprimento) ou 'S' (sangria),
      valor > 0, caixa da empresa e aberto, descrição até 255;
    - produtos sempre no escopo da empresa e ativos.

  Correções em relação à tela antiga: a tela gravava itens em
  ITEM_PEDIDO_VENDA (tabela inexistente), não informava o
  CLIENTE_ID obrigatório, nem EMPRESA_ID/USUARIO_ID em
  MOVIMENTO_CAIXA, e confirmava o movimento no meio da venda.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uConexao;

type
  { Item informado para a venda do PDV. }
  TItemPDVEntrada = record
    ProdutoId: Int64;
    Quantidade: Double;
    PrecoUnitario: Double;
  end;
  TItensPDVEntrada = array of TItemPDVEntrada;

  { TPDVService }
  TPDVService = class
  private
    FConexao: TConexao;

    function CaixaDaEmpresaAberto(ACaixaId: Int64): Boolean;
    function ClienteValido(AClienteId: Int64): Boolean;
    function ProdutoDaEmpresa(AProdutoId: Int64): Boolean;
    function ResolverConsumidorFinal: Int64;
    procedure ValidarItens(const AItens: TItensPDVEntrada);
  public
    constructor Create;

    { Maior número numérico da empresa + 1 (PEDIDO_VENDA e CAIXA);
      valores em texto são ignorados. }
    function ProximoNumeroVenda: Integer;
    function ProximoNumeroCaixa: Integer;

    { Caixa aberto do usuário (padrão: sessão); 0 quando não há. }
    function CaixaAberto(AUsuarioId: Int64 = 0): Int64;

    { Abre o caixa da empresa/usuário da sessão e devolve o ID. }
    function AbrirCaixa(AValorAbertura: Double): Int64;

    { Busca produto ativo da empresa por código ou código de barras.
      Devolve False quando não encontra. }
    function BuscarProduto(const ACodigo: string; out AProdutoId: Int64;
      out ACodigoProduto, ADescricao: string; out APrecoVenda: Double): Boolean;

    { Grava a venda (cabeçalho + itens + movimento 'V') na mesma
      transação e devolve o ID do PEDIDO_VENDA. AClienteId <= 0 usa o
      "Consumidor Final" da empresa. }
    function SalvarVenda(ACaixaId: Int64; const AItens: TItensPDVEntrada;
      ADesconto: Double; AFormaPagamentoId: Int64 = 0;
      AClienteId: Int64 = 0; const AObservacoes: string = 'PDV'): Int64;

    { Lança sangria ('S') ou suprimento ('E') no caixa. }
    procedure RegistrarMovimento(ACaixaId: Int64; ATipo: Char;
      AValor: Double; const ADescricao: string);

    { Saldo atual do caixa. }
    function SaldoCaixa(ACaixaId: Int64): Double;

    { Fecha o caixa e devolve o saldo gravado em VALOR_FECHAMENTO. }
    function FecharCaixa(ACaixaId: Int64): Double;

    { Quantidade de itens da venda. }
    function QuantidadeItens(AVendaId: Int64): Integer;

    { Preenche a lista de formas de pagamento ativas (ID em Objects). }
    procedure CarregarFormasPagamento(AItems: TStrings);
  end;

{ Total de um item do PDV: quantidade * preço unitário, nunca negativo. }
function TotalItemPDV(AQuantidade, APrecoUnitario: Double): Double;

{ Total da venda: subtotal - desconto, nunca negativo. }
function TotalVendaPDV(ASubtotal, ADesconto: Double): Double;

implementation

uses
  uSessao, uAuditoria, uPedidoVendaService;

const
  STATUS_VENDA = 'F';
  STATUS_CAIXA_ABERTO = 'A';
  TIPO_MOV_VENDA = 'V';
  TIPO_MOV_ENTRADA = 'E';
  TIPO_MOV_SAIDA = 'S';
  CFOP_PADRAO = '5102';
  TAMANHO_DESCRICAO = 255;

function TotalItemPDV(AQuantidade, APrecoUnitario: Double): Double;
begin
  Result := TotalItemPedido(AQuantidade, APrecoUnitario, 0);
end;

function TotalVendaPDV(ASubtotal, ADesconto: Double): Double;
begin
  Result := TotalDoPedidoVenda(ASubtotal, ADesconto);
end;

constructor TPDVService.Create;
begin
  inherited Create;
  FConexao := TConexao.GetInstance;
end;

function TPDVService.ProximoNumeroVenda: Integer;
var
  LQuery: TSQLQuery;
  LNum, LMax: Integer;
begin
  LMax := 0;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
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

function TPDVService.ProximoNumeroCaixa: Integer;
var
  LQuery: TSQLQuery;
  LNum, LMax: Integer;
begin
  LMax := 0;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT NUMERO FROM CAIXA WHERE EMPRESA_ID = :EMP';
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

function TPDVService.CaixaAberto(AUsuarioId: Int64): Int64;
var
  LQuery: TSQLQuery;
begin
  Result := 0;
  if AUsuarioId <= 0 then
    AUsuarioId := TSessao.GetInstance.UsuarioId;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM CAIXA ' +
      'WHERE EMPRESA_ID = :EMP AND USUARIO_ID = :USR AND STATUS = :STS ' +
      'ORDER BY ID DESC';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.ParamByName('USR').AsLargeInt := AUsuarioId;
    LQuery.ParamByName('STS').AsString := STATUS_CAIXA_ABERTO;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('ID').AsLargeInt;
  finally
    LQuery.Free;
  end;
end;

function TPDVService.AbrirCaixa(AValorAbertura: Double): Int64;
var
  LQuery: TSQLQuery;
  LNumero: string;
begin
  if AValorAbertura < 0 then
    raise Exception.Create('O valor de abertura não pode ser negativo.');
  if CaixaAberto > 0 then
    raise Exception.Create('Já existe um caixa aberto para este usuário.');

  LNumero := IntToStr(ProximoNumeroCaixa);
  FConexao.IniciarTransacao;
  LQuery := TSQLQuery.Create(nil);
  try
    try
      LQuery.DataBase := FConexao.Connection;
      LQuery.Transaction := FConexao.Transaction;
      LQuery.SQL.Text :=
        'INSERT INTO CAIXA (EMPRESA_ID, USUARIO_ID, NUMERO, ' +
        '  VALOR_ABERTURA, STATUS) ' +
        'VALUES (:EMP, :USR, :NUM, :VLR, :STS) RETURNING ID';
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
      LQuery.ParamByName('NUM').AsString := LNumero;
      LQuery.ParamByName('VLR').AsFloat := AValorAbertura;
      LQuery.ParamByName('STS').AsString := STATUS_CAIXA_ABERTO;
      LQuery.Open;
      Result := LQuery.FieldByName('ID').AsLargeInt;
      LQuery.Close;

      RegistrarAuditoriaSegura('CAIXA', 'INSERT', Result, '',
        ResumoAuditoria([
          'NUMERO=' + LNumero,
          'VALOR_ABERTURA=' + FloatToStr(AValorAbertura)]));

      FConexao.Confirmar;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

function TPDVService.BuscarProduto(const ACodigo: string;
  out AProdutoId: Int64; out ACodigoProduto, ADescricao: string;
  out APrecoVenda: Double): Boolean;
var
  LQuery: TSQLQuery;
  LCodigo: string;
begin
  Result := False;
  AProdutoId := 0;
  ACodigoProduto := '';
  ADescricao := '';
  APrecoVenda := 0;

  LCodigo := Trim(ACodigo);
  if LCodigo = '' then
    Exit;

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    { um parâmetro nomeado repetido só é ligado na primeira ocorrência
      no SQLDB: usar :COD1/:COD2 }
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID, CODIGO, DESCRICAO, PRECO_VENDA FROM PRODUTO ' +
      'WHERE (CODIGO = :COD1 OR CODIGO_BARRAS = :COD2) ' +
      'AND ATIVO = ''A'' AND EMPRESA_ID = :EMP';
    LQuery.ParamByName('COD1').AsString := LCodigo;
    LQuery.ParamByName('COD2').AsString := LCodigo;
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    if not LQuery.IsEmpty then
    begin
      AProdutoId := LQuery.FieldByName('ID').AsLargeInt;
      ACodigoProduto := Trim(LQuery.FieldByName('CODIGO').AsString);
      ADescricao := LQuery.FieldByName('DESCRICAO').AsString;
      APrecoVenda := LQuery.FieldByName('PRECO_VENDA').AsFloat;
      Result := True;
    end;
  finally
    LQuery.Free;
  end;
end;

function TPDVService.CaixaDaEmpresaAberto(ACaixaId: Int64): Boolean;
var
  LQuery: TSQLQuery;
begin
  Result := False;
  if ACaixaId <= 0 then
    Exit;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM CAIXA ' +
      'WHERE ID = :ID AND EMPRESA_ID = :EMP AND STATUS = :STS';
    LQuery.ParamByName('ID').AsLargeInt := ACaixaId;
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.ParamByName('STS').AsString := STATUS_CAIXA_ABERTO;
    LQuery.Open;
    Result := not LQuery.IsEmpty;
  finally
    LQuery.Free;
  end;
end;

function TPDVService.ClienteValido(AClienteId: Int64): Boolean;
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

function TPDVService.ProdutoDaEmpresa(AProdutoId: Int64): Boolean;
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
      'SELECT FIRST 1 ID FROM PRODUTO ' +
      'WHERE ID = :ID AND EMPRESA_ID = :EMP AND ATIVO = ''A''';
    LQuery.ParamByName('ID').AsLargeInt := AProdutoId;
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    Result := not LQuery.IsEmpty;
  finally
    LQuery.Free;
  end;
end;

function TPDVService.ResolverConsumidorFinal: Int64;
var
  LQuery: TSQLQuery;
begin
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM PESSOA ' +
      'WHERE EMPRESA_ID = :EMP AND TIPO = ''C'' ' +
      '  AND UPPER(NOME) = ''CONSUMIDOR FINAL'' ORDER BY ID';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('ID').AsLargeInt
    else
    begin
      LQuery.Close;
      LQuery.SQL.Text :=
        'INSERT INTO PESSOA (EMPRESA_ID, TIPO, TIPO_PESSOA, NOME, ' +
        '  CPF_CNPJ, ATIVO, DATA_CADASTRO) ' +
        'VALUES (:EMP, ''C'', ''F'', ''Consumidor Final'', ' +
        '  ''000.000.000-00'', ''A'', CURRENT_TIMESTAMP) RETURNING ID';
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.Open;
      Result := LQuery.FieldByName('ID').AsLargeInt;
      LQuery.Close;
      RegistrarAuditoriaSegura('PESSOA', 'INSERT', Result, '',
        'NOME=Consumidor Final');
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TPDVService.ValidarItens(const AItens: TItensPDVEntrada);
var
  I: Integer;
begin
  if Length(AItens) = 0 then
    raise Exception.Create('Nenhum item na venda.');

  for I := 0 to High(AItens) do
  begin
    if AItens[I].ProdutoId <= 0 then
      raise Exception.Create('Selecione um produto para o item.');
    if not ProdutoDaEmpresa(AItens[I].ProdutoId) then
      raise Exception.Create('Produto do item não encontrado.');
    if AItens[I].Quantidade <= 0 then
      raise Exception.Create('A quantidade do item deve ser maior que zero.');
    if AItens[I].PrecoUnitario < 0 then
      raise Exception.Create('O preço unitário do item não pode ser negativo.');
  end;
end;

function TPDVService.SalvarVenda(ACaixaId: Int64;
  const AItens: TItensPDVEntrada; ADesconto: Double;
  AFormaPagamentoId: Int64; AClienteId: Int64;
  const AObservacoes: string): Int64;
var
  LQuery: TSQLQuery;
  LSubtotal, LTotal, LTotalItem: Double;
  LNumero: string;
  LMovId: Int64;
  I: Integer;
begin
  if not CaixaDaEmpresaAberto(ACaixaId) then
    raise Exception.Create('Caixa inválido ou fechado.');
  ValidarItens(AItens);
  if ADesconto < 0 then
    raise Exception.Create('O desconto da venda não pode ser negativo.');
  if Length(AObservacoes) > TAMANHO_DESCRICAO then
    raise Exception.CreateFmt('As observações devem ter no máximo %d caracteres.',
      [TAMANHO_DESCRICAO]);
  if (AClienteId > 0) and (not ClienteValido(AClienteId)) then
    raise Exception.Create('Selecione um cliente ativo.');

  LSubtotal := 0;
  for I := 0 to High(AItens) do
    LSubtotal := LSubtotal + TotalItemPDV(AItens[I].Quantidade,
      AItens[I].PrecoUnitario);
  LTotal := TotalVendaPDV(LSubtotal, ADesconto);
  LNumero := IntToStr(ProximoNumeroVenda);

  FConexao.IniciarTransacao;
  LQuery := TSQLQuery.Create(nil);
  try
    try
      LQuery.DataBase := FConexao.Connection;
      LQuery.Transaction := FConexao.Transaction;

      { venda balcão sem cliente informado usa o Consumidor Final da empresa }
      if AClienteId <= 0 then
        AClienteId := ResolverConsumidorFinal;

      LQuery.SQL.Text :=
        'INSERT INTO PEDIDO_VENDA (EMPRESA_ID, CLIENTE_ID, USUARIO_ID, ' +
        '  NUMERO, STATUS, SUBTOTAL, DESCONTO, TOTAL, OBSERVACOES, ' +
        '  FORMA_PAGAMENTO_ID) ' +
        'VALUES (:EMP, :CLI, :USR, :NUM, :STS, :SUB, :DESC, :TOT, :OBS, ' +
        '  :FP) RETURNING ID';
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.ParamByName('CLI').AsLargeInt := AClienteId;
      LQuery.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
      LQuery.ParamByName('NUM').AsString := LNumero;
      LQuery.ParamByName('STS').AsString := STATUS_VENDA;
      LQuery.ParamByName('SUB').AsFloat := LSubtotal;
      LQuery.ParamByName('DESC').AsFloat := ADesconto;
      LQuery.ParamByName('TOT').AsFloat := LTotal;
      LQuery.ParamByName('OBS').AsString := Trim(AObservacoes);
      if AFormaPagamentoId > 0 then
        LQuery.ParamByName('FP').AsLargeInt := AFormaPagamentoId
      else
        LQuery.ParamByName('FP').Clear;
      LQuery.Open;
      Result := LQuery.FieldByName('ID').AsLargeInt;
      LQuery.Close;

      for I := 0 to High(AItens) do
      begin
        LTotalItem := TotalItemPDV(AItens[I].Quantidade,
          AItens[I].PrecoUnitario);
        LQuery.SQL.Text :=
          'INSERT INTO ITEM_PEDIDO (PEDIDO_VENDA_ID, PRODUTO_ID, ' +
          '  QUANTIDADE, PRECO_UNITARIO, VALOR_UNITARIO, DESCONTO, ' +
          '  VALOR_TOTAL, CFOP) ' +
          'VALUES (:PED, :PROD, :QTD, :PRECO, :VLR, 0, :TOT, :CFOP)';
        LQuery.ParamByName('PED').AsLargeInt := Result;
        LQuery.ParamByName('PROD').AsLargeInt := AItens[I].ProdutoId;
        LQuery.ParamByName('QTD').AsFloat := AItens[I].Quantidade;
        LQuery.ParamByName('PRECO').AsFloat := AItens[I].PrecoUnitario;
        LQuery.ParamByName('VLR').AsFloat := AItens[I].PrecoUnitario;
        LQuery.ParamByName('TOT').AsFloat := LTotalItem;
        LQuery.ParamByName('CFOP').AsString := CFOP_PADRAO;
        LQuery.ExecSQL;
      end;

      LQuery.SQL.Text :=
        'INSERT INTO MOVIMENTO_CAIXA (EMPRESA_ID, CAIXA_ID, TIPO, VALOR, ' +
        '  DESCRICAO, USUARIO_ID, PEDIDO_VENDA_ID, FORMA_PAGAMENTO_ID) ' +
        'VALUES (:EMP, :CX, :TIPO, :VLR, :DESC, :USR, :PED, :FP) ' +
        'RETURNING ID';
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.ParamByName('CX').AsLargeInt := ACaixaId;
      LQuery.ParamByName('TIPO').AsString := TIPO_MOV_VENDA;
      LQuery.ParamByName('VLR').AsFloat := LTotal;
      LQuery.ParamByName('DESC').AsString := 'Venda PDV';
      LQuery.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
      LQuery.ParamByName('PED').AsLargeInt := Result;
      if AFormaPagamentoId > 0 then
        LQuery.ParamByName('FP').AsLargeInt := AFormaPagamentoId
      else
        LQuery.ParamByName('FP').Clear;
      LQuery.Open;
      LMovId := LQuery.FieldByName('ID').AsLargeInt;
      LQuery.Close;

      RegistrarAuditoriaSegura('PEDIDO_VENDA', 'INSERT', Result, '',
        ResumoAuditoria([
          'NUMERO=' + LNumero,
          'CLIENTE_ID=' + IntToStr(AClienteId),
          'ITENS=' + IntToStr(Length(AItens)),
          'SUBTOTAL=' + FloatToStr(LSubtotal),
          'DESCONTO=' + FloatToStr(ADesconto),
          'TOTAL=' + FloatToStr(LTotal),
          'CAIXA_ID=' + IntToStr(ACaixaId)]));
      RegistrarAuditoriaSegura('MOVIMENTO_CAIXA', 'INSERT', LMovId, '',
        ResumoAuditoria([
          'CAIXA_ID=' + IntToStr(ACaixaId),
          'TIPO=' + TIPO_MOV_VENDA,
          'VALOR=' + FloatToStr(LTotal),
          'PEDIDO_VENDA_ID=' + IntToStr(Result)]));

      FConexao.Confirmar;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TPDVService.RegistrarMovimento(ACaixaId: Int64; ATipo: Char;
  AValor: Double; const ADescricao: string);
var
  LQuery: TSQLQuery;
  LMovId: Int64;
  LDescricao: string;
begin
  if (ATipo <> TIPO_MOV_ENTRADA) and (ATipo <> TIPO_MOV_SAIDA) then
    raise Exception.Create('Tipo de movimento inválido.');
  if AValor <= 0 then
    raise Exception.Create('O valor do movimento deve ser maior que zero.');
  if not CaixaDaEmpresaAberto(ACaixaId) then
    raise Exception.Create('Caixa inválido ou fechado.');

  LDescricao := Trim(ADescricao);
  if Length(LDescricao) > TAMANHO_DESCRICAO then
    raise Exception.CreateFmt('A descrição deve ter no máximo %d caracteres.',
      [TAMANHO_DESCRICAO]);

  FConexao.IniciarTransacao;
  LQuery := TSQLQuery.Create(nil);
  try
    try
      LQuery.DataBase := FConexao.Connection;
      LQuery.Transaction := FConexao.Transaction;
      LQuery.SQL.Text :=
        'INSERT INTO MOVIMENTO_CAIXA (EMPRESA_ID, CAIXA_ID, TIPO, VALOR, ' +
        '  DESCRICAO, USUARIO_ID) ' +
        'VALUES (:EMP, :CX, :TIPO, :VLR, :DESC, :USR) RETURNING ID';
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.ParamByName('CX').AsLargeInt := ACaixaId;
      LQuery.ParamByName('TIPO').AsString := ATipo;
      LQuery.ParamByName('VLR').AsFloat := AValor;
      LQuery.ParamByName('DESC').AsString := LDescricao;
      LQuery.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
      LQuery.Open;
      LMovId := LQuery.FieldByName('ID').AsLargeInt;
      LQuery.Close;

      RegistrarAuditoriaSegura('MOVIMENTO_CAIXA', 'INSERT', LMovId, '',
        ResumoAuditoria([
          'CAIXA_ID=' + IntToStr(ACaixaId),
          'TIPO=' + ATipo,
          'VALOR=' + FloatToStr(AValor)]));

      FConexao.Confirmar;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

function TPDVService.SaldoCaixa(ACaixaId: Int64): Double;
var
  LQuery: TSQLQuery;
begin
  Result := 0;
  if ACaixaId <= 0 then
    raise Exception.Create('Caixa inválido.');
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    { o CAST é necessário: SQLDB devolve a expressão NUMERIC sem ele
      como ftUnknown e o valor vem 0 }
    LQuery.SQL.Text :=
      'SELECT CAST(COALESCE(C.VALOR_ABERTURA, 0) + ' +
      '  COALESCE((SELECT SUM(CASE MC.TIPO ' +
      '    WHEN ''V'' THEN MC.VALOR WHEN ''E'' THEN MC.VALOR ' +
      '    WHEN ''S'' THEN -MC.VALOR ELSE 0 END) ' +
      '  FROM MOVIMENTO_CAIXA MC WHERE MC.CAIXA_ID = C.ID), 0) ' +
      '  AS NUMERIC(18,4)) AS SALDO ' +
      'FROM CAIXA C WHERE C.ID = :CX AND C.EMPRESA_ID = :EMP';
    LQuery.ParamByName('CX').AsLargeInt := ACaixaId;
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    if LQuery.IsEmpty then
      raise Exception.Create('Caixa não encontrado.');
    Result := LQuery.FieldByName('SALDO').AsFloat;
  finally
    LQuery.Free;
  end;
end;

function TPDVService.FecharCaixa(ACaixaId: Int64): Double;
var
  LQuery: TSQLQuery;
begin
  if not CaixaDaEmpresaAberto(ACaixaId) then
    raise Exception.Create('Caixa inválido ou já fechado.');

  Result := SaldoCaixa(ACaixaId);

  FConexao.IniciarTransacao;
  LQuery := TSQLQuery.Create(nil);
  try
    try
      LQuery.DataBase := FConexao.Connection;
      LQuery.Transaction := FConexao.Transaction;
      LQuery.SQL.Text :=
        'UPDATE CAIXA SET STATUS = ''F'', DATA_FECHAMENTO = CURRENT_TIMESTAMP, ' +
        '  VALOR_FECHAMENTO = :VLR WHERE ID = :ID AND STATUS = :STS';
      LQuery.ParamByName('VLR').AsFloat := Result;
      LQuery.ParamByName('ID').AsLargeInt := ACaixaId;
      LQuery.ParamByName('STS').AsString := STATUS_CAIXA_ABERTO;
      LQuery.ExecSQL;
      if LQuery.RowsAffected <> 1 then
        raise Exception.Create('Não foi possível fechar o caixa: o status mudou.');

      RegistrarAuditoriaSegura('CAIXA', 'FECHAMENTO', ACaixaId,
        'STATUS=' + STATUS_CAIXA_ABERTO,
        'STATUS=F; VALOR_FECHAMENTO=' + FloatToStr(Result));

      FConexao.Confirmar;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

function TPDVService.QuantidadeItens(AVendaId: Int64): Integer;
var
  LQuery: TSQLQuery;
begin
  Result := 0;
  if AVendaId <= 0 then
    Exit;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT COUNT(*) FROM ITEM_PEDIDO WHERE PEDIDO_VENDA_ID = :PED';
    LQuery.ParamByName('PED').AsLargeInt := AVendaId;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
  finally
    LQuery.Free;
  end;
end;

procedure TPDVService.CarregarFormasPagamento(AItems: TStrings);
var
  LQuery: TSQLQuery;
begin
  if AItems = nil then
    raise Exception.Create('CarregarFormasPagamento: lista não informada.');
  AItems.Clear;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT ID, DESCRICAO FROM FORMA_PAGAMENTO ' +
      'WHERE ATIVO = ''A'' ORDER BY ID';
    LQuery.Open;
    while not LQuery.EOF do
    begin
      AItems.AddObject(LQuery.FieldByName('DESCRICAO').AsString,
        TObject(PtrInt(LQuery.FieldByName('ID').AsLargeInt)));
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

end.
