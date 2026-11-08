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
        if LQuery.FindField('ATIVO') <> nil then
          Result.Ativo := LQuery.FieldByName('ATIVO').AsString[1]
        else
          Result.Ativo := 'A';
      end
      else
        FreeAndNil(Result);
    finally
      if LQuery.Active then
        LQuery.Close;
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
begin
  Validar(AObj);
  if AObj.Ativo = #0 then
    AObj.Ativo := 'A';
  Result := FRepo.InserirParam(
    'NOME, CODIGO, DDI, ATIVO', ':NOME, :CODIGO, :DDI, :ATIVO',
    ['NOME', 'CODIGO', 'DDI', 'ATIVO'],
    [AObj.Nome, AObj.Codigo, AObj.Ddi, AObj.Ativo]);
  LogOperacao('PAIS', 'I', Result);
end;

function TPaisService.Atualizar(AObj: TPais): Boolean;
begin
  ValidarId(AObj.Id, 'País');
  Validar(AObj);
  Result := FRepo.AtualizarParam(
    AObj.Id,
    'NOME = :NOME, CODIGO = :CODIGO, DDI = :DDI, ATIVO = :ATIVO',
    ['NOME', 'CODIGO', 'DDI', 'ATIVO'],
    [AObj.Nome, AObj.Codigo, AObj.Ddi, AObj.Ativo]);
  LogOperacao('PAIS', 'U', AObj.Id);
end;

function TPaisService.Excluir(AId: Int64): Boolean;
var
  LQuery: TSQLQuery;
  LUsos: Int64;
begin
  ValidarId(AId, 'País');
  { não deixa excluir país com estados vinculados (referência lógica) }
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := Conexao.Connection;
    LQuery.Transaction := Conexao.Transaction;
    LQuery.SQL.Text := 'SELECT COUNT(*) FROM ESTADO WHERE PAIS_ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    LUsos := LQuery.Fields[0].AsLargeInt;
    LQuery.Close;
  finally
    LQuery.Free;
  end;
  if LUsos > 0 then
    raise Exception.Create(
      'Este país possui estados vinculados e não pode ser excluído.');
  Result := FRepo.Excluir(AId);
  LogOperacao('PAIS', 'D', AId);
end;

end.
