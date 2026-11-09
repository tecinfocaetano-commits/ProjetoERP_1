unit uCorService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Service: Cor
  Descrição: Regras de negócio para cores do produto de produção
             (cada cor tem sua Ficha Técnica)
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uServiceBase, uRepositoryBase, uCor, uSessao;

type
  { TCorService }
  TCorService = class(TServiceBase)
  private
    FRepo: TRepositoryBase;
    function NomeExiste(AProdutoId: Int64; const ANome: string;
      AExcluirId: Int64 = 0): Boolean;
    procedure Validar(AObj: TCor);
    procedure GarantirDaEmpresa(AId: Int64);
  public
    constructor Create;
    destructor Destroy; override;

    function BuscarPorId(AId: Int64): TCor;
    function BuscarTodos(const AFiltro: string = ''): TSQLQuery;
    function BuscarPorProduto(AProdutoId: Int64): TSQLQuery;
    function Inserir(AObj: TCor): Int64;
    function Atualizar(AObj: TCor): Boolean;
    function Excluir(AId: Int64): Boolean;
  end;

implementation

{ TCorService }

constructor TCorService.Create;
begin
  FRepo := TRepositoryBase.Create('COR');
  inherited Create(FRepo);
end;

destructor TCorService.Destroy;
begin
  FRepo.Free;
  inherited Destroy;
end;

procedure TCorService.Validar(AObj: TCor);
begin
  ValidarCampoObrigatorio(AObj.Nome, 'Nome da cor');
  if AObj.ProdutoId <= 0 then
    raise Exception.Create('Produto de produção não informado para a cor.');
  if NomeExiste(AObj.ProdutoId, AObj.Nome, AObj.Id) then
    raise Exception.Create('Já existe esta cor para o produto.');
end;

function TCorService.NomeExiste(AProdutoId: Int64; const ANome: string;
  AExcluirId: Int64): Boolean;
var
  LCond: string;
  LNome: array of string;
  LVal: array of string;
begin
  if AExcluirId > 0 then
  begin
    LCond := 'PRODUTO_ID = :PROD AND UPPER(NOME) = UPPER(:NOM) AND ID <> :EXC';
    LNome := ['PROD', 'NOM', 'EXC'];
    LVal := [IntToStr(AProdutoId), ANome, IntToStr(AExcluirId)];
  end
  else
  begin
    LCond := 'PRODUTO_ID = :PROD AND UPPER(NOME) = UPPER(:NOM)';
    LNome := ['PROD', 'NOM'];
    LVal := [IntToStr(AProdutoId), ANome];
  end;
  Result := FRepo.ContarParam(LCond, LNome, LVal) > 0;
end;

function TCorService.BuscarPorId(AId: Int64): TCor;
var
  LQuery: TSQLQuery;
begin
  Result := nil;
  LQuery := FRepo.BuscarPorId(AId);
  try
    if not LQuery.IsEmpty then
    begin
      Result := TCor.Create;
      Result.Id := LQuery.FieldByName('ID').AsLargeInt;
      Result.EmpresaId := LQuery.FieldByName('EMPRESA_ID').AsLargeInt;
      Result.ProdutoId := LQuery.FieldByName('PRODUTO_ID').AsLargeInt;
      Result.Nome := LQuery.FieldByName('NOME').AsString;
      Result.Hex := LQuery.FieldByName('HEX').AsString;
      Result.Ativo := LQuery.FieldByName('ATIVO').AsString[1];
    end;
  finally
    if LQuery.Active then
      LQuery.Close;
  end;
end;

function TCorService.BuscarTodos(const AFiltro: string): TSQLQuery;
begin
  Result := FRepo.BuscarTodosParam(
    'EMPRESA_ID = :EMP',
    ['EMP'],
    [IntToStr(TSessao.GetInstance.EmpresaId)],
    'NOME');
end;

function TCorService.BuscarPorProduto(AProdutoId: Int64): TSQLQuery;
begin
  Result := FRepo.BuscarTodosParam(
    'PRODUTO_ID = :PROD AND ATIVO = ''A''',
    ['PROD'],
    [IntToStr(AProdutoId)],
    'NOME');
end;

function TCorService.Inserir(AObj: TCor): Int64;
const
  CAMPOS = 'EMPRESA_ID, PRODUTO_ID, NOME, HEX, ATIVO';
  VALORES_PARAM = ':EMP, :PROD, :NOM, :HEX, :ATIVO';
begin
  Validar(AObj);
  Result := FRepo.InserirParam(
    CAMPOS, VALORES_PARAM,
    ['EMP', 'PROD', 'NOM', 'HEX', 'ATIVO'],
    [IntToStr(AObj.EmpresaId), IntToStr(AObj.ProdutoId),
     AObj.Nome, AObj.Hex, AObj.Ativo]);

  LogOperacao('COR', 'I', Result);
end;

procedure TCorService.GarantirDaEmpresa(AId: Int64);
var
  LQuery: TSQLQuery;
begin
  { escrita por ID só vale para registro da empresa da sessão }
  LQuery := FRepo.BuscarPorId(AId);
  try
    if LQuery.IsEmpty or
       (LQuery.FieldByName('EMPRESA_ID').AsLargeInt <>
        TSessao.GetInstance.EmpresaId) then
      raise Exception.Create('Cor não encontrada para a empresa atual.');
  finally
    if LQuery.Active then
      LQuery.Close;
  end;
end;

function TCorService.Atualizar(AObj: TCor): Boolean;
const
  CAMPOS_PARAM = 'NOME = :NOM, HEX = :HEX, ATIVO = :ATIVO';
begin
  ValidarId(AObj.Id, 'Cor');
  GarantirDaEmpresa(AObj.Id);
  Validar(AObj);

  Result := FRepo.AtualizarParam(
    AObj.Id, CAMPOS_PARAM,
    ['NOM', 'HEX', 'ATIVO'],
    [AObj.Nome, AObj.Hex, AObj.Ativo]);

  LogOperacao('COR', 'U', AObj.Id);
end;

function TCorService.Excluir(AId: Int64): Boolean;
begin
  ValidarId(AId, 'Cor');
  GarantirDaEmpresa(AId);
  Result := FRepo.Excluir(AId);
  LogOperacao('COR', 'D', AId);
end;

end.
