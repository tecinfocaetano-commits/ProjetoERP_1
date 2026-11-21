unit uPagamentoService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Service de Pagamentos eletronicos do PDV
  ------------------------------------------------------------
  Esqueleto multi-provedor (Fase 0 do PROMPT_PAGAMENTOS_TEF_PIX):

    - maquina de estados em PAGAMENTO:
        PENDENTE -> PROCESSANDO -> APROVADO | RECUSADO | CANCELADO
        | EXPIRADO
    - NENHUMA venda/cupom/movimento de caixa existe enquanto o
      pagamento nao estiver APROVADO; a finalizacao chama
      TPDVService.SalvarVenda na mesma transacao das regras de caixa;
    - provedores sao plugaveis: TPaymentProvider + registry
      (ProvedorPagamento) resolvem o ativo pela configuracao
      PAG_PROVIDER da empresa (padrao SIMULADO);
    - IDEMPOTENCY_KEY unica por empresa impede cobranca duplicada
      em retry/webhook;
    - credenciais do PSP ficam em CONFIGURACAO (chaves PAG_*),
      nunca em codigo.

  O adapter SIMULADO existe para testes ponta a ponta sem PSP real:
  aprova a cobranca ~8s apos a criacao (ConsultarStatus faz a
  transicao) e devolve um QR_PAYLOAD no formato BR Code de mentira.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, fpjson, jsonparser, uConexao;

type
  { Status possiveis de PAGAMENTO.STATUS (espelha CK_PAG_STATUS). }
  TStatusPagamento = (
    spPendente, spProcessando, spAprovado, spRecusado,
    spCancelado, spExpirado);

  { Dados que o provedor devolve ao iniciar a cobranca. }
  TProviderCobranca = record
    TxId: string;
    QrPayload: string;
    QrImagemUrl: string;
    Instrucoes: string;
  end;

  { Contrato de um provedor de pagamento. Implementacoes reais
    (Asaas, MercadoPago, EFI, TEF...) herdam esta classe; a escolha
    do provedor ativo e por configuracao, nunca fixa no codigo. }
  TPaymentProvider = class
  public
    { Identificador estavel usado em PAGAMENTO.PROVEDOR. }
    function Codigo: string; virtual; abstract;

    { Inicia a cobranca no PSP. ADadosJson e o payload normalizado
      da intencao (valor, itens, descricao). }
    procedure IniciarCobranca(const ADadosJson: string;
      out ACobranca: TProviderCobranca); virtual; abstract;

    { Consulta o estado atual da cobranca no PSP.
      Retorna um TStatusPagamento. }
    function ConsultarStatus(const ATxId: string): TStatusPagamento;
      virtual; abstract;

    { Cancela/estorna a cobranca pendente. Implementacao padrao
      nao faz nada (provedores sem cancelamento remoto). }
    procedure Cancelar(const ATxId: string); virtual;
  end;

  TPagamentoService = class
  private
    FConexao: TConexao;

    function ExistePendente(const AIdempotencyKey: string): Int64;
    procedure CarregarPagamento(const APagamentoId: Int64;
      var LStatus: TStatusPagamento; var LTxId, LDadosJson: string;
      var LVendaId: Int64; var LExpiraEm: TDateTime);
    procedure AtualizarStatus(const APagamentoId: Int64;
      AStatus: TStatusPagamento; const AMotivo: string);
    function FinalizarSeAprovado(const APagamentoId: Int64;
      const LDadosJson, ATipoCobranca: string; AValor, ADesconto: Double;
      ACaixaId, AFormaPagamentoId: Int64): Int64;
  public
    constructor Create;

    { Cria a intencao de cobranca (PENDENTE) e chama o provedor.
      AIItensJson e o carrinho normalizado {itens,desconto}.
      Devolve o ID de PAGAMENTO; em retry com a mesma
      IDEMPOTENCY_KEY devolve o ID existente sem duplicar. }
    function IniciarCobranca(ACaixaId, AFormaPagamentoId: Int64;
      AValor, ADesconto: Double; const AIItensJson,
      AIdempotencyKey, ATipoCobranca: string): Int64;

    { Consulta o estado; se APROVADO e ainda nao finalizado, gera a
      venda via TPDVService (PEDIDO_VENDA + itens + movimento 'V').
      Devolve o status e, quando aprovado, o ID/numero da venda. }
    function ConsultarStatus(const APagamentoId: Int64;
      out AVendaId: Int64; out ANumeroVenda: string;
      out ATotalVenda: Double): TStatusPagamento;

    { Cancela cobranca ainda nao aprovada. }
    procedure CancelarCobranca(const APagamentoId: Int64);

    { Aplica um status vindo de fonte externa (webhook do PSP).
      So transiciona a partir de PENDENTE/PROCESSANDO; status
      terminais nunca sao reescritos (idempotencia de webhook
      duplicado). Retorna True se o status foi aplicado. }
    function AplicarStatusExterno(const APagamentoId: Int64;
      AStatus: TStatusPagamento; const AMotivo: string): Boolean;
  end;

