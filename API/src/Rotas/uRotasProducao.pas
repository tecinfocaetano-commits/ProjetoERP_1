unit uRotasProducao;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Rotas de Produção (bipagem de talões)
  Endpoints:
    POST /api/producao/bipar   { "codigo": "...", "origem": "..." }

  A regra de negócio é a MESMA do desktop: executada por
  uProducaoBipagem.ExecutarBipagemTalao (unit compartilhada),
  com EMPRESA_ID/USUARIO_ID vindos do JWT — nunca do corpo.
  ============================================================ }

interface

uses
  Horse;

procedure RegistrarRotasProducao;

implementation

uses
  SysUtils, fpjson, jsonparser, SQLDB, IBConnection,
  uConexao, uMiddlewareJWT, uProducaoBipagem;

function ErroJSON(const AMensagem: string): string;
var
  LObj: TJSONObject;
begin
  LObj := TJSONObject.Create;
  try
    LObj.Add('error', AMensagem);
    Result := LObj.AsJSON;
  finally
    LObj.Free;
  end;
end;

procedure PostBiparTalao(Req: THorseRequest; Res: THorseResponse);
var
  LData: TJSONData;
  LBody: TJSONObject;
  LConexao: TConexao;
  LUsuarioId, LEmpresaId: Int64;
  LCodigo, LOrigem: string;
  LBip: TBipagemTalao;
  LObj: TJSONObject;
begin
  LData := nil;
  try
    try
      LData := GetJSON(Req.Body);
    except
      LData := nil;
    end;
    if not (LData is TJSONObject) then
    begin
      Res.Send(ErroJSON('Corpo da requisição inválido (objeto JSON esperado)'))
        .Status(THTTPStatus.BadRequest);
      Exit;
    end;

    DadosDoToken(Req, LUsuarioId, LEmpresaId);
    if LEmpresaId <= 0 then
    begin
      Res.Send(ErroJSON('Token sem empresa. Entre novamente.'))
        .Status(THTTPStatus.Unauthorized);
      Exit;
    end;

    LBody := TJSONObject(LData);
    LData := nil; { posse passa para LBody — evita double-free no finally }
    try
      LCodigo := LBody.Get('codigo', '');
      LOrigem := LBody.Get('origem', 'API');
    finally
      LBody.Free;
    end;

    if Trim(LCodigo) = '' then
    begin
      Res.Send(ErroJSON('Informe o código de barras do talão.'))
        .Status(THTTPStatus.BadRequest);
      Exit;
    end;

    LConexao := TConexao.GetInstance;
    LConexao.IniciarTransacao;
    try
      LBip := ExecutarBipagemTalao(LConexao.Connection,
        LConexao.Transaction, LEmpresaId, LUsuarioId, LCodigo, LOrigem);
      LConexao.Confirmar;
    except
      on E: Exception do
      begin
        LConexao.Cancelar;
        Res.Send(ErroJSON('Falha ao processar a bipagem: ' + E.Message))
          .Status(THTTPStatus.InternalServerError);
        Exit;
      end;
    end;

    LObj := TJSONObject.Create;
    try
      LObj.Add('resultado', LBip.Resultado);
      LObj.Add('mensagem', LBip.Mensagem);
      LObj.Add('etapa', LBip.Etapa);
      LObj.Add('codigo_barras', LBip.CodigoBarras);
      LObj.Add('talão_id', LBip.TalaoId);
      LObj.Add('numero_talao', LBip.NumeroTalao);
      LObj.Add('produto', LBip.Produto);
      LObj.Add('quantidade', LBip.Quantidade);
      LObj.Add('status_anterior', LBip.StatusAnterior);
      LObj.Add('status_novo', LBip.StatusNovo);
      LObj.Add('mapa_id', LBip.MapaId);
      LObj.Add('mapa_numero', LBip.MapaNumero);
      LObj.Add('mapa_concluido', LBip.MapaConcluido);
      Res.Send(LObj.AsJSON).Status(THTTPStatus.OK);
    finally
      LObj.Free;
    end;
  finally
    if LData <> nil then
      LData.Free;
  end;
end;

procedure RegistrarRotasProducao;
begin
  THorse.Post('/api/producao/bipar', @PostBiparTalao);
end;

end.
