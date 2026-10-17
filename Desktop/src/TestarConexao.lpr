program TestarConexao;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, SQLDB, IBConnection;

var
  Connection: TIBConnection;
begin
  Connection := TIBConnection.Create(nil);
  try
    Connection.HostName := '';
    Connection.DatabaseName := 'C:\Users\Charles\Documents\ProjetoERP_1\Banco\dados.fdb';
    Connection.UserName := 'SYSDBA';
    Connection.Password := 'masterkey';
    Connection.CharSet := 'UTF8';
    
    try
      Connection.Connected := True;
      WriteLn('Conexão bem-sucedida!');
      WriteLn('Pressione ENTER para sair...');
      ReadLn;
      Connection.Connected := False;
    except
      on E: Exception do
      begin
        WriteLn('Erro na conexão: ', E.Message);
        WriteLn('Pressione ENTER para sair...');
        ReadLn;
      end;
    end;
  finally
    Connection.Free;
  end;
end.
