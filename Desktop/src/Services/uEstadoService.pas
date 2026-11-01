unit uEstadoService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Fase 1 (redesenho) - Service: Estado
  Tabela geográfica global (sem EMPRESA_ID); filtra por país.
  SQL sempre parametrizado (InserirParam/AtualizarParam).
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uServiceBase, uRepositoryBase, uEstado, uSessao;

type
  TEstadoService = class(TServiceBase)
  private
    FRepo: TRepositoryBase;
    procedure Validar(AObj: TEstado);
  public
    constructor Create;
    destructor Destroy; override;

    function BuscarPorId(AId: Int64): TEstado;
    function BuscarTodos(APaisId: Int64 = 0): TSQLQuery;
    function Inserir(AObj: TEstado): Int64;
    function Atualizar(AObj: TEstado): Boolean;
    function Excluir(AId: Int64): Boolean;
  end;

implementation

constructor TEstadoService.Create;
begin
  FRepo := TRepositoryBase.Create('ESTADO');
  inherited Create(FRepo);
end;

destructor TEstadoService.Destroy;
begin
  FRepo.Free;
  inherited Destroy;
end;

procedure TEstadoService.Validar(AObj: TEstado);
begin
  ValidarCampoObrigatorio(AObj.Nome, 'Nome');
  ValidarCampoObrigatorio(AObj.Uf, 'UF');
  if Length(Trim(AObj.Uf)) <> 2 then
    raise Exception.Create('A UF deve ter 2 caracteres.');
  if AObj.PaisId <= 0 then
    raise Exception.Create('País é obrigatório.');
end;

function TEstadoService.BuscarPorId(AId: Int64): TEstado;
var
  LQuery: TSQLQuery;
begin
  Result := TEstado.Create;
  try
    LQuery := FRepo.BuscarPorId(AId);
    try
      if not LQuery.IsEmpty then
      begin
        Result.Id := LQuery.FieldByName('ID').AsLargeInt;
        Result.PaisId := LQuery.FieldByName('PAIS_ID').AsLargeInt;
        Result.Nome := LQuery.FieldByName('NOME').AsString;
        Result.Uf := LQuery.FieldByName('UF').AsString;
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

function TEstadoService.BuscarTodos(APaisId: Int64 = 0): TSQLQuery;
var
  LCondicao, LOrdem: string;
  LNome, LVal: array of string;
begin
  LOrdem := 'UF';
  if APaisId > 0 then
  begin
    LCondicao := 'PAIS_ID = :PAIS';
    LNome := ['PAIS'];
    LVal := [IntToStr(APaisId)];
    Result := FRepo.BuscarTodosParam(LCondicao, LNome, LVal, LOrdem);
  end
  else
    Result := FRepo.BuscarTodos('ORDER BY ' + LOrdem);
end;

function TEstadoService.Inserir(AObj: TEstado): Int64;
var
  LCampos, LParams: string;
  LNome, LVal: array of string;
begin
  Validar(AObj);
  LCampos := 'PAIS_ID, NOME, UF, CODIGO_IBGE';
  LParams := ':PAIS, :NOME, :UF, :IBGE';
  LNome := ['PAIS', 'NOME', 'UF', 'IBGE'];
  LVal := [IntToStr(AObj.PaisId), AObj.Nome, AObj.Uf, AObj.CodigoIbge];
  Result := FRepo.InserirParam(LCampos, LParams, LNome, LVal);
end;

function TEstadoService.Atualizar(AObj: TEstado): Boolean;
var
  LCamposParam: string;
  LNome, LVal: array of string;
begin
  Validar(AObj);
  LCamposParam := 'PAIS_ID = :PAIS, NOME = :NOME, UF = :UF, CODIGO_IBGE = :IBGE';
  LNome := ['PAIS', 'NOME', 'UF', 'IBGE'];
  LVal := [IntToStr(AObj.PaisId), AObj.Nome, AObj.Uf, AObj.CodigoIbge];
  Result := FRepo.AtualizarParam(AObj.Id, LCamposParam, LNome, LVal);
end;

function TEstadoService.Excluir(AId: Int64): Boolean;
begin
  Result := FRepo.Excluir(AId);
end;

end.
