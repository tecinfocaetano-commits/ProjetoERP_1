unit uPagamentoMercadoPago;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Adapter Mercado Pago (PIX via API v1)
  ------------------------------------------------------------
  Provedor real de PIX — Fase 1 do PROMPT_EXECUCAO_PAGAMENTOS.

  Fluxo (Checkout API /v1/payments, payment_method_id=PIX):
    IniciarCobranca  POST /v1/payments  -> id + QR copia-e-cola
                     (point_of_interaction.transaction_data)
    ConsultarStatus  GET  /v1/payments/{id} -> mapeia status MP
    Cancelar         PUT  /v1/payments/{id} {"status":"cancelled"}
                     (so funciona enquanto pending)

  Credenciais (CONFIGURACAO da empresa, chaves PAG_*):
    PAG_PROVIDER = 'MERCADOPAGO'
    PAG_MERCADOPAGO_ACCESS_TOKEN = token de teste/produção
    PAG_MERCADOPAGO_PAYER_EMAIL  = e-mail do pagador (MP exige;
                                  fallback pdv@erp2026.local)

  NUNCA commitar o token. O adapter falha com mensagem clara
  quando a chave nao esta configurada.

  Status MP -> maquina de estados local:
    approved      -> APROVADO
    in_process    -> PROCESSANDO
    pending       -> PENDENTE
    authorized    -> PENDENTE
    rejected      -> RECUSADO
    cancelled     -> CANCELADO
    refunded /
    charged_back  -> RECUSADO (estorno pos-venda: registrar motivo)
  ============================================================ }

interface

uses
  Classes, SysUtils, fpjson, jsonparser, fphttpclient,
  uPagamentoTipos, uConfiguracaoService;

type
  TPaymentProviderMercadoPago = class(TPaymentProvider)
  private
    FAccessToken: string;
    FPayerEmail: string;

    function HttpJson(const AMethod, AUrl, ABody: string): string;
    function LerChave(const AChave, APadrao: string): string;
  public
    constructor Create;
    function Codigo: string; override;
    procedure IniciarCobranca(const ADadosJson: string;
      out ACobranca: TProviderCobranca); override;
    function ConsultarStatus(const ATxId: string): TStatusPagamento;
      override;
    procedure Cancelar(const ATxId: string); override;
  end;

implementation

uses
  DateUtils;

const
  API_BASE = 'https://api.mercadopago.com';
  CHAVE_TOKEN = 'PAG_MERCADOPAGO_ACCESS_TOKEN';
  CHAVE_EMAIL = 'PAG_MERCADOPAGO_PAYER_EMAIL';
  EMAIL_PADRAO = 'pdv@erp2026.local';
  TIMEOUT_MS = 15000;

constructor TPaymentProviderMercadoPago.Create;
begin
  inherited Create;
  FAccessToken := '';
  FPayerEmail := '';
end;

function TPaymentProviderMercadoPago.Codigo: string;
begin
  Result := 'MERCADOPAGO';
end;

function TPaymentProviderMercadoPago.LerChave(const AChave,
  APadrao: string): string;
var
  LConfig: TConfiguracaoService;
begin
  LConfig := TConfiguracaoService.Create;
  try
    Result := Trim(LConfig.LerValor(AChave));
  finally
    LConfig.Free;
  end;
  if Result = '' then
    Result := APadrao;
end;

{ POST/GET/PUT JSON contra a API do MP. Devolve o corpo ou levanta
  excecao com o erro do PSP. }
function TPaymentProviderMercadoPago.HttpJson(const AMethod,
  AUrl, ABody: string): string;
var
  LClient: TFPHTTPClient;
  LStream: TStringStream;
  LResp: RawByteString;
begin
  LClient := TFPHTTPClient.Create(nil);
  LStream := nil;
  try
    LClient.ConnectTimeout := TIMEOUT_MS;
    LClient.IOTimeout := TIMEOUT_MS;
    LClient.AddHeader('Authorization', 'Bearer ' + FAccessToken);
    LClient.AddHeader('Content-Type', 'application/json');
    if AMethod <> 'GET' then
      LClient.AddHeader('X-Idempotency-Key',
        'erp2026-' + IntToStr(DateTimeToUnix(Now)) + '-' +
        IntToStr(Random(999999)));
    if (AMethod <> 'GET') and (Trim(ABody) <> '') then
    begin
      LStream := TStringStream.Create(ABody, TEncoding.UTF8);
      LClient.RequestBody := LStream;
    end;
    if SameText(AMethod, 'POST') then
      LResp := LClient.Post(AUrl)
    else if SameText(AMethod, 'PUT') then
      LResp := LClient.Put(AUrl)
    else
      LResp := LClient.Get(AUrl);
    if (LClient.ResponseStatusCode < 200) or
       (LClient.ResponseStatusCode >= 300) then
      raise Exception.CreateFmt(
        'Mercado Pago HTTP %d: %s',
        [LClient.ResponseStatusCode, String(LResp)]);
    Result := String(LResp);
  finally
    LClient.Free;
    LStream.Free;
  end;
