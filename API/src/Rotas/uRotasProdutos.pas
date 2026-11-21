unit uRotasProdutos;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Rotas de Produtos
  Endpoints: GET/POST /api/produtos, GET/PUT/DELETE /api/produtos/:id
  F1: edição/exclusão pelo TProdutoService compartilhado com o desktop
  (validação de descrição/categoria/unidade/preço, isolamento por empresa
  e auditoria PRODUTO/U e PRODUTO/D).
  ============================================================ }

interface

uses
  Horse;

procedure RegistrarRotasProdutos;

implementation

uses
  SysUtils, fpjson, jsonparser, SQLDB, uConexao, uMiddlewareJWT, uAuditoria,
  uProdutoService, uProduto;

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

procedure EnviarErro(Res: THorseResponse; const AMensagem: string;
  AStatus: THTTPStatus);
begin
  Res.Send(ErroJSON(AMensagem)).Status(AStatus);
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
    LData.Free;
    EnviarErro(Res, 'Corpo da requisição inválido (objeto JSON esperado)',
      THTTPStatus.BadRequest);
    Exit;
  end;
  LBody := TJSONObject(LData);
  Result := True;
end;

function TextoBody(ABody: TJSONObject; const AChave, AAtual: string): string;
var
  D: TJSONData;
begin
  Result := AAtual;
  D := ABody.Find(AChave);
  if D <> nil then
    Result := D.AsString;
end;

function InteiroBody(ABody: TJSONObject; const AChave: string;
  AAtual: Int64): Int64;
var
  D: TJSONData;
begin
  Result := AAtual;
  D := ABody.Find(AChave);
  if D <> nil then
    Result := D.AsInt64;
end;

function NumeroBody(ABody: TJSONObject; const AChave: string;
  AAtual: Double): Double;
var
  D: TJSONData;
begin
  Result := AAtual;
  D := ABody.Find(AChave);
  if D <> nil then
    Result := D.AsFloat;
end;

function StatusBody(ABody: TJSONObject; AAtual: Char): Char;
var
  D: TJSONData;
  S: string;
begin
  Result := AAtual;
  D := ABody.Find('status');
  if D = nil then
    D := ABody.Find('ativo');
  if D = nil then
    Exit;
  S := LowerCase(Trim(D.AsString));
  if (S = 'i') or (S = 'inativo') or (S = 'false') or (S = '0') then
    Result := 'I'
  else if (S = 'a') or (S = 'ativo') or (S = 'true') or (S = '1') then
    Result := 'A';
end;

function ControlaEstoqueBody(ABody: TJSONObject; AAtual: Boolean): Boolean;
var
  D: TJSONData;
  S: string;
begin
  Result := AAtual;
  D := ABody.Find('controla_estoque');
  if D = nil then
    Exit;
  S := LowerCase(Trim(D.AsString));
  Result := (S = 's') or (S = 'sim') or (S = 'true') or (S = '1');
end;

procedure AplicarBody(ABody: TJSONObject; AProduto: TProduto);
begin
  AProduto.Codigo := TextoBody(ABody, 'codigo', AProduto.Codigo);
  AProduto.CodigoBarras := TextoBody(ABody, 'codigo_barras', AProduto.CodigoBarras);
  AProduto.Descricao := TextoBody(ABody, 'descricao', AProduto.Descricao);
  AProduto.DescricaoPDV := TextoBody(ABody, 'descricao_pdv', AProduto.DescricaoPDV);
  AProduto.Ncm := TextoBody(ABody, 'ncm', AProduto.Ncm);
  AProduto.CategoriaId := InteiroBody(ABody, 'categoria_id', AProduto.CategoriaId);
  AProduto.UnidadeId := InteiroBody(ABody, 'unidade_id', AProduto.UnidadeId);
  AProduto.PrecoVenda := NumeroBody(ABody, 'preco_venda', AProduto.PrecoVenda);
  AProduto.PrecoCusto := NumeroBody(ABody, 'preco_custo', AProduto.PrecoCusto);
  AProduto.EstoqueMinimo := NumeroBody(ABody, 'estoque_minimo', AProduto.EstoqueMinimo);
  AProduto.EstoqueMaximo := NumeroBody(ABody, 'estoque_maximo', AProduto.EstoqueMaximo);
  AProduto.Observacoes := TextoBody(ABody, 'observacoes', AProduto.Observacoes);
  AProduto.Ativo := StatusBody(ABody, AProduto.Ativo);
  AProduto.ControlaEstoque := ControlaEstoqueBody(ABody, AProduto.ControlaEstoque);
end;

procedure GetProdutos(Req: THorseRequest; Res: THorseResponse);
var
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LArray: TJSONArray;
  LObj: TJSONObject;
  LUsuarioId, LEmpresaId: Int64;
