unit uConexao;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SQLDB, IBConnection;

type
  TConexao = class
  private
    class var FInstance: TConexao;
    constructor CreatePrivate;
  public
    Connection: TIBConnection;
    Transaction: TSQLTransaction;
    Host: string;
    Database: string;
    User: string;
    Password: string;
    Port: Integer;

    class function GetInstance: TConexao;
    class procedure ReleaseInstance;

    procedure Conectar;
    procedure Desconectar;
    function Conectado: Boolean;

    procedure IniciarTransacao;
    procedure Confirmar;
    procedure Cancelar;
    function EmTransacao: Boolean;

    destructor Destroy; override;
  end;

implementation

constructor TConexao.CreatePrivate;
begin
  inherited Create;
  Connection := TIBConnection.Create(nil);
  Transaction := TSQLTransaction.Create(nil);
  // READ COMMITTED + rec_version: cada consulta enxerga o que ja foi confirmado
  // por outras conexoes (Desktop, outro usuario). Sem isto o Firebird usa
  // SNAPSHOT e a API passa a devolver dados obsoletos enquanto a transacao
  // permanecer aberta.
  Transaction.Params.Add('read_committed');
  Transaction.Params.Add('rec_version');
  Transaction.Params.Add('nowait');
  Connection.Transaction := Transaction;
  Transaction.DataBase := Connection;
  Host := 'localhost';
  Database := 'C:\Users\Charles\Documents\ProjetoERP_1\Banco\dados.fdb';
  User := 'SYSDBA';
  Password := 'masterkey';
  Port := 3050;
end;

class function TConexao.GetInstance: TConexao;
begin
  if FInstance = nil then
    FInstance := TConexao.CreatePrivate;
  Result := FInstance;
end;

class procedure TConexao.ReleaseInstance;
begin
  if FInstance <> nil then
  begin
    FInstance.Free;
    FInstance := nil;
  end;
end;

procedure TConexao.Conectar;
begin
  if not Connection.Connected then
  begin
    Connection.HostName := '';
    Connection.DatabaseName := Database;
    Connection.UserName := 'SYSDBA';
    Connection.Password := 'masterkey';
    Connection.LoginPrompt := False;
    // IMPORTANTE (API): NAO definir CharSet='UTF8'.
    // Com CharSet=UTF8 o FPC converte o texto para o codepage do sistema (CP1252),
    // o que corrompe o JSON (que precisa de UTF-8). Sem CharSet, o Firebird
    // entrega os bytes UTF-8 crus, que e exatamente o que a API deve repassar.
    Connection.Connected := True;
  end;
end;

procedure TConexao.Desconectar;
begin
  if Connection.Connected then
    Connection.Connected := False;
end;

function TConexao.Conectado: Boolean;
begin
  Result := Connection.Connected;
end;

procedure TConexao.IniciarTransacao;
begin
  if not Transaction.Active then
    Transaction.StartTransaction;
end;

procedure TConexao.Confirmar;
begin
  if Transaction.Active then
    Transaction.Commit;
end;

procedure TConexao.Cancelar;
begin
  if Transaction.Active then
    Transaction.Rollback;
end;

function TConexao.EmTransacao: Boolean;
begin
  Result := Transaction.Active;
end;

destructor TConexao.Destroy;
begin
  Desconectar;
  Transaction.Free;
  Connection.Free;
  inherited Destroy;
end;

initialization

finalization
  TConexao.ReleaseInstance;

end.
