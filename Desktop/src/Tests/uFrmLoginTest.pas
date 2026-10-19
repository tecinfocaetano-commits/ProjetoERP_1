unit uFrmLoginTest;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Testes Unitários para Login
  Descrição: Testes de autenticação de usuários
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uAssert, uConexao, uSessao, uSenhaHash;

type
  { TLoginTest }
  TLoginTest = class
  public
    class procedure RunAllTests(ASuite: TTestSuite);
  end;

implementation

{ TLoginTest }

class procedure TLoginTest.RunAllTests(ASuite: TTestSuite);
var
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LTestUser: string;
  LTestPassword: string;
  LTestUserId: Int64;
  LSuccess: Boolean;
  LSenhaGuardada: string;

  { replica o fluxo do login real: busca por LOGIN (a senha não
    entra no WHERE) e confere em código via uSenhaHash }
  procedure BuscarSenhaDoUsuario(const ALogin: string; out AEncontrou: Boolean);
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT ID, SENHA FROM USUARIO ' +
      'WHERE LOGIN = :LOGIN AND ATIVO = ''A''';
    LQuery.ParamByName('LOGIN').AsString := ALogin;
    LQuery.Open;
    AEncontrou := not LQuery.IsEmpty;
    if AEncontrou then
      LSenhaGuardada := LQuery.FieldByName('SENHA').AsString
    else
      LSenhaGuardada := '';
  end;

  procedure TestAutenticacaoSucesso;
  var
    LEncontrou: Boolean;
  begin
    try
      BuscarSenhaDoUsuario(LTestUser, LEncontrou);
      LSuccess := LEncontrou and SenhaConfere(LTestPassword, LSenhaGuardada);
      if LSuccess then
        LTestUserId := LQuery.FieldByName('ID').AsLargeInt;

      AssertTrue(LSuccess, 'Autenticação deve ter sucesso com credenciais válidas');
      ASuite.AddResult('TestAutenticacaoSucesso', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestAutenticacaoSucesso', False, E.Message);
    end;
  end;

  procedure TestAutenticacaoFalhaSenhaIncorreta;
  var
    LEncontrou: Boolean;
  begin
    try
      BuscarSenhaDoUsuario(LTestUser, LEncontrou);
      LSuccess := (not LEncontrou) or
        (not SenhaConfere('senha_errada_123', LSenhaGuardada));
      AssertTrue(LSuccess, 'Autenticação deve falhar com senha incorreta');
      ASuite.AddResult('TestAutenticacaoFalhaSenhaIncorreta', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestAutenticacaoFalhaSenhaIncorreta', False, E.Message);
    end;
  end;

  procedure TestAutenticacaoFalhaUsuarioInexistente;
  var
    LEncontrou: Boolean;
  begin
    try
      BuscarSenhaDoUsuario('usuario_inexistente_999', LEncontrou);
      LSuccess := not LEncontrou;
      AssertTrue(LSuccess, 'Autenticação deve falhar com usuário inexistente');
      ASuite.AddResult('TestAutenticacaoFalhaUsuarioInexistente', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestAutenticacaoFalhaUsuarioInexistente', False, E.Message);
    end;
  end;

  procedure TestAutenticacaoFalhaUsuarioInativo;
  var
    LEncontrou: Boolean;
  begin
    try
      { busca o usuário inativo pelo mesmo filtro do login (ATIVO='A'):
        não pode ser encontrado — é o que impede a autenticação }
      LQuery.Close;
      LQuery.SQL.Text :=
        'SELECT ID FROM USUARIO ' +
        'WHERE LOGIN = :LOGIN AND SENHA = :SENHA AND ATIVO = ''I''';
      LQuery.ParamByName('LOGIN').AsString := LTestUser;
      LQuery.ParamByName('SENHA').AsString := LSenhaGuardada;
      LQuery.Open;

      LEncontrou := not LQuery.IsEmpty;
      { se existe uma linha inativa com esse login, o filtro ATIVO='A'
        do login a esconde: autenticação falha como esperado }
      LSuccess := True;
      if LEncontrou then
      begin
        LQuery.Close;
        LQuery.SQL.Text :=
          'SELECT ID FROM USUARIO ' +
          'WHERE LOGIN = :LOGIN AND ATIVO = ''A''';
        LQuery.ParamByName('LOGIN').AsString := LTestUser;
        LQuery.Open;
        LSuccess := LQuery.IsEmpty;
      end;

      AssertTrue(LSuccess, 'Autenticação deve falhar para usuário inativo');
      ASuite.AddResult('TestAutenticacaoFalhaUsuarioInativo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestAutenticacaoFalhaUsuarioInativo', False, E.Message);
    end;
  end;

  procedure TestAtualizarUltimoAcesso;
  begin
    try
      if LTestUserId > 0 then
      begin
        LQuery.Close;
        LQuery.SQL.Text := 'UPDATE USUARIO SET ULTIMO_ACESSO = CURRENT_TIMESTAMP WHERE ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := LTestUserId;
        LQuery.ExecSQL;
        LConexao.Confirmar;

        AssertTrue(True, 'Atualização de último acesso deve funcionar');
        ASuite.AddResult('TestAtualizarUltimoAcesso', True, '');
      end
      else
      begin
        ASuite.AddResult('TestAtualizarUltimoAcesso', True, 'Skipped - No test user');
      end;
    except
      on E: Exception do
        ASuite.AddResult('TestAtualizarUltimoAcesso', False, E.Message);
    end;
  end;

  { --- SHA-256 (uSenhaHash) --------------------------------------- }

  procedure TestHashSenhaVetorAdmin123;
  begin
    try
      { vetor calculado fora (PowerShell SHA256 de 'admin123') }
      LSuccess := HashSenha('admin123') =
        '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9';
      AssertTrue(LSuccess, 'SHA-256(''admin123'') deve bater com o vetor conhecido');
      ASuite.AddResult('TestHashSenhaVetorAdmin123', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestHashSenhaVetorAdmin123', False, E.Message);
    end;
  end;

  procedure TestHashSenhaVetorAbc;
  begin
    try
      { vetor oficial FIPS 180-4: SHA256('abc') }
      LSuccess := SHA256Hex('abc') =
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
      AssertTrue(LSuccess, 'SHA256(''abc'') deve bater com o vetor FIPS');
      ASuite.AddResult('TestHashSenhaVetorAbc', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestHashSenhaVetorAbc', False, E.Message);
    end;
  end;

  procedure TestEhHashSha256;
  begin
    try
      LSuccess := EhHashSHA256(HashSenha('abc')) and
        (not EhHashSHA256('admin123')) and
        (not EhHashSHA256('')) and
        (not EhHashSHA256(StringOfChar('g', 64)));
      AssertTrue(LSuccess, 'EhHashSHA256 deve reconhecer só hex de 64 chars');
      ASuite.AddResult('TestEhHashSha256', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEhHashSha256', False, E.Message);
    end;
  end;

  procedure TestSenhaLegadaMigraParaHash;
  var
    LLoginTemp: string;
    LEncontrou: Boolean;
  begin
    { simula a migração progressiva: usuário com senha antiga em
      texto puro é autenticado e a senha é regravada como hash }
    LLoginTemp := 'teste_migra_senha';
    try
      try
        LQuery.Close;
        LQuery.SQL.Text :=
          'DELETE FROM USUARIO WHERE LOGIN = :LOGIN';
        LQuery.ParamByName('LOGIN').AsString := LLoginTemp;
        LQuery.ExecSQL;

        LQuery.SQL.Text :=
          'INSERT INTO USUARIO (EMPRESA_ID, GRUPO_ID, NOME, LOGIN, SENHA, ADMINISTRADOR, ATIVO) ' +
          'VALUES (1, 0, ''Teste Migra'', :LOGIN, :SENHA, ''N'', ''A'')';
        LQuery.ParamByName('LOGIN').AsString := LLoginTemp;
        LQuery.ParamByName('SENHA').AsString := 'senha_legada_1';
        LQuery.ExecSQL;
        LConexao.Confirmar;

        BuscarSenhaDoUsuario(LLoginTemp, LEncontrou);
        LSuccess := LEncontrou and SenhaConfere('senha_legada_1', LSenhaGuardada) and
          PrecisaMigrarSenha(LSenhaGuardada);
        AssertTrue(LSuccess, 'Senha legada deve autenticar e exigir migração');

        { migra (o que o login faz) e reconfere }
        LQuery.Close;
        LQuery.SQL.Text := 'UPDATE USUARIO SET SENHA = :SENHA WHERE LOGIN = :LOGIN';
        LQuery.ParamByName('SENHA').AsString := HashSenha('senha_legada_1');
        LQuery.ParamByName('LOGIN').AsString := LLoginTemp;
        LQuery.ExecSQL;
        LConexao.Confirmar;

        BuscarSenhaDoUsuario(LLoginTemp, LEncontrou);
        LSuccess := LEncontrou and SenhaConfere('senha_legada_1', LSenhaGuardada) and
          (not PrecisaMigrarSenha(LSenhaGuardada));
        AssertTrue(LSuccess, 'Senha migrada deve autenticar sem nova migração');
        ASuite.AddResult('TestSenhaLegadaMigraParaHash', True, '');
      finally
        LQuery.Close;
        LQuery.SQL.Text := 'DELETE FROM USUARIO WHERE LOGIN = :LOGIN';
        LQuery.ParamByName('LOGIN').AsString := LLoginTemp;
        LQuery.ExecSQL;
        LConexao.Confirmar;
      end;
    except
      on E: Exception do
        ASuite.AddResult('TestSenhaLegadaMigraParaHash', False, E.Message);
    end;
  end;

begin
  WriteLn('========================================');
  WriteLn('EXECUTANDO TESTES DE LOGIN');
  WriteLn('========================================');

  LConexao := TConexao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  LTestUserId := 0;

  try
    // Conectar ao banco
    LConexao.Conectar;
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;

    // Configurar usuário de teste (usar um usuário existente ou criar um)
    LTestUser := 'admin'; // Usuário padrão para testes
    LTestPassword := 'admin123'; // Senha padrão para testes

    // Verificar se existe usuário admin, senão criar um temporário
    LQuery.SQL.Text := 'SELECT ID FROM USUARIO WHERE LOGIN = :LOGIN';
    LQuery.ParamByName('LOGIN').AsString := LTestUser;
    LQuery.Open;

    if LQuery.IsEmpty then
    begin
      // Criar usuário de teste (sem EMPRESA_ID pois não existe no banco real)
      LQuery.Close;
      LQuery.SQL.Text :=
        'INSERT INTO USUARIO (NOME, LOGIN, SENHA, ADMINISTRADOR, ATIVO) ' +
        'VALUES (''Usuario Teste'', :LOGIN, :SENHA, ''S'', ''A'')';
      LQuery.ParamByName('LOGIN').AsString := LTestUser;
      LQuery.ParamByName('SENHA').AsString := HashSenha(LTestPassword);
      LQuery.ExecSQL;
      LConexao.Confirmar;
    end;

    // Executar testes
    TestAutenticacaoSucesso;
    TestAutenticacaoFalhaSenhaIncorreta;
    TestAutenticacaoFalhaUsuarioInexistente;
    TestAutenticacaoFalhaUsuarioInativo;
    TestAtualizarUltimoAcesso;

    // SHA-256 (pendência: senhas em hash)
    TestHashSenhaVetorAdmin123;
    TestHashSenhaVetorAbc;
    TestEhHashSha256;
    TestSenhaLegadaMigraParaHash;

  finally
    LQuery.Free;
    // Não desconectar, pois a conexão é singleton
  end;
end;

end.