{ Factory: devolve uma instancia do provedor pedido (caller libera).
  'SIMULADO' e o padrao; 'ASAAS', 'MERCADOPAGO', 'EFI' etc. serao
  registrados aqui conforme os adapters forem implementados. }
function ProvedorPagamento(const ACodigo: string): TPaymentProvider;

{ Le a chave PAG_PROVIDER da empresa (fallback global). }
function ProvedorPagamentoAtivo: string;

{ StatusPagamento -> texto gravado em PAGAMENTO.STATUS. }
function StatusParaTexto(AStatus: TStatusPagamento): string;

implementation

uses
  uSessao, uAuditoria, uPDVService, uConfiguracaoService, DateUtils;

const
  STATUS_PENDENTE   = 'PENDENTE';
  STATUS_PROCESSANDO= 'PROCESSANDO';
  STATUS_APROVADO   = 'APROVADO';
  STATUS_RECUSADO   = 'RECUSADO';
  STATUS_CANCELADO  = 'CANCELADO';
  STATUS_EXPIRADO   = 'EXPIRADO';

  CHAVE_PROVIDER = 'PAG_PROVIDER';
  PROVIDER_PADRAO = 'SIMULADO';

{ ------------------------------------------------------------------
  Status <-> texto
  ------------------------------------------------------------------ }

function StatusParaTexto(AStatus: TStatusPagamento): string;
begin
  case AStatus of
    spPendente:     Result := STATUS_PENDENTE;
    spProcessando:  Result := STATUS_PROCESSANDO;
    spAprovado:     Result := STATUS_APROVADO;
    spRecusado:     Result := STATUS_RECUSADO;
    spCancelado:    Result := STATUS_CANCELADO;
    spExpirado:     Result := STATUS_EXPIRADO;
  else
    Result := STATUS_PENDENTE;
  end;
end;

function TextoParaStatus(const ATexto: string): TStatusPagamento;
begin
  if SameText(ATexto, STATUS_PROCESSANDO) then
    Result := spProcessando
  else if SameText(ATexto, STATUS_APROVADO) then
    Result := spAprovado
  else if SameText(ATexto, STATUS_RECUSADO) then
    Result := spRecusado
  else if SameText(ATexto, STATUS_CANCELADO) then
    Result := spCancelado
  else if SameText(ATexto, STATUS_EXPIRADO) then
    Result := spExpirado
  else
    Result := spPendente;
end;

{ ------------------------------------------------------------------
  TPaymentProvider - implementacao padrao de Cancelar (no-op)
  ------------------------------------------------------------------ }

procedure TPaymentProvider.Cancelar(const ATxId: string);
begin
  { provedores sem cancelamento remoto herdam este no-op }