begin
  { Catalogo da empresa do usuario logado. }
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
      'SELECT P.ID, P.CODIGO, P.DESCRICAO, P.PRECO_VENDA, P.PRECO_CUSTO, ' +
      'COALESCE(E.QUANTIDADE, 0) AS ESTOQUE, P.ATIVO ' +
      'FROM PRODUTO P LEFT JOIN ESTOQUE E ON E.PRODUTO_ID = P.ID ' +
      'WHERE P.ATIVO = ''A'' AND P.EMPRESA_ID = :EMP ORDER BY P.DESCRICAO';
    LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
    LQuery.Open;

    LArray := TJSONArray.Create;
    while not LQuery.EOF do
    begin
      LObj := TJSONObject.Create;
      LObj.Add('id', LQuery.FieldByName('ID').AsLargeInt);
      LObj.Add('codigo', LQuery.FieldByName('CODIGO').AsString);
      LObj.Add('descricao', LQuery.FieldByName('DESCRICAO').AsString);
      LObj.Add('preco_venda', LQuery.FieldByName('PRECO_VENDA').AsFloat);
      LObj.Add('preco_custo', LQuery.FieldByName('PRECO_CUSTO').AsFloat);
      LObj.Add('estoque', LQuery.FieldByName('ESTOQUE').AsFloat);
      LArray.Add(LObj);
      LQuery.Next;
    end;
    Res.Send(LArray.AsJSON).Status(THTTPStatus.OK);
    LArray.Free;
  finally
    LQuery.Free;
  end;
end;

procedure GetProdutoById(Req: THorseRequest; Res: THorseResponse);
var
  LId: Int64;
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LObj: TJSONObject;
  LUsuarioId, LEmpresaId: Int64;
begin
  LId := StrToInt64Def(Req.Params['id'], 0);

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
      'SELECT P.*, COALESCE(E.QUANTIDADE, 0) AS ESTOQUE FROM PRODUTO P ' +
      'LEFT JOIN ESTOQUE E ON E.PRODUTO_ID = P.ID ' +
      'WHERE P.ID = :ID AND P.EMPRESA_ID = :EMP';
    LQuery.ParamByName('ID').AsLargeInt := LId;
    LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
    LQuery.Open;

    if LQuery.IsEmpty then
    begin
      Res.Send('{"error":"Produto não encontrado"}').Status(THTTPStatus.NotFound);
      Exit;
    end;

    LObj := TJSONObject.Create;
    LObj.Add('id', LQuery.FieldByName('ID').AsLargeInt);
    LObj.Add('codigo', LQuery.FieldByName('CODIGO').AsString);
    LObj.Add('descricao', LQuery.FieldByName('DESCRICAO').AsString);
    LObj.Add('preco_venda', LQuery.FieldByName('PRECO_VENDA').AsFloat);
    LObj.Add('preco_custo', LQuery.FieldByName('PRECO_CUSTO').AsFloat);
    LObj.Add('ncm', LQuery.FieldByName('NCM').AsString);
    LObj.Add('estoque', LQuery.FieldByName('ESTOQUE').AsFloat);
    Res.Send(LObj.AsJSON).Status(THTTPStatus.OK);
    LObj.Free;
  finally
    LQuery.Free;
  end;
end;

procedure PostProduto(Req: THorseRequest; Res: THorseResponse);
var
  LBody: TJSONObject;
  LData: TJSONData;
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LUsuarioId, LEmpresaId: Int64;
  LId: Int64;
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
        LConexao.IniciarTransacao;
        { D4: o ID é lido do generator antes do INSERT para a auditoria }
        LQuery.SQL.Text := 'SELECT GEN_ID(GEN_PRODUTO_ID, 1) FROM RDB$DATABASE';
        LQuery.Open;
        LId := LQuery.Fields[0].AsLargeInt;
        LQuery.Close;

        LQuery.SQL.Text :=
          'INSERT INTO PRODUTO (ID, EMPRESA_ID, CATEGORIA_ID, UNIDADE_ID, CODIGO, DESCRICAO, ' +
          'PRECO_VENDA, PRECO_CUSTO, ATIVO, CONTROLA_ESTOQUE) ' +
          'VALUES (:ID, :EMP, :CAT, :UNI, :COD, :DESC, :PV, :PC, ''A'', ''S'')';
        LQuery.ParamByName('ID').AsLargeInt := LId;
        LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
        LQuery.ParamByName('CAT').AsLargeInt := LBody.Get('categoria_id', Int64(1));
        LQuery.ParamByName('UNI').AsLargeInt := LBody.Get('unidade_id', Int64(1));
        LQuery.ParamByName('COD').AsString := LBody.Get('codigo', '');
        LQuery.ParamByName('DESC').AsString := LBody.Get('descricao', '');
        LQuery.ParamByName('PV').AsFloat := LBody.Get('preco_venda', Double(0));
        LQuery.ParamByName('PC').AsFloat := LBody.Get('preco_custo', Double(0));
        LQuery.ExecSQL;

        { D4: auditoria na mesma transação da gravação }
        RegistrarAuditoriaSeguraConexao(LConexao.Connection, LConexao.Transaction,
          LEmpresaId, LUsuarioId, 'PRODUTO', 'I', LId, '',
          ResumoAuditoria(['CODIGO=' + LBody.Get('codigo', ''),
            'DESCRICAO=' + LBody.Get('descricao', '')]));

        LConexao.Confirmar;
        Res.Send('{"message":"Produto criado com sucesso"}').Status(THTTPStatus.Created);
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

