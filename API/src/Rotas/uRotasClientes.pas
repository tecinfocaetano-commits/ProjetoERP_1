unit uRotasClientes;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 7 - Rotas de Clientes
  Endpoints: GET/POST/PUT/DELETE /api/clientes
  F4/D9: POST devolve o ID criado, PUT edita e o Service valida
  CPF/CNPJ por empresa+tipo (protegido por indice unico no banco).
  ============================================================ }

interface

uses
  Horse;

procedure RegistrarRotasClientes;

implementation

uses
  SysUtils, fpjson, jsonparser, SQLDB, uConexao, uMiddlewareJWT,
  uPessoaService, uPessoa, uAuditoria;

function TextoBody(ABody: TJSONObject; const AChave: string;
  const AAtual: string): string;
var
  D: TJSONData;
begin
  Result := AAtual;
  D := ABody.Find(AChave);
  if D <> nil then
    Result := D.AsString;
end;

function CharBody(ABody: TJSONObject; const AChave: string;
  AAtual: Char): Char;
var
  D: TJSONData;
  S: string;
begin
  Result := AAtual;
  D := ABody.Find(AChave);
  if D = nil then
    Exit;
  S := UpperCase(Trim(D.AsString));
  if S <> '' then
    Result := S[1];
end;

procedure AplicarBody(ABody: TJSONObject; APessoa: TPessoa);
var
  D: TJSONData;
begin
  APessoa.Nome := TextoBody(ABody, 'nome', APessoa.Nome);
  APessoa.NomeFantasia := TextoBody(ABody, 'nome_fantasia', APessoa.NomeFantasia);
  APessoa.CpfCnpj := TextoBody(ABody, 'cpf_cnpj', APessoa.CpfCnpj);
  APessoa.RgIe := TextoBody(ABody, 'rg_ie', APessoa.RgIe);
  APessoa.Endereco := TextoBody(ABody, 'endereco', APessoa.Endereco);
  APessoa.Numero := TextoBody(ABody, 'numero', APessoa.Numero);
  APessoa.Complemento := TextoBody(ABody, 'complemento', APessoa.Complemento);
  APessoa.Bairro := TextoBody(ABody, 'bairro', APessoa.Bairro);
  APessoa.Cidade := TextoBody(ABody, 'cidade', APessoa.Cidade);
  APessoa.Uf := TextoBody(ABody, 'uf', APessoa.Uf);
  APessoa.Cep := TextoBody(ABody, 'cep', APessoa.Cep);
  APessoa.Telefone := TextoBody(ABody, 'telefone', APessoa.Telefone);
  APessoa.Celular := TextoBody(ABody, 'celular', APessoa.Celular);
  APessoa.Email := TextoBody(ABody, 'email', APessoa.Email);
  APessoa.Contato := TextoBody(ABody, 'contato', APessoa.Contato);
  APessoa.Observacoes := TextoBody(ABody, 'observacoes', APessoa.Observacoes);
  APessoa.Ativo := CharBody(ABody, 'status', APessoa.Ativo);
  APessoa.TipoPessoa := CharBody(ABody, 'tipo_pessoa', APessoa.TipoPessoa);

  D := ABody.Find('limite_credito');
  if D <> nil then
    APessoa.LimiteCredito := D.AsFloat;
end;

function CorpoJSON(Req: THorseRequest; Res: THorseResponse;
  out LBody: TJSONObject): Boolean;
var
  LData: TJSONData;
begin
  Result := False;
  LBody := nil;
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
    Res.Send('{"error":"Corpo da requisição inválido (objeto JSON esperado)"}')
      .Status(THTTPStatus.BadRequest);
    Exit;
  end;
  LBody := TJSONObject(LData);
  Result := True;
end;

procedure EnviarErro(Res: THorseResponse; const AMensagem: string;
  AStatus: THTTPStatus);
var
  LObj: TJSONObject;