end;

{ ------------------------------------------------------------------
  Adapter SIMULADO - apenas para testes, NAO fala com PSP real.
  Aprova ~8s apos a criacao (o txid carrega o timestamp).
  ------------------------------------------------------------------ }

type
  TPaymentProviderSimulado = class(TPaymentProvider)
  public
    function Codigo: string; override;
    procedure IniciarCobranca(const ADadosJson: string;
      out ACobranca: TProviderCobranca); override;
    function ConsultarStatus(const ATxId: string): TStatusPagamento;
      override;
    procedure Cancelar(const ATxId: string); override;
  end;

function TPaymentProviderSimulado.Codigo: string;
begin
  Result := 'SIMULADO';
end;

procedure TPaymentProviderSimulado.IniciarCobranca(const ADadosJson: string;
  out ACobranca: TProviderCobranca);
var
  LValor: Double;
  LData: TJSONData;
begin
  FillChar(ACobranca, SizeOf(ACobranca), 0);
  { extrai o valor para o payload fake; qualquer falha usa 0 }
  LValor := 0;
  try
    LData := GetJSON(ADadosJson);
    try
      if LData is TJSONObject then
        LValor := TJSONObject(LData).Get('valor', Double(0));
    finally
      LData.Free;
    end;
  except
  end;
  ACobranca.TxId := 'SIM-' + IntToStr(DateTimeToUnix(Now)) + '-' +
    IntToStr(Random(99999));
  ACobranca.QrPayload :=
    '00020126BR.GOV.BCB.PIXfake' + Format('%.2f', [LValor]) +
    ACobranca.TxId;
  ACobranca.Instrucoes :=
    'MODO SIMULADO: cobranca aprovada automaticamente ~8s apos o inicio. ' +
    'Nao ha integracao real com PSP.';
end;

function TPaymentProviderSimulado.ConsultarStatus(const ATxId: string)
  : TStatusPagamento;
var
  LPos: Integer;
  LTs: Int64;
  LTx: string;
begin
  { txid = SIM-<unixtime>-<rand>; aprovado apos 8 segundos }
  Result := spPendente;
  LTx := ATxId;
  LPos := Pos('SIM-', LTx);
  if LPos = 0 then
    Exit;
  Delete(LTx, 1, LPos + 3);
  LPos := Pos('-', LTx);
  if LPos = 0 then
    Exit;
  try
    LTs := StrToInt64(Copy(LTx, 1, LPos - 1));
  except
    Exit;
  end;
  if (DateTimeToUnix(Now) - LTs) >= 8 then
    Result := spAprovado;
end;

procedure TPaymentProviderSimulado.Cancelar(const ATxId: string);
begin
  { nada a fazer: a "cobranca" e apenas o relogio }
end;

{ ------------------------------------------------------------------
  Registry de provedores
  ------------------------------------------------------------------ }

function ProvedorPagamento(const ACodigo: string): TPaymentProvider;
begin
  if SameText(Trim(ACodigo), 'SIMULADO') or (Trim(ACodigo) = '') then
    Result := TPaymentProviderSimulado.Create
  else
    raise Exception.CreateFmt(
      'Provedor de pagamento "%s" ainda nao implementado. ' +
      'Provedores previstos: ASAAS, MERCADOPAGO, EFI, TEF_*.',
      [Trim(ACodigo)]);
end;

function ProvedorPagamentoAtivo: string;
var
  LConfig: TConfiguracaoService;
begin
  LConfig := TConfiguracaoService.Create;
  try
    Result := Trim(LConfig.LerValor(CHAVE_PROVIDER));
  finally
    LConfig.Free;
  end;
  if Result = '' then
    Result := PROVIDER_PADRAO;
end;

{ ------------------------------------------------------------------
  TPagamentoService
  ------------------------------------------------------------------ }

constructor TPagamentoService.Create;
begin
  inherited Create;
  FConexao := TConexao.GetInstance;
