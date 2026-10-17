unit uRotasClientes;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 7 - Rotas de Clientes
  Endpoints: GET/POST/PUT/DELETE /api/clientes
  ============================================================ }

interface

uses
  Horse;

procedure RegistrarRotasClientes;

implementation

uses
  SysUtils, fpjson, jsonparser, SQLDB, uConexao;

procedure GetClientes(Req: THorseRequest; Res: THorseResponse);
var
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LArray: TJSONArray;
  LObj: TJSONObject;
begin
  LConexao := TConexao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;
    LQuery.SQL.Text := 'SELECT ID, NOME, CPF_CNPJ, EMAIL, TELEFONE, CIDADE, UF, ATIVO FROM CLIENTE ORDER BY NOME';
    LQuery.Open;

    LArray := TJSONArray.Create;
    while not LQuery.EOF do
    begin
      LObj := TJSONObject.Create;
      LObj.Add('id', LQuery.FieldByName('ID').AsLargeInt);
      LObj.Add('nome', LQuery.FieldByName('NOME').AsString);
      LObj.Add('cpf_cnpj', LQuery.FieldByName('CPF_CNPJ').AsString);
      LObj.Add('email', LQuery.FieldByName('EMAIL').AsString);
      LObj.Add('telefone', LQuery.FieldByName('TELEFONE').AsString);
      LObj.Add('cidade', LQuery.FieldByName('CIDADE').AsString);
      LObj.Add('uf', LQuery.FieldByName('UF').AsString);
      LObj.Add('status', LQuery.FieldByName('ATIVO').AsString);
      LArray.Add(LObj);
      LQuery.Next;
    end;
    Res.Send(LArray.AsJSON).Status(THTTPStatus.OK);
    LArray.Free;
  finally
    LQuery.Free;
  end;
end;

procedure GetClienteById(Req: THorseRequest; Res: THorseResponse);
var
  LId: Int64;
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LObj: TJSONObject;
begin
  LId := StrToInt64Def(Req.Params['id'], 0);
  if LId = 0 then
  begin
    Res.Send('{"error":"ID inválido"}').Status(THTTPStatus.BadRequest);
    Exit;
  end;

  LConexao := TConexao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;
    LQuery.SQL.Text := 'SELECT * FROM CLIENTE WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := LId;
    LQuery.Open;

    if LQuery.IsEmpty then
    begin
      Res.Send('{"error":"Cliente não encontrado"}').Status(THTTPStatus.NotFound);
      Exit;
    end;

    LObj := TJSONObject.Create;
    LObj.Add('id', LQuery.FieldByName('ID').AsLargeInt);
    LObj.Add('nome', LQuery.FieldByName('NOME').AsString);
    LObj.Add('cpf_cnpj', LQuery.FieldByName('CPF_CNPJ').AsString);
    LObj.Add('email', LQuery.FieldByName('EMAIL').AsString);
    LObj.Add('telefone', LQuery.FieldByName('TELEFONE').AsString);
    LObj.Add('endereco', LQuery.FieldByName('ENDERECO').AsString);
    LObj.Add('cidade', LQuery.FieldByName('CIDADE').AsString);
    LObj.Add('uf', LQuery.FieldByName('UF').AsString);
    LObj.Add('cep', LQuery.FieldByName('CEP').AsString);
    LObj.Add('status', LQuery.FieldByName('ATIVO').AsString);
    Res.Send(LObj.AsJSON).Status(THTTPStatus.OK);
    LObj.Free;
  finally
    LQuery.Free;
  end;
end;

procedure PostCliente(Req: THorseRequest; Res: THorseResponse);
var
  LBody: TJSONObject;
  LData: TJSONData;
  LConexao: TConexao;
  LQuery: TSQLQuery;
begin
  try
    LData := nil;
    try
      LData := GetJSON(Req.Body);
    except
      LData := nil;
    end;
    if not (LData is TJSONObject) then
    begin
      if LData <> nil then
        LData.Free;
      Res.Send('{"error":"Corpo da requisição inválido (objeto JSON esperado)"}').Status(THTTPStatus.BadRequest);
      Exit;
    end;
    LBody := TJSONObject(LData);
    try
      LConexao := TConexao.GetInstance;
      LQuery := TSQLQuery.Create(nil);
      try
        LQuery.DataBase := LConexao.Connection;
        LQuery.Transaction := LConexao.Transaction;
        LQuery.SQL.Text :=
          'INSERT INTO CLIENTE (ID, EMPRESA_ID, NOME, CPF_CNPJ, EMAIL, TELEFONE, ENDERECO, CIDADE, UF, CEP, ATIVO) ' +
          'VALUES (GEN_ID(GEN_CLIENTE_ID, 1), 1, :NOME, :CPF, :EMAIL, :TEL, :END, :CID, :UF, :CEP, ''A'')';
        LQuery.ParamByName('NOME').AsString := LBody.Get('nome', '');
        LQuery.ParamByName('CPF').AsString := LBody.Get('cpf_cnpj', '');
        LQuery.ParamByName('EMAIL').AsString := LBody.Get('email', '');
        LQuery.ParamByName('TEL').AsString := LBody.Get('telefone', '');
        LQuery.ParamByName('END').AsString := LBody.Get('endereco', '');
        LQuery.ParamByName('CID').AsString := LBody.Get('cidade', '');
        LQuery.ParamByName('UF').AsString := LBody.Get('uf', '');
        LQuery.ParamByName('CEP').AsString := LBody.Get('cep', '');
        LQuery.ExecSQL;
        LConexao.Confirmar;
        Res.Send('{"message":"Cliente criado com sucesso"}').Status(THTTPStatus.Created);
      finally
        LQuery.Free;
      end;
    finally
      LBody.Free;
    end;
  except
    on E: Exception do
      Res.Send('{"error":"' + E.Message + '"}').Status(THTTPStatus.InternalServerError);
  end;
end;

procedure DeleteCliente(Req: THorseRequest; Res: THorseResponse);
var
  LId: Int64;
  LConexao: TConexao;
  LQuery: TSQLQuery;
begin
  LId := StrToInt64Def(Req.Params['id'], 0);
  if LId = 0 then
  begin
    Res.Send('{"error":"ID inválido"}').Status(THTTPStatus.BadRequest);
    Exit;
  end;
  LConexao := TConexao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;
    LQuery.SQL.Text := 'DELETE FROM CLIENTE WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := LId;
    LQuery.ExecSQL;
    LConexao.Confirmar;
    Res.Send('{"message":"Cliente removido"}').Status(THTTPStatus.OK);
  finally
    LQuery.Free;
  end;
end;

procedure RegistrarRotasClientes;
begin
  THorse.Get('/api/clientes', @GetClientes);
  THorse.Get('/api/clientes/:id', @GetClienteById);
  THorse.Post('/api/clientes', @PostCliente);
  THorse.Delete('/api/clientes/:id', @DeleteCliente);
end;

end.