begin
  LObj := TJSONObject.Create;
  try
    LObj.Add('error', AMensagem);
    Res.Send(LObj.AsJSON).Status(AStatus);
  finally
    LObj.Free;
  end;
end;

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
      LObj.Add('telefone', LPessoa.Telefone);
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
  LServico: TPessoaService;
  LPessoa: TPessoa;
  LResposta: TJSONObject;
  LId: Int64;
  LUsuarioId, LEmpresaId: Int64;
begin
  DadosDoToken(Req, LUsuarioId, LEmpresaId);
  if LEmpresaId <= 0 then
  begin
    Res.Send('{"error":"Token sem empresa. Entre novamente."}')
      .Status(THTTPStatus.Unauthorized);
    Exit;
  end;

  if not CorpoJSON(Req, Res, LBody) then
    Exit;
  try
    try
      LPessoa := TPessoa.Create;
      try
        LPessoa.EmpresaId := LEmpresaId;
        LPessoa.Tipo := 'C';
        LPessoa.TipoPessoa := 'F';
        LPessoa.Ativo := 'A';
        AplicarBody(LBody, LPessoa);
        LPessoa.Tipo := 'C';

        LServico := TPessoaService.Create;
        try
          { D4: o Service já audita PESSOA/I usando o contexto de sessão
            da thread, definido pelo middleware JWT (empresa/usuário). }
          LId := LServico.Inserir(LPessoa);
          LResposta := TJSONObject.Create;
          try
            LResposta.Add('id', LId);
            LResposta.Add('message', 'Cliente criado com sucesso');
            Res.Send(LResposta.AsJSON).Status(THTTPStatus.Created);
          finally
            LResposta.Free;
          end;
        finally
          LServico.Free;
        end;
      finally
        LPessoa.Free;
      end;
    except
      on E: Exception do
        EnviarErro(Res, E.Message, THTTPStatus.BadRequest);
    end;
  finally
    LBody.Free;
  end;
end;

procedure PutCliente(Req: THorseRequest; Res: THorseResponse);
var
  LId: Int64;
  LBody: TJSONObject;
  LServico: TPessoaService;
  LPessoa: TPessoa;
  LResposta: TJSONObject;
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

  if not CorpoJSON(Req, Res, LBody) then
    Exit;
  try
    try
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

          AplicarBody(LBody, LPessoa);
          LPessoa.EmpresaId := LEmpresaId;
          LPessoa.Tipo := 'C';
          { D4: o Service já audita PESSOA/U com o contexto da thread }
          LServico.Atualizar(LPessoa);

          LResposta := TJSONObject.Create;
          try
            LResposta.Add('id', LId);
            LResposta.Add('message', 'Cliente atualizado com sucesso');
            Res.Send(LResposta.AsJSON).Status(THTTPStatus.OK);
          finally
            LResposta.Free;
          end;
        finally
          LPessoa.Free;
        end;
      finally
        LServico.Free;
      end;
    except
      on E: Exception do
        EnviarErro(Res, E.Message, THTTPStatus.BadRequest);
    end;
  finally
    LBody.Free;
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
    LConexao.IniciarTransacao;
    LQuery.SQL.Text :=
      'DELETE FROM PESSOA WHERE ID = :ID AND TIPO = ''C'' AND EMPRESA_ID = :EMP';
    LQuery.ParamByName('ID').AsLargeInt := LId;
    LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
    LQuery.ExecSQL;

    { D4: escrita na API também entra em LOG_SISTEMA, com empresa/usuário
      do JWT, na mesma transação da operação principal. }
    RegistrarAuditoriaSeguraConexao(LConexao.Connection, LConexao.Transaction,
      LEmpresaId, LUsuarioId, 'PESSOA', 'D', LId, '', '');

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
  THorse.Put('/api/clientes/:id', @PutCliente);
  THorse.Delete('/api/clientes/:id', @DeleteCliente);
end;

end.