end;

function TPagamentoService.ExistePendente(const AIdempotencyKey: string)
  : Int64;
var
  LQuery: TSQLQuery;
begin
  Result := 0;
  if Trim(AIdempotencyKey) = '' then
    Exit;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM PAGAMENTO ' +
      'WHERE EMPRESA_ID = :EMP AND IDEMPOTENCY_KEY = :KEY';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.ParamByName('KEY').AsString := Trim(AIdempotencyKey);
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('ID').AsLargeInt;
  finally
    LQuery.Free;
  end;
end;

procedure TPagamentoService.CarregarPagamento(const APagamentoId: Int64;
  var LStatus: TStatusPagamento; var LTxId, LDadosJson: string;
  var LVendaId: Int64; var LExpiraEm: TDateTime);
var
  LQuery: TSQLQuery;
begin
  LStatus := spPendente;
  LTxId := '';
  LDadosJson := '';
  LVendaId := 0;
  LExpiraEm := 0;

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT STATUS, PROVEDOR_TXID, DADOS_JSON, PEDIDO_VENDA_ID, ' +
      '  EXPIRA_EM FROM PAGAMENTO ' +
      'WHERE ID = :ID AND EMPRESA_ID = :EMP';
    LQuery.ParamByName('ID').AsLargeInt := APagamentoId;
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    if LQuery.IsEmpty then
      raise Exception.Create('Pagamento não encontrado.');
    LStatus := TextoParaStatus(
      Trim(LQuery.FieldByName('STATUS').AsString));
    LTxId := Trim(LQuery.FieldByName('PROVEDOR_TXID').AsString);
    LDadosJson := LQuery.FieldByName('DADOS_JSON').AsString;
    LVendaId := LQuery.FieldByName('PEDIDO_VENDA_ID').AsLargeInt;
    if not LQuery.FieldByName('EXPIRA_EM').IsNull then
      LExpiraEm := LQuery.FieldByName('EXPIRA_EM').AsDateTime;
  finally
    LQuery.Free;
  end;
end;

procedure TPagamentoService.AtualizarStatus(const APagamentoId: Int64;
  AStatus: TStatusPagamento; const AMotivo: string);
var
  LQuery: TSQLQuery;
begin
  { PROVEDOR_TXID nunca e reescrito aqui: o txid e a chave de
    correlacao do webhook e precisa permanecer estavel. }
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'UPDATE PAGAMENTO SET STATUS = :STS, MOTIVO = :MOT, ' +
      '  CONFIRMADO_EM = ' +
      '  CASE WHEN :STS2 = ''APROVADO'' THEN CURRENT_TIMESTAMP ' +
      '       ELSE CONFIRMADO_EM END ' +
      'WHERE ID = :ID AND EMPRESA_ID = :EMP';
    LQuery.ParamByName('STS').AsString := StatusParaTexto(AStatus);
    LQuery.ParamByName('STS2').AsString := StatusParaTexto(AStatus);
    if Trim(AMotivo) <> '' then
      LQuery.ParamByName('MOT').AsString := Trim(AMotivo)
    else
      LQuery.ParamByName('MOT').Clear;
    LQuery.ParamByName('ID').AsLargeInt := APagamentoId;
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

{ Monta TItensPDVEntrada + desconto a partir do DADOS_JSON gravado.
  Formato: {"itens":[{"produto_id":N,"quantidade":N,"preco_unitario":N}],
            "desconto":N} }
function ItensDoDadosJson(const ADadosJson: string;
  out AItens: TItensPDVEntrada; out ADesconto: Double): Boolean;
var
  LData, LItemData: TJSONData;
  LArray: TJSONArray;
  I: Integer;
