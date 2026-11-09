unit uCategoriaService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Service: Categoria
  Descrição: Regras de negócio para Categorias de produtos.
             CATEGORIA é tabela global (sem EMPRESA_ID).
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uServiceBase, uRepositoryBase, uCategoria;

type
  { TCategoriaService }
  TCategoriaService = class(TServiceBase)
  private
    FRepo: TRepositoryBase;
    function NomeExiste(const ANome: string; AExcluirId: Int64 = 0): Boolean;
    procedure Validar(AObj: TCategoria);
  public
    constructor Create;
    destructor Destroy; override;

    function BuscarPorId(AId: Int64): TCategoria;
    function BuscarTodos(const AFiltro: string = ''): TSQLQuery;
    function Inserir(AObj: TCategoria): Int64;
    function Atualizar(AObj: TCategoria): Boolean;
    function Excluir(AId: Int64): Boolean;
    function Pesquisar(const ATermo: string): TSQLQuery;
  end;

implementation

{ TCategoriaService }

constructor TCategoriaService.Create;
begin
  FRepo := TRepositoryBase.Create('CATEGORIA');
  inherited Create(FRepo);
end;

destructor TCategoriaService.Destroy;
begin
  FRepo.Free;
  inherited Destroy;
end;

procedure TCategoriaService.Validar(AObj: TCategoria);
begin
  ValidarCampoObrigatorio(AObj.Nome, 'Nome');
  if NomeExiste(AObj.Nome, AObj.Id) then
    raise Exception.Create('Já existe uma categoria com este nome.');
end;

function TCategoriaService.NomeExiste(const ANome: string;
  AExcluirId: Int64): Boolean;
var
  LCond: string;
  LNome: array of string;
  LVal: array of string;
begin
  if Trim(ANome) = '' then
  begin
    Result := False;
    Exit;
  end;

  if AExcluirId > 0 then
  begin
    LCond := 'UPPER(NOME) = UPPER(:NOM) AND ID <> :EXC';
    LNome := ['NOM', 'EXC'];
    LVal := [ANome, IntToStr(AExcluirId)];
  end
  else
  begin
    LCond := 'UPPER(NOME) = UPPER(:NOM)';
    LNome := ['NOM'];
    LVal := [ANome];
  end;
  Result := FRepo.ContarParam(LCond, LNome, LVal) > 0;
end;

function TCategoriaService.BuscarPorId(AId: Int64): TCategoria;
var
  LQuery: TSQLQuery;
begin
  Result := nil;
  LQuery := FRepo.BuscarPorId(AId);
  try
    if not LQuery.IsEmpty then
    begin
      Result := TCategoria.Create;
      Result.Id := LQuery.FieldByName('ID').AsLargeInt;
      Result.Nome := LQuery.FieldByName('NOME').AsString;
      Result.Descricao := LQuery.FieldByName('DESCRICAO').AsString;
      Result.Ativo := LQuery.FieldByName('ATIVO').AsString[1];
    end;
  finally
    if LQuery.Active then
      LQuery.Close;
  end;
end;

function TCategoriaService.BuscarTodos(const AFiltro: string): TSQLQuery;
begin
  Result := FRepo.BuscarTodosParam('', [], [], 'NOME');
end;

function TCategoriaService.Inserir(AObj: TCategoria): Int64;
const
  CAMPOS = 'NOME, DESCRICAO, ATIVO';
  VALORES_PARAM = ':NOM, :DESC, :ATIVO';
begin
  Validar(AObj);
  Result := FRepo.InserirParam(
    CAMPOS, VALORES_PARAM,
    ['NOM', 'DESC', 'ATIVO'],
    [AObj.Nome, AObj.Descricao, AObj.Ativo]);

  LogOperacao('CATEGORIA', 'I', Result);
end;

function TCategoriaService.Atualizar(AObj: TCategoria): Boolean;
const
  CAMPOS_PARAM = 'NOME = :NOM, DESCRICAO = :DESC, ATIVO = :ATIVO';
begin
  ValidarId(AObj.Id, 'Categoria');
  Validar(AObj);

  Result := FRepo.AtualizarParam(
    AObj.Id, CAMPOS_PARAM,
    ['NOM', 'DESC', 'ATIVO'],
    [AObj.Nome, AObj.Descricao, AObj.Ativo]);

  LogOperacao('CATEGORIA', 'U', AObj.Id);
end;

function TCategoriaService.Excluir(AId: Int64): Boolean;
begin
  ValidarId(AId, 'Categoria');
  Result := FRepo.Excluir(AId);
  LogOperacao('CATEGORIA', 'D', AId);
end;

function TCategoriaService.Pesquisar(const ATermo: string): TSQLQuery;
begin
  { CAST + CONTAINING: o termo pode ser maior que NOME e o CONTAINING
    direto estoura com "string right truncation". }
  Result := FRepo.BuscarTodosParam(
    '(UPPER(CAST(NOME AS VARCHAR(200))) CONTAINING UPPER(:T) OR ' +
    'UPPER(CAST(DESCRICAO AS VARCHAR(500))) CONTAINING UPPER(:T))',
    ['T'], [ATermo],
    'NOME');
end;

end.
