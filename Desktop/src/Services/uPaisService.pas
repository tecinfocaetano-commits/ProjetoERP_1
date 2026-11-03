unit uPaisService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Fase 1 (redesenho) - Service: País
  Tabela geográfica global (sem EMPRESA_ID).
  SQL sempre parametrizado (InserirParam/AtualizarParam).
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uServiceBase, uRepositoryBase, uPais, uSessao;

type
  TPaisService = class(TServiceBase)
  private
    FRepo: TRepositoryBase;
    procedure Validar(AObj: TPais);
  public
    constructor Create;
    destructor Destroy; override;

    function BuscarPorId(AId: Int64): TPais;
    function BuscarTodos: TSQLQuery;
    function Inserir(AObj: TPais): Int64;
    function Atualizar(AObj: TPais): Boolean;
    function Excluir(AId: Int64): Boolean;
  end;

implementation

constructor TPaisService.Create;
begin
  FRepo := TRepositoryBase.Create('PAIS');
  inherited Create(FRepo);
end;

destructor TPaisService.Destroy;
begin
  FRepo.Free;
  inherited Destroy;
end;

procedure TPaisService.Validar(AObj: TPais);
begin
  ValidarCampoObrigatorio(AObj.Nome, 'Nome');
  ValidarCampoObrigatorio(AObj.Codigo, 'Código');
end;

function TPaisService.BuscarPorId(AId: Int64): TPais;
var
  LQuery: TSQLQuery;
begin
  Result := TPais.Create;
  try
    LQuery := FRepo.BuscarPorId(AId);
    try
      if not LQuery.IsEmpty then
      begin
        Result.Id := LQuery.FieldByName('ID').AsLargeInt;
        Result.Nome := LQuery.FieldByName('NOME').AsString;
        Result.Codigo := LQuery.FieldByName('CODIGO').AsString;
        Result.Ddi := LQuery.FieldByName('DDI').AsString;
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

function TPaisService.BuscarTodos: TSQLQuery;
begin
  Result := FRepo.BuscarTodos('', 'NOME');
end;

function TPaisService.Inserir(AObj: TPais): Int64;
var
  LCampos, LParams: string;
  LNome, LVal: array of string;
begin
  Validar(AObj);
  LCampos := 'NOME, CODIGO, DDI';
  LParams := ':NOME, :CODIGO, :DDI';
  LNome := ['NOME', 'CODIGO', 'DDI'];
  LVal := [AObj.Nome, AObj.Codigo, AObj.Ddi];
  Result := FRepo.InserirParam(LCampos, LParams, LNome, LVal);
end;

function TPaisService.Atualizar(AObj: TPais): Boolean;
var
  LCamposParam: string;
  LNome, LVal: array of string;
begin
  Validar(AObj);
  LCamposParam := 'NOME = :NOME, CODIGO = :CODIGO, DDI = :DDI';
  LNome := ['NOME', 'CODIGO', 'DDI'];
  LVal := [AObj.Nome, AObj.Codigo, AObj.Ddi];
  Result := FRepo.AtualizarParam(AObj.Id, LCamposParam, LNome, LVal);
end;

function TPaisService.Excluir(AId: Int64): Boolean;
begin
  Result := FRepo.Excluir(AId);
end;

end.