begin
  Result := False;
  ADesconto := 0;
  SetLength(AItens, 0);
  try
    LData := GetJSON(ADadosJson);
  except
    Exit;
  end;
  try
    if not (LData is TJSONObject) then
      Exit;
    ADesconto := TJSONObject(LData).Get('desconto', Double(0));
    LItemData := TJSONObject(LData).Find('itens');
    if not (LItemData is TJSONArray) then
      Exit;
    LArray := TJSONArray(LItemData);
    SetLength(AItens, LArray.Count);
    for I := 0 to LArray.Count - 1 do
    begin
      if LArray.Items[I] is TJSONObject then
      begin
        AItens[I].ProdutoId :=
          TJSONObject(LArray.Items[I]).Get('produto_id', Int64(0));
        AItens[I].Quantidade :=
          TJSONObject(LArray.Items[I]).Get('quantidade', Double(0));
        AItens[I].PrecoUnitario :=
          TJSONObject(LArray.Items[I]).Get('preco_unitario', Double(0));
      end;
    end;
    Result := Length(AItens) > 0;
  finally
    LData.Free;
  end;
end;

function TPagamentoService.FinalizarSeAprovado(const APagamentoId: Int64;
  const LDadosJson, ATipoCobranca: string; AValor, ADesconto: Double;
  ACaixaId, AFormaPagamentoId: Int64): Int64;
var
  LItens: TItensPDVEntrada;
  LDesc: Double;
  LServico: TPDVService;
  LQuery: TSQLQuery;
begin
  { CLAIM ATOMICO: so um finalizador por vez. O UPDATE so casa se a
    cobranca ainda esta APROVADO e sem venda vinculada; o lock da
    linha impede duas threads de entrarem juntas. Em caso de falha
    na gravacao da venda, o status volta para APROVADO. }
  FConexao.IniciarTransacao;
  LQuery := TSQLQuery.Create(nil);
  try
    try
      LQuery.DataBase := FConexao.Connection;
      LQuery.Transaction := FConexao.Transaction;
      LQuery.SQL.Text :=
        'UPDATE PAGAMENTO SET STATUS = ''PROCESSANDO'' ' +
        'WHERE ID = :ID AND EMPRESA_ID = :EMP ' +
        '  AND STATUS = ''APROVADO'' AND PEDIDO_VENDA_ID IS NULL';
      LQuery.ParamByName('ID').AsLargeInt := APagamentoId;
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.ExecSQL;
      if LQuery.RowsAffected = 0 then
      begin
        { outro processo ja vinculou a venda (ou estado mudou) }
        FConexao.Confirmar;
        Result := 0;
        Exit;
      end;
      FConexao.Confirmar;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;

  if not ItensDoDadosJson(LDadosJson, LItens, LDesc) then
  begin
    AtualizarStatus(APagamentoId, spAprovado,
      'Aprovado mas carrinho inválido.');
    raise Exception.Create('Pagamento aprovado mas o carrinho está ' +
      'vazio ou inválido — finalize manualmente ou cancele.');
  end;

  LServico := TPDVService.Create;
  try
    Result := LServico.SalvarVenda(ACaixaId, LItens, ADesconto,
      AFormaPagamentoId, 0,
      'PDV ' + ATipoCobranca + ' (pagamento ' + IntToStr(APagamentoId) + ')');
  finally
    LServico.Free;
  end;

  { vincula a venda a cobranca em transacao explicita — sem isso o
    middleware devolve a conexao com a transacao aberta e o UPDATE
    e revertido (bug que gerava venda duplicada a cada consulta) }
  FConexao.IniciarTransacao;
  LQuery := TSQLQuery.Create(nil);
  try
    try
      LQuery.DataBase := FConexao.Connection;
      LQuery.Transaction := FConexao.Transaction;
      LQuery.SQL.Text :=
        'UPDATE PAGAMENTO SET PEDIDO_VENDA_ID = :PED, ' +
        '  STATUS = ''APROVADO'' ' +
        'WHERE ID = :ID AND EMPRESA_ID = :EMP';
      LQuery.ParamByName('PED').AsLargeInt := Result;
      LQuery.ParamByName('ID').AsLargeInt := APagamentoId;
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.ExecSQL;
      FConexao.Confirmar;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