end;

procedure TPaymentProviderMercadoPago.IniciarCobranca(
  const ADadosJson: string; out ACobranca: TProviderCobranca);
var
  LData, LTransacao: TJSONData;
  LRoot, LPayer: TJSONObject;
  LValor: Double;
  LBody, LResp, LEmail: string;
begin
  FillChar(ACobranca, SizeOf(ACobranca), 0);

  FAccessToken := LerChave(CHAVE_TOKEN, '');
  if FAccessToken = '' then
    raise Exception.Create('PAG_MERCADOPAGO_ACCESS_TOKEN não ' +
      'configurado em CONFIGURACAO (empresa). Cadastre o token ' +
      'de teste do Mercado Pago para usar PIX real.');
  FPayerEmail := LerChave(CHAVE_EMAIL, EMAIL_PADRAO);

  { valor e descricao do carrinho normalizado }
  LValor := 0;
  try
    LData := GetJSON(ADadosJson);
    try
      if LData is TJSONObject then
      begin
        LValor := TJSONObject(LData).Get('valor', Double(0));
        if LValor <= 0 then
          LValor := 0.01; { MP exige valor > 0 }
      end;
    finally
      LData.Free;
    end;
  except
  end;

  LRoot := TJSONObject.Create;
  try
    LRoot.Add('transaction_amount', LValor);
    LRoot.Add('description', 'Venda PDV ERP2026');
    LRoot.Add('payment_method_id', 'pix');
    LPayer := TJSONObject.Create;
    TJSONObject(LPayer).Add('email', FPayerEmail);
    LRoot.Add('payer', LPayer);
    LRoot.Add('external_reference',
      'PDV-' + IntToStr(DateTimeToUnix(Now)));
    LBody := LRoot.AsJSON;
  finally
    LRoot.Free;
    { LPayer pertence ao root }
  end;

  LResp := HttpJson('POST', API_BASE + '/v1/payments', LBody);

  { extrai id, QR copia-e-cola e expiração }
  try
    LData := GetJSON(LResp);
    try
      if not (LData is TJSONObject) then
        raise Exception.Create('Resposta inesperada do Mercado Pago.');
      ACobranca.TxId :=
        TJSONObject(LData).Get('id', Int64(0)).ToString;
      if ACobranca.TxId = '0' then
        raise Exception.Create('Mercado Pago não retornou id do pagamento.');
      LTransacao := TJSONObject(LData).Find('point_of_interaction');
      if LTransacao is TJSONObject then
      begin
        LTransacao := TJSONObject(LTransacao).Find(
          'transaction_data');
        if LTransacao is TJSONObject then
          ACobranca.QrPayload := TJSONObject(LTransacao)
            .Get('qr_code', '');
      end;
      ACobranca.Instrucoes :=
        'Pague o QR Code no app do seu banco. Aguardando confirmação ' +
        'do Mercado Pago.';
    finally
      LData.Free;
    end;
  except
    on E: Exception do
      raise Exception.Create('Falha ao criar cobrança PIX no ' +
        'Mercado Pago: ' + E.Message);
  end;
end;

function TPaymentProviderMercadoPago.ConsultarStatus(
  const ATxId: string): TStatusPagamento;
var
  LResp, LStatus: string;
  LData: TJSONData;
begin
  LResp := HttpJson('GET', API_BASE + '/v1/payments/' + ATxId, '');
  try
    LData := GetJSON(LResp);
    try
      if not (LData is TJSONObject) then
        Exit(spPendente);
      LStatus := LowerCase(Trim(
        TJSONObject(LData).Get('status', '')));
      if LStatus = 'approved' then
        Result := spAprovado
      else if LStatus = 'in_process' then
        Result := spProcessando
      else if LStatus = 'rejected' then
        Result := spRecusado
      else if LStatus = 'cancelled' then
        Result := spCancelado
      else if (LStatus = 'refunded') or (LStatus = 'charged_back') then
        Result := spRecusado
      else
        Result := spPendente; { pending, authorized, etc. }
    finally
      LData.Free;
    end;
  except
    on E: Exception do
      raise; { propaga: a rota decide manter PENDENTE }
  end;
end;

procedure TPaymentProviderMercadoPago.Cancelar(const ATxId: string);
begin
  { PUT /v1/payments/{id} {"status":"cancelled"} — só vale para
    pagamentos pending; se já foi pago, o PSP recusa e o erro
    propaga (a rota cancela localmente mesmo assim). }
  HttpJson('PUT', API_BASE + '/v1/payments/' + ATxId,
    '{"status":"cancelled"}');
end;

end.
