unit uCidadeService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Fase 1 (redesenho) - Service: Cidade
  Tabela geográfica global (sem EMPRESA_ID); filtra por estado.
  SQL sempre parametrizado (InserirParam/AtualizarParam).
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uServiceBase, uRepositoryBase, uCidade, uSessao;

type
  TCidadeService = class(TServiceBase)
  private
    FRepo: TRepositoryBase;
    procedure Validar(AObj: TCidade);
  public
    constructor Create;
    destructor Destroy; override;

    function BuscarPorId(AId: Int64): TCidade;
    function BuscarTodos(AEstadoId: Int64 = 0): TSQLQuery;
    function Inserir(AObj: TCidade): Int64;
    function Atualizar(AObj: TCidade): Boolean;
    function Excluir(AId: Int64): Boolean;
  end;

implementation

constructor TCidadeService.Create;
begin
  FRepo := TRepositoryBase.Create('CIDADE');
  inherited Create(FRepo);
end;

destructor TCidadeService.Destroy;
begin
  FRepo.Free;
  inherited Destroy;
end;

procedure TCidadeService.Validar(AObj: TCidade);
begin
  ValidarCampoObrigatorio(AObj.Nome, 'Nome');
  if AObj.EstadoId <= 0 then
    raise Exception.Create('Estado é obrigatório.');
end;

function TCidadeService.BuscarPorId(AId: Int64): TCidade;
var
  LQuery: TSQLQuery;
begin
  Result := TCidade.Create;
  try
    LQuery := FRepo.BuscarPorId(AId);
    try
      if not LQuery.IsEmpty then
      begin
        Result.Id := LQuery.FieldByName('ID').AsLargeInt;
        Result.EstadoId := LQuery.FieldByName('ESTADO_ID').AsLargeInt;
        Result.Nome := LQuery.FieldByName('NOME').AsString;
        Result.CodigoIbge := LQuery.FieldByName('CODIGO_IBGE').AsString;
      end
      else
        FreeAndNil(Result);
    finally
      LQuery.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TCidadeService.BuscarTodos(AEstadoId: Int64 = 0): TSQLQuery;
begin
  if AEstadoId > 0 then
    Result := FRepo.BuscarTodos('ESTADO_ID = ' + IntToStr(AEstadoId), 'NOME')
  else
    Result := FRepo.BuscarTodos('', 'NOME');
end;

function TCidadeService.Inserir(AObj: TCidade): Int64;
var
  LCampos, LParams: string;
  LNome, LVal: array of string;
begin
  Validar(AObj);
  LCampos := 'ESTADO_ID, NOME, CODIGO_IBGE';
  LParams := ':ESTADO, :NOME, :IBGE';
  LNome := ['ESTADO', 'NOME', 'IBGE'];
  LVal := [IntToStr(AObj.EstadoId), AObj.Nome, AObj.CodigoIbge];
  Result := FRepo.InserirParam(LCampos, LParams, LNome, LVal);
end;

function TCidadeService.Atualizar(AObj: TCidade): Boolean;
var
  LCamposParam: string;
  LNome, LVal: array of string;
begin
  Validar(AObj);
  LCamposParam := 'ESTADO_ID = :ESTADO, NOME = :NOME, CODIGO_IBGE = :IBGE';
  LNome := ['ESTADO', 'NOME', 'IBGE'];
  LVal := [IntToStr(AObj.EstadoId), AObj.Nome, AObj.CodigoIbge];
  Result := FRepo.AtualizarParam(AObj.Id, LCamposParam, LNome, LVal);
end;

function TCidadeService.Excluir(AId: Int64): Boolean;
begin
  Result := FRepo.Excluir(AId);
end;

end.