function TPagamentoService.IniciarCobranca(ACaixaId,
  AFormaPagamentoId: Int64; AValor, ADesconto: Double;
  const AIItensJson, AIdempotencyKey, ATipoCobranca: string): Int64;
var
  LProvider: TPaymentProvider;
  LCobranca: TProviderCobranca;
  LProviderNome, LProviderCodigo, LIdem: string;
  LQuery: TSQLQuery;
  LExpira: TDateTime;
begin
  LIdem := Trim(AIdempotencyKey);
  Result := ExistePendente(LIdem);
  if Result > 0 then
    Exit;

  if AValor <= 0 then
    raise Exception.Create('O valor da cobrança deve ser maior que zero.');
  if Trim(AIItensJson) = '' then
    raise Exception.Create('Carrinho vazio para cobrança.');

  LProviderNome := ProvedorPagamentoAtivo;
  LProvider := ProvedorPagamento(LProviderNome);
  try
    LProvider.IniciarCobranca(AIItensJson, LCobranca);
    LProviderCodigo := LProvider.Codigo;
  finally
    LProvider.Free;
  end;

  if Trim(LCobranca.TxId) = '' then
    raise Exception.Create('Provedor não retornou identificador da cobrança.');

  { PIX expira em 30min por padrão; demais tipos não expiram }
  LExpira := 0;
  if SameText(ATipoCobranca, 'PIX') then
    LExpira := Now + (30 / 1440);

  FConexao.IniciarTransacao;
  LQuery := TSQLQuery.Create(nil);
  try
    try
      LQuery.DataBase := FConexao.Connection;
      LQuery.Transaction := FConexao.Transaction;
      LQuery.SQL.Text :=
        'INSERT INTO PAGAMENTO (EMPRESA_ID, USUARIO_ID, CAIXA_ID, ' +
        '  FORMA_PAGAMENTO_ID, PROVEDOR, TIPO_COBRANCA, STATUS, VALOR, ' +
        '  DESCONTO, DADOS_JSON, IDEMPOTENCY_KEY, PROVEDOR_TXID, ' +
        '  QR_PAYLOAD, QR_IMAGEM_URL, EXPIRA_EM, OBSERVACOES) ' +
        'VALUES (:EMP, :USR, :CX, :FP, :PROV, :TIPO, :STS, :VLR, ' +
        '  :DESC, :JSON, :IDEM, :TX, :QR, :QRI, :EXP, :OBS) RETURNING ID';
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
      if ACaixaId > 0 then
        LQuery.ParamByName('CX').AsLargeInt := ACaixaId
      else
        LQuery.ParamByName('CX').Clear;
      if AFormaPagamentoId > 0 then
        LQuery.ParamByName('FP').AsLargeInt := AFormaPagamentoId
      else
        LQuery.ParamByName('FP').Clear;
      LQuery.ParamByName('PROV').AsString := LProviderCodigo;
      LQuery.ParamByName('TIPO').AsString := Trim(ATipoCobranca);
      LQuery.ParamByName('STS').AsString := STATUS_PENDENTE;
      LQuery.ParamByName('VLR').AsFloat := AValor;
      LQuery.ParamByName('DESC').AsFloat := ADesconto;
      LQuery.ParamByName('JSON').AsString := AIItensJson;
      if LIdem <> '' then
        LQuery.ParamByName('IDEM').AsString := LIdem
      else
        LQuery.ParamByName('IDEM').Clear;
      LQuery.ParamByName('TX').AsString := LCobranca.TxId;
      LQuery.ParamByName('QR').AsString := LCobranca.QrPayload;
      LQuery.ParamByName('QRI').AsString := LCobranca.QrImagemUrl;
      if LExpira > 0 then
        LQuery.ParamByName('EXP').AsDateTime := LExpira
      else
        LQuery.ParamByName('EXP').Clear;
      LQuery.ParamByName('OBS').AsString := LCobranca.Instrucoes;
      LQuery.Open;
      Result := LQuery.FieldByName('ID').AsLargeInt;
      LQuery.Close;

      RegistrarAuditoriaSegura('PAGAMENTO', 'INSERT', Result, '',
        ResumoAuditoria([
          'PROVEDOR=' + LProviderCodigo,
          'TIPO=' + Trim(ATipoCobranca),
          'VALOR=' + FloatToStr(AValor),
          'TXID=' + LCobranca.TxId]));

      FConexao.Confirmar;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

