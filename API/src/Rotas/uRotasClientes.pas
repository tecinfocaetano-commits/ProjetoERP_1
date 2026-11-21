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
  SysUtils, fpjson, jsonparser, SQLDB, uConexao, uMiddlewareJWT,
  uPessoaService, uPessoa;

procedure GetClientes(Req: THorseRequest; Res: THorseResponse);
var
  LServico: TPessoaService;
  LQuery: TSQLQuery;
  LArray: TJSONArray;
  LObj: TJSONObject;
  LUsuarioId, LEmpresaId: Int64;
begin
  { Empresa do usuario logado: cada um ve apenas os clientes da sua empresa. }
  DadosDoToken(Req, LUsuarioId, LEmpresaId);
  if LEmpresaId <= 0 then
  begin
    Res.Send('{"error":"Token sem empresa. Entre novamente."}')
      .Status(THTTPStatus.Unauthorized);
    Exit;
  end;

  { D3: a regra de listar pessoas da empresa (e filtrar TIPO='C') fica no
    Service compartilhado com o desktop; sem SQL duplicado na rota. }
  LServico := TPessoaService.Create;
  try
    LQuery := LServico.BuscarTodos('C');
    LArray := TJSONArray.Create;
    try
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
    finally
      LArray.Free;
      LQuery.Close;
    end;
  finally
    LServico.Free;
  end;
end;

procedure GetClienteById(Req: THorseRequest; Res: THorseResponse);
var
  LId: Int64;
  LServico: TPessoaService;
  LPessoa: TPessoa;
  LObj: TJSONObject;
  LUsuarioId, LEmpresaId: Int64;
begin
  LId := StrToInt64Def(Req.Params['id'], 0);
  if LId = 0 then
  begin
    Res.Send('{"error":"ID inválido"}').Status(THTTPStatus.BadRequest);
    Exit;
  end;

  DadosDoToken(Req, LUsuarioId, LEmpresaId);
  if LEmpresaId <= 0 then
  begin
    Res.Send('{"error":"Token sem empresa. Entre novamente."}')
      .Status(THTTPStatus.Unauthorized);
    Exit;
  end;

  { D3: leitura pelo Service; a rota so garante que o registro e um cliente
    da empresa autenticada (o Service e compartilhado com o desktop). }
  LServico := TPessoaService.Create;
  try
    LPessoa := LServico.BuscarPorId(LId);
    try
      if (LPessoa = nil) or (LPessoa.EmpresaId <> LEmpresaId) or
         (LPessoa.Tipo <> 'C') then
        begin
          Res.Send('{"error":"Cliente não encontrado"}').Status(THTTPStatus.NotFound);
          Exit;
        end;

      LObj := TJSONObject.Create;
      LObj.Add('id', LPessoa.Id);
      LObj.Add('nome', LPessoa.Nome);
      LObj.Add('cpf_cnpj', LPessoa.CpfCnpj);
      LObj.Add('email', LPessoa.Email);
      LObj.Add('endereco', LPessoa.Endereco);
      LObj.Add('cidade', LPessoa.Cidade);
      LObj.Add('uf', LPessoa.Uf);
      LObj.Add('cep', LPessoa.Cep);
      LObj.Add('status', LPessoa.Ativo);
      Res.Send(LObj.AsJSON).Status(THTTPStatus.OK);
      LObj.Free;
    finally
      LPessoa.Free;
    end;
  finally
    LServico.Free;
  end;
end;

procedure PostCliente(Req: THorseRequest; Res: THorseResponse);
var
  LBody: TJSONObject;
  LData: TJSONData;
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LUsuarioId, LEmpresaId: Int64;
begin
  try
    DadosDoToken(Req, LUsuarioId, LEmpresaId);
    if LEmpresaId <= 0 then
    begin
      Res.Send('{"error":"Token sem empresa. Entre novamente."}')
        .Status(THTTPStatus.Unauthorized);
      Exit;
    end;

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
          'INSERT INTO PESSOA (ID, EMPRESA_ID, TIPO, TIPO_PESSOA, NOME, CPF_CNPJ, EMAIL, TELEFONE, ENDERECO, CIDADE, UF, CEP, ATIVO) ' +
          'VALUES (GEN_ID(GEN_PESSOA_ID, 1), :EMP, ''C'', ''F'', :NOME, :CPF, :EMAIL, :TEL, :END, :CID, :UF, :CEP, ''A'')';
        LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
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
  LUsuarioId, LEmpresaId: Int64;
begin
  LId := StrToInt64Def(Req.Params['id'], 0);
  if LId = 0 then
  begin
    Res.Send('{"error":"ID inválido"}').Status(THTTPStatus.BadRequest);
    Exit;
  end;

  DadosDoToken(Req, LUsuarioId, LEmpresaId);
  if LEmpresaId <= 0 then
  begin
    Res.Send('{"error":"Token sem empresa. Entre novamente."}')
      .Status(THTTPStatus.Unauthorized);
    Exit;
  end;

  LConexao := TConexao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;
    LQuery.SQL.Text :=
      'DELETE FROM PESSOA WHERE ID = :ID AND TIPO = ''C'' AND EMPRESA_ID = :EMP';
    LQuery.ParamByName('ID').AsLargeInt := LId;
    LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
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
