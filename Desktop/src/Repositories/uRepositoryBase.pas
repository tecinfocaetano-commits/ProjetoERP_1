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
    procedure AplicarParams(const ANomes, AValores: array of string);
    procedure AplicarParamsN(const ANomes, AValores,
      ANulos: array of string);
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

    { --- variantes parametrizadas (seguras contra injeção/aspas) ---
      Os valores entram por ParamByName, nunca por concatenação de
      string. Os placeholders são nomeados e batem com os nomes
      passados em AParams. }
    function InserirParam(const ACampos, AValoresParam: string;
      const ANomes, AValores: array of string): Int64;
    function AtualizarParam(AId: Int64; const ACamposParam: string;
      const ANomes, AValores: array of string): Boolean;
    { Variantes que aceitam ANulos: nomes de parâmetros gravados como
      NULL (para colunas anuláveis com CHECK que rejeita string vazia). }
    function InserirParamN(const ACampos, AValoresParam: string;
      const ANomes, AValores, ANulos: array of string): Int64;
    function AtualizarParamN(AId: Int64; const ACamposParam: string;
      const ANomes, AValores, ANulos: array of string): Boolean;
    function BuscarTodosParam(const ACondicaoParam: string;
      const ANomes, AValores: array of string;
      const AOrdem: string = 'ID'): TSQLQuery;
    function ContarParam(const ACondicaoParam: string;
      const ANomes, AValores: array of string): Int64;
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

{ Liga cada nome ao valor como parâmetro da query já preparada.
  Valores são sempre string e entram via ParamByName (nunca
  concatenados no SQL) — o tipo string cobre texto, numérico e
  o SQLDB converte conforme a coluna no banco. }
procedure TRepositoryBase.AplicarParams(const ANomes, AValores: array of string);
var
  I: Integer;
begin
  if Length(ANomes) <> Length(AValores) then
    raise Exception.CreateFmt(
      'AplicarParams: %d nomes para %d valores.', [Length(ANomes), Length(AValores)]);
  for I := 0 to High(ANomes) do
    FQuery.ParamByName(ANomes[I]).AsString := AValores[I];
end;

procedure TRepositoryBase.AplicarParamsN(const ANomes, AValores,
  ANulos: array of string);
var
  I, J: Integer;
  LEhNulo: Boolean;
begin
  if Length(ANomes) <> Length(AValores) then
    raise Exception.CreateFmt(
      'AplicarParamsN: %d nomes para %d valores.', [Length(ANomes), Length(AValores)]);
  for I := 0 to High(ANomes) do
  begin
    LEhNulo := False;
    if Length(ANulos) > 0 then
      for J := 0 to High(ANulos) do
        if ANulos[J] = ANomes[I] then
        begin
          LEhNulo := True;
          Break;
        end;
    if LEhNulo then
      FQuery.ParamByName(ANomes[I]).Clear
    else
      FQuery.ParamByName(ANomes[I]).AsString := AValores[I];
  end;
end;

function TRepositoryBase.InserirParam(const ACampos, AValoresParam: string;
  const ANomes, AValores: array of string): Int64;
begin
  PrepararQuery(Format('INSERT INTO %s (%s) VALUES (%s)',
    [FTableName, ACampos, AValoresParam]));
  AplicarParams(ANomes, AValores);
  ExecutarQuery;
  FConexao.Confirmar;

  Result := Int64(ExecutarScalar(
    Format('SELECT GEN_ID(GEN_%s_ID, 0) FROM RDB$DATABASE', [FTableName])));
end;

function TRepositoryBase.InserirParamN(const ACampos, AValoresParam: string;
  const ANomes, AValores, ANulos: array of string): Int64;
begin
  PrepararQuery(Format('INSERT INTO %s (%s) VALUES (%s)',
    [FTableName, ACampos, AValoresParam]));
  AplicarParamsN(ANomes, AValores, ANulos);
  ExecutarQuery;
  FConexao.Confirmar;

  Result := Int64(ExecutarScalar(
    Format('SELECT GEN_ID(GEN_%s_ID, 0) FROM RDB$DATABASE', [FTableName])));
end;

function TRepositoryBase.AtualizarParam(AId: Int64; const ACamposParam: string;
  const ANomes, AValores: array of string): Boolean;
begin
  PrepararQuery(Format('UPDATE %s SET %s WHERE ID = :ID',
    [FTableName, ACamposParam]));
  AplicarParams(ANomes, AValores);
  FQuery.ParamByName('ID').AsLargeInt := AId;
  ExecutarQuery;
  FConexao.Confirmar;
  Result := True;
end;

function TRepositoryBase.AtualizarParamN(AId: Int64; const ACamposParam: string;
  const ANomes, AValores, ANulos: array of string): Boolean;
begin
  PrepararQuery(Format('UPDATE %s SET %s WHERE ID = :ID',
    [FTableName, ACamposParam]));
  AplicarParamsN(ANomes, AValores, ANulos);
  FQuery.ParamByName('ID').AsLargeInt := AId;
  ExecutarQuery;
  FConexao.Confirmar;
  Result := True;
end;

function TRepositoryBase.BuscarTodosParam(const ACondicaoParam: string;
  const ANomes, AValores: array of string;
  const AOrdem: string): TSQLQuery;
var
  LSQL: string;
begin
  LSQL := Format('SELECT * FROM %s', [FTableName]);
  if ACondicaoParam <> '' then
    LSQL := LSQL + ' WHERE ' + ACondicaoParam;
  LSQL := LSQL + ' ORDER BY ' + AOrdem;

  PrepararQuery(LSQL);
  AplicarParams(ANomes, AValores);
  FQuery.Open;
  Result := FQuery;
end;

function TRepositoryBase.ContarParam(const ACondicaoParam: string;
  const ANomes, AValores: array of string): Int64;
var
  LSQL: string;
begin
  { não usa ExecutarScalar: ele re-preparia a SQL e limparia os
    parâmetros recém-aplicados }
  LSQL := Format('SELECT COUNT(*) FROM %s', [FTableName]);
  if ACondicaoParam <> '' then
    LSQL := LSQL + ' WHERE ' + ACondicaoParam;
  PrepararQuery(LSQL);
  AplicarParams(ANomes, AValores);
  FQuery.Open;
  try
    Result := FQuery.Fields[0].AsLargeInt;
  finally
    FQuery.Close;
  end;
end;

end.