function TPagamentoService.ConsultarStatus(const APagamentoId: Int64;
  out AVendaId: Int64; out ANumeroVenda: string;
  out ATotalVenda: Double): TStatusPagamento;
var
  LStatus: TStatusPagamento;
  LTxId, LDadosJson, LProviderNome, LTipo, LObs: string;
  LVendaId, LCaixaId, LFormaId: Int64;
  LValor, LDesconto: Double;
  LExpiraEm: TDateTime;
  LProvider: TPaymentProvider;
  LNovoStatus: TStatusPagamento;
  LQuery: TSQLQuery;
begin
  AVendaId := 0;
  ANumeroVenda := '';
  ATotalVenda := 0;

  CarregarPagamento(APagamentoId, LStatus, LTxId, LDadosJson,
    LVendaId, LExpiraEm);

  { dados complementares para eventual finalizacao }
  LProviderNome := '';
  LTipo := '';
  LCaixaId := 0;
  LFormaId := 0;
  LValor := 0;
  LDesconto := 0;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT PROVEDOR, TIPO_COBRANCA, CAIXA_ID, FORMA_PAGAMENTO_ID, ' +
      '  VALOR, DESCONTO FROM PAGAMENTO WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := APagamentoId;
    LQuery.Open;
    if not LQuery.IsEmpty then
    begin
      LProviderNome := Trim(LQuery.FieldByName('PROVEDOR').AsString);
      LTipo := Trim(LQuery.FieldByName('TIPO_COBRANCA').AsString);
      LCaixaId := LQuery.FieldByName('CAIXA_ID').AsLargeInt;
      LFormaId := LQuery.FieldByName('FORMA_PAGAMENTO_ID').AsLargeInt;
      LValor := LQuery.FieldByName('VALOR').AsFloat;
      LDesconto := LQuery.FieldByName('DESCONTO').AsFloat;
    end;
  finally
    LQuery.Free;
  end;

  { expirou? (PIX tem EXPIRA_EM; demais tipos EXPIRA_EM nulo) }
  if (LExpiraEm > 0) and (Now > LExpiraEm) and
     (LStatus in [spPendente, spProcessando]) then
  begin
    AtualizarStatus(APagamentoId, spExpirado, 'Tempo de pagamento esgotado.');
    LStatus := spExpirado;
  end;

  { consulta o provedor apenas se ainda esta em aberto }
  if LStatus in [spPendente, spProcessando] then
  begin
    if LTxId = '' then
    begin
      AtualizarStatus(APagamentoId, spRecusado,
        'Cobrança sem identificador do provedor.');
      LStatus := spRecusado;
    end
    else
    begin
      LProvider := ProvedorPagamento(LProviderNome);
      try
        try
          LNovoStatus := LProvider.ConsultarStatus(LTxId);
        except
          on E: Exception do
          begin
            { falha de comunicacao nao muda o estado: segue pendente }
            LNovoStatus := LStatus;
          end;
        end;
      finally
        LProvider.Free;
      end;
      if LNovoStatus <> LStatus then
      begin
        AtualizarStatus(APagamentoId, LNovoStatus, '');
        LStatus := LNovoStatus;
      end;
    end;
  end;

  { aprovado -> finaliza a venda UMA vez (idempotente por
    PEDIDO_VENDA_ID preenchido); se ja vinculado, devolve a venda
    existente para a tela de espera nao ficar sem o cupom }
  if LStatus = spAprovado then
  begin
    if LVendaId = 0 then
      AVendaId := FinalizarSeAprovado(APagamentoId, LDadosJson, LTipo,
        LValor, LDesconto, LCaixaId, LFormaId)
    else
      AVendaId := LVendaId;
  end;

  if AVendaId > 0 then
  begin
    LQuery := TSQLQuery.Create(nil);
    try
      LQuery.DataBase := FConexao.Connection;
      LQuery.Transaction := FConexao.Transaction;
      LQuery.SQL.Text :=
        'SELECT NUMERO, TOTAL FROM PEDIDO_VENDA WHERE ID = :ID';
      LQuery.ParamByName('ID').AsLargeInt := AVendaId;
      LQuery.Open;
      if not LQuery.IsEmpty then
      begin
        ANumeroVenda := LQuery.FieldByName('NUMERO').AsString;
        ATotalVenda := LQuery.FieldByName('TOTAL').AsFloat;
      end;
    finally
      LQuery.Free;
    end;
  end;

  Result := LStatus;
