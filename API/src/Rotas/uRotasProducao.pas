unit uRotasProducao;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Rotas de Produção (bipagem de talões)
  Endpoints:
    POST /api/producao/bipar     { "codigo": "...", "origem": "..." }
    GET  /api/producao/bipagens?limite=50

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

{ GET /api/producao/bipagens?limite=50 — últimas bipagens da empresa.
  TALAO_BIPAGEM não tem EMPRESA_ID: o isolamento é pelo USUARIO que
  bipou (USUARIO.EMPRESA_ID = empresa do token). TALAO_ID = 0 marca
  código inexistente, então o join com TALAO é LEFT. }
procedure GetBipagens(Req: THorseRequest; Res: THorseResponse);
var
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LUsuarioId, LEmpresaId: Int64;
  LLimite: Integer;
  LArr: TJSONArray;
  LObj: TJSONObject;
  LParam: string;
begin
  DadosDoToken(Req, LUsuarioId, LEmpresaId);
  if LEmpresaId <= 0 then
  begin
    Res.Send(ErroJSON('Token sem empresa. Entre novamente.'))
      .Status(THTTPStatus.Unauthorized);
    Exit;
  end;

  LLimite := StrToIntDef(Req.Query['limite'], 50);
  if (LLimite <= 0) or (LLimite > 500) then
    LLimite := 50;

  LConexao := TConexao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  LArr := TJSONArray.Create;
  try
    LConexao.IniciarTransacao;
    try
      LQuery.DataBase := LConexao.Connection;
      LQuery.Transaction := LConexao.Transaction;
      LQuery.SQL.Text :=
      'SELECT FIRST ' + IntToStr(LLimite) + ' ' +
      '  B.ID, B.DATA_HORA, B.ETAPA, B.ORIGEM, B.RESULTADO, ' +
      '  B.OBSERVACAO, B.USUARIO_ID, U.NOME AS OPERADOR, ' +
      '  T.NUMERO AS NUMERO_TALAO, T.CODIGO_BARRAS, T.STATUS AS STATUS_TALAO ' +
      'FROM TALAO_BIPAGEM B ' +
      '  JOIN USUARIO U ON U.ID = B.USUARIO_ID ' +
      '  LEFT JOIN TALAO T ON T.ID = B.TALAO_ID ' +
      'WHERE U.EMPRESA_ID = :EMP ' +
      'ORDER BY B.DATA_HORA DESC, B.ID DESC';
    LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
    LQuery.Open;
    while not LQuery.EOF do
    begin
      { a TJSONArray passa a ser dona do objeto — não liberar aqui }
      LObj := TJSONObject.Create;
      LObj.Add('id', LQuery.FieldByName('ID').AsLargeInt);
        LObj.Add('data_hora', LQuery.FieldByName('DATA_HORA').AsString);
        LObj.Add('etapa', LQuery.FieldByName('ETAPA').AsString);
        LObj.Add('origem', LQuery.FieldByName('ORIGEM').AsString);
        LObj.Add('resultado', LQuery.FieldByName('RESULTADO').AsString);
        LParam := LQuery.FieldByName('OBSERVACAO').AsString;
        if LParam <> '' then
          LObj.Add('observacao', LParam);
        LObj.Add('usuario_id', LQuery.FieldByName('USUARIO_ID').AsLargeInt);
        LObj.Add('operador', LQuery.FieldByName('OPERADOR').AsString);
        if not LQuery.FieldByName('NUMERO_TALAO').IsNull then
        begin
          LObj.Add('numero_talao',
            LQuery.FieldByName('NUMERO_TALAO').AsInteger);
          LObj.Add('codigo_barras',
            LQuery.FieldByName('CODIGO_BARRAS').AsString);
          LObj.Add('status_talao',
            LQuery.FieldByName('STATUS_TALAO').AsString);
        end;
        LArr.Add(LObj);
      LQuery.Next;
    end;
    LConexao.Confirmar;
    Res.Send(LArr.AsJSON).Status(THTTPStatus.OK);
  except
    on E: Exception do
    begin
      try
        LConexao.Cancelar;
      except
      end;
      Res.Send(ErroJSON('Falha ao listar bipagens: ' + E.Message))
        .Status(THTTPStatus.InternalServerError);
    end;
    end;
  finally
    LArr.Free;
    LQuery.Free;
  end;
end;

procedure RegistrarRotasProducao;
begin
  THorse.Post('/api/producao/bipar', @PostBiparTalao);
  THorse.Get('/api/producao/bipagens', @GetBipagens);
end;

end.