procedure PutProduto(Req: THorseRequest; Res: THorseResponse);
var
  LId: Int64;
  LBody: TJSONObject;
  LServico: TProdutoService;
  LProduto: TProduto;
  LResposta: TJSONObject;
  LUsuarioId, LEmpresaId: Int64;
begin
  LId := StrToInt64Def(Req.Params['id'], 0);
  if LId <= 0 then
  begin
    EnviarErro(Res, 'ID inválido', THTTPStatus.BadRequest);
    Exit;
  end;

  DadosDoToken(Req, LUsuarioId, LEmpresaId);
  if LEmpresaId <= 0 then
  begin
    EnviarErro(Res, 'Token sem empresa. Entre novamente.',
      THTTPStatus.Unauthorized);
    Exit;
  end;

  if not CorpoJSON(Req, Res, LBody) then
    Exit;
  try
    try
      LServico := TProdutoService.Create;
      try
        LProduto := LServico.BuscarPorId(LId);
        try
          if (LProduto = nil) or (LProduto.EmpresaId <> LEmpresaId) then
          begin
            EnviarErro(Res, 'Produto não encontrado', THTTPStatus.NotFound);
            Exit;
          end;

          AplicarBody(LBody, LProduto);
          LProduto.EmpresaId := LEmpresaId;
          { F1: o Service valida descrição/categoria/unidade/preço, garante
            a empresa e grava PRODUTO/U na auditoria da thread. }
          LServico.Atualizar(LProduto);

          LResposta := TJSONObject.Create;
          try
            LResposta.Add('id', LId);
            LResposta.Add('message', 'Produto atualizado com sucesso');
            Res.Send(LResposta.AsJSON).Status(THTTPStatus.OK);
          finally
            LResposta.Free;
          end;
        finally
          LProduto.Free;
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

procedure DeleteProduto(Req: THorseRequest; Res: THorseResponse);
var
  LId: Int64;
  LServico: TProdutoService;
  LProduto: TProduto;
  LResposta: TJSONObject;
  LUsuarioId, LEmpresaId: Int64;
begin
  LId := StrToInt64Def(Req.Params['id'], 0);
  if LId <= 0 then
  begin
    EnviarErro(Res, 'ID inválido', THTTPStatus.BadRequest);
    Exit;
  end;

  DadosDoToken(Req, LUsuarioId, LEmpresaId);
  if LEmpresaId <= 0 then
  begin
    EnviarErro(Res, 'Token sem empresa. Entre novamente.',
      THTTPStatus.Unauthorized);
    Exit;
  end;

  try
    LServico := TProdutoService.Create;
    try
      LProduto := LServico.BuscarPorId(LId);
      try
        if (LProduto = nil) or (LProduto.EmpresaId <> LEmpresaId) then
        begin
          EnviarErro(Res, 'Produto não encontrado', THTTPStatus.NotFound);
          Exit;
        end;

        { F1: o Service grava PRODUTO/D (auditoria da empresa/usuário da
          thread) e devolve erro se o ID não pertencer à empresa. }
        LServico.Excluir(LId);

        LResposta := TJSONObject.Create;
        try
          LResposta.Add('id', LId);
          LResposta.Add('message', 'Produto removido');
          Res.Send(LResposta.AsJSON).Status(THTTPStatus.OK);
        finally
          LResposta.Free;
        end;
      finally
        LProduto.Free;
      end;
    finally
      LServico.Free;
    end;
  except
    on E: Exception do
      EnviarErro(Res, E.Message, THTTPStatus.BadRequest);
  end;
end;

procedure RegistrarRotasProdutos;
begin
  THorse.Get('/api/produtos', @GetProdutos);
  THorse.Get('/api/produtos/:id', @GetProdutoById);
  THorse.Post('/api/produtos', @PostProduto);
  THorse.Put('/api/produtos/:id', @PutProduto);
  THorse.Delete('/api/produtos/:id', @DeleteProduto);
end;

end.
