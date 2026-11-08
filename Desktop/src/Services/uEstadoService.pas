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

function TEstadoService.BuscarTodos(APaisId: Int64 = 0): TSQLQuery;
begin
  if APaisId > 0 then
    Result := FRepo.BuscarTodos('PAIS_ID = ' + IntToStr(APaisId), 'NOME')
  else
    Result := FRepo.BuscarTodos('', 'NOME');
end;

function TEstadoService.Inserir(AObj: TEstado): Int64;
begin
  Validar(AObj);
  if AObj.Ativo = #0 then
    AObj.Ativo := 'A';
  Result := FRepo.InserirParam(
    'PAIS_ID, NOME, UF, CODIGO_IBGE, ATIVO',
    ':PAIS, :NOME, :UF, :IBGE, :ATIVO',
    ['PAIS', 'NOME', 'UF', 'IBGE', 'ATIVO'],
    [IntToStr(AObj.PaisId), AObj.Nome, AObj.Uf, AObj.CodigoIbge, AObj.Ativo]);
  LogOperacao('ESTADO', 'I', Result);
end;

function TEstadoService.Atualizar(AObj: TEstado): Boolean;
begin
  ValidarId(AObj.Id, 'Estado');
  Validar(AObj);
  Result := FRepo.AtualizarParam(
    AObj.Id,
    'PAIS_ID = :PAIS, NOME = :NOME, UF = :UF, CODIGO_IBGE = :IBGE, ' +
    'ATIVO = :ATIVO',
    ['PAIS', 'NOME', 'UF', 'IBGE', 'ATIVO'],
    [IntToStr(AObj.PaisId), AObj.Nome, AObj.Uf, AObj.CodigoIbge, AObj.Ativo]);
  LogOperacao('ESTADO', 'U', AObj.Id);
end;

function TEstadoService.Excluir(AId: Int64): Boolean;
var
  LQuery: TSQLQuery;
  LUsos: Int64;
begin
  ValidarId(AId, 'Estado');
  { não deixa excluir estado com cidades vinculadas (referência lógica) }
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := Conexao.Connection;
    LQuery.Transaction := Conexao.Transaction;
    LQuery.SQL.Text := 'SELECT COUNT(*) FROM CIDADE WHERE ESTADO_ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    LUsos := LQuery.Fields[0].AsLargeInt;
    LQuery.Close;
  finally
    LQuery.Free;
  end;
  if LUsos > 0 then
    raise Exception.Create(
      'Este estado possui cidades vinculadas e não pode ser excluído.');
  Result := FRepo.Excluir(AId);
  LogOperacao('ESTADO', 'D', AId);
end;

end.
