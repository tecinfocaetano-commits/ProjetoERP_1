unit uRepositoryBase;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Repository Base
  Descrição: Classe base para repositórios (CRUD genérico)
  Padrão: Repository Pattern + Template Method
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, DB, uConexao;

type
  { TRepositoryBase - Operações genéricas de persistência }
  TRepositoryBase = class
  private
    FConexao: TConexao;
    FQuery: TSQLQuery;
    FTableName: string;
  protected
    property Conexao: TConexao read FConexao;
    property Query: TSQLQuery read FQuery;
    property TableName: string read FTableName;

    procedure PrepararQuery(const ASQL: string);
    procedure ExecutarQuery;
    function ExecutarScalar(const ASQL: string): Variant;
  public
    constructor Create(const ATableName: string);
    destructor Destroy; override;

    function BuscarPorId(AId: Int64): TSQLQuery;
    function BuscarTodos(const ACondicao: string = '';
      const AOrdem: string = 'ID'): TSQLQuery;
    function Inserir(const ACampos, AValores: string): Int64;
    function Atualizar(AId: Int64; const ACamposValores: string): Boolean;
    function Excluir(AId: Int64): Boolean;
    function Contar(const ACondicao: string = ''): Int64;
    function Existe(AId: Int64): Boolean;
  end;

implementation

{ TRepositoryBase }

constructor TRepositoryBase.Create(const ATableName: string);
begin
  inherited Create;
  FConexao := TConexao.GetInstance;
  FQuery := TSQLQuery.Create(nil);
  FQuery.DataBase := FConexao.Connection;
  FQuery.Transaction := FConexao.Transaction;
  FTableName := ATableName;
end;

destructor TRepositoryBase.Destroy;
begin
  FQuery.Free;
  inherited Destroy;
end;

procedure TRepositoryBase.PrepararQuery(const ASQL: string);
begin
  FQuery.Close;
  FQuery.SQL.Clear;
  FQuery.SQL.Text := ASQL;
end;

procedure TRepositoryBase.ExecutarQuery;
begin
  FQuery.ExecSQL;
end;

function TRepositoryBase.ExecutarScalar(const ASQL: string): Variant;
begin
  PrepararQuery(ASQL);
  FQuery.Open;
  try
    if not FQuery.IsEmpty then
      Result := FQuery.Fields[0].Value
    else
      Result := Null;
  finally
    FQuery.Close;
  end;
end;

function TRepositoryBase.BuscarPorId(AId: Int64): TSQLQuery;
begin
  PrepararQuery(Format('SELECT * FROM %s WHERE ID = :ID', [FTableName]));
  FQuery.ParamByName('ID').AsLargeInt := AId;
  FQuery.Open;
  Result := FQuery;
end;

function TRepositoryBase.BuscarTodos(const ACondicao: string;
  const AOrdem: string): TSQLQuery;
var
  LSQL: string;
begin
  LSQL := Format('SELECT * FROM %s', [FTableName]);
  if ACondicao <> '' then
    LSQL := LSQL + ' WHERE ' + ACondicao;
  LSQL := LSQL + ' ORDER BY ' + AOrdem;

  PrepararQuery(LSQL);
  FQuery.Open;
  Result := FQuery;
end;

function TRepositoryBase.Inserir(const ACampos, AValores: string): Int64;
var
  LSQL: string;
begin
  LSQL := Format('INSERT INTO %s (%s) VALUES (%s)', [FTableName, ACampos, AValores]);
  PrepararQuery(LSQL);
  ExecutarQuery;
  FConexao.Confirmar;

  // Retorna o último ID gerado
  Result := Int64(ExecutarScalar(
    Format('SELECT GEN_ID(GEN_%s_ID, 0) FROM RDB$DATABASE', [FTableName])));
end;

function TRepositoryBase.Atualizar(AId: Int64; const ACamposValores: string): Boolean;
var
  LSQL: string;
begin
  LSQL := Format('UPDATE %s SET %s WHERE ID = %d', [FTableName, ACamposValores, AId]);
  PrepararQuery(LSQL);
  ExecutarQuery;
  FConexao.Confirmar;
  Result := True;
end;

function TRepositoryBase.Excluir(AId: Int64): Boolean;
var
  LSQL: string;
begin
  LSQL := Format('DELETE FROM %s WHERE ID = %d', [FTableName, AId]);
  PrepararQuery(LSQL);
  ExecutarQuery;
  FConexao.Confirmar;
  Result := True;
end;

function TRepositoryBase.Contar(const ACondicao: string): Int64;
var
  LSQL: string;
begin
  LSQL := Format('SELECT COUNT(*) FROM %s', [FTableName]);
  if ACondicao <> '' then
    LSQL := LSQL + ' WHERE ' + ACondicao;
  Result := Int64(ExecutarScalar(LSQL));
end;

function TRepositoryBase.Existe(AId: Int64): Boolean;
begin
  Result := Contar(Format('ID = %d', [AId])) > 0;
end;

end.