end;

procedure TPagamentoService.CancelarCobranca(const APagamentoId: Int64);
var
  LStatus: TStatusPagamento;
  LTxId, LDadosJson: string;
  LVendaId: Int64;
  LExpiraEm: TDateTime;
  LQuery: TSQLQuery;
  LProviderNome: string;
  LProvider: TPaymentProvider;
begin
  CarregarPagamento(APagamentoId, LStatus, LTxId, LDadosJson,
    LVendaId, LExpiraEm);

  if LStatus = spAprovado then
    raise Exception.Create('Pagamento já aprovado — não pode ser cancelado.');
  if LStatus in [spRecusado, spCancelado, spExpirado] then
    Exit; { já encerrou }

  { avisa o provedor (best-effort) }
  if LTxId <> '' then
  begin
    LQuery := TSQLQuery.Create(nil);
    try
      LQuery.DataBase := FConexao.Connection;
      LQuery.Transaction := FConexao.Transaction;
      LQuery.SQL.Text :=
        'SELECT PROVEDOR FROM PAGAMENTO WHERE ID = :ID';
      LQuery.ParamByName('ID').AsLargeInt := APagamentoId;
      LQuery.Open;
      LProviderNome := Trim(LQuery.FieldByName('PROVEDOR').AsString);
    finally
      LQuery.Free;
    end;
    try
      LProvider := ProvedorPagamento(LProviderNome);
      try
        LProvider.Cancelar(LTxId);
      finally
        LProvider.Free;
      end;
    except
      { provedor indisponível: cancela localmente mesmo assim }
    end;
  end;

  AtualizarStatus(APagamentoId, spCancelado, 'Cancelado pelo operador.');
end;

function TPagamentoService.AplicarStatusExterno(const APagamentoId: Int64;
  AStatus: TStatusPagamento; const AMotivo: string): Boolean;
var
  LStatus: TStatusPagamento;
  LTxId, LDadosJson: string;
  LVendaId: Int64;
  LExpiraEm: TDateTime;
begin
  Result := False;
  CarregarPagamento(APagamentoId, LStatus, LTxId, LDadosJson,
    LVendaId, LExpiraEm);

  { terminais sao imutaveis: webhook duplicado e inofensivo }
  if not (LStatus in [spPendente, spProcessando]) then
    Exit;
  if AStatus in [spPendente, spProcessando] then
    Exit; { webhook "pending" nao avanca a maquina }

  AtualizarStatus(APagamentoId, AStatus, AMotivo);
  Result := True;
end;

end.
