unit uServiceBase;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Service Base
  Descrição: Classe base para serviços de negócio
  Padrão: Service Layer + Template Method
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uRepositoryBase, uConexao;

type
  { TServiceBase - Lógica de negócio base }
  TServiceBase = class
  private
    FRepository: TRepositoryBase;
    FConexao: TConexao;
  protected
    property Repository: TRepositoryBase read FRepository;
    property Conexao: TConexao read FConexao;

    procedure ValidarCampoObrigatorio(const AValor, ACampo: string);
    procedure ValidarId(AId: Int64; const AEntidade: string);
    procedure LogOperacao(const ATabela, AOperacao: string; ARegistroId: Int64;
      const ADadosAnteriores: string = ''; const ADadosNovos: string = '');
  public
    constructor Create(ARepository: TRepositoryBase);
    destructor Destroy; override;
  end;

implementation

{ TServiceBase }

constructor TServiceBase.Create(ARepository: TRepositoryBase);
begin
  inherited Create;
  FRepository := ARepository;
  FConexao := TConexao.GetInstance;
end;

destructor TServiceBase.Destroy;
begin
  // Repository é gerenciado externamente ou pela subclasse
  inherited Destroy;
end;

procedure TServiceBase.ValidarCampoObrigatorio(const AValor, ACampo: string);
begin
  if Trim(AValor) = '' then
    raise Exception.CreateFmt('O campo "%s" é obrigatório.', [ACampo]);
end;

procedure TServiceBase.ValidarId(AId: Int64; const AEntidade: string);
begin
  if AId <= 0 then
    raise Exception.CreateFmt('%s: ID inválido (%d).', [AEntidade, AId]);
  if not FRepository.Existe(AId) then
    raise Exception.CreateFmt('%s com ID %d não encontrado.', [AEntidade, AId]);
end;

procedure TServiceBase.LogOperacao(const ATabela, AOperacao: string;
  ARegistroId: Int64; const ADadosAnteriores: string;
  const ADadosNovos: string);
var
  LSQL: string;
  LQuery: TSQLQuery;
begin
  LSQL := Format(
    'INSERT INTO LOG_SISTEMA (EMPRESA_ID, USUARIO_ID, TABELA, OPERACAO, REGISTRO_ID, ' +
    'DADOS_ANTERIORES, DADOS_NOVOS) VALUES (%d, %d, ''%s'', ''%s'', %d, ''%s'', ''%s'')',
    [FConexao.Connection.Tag, { EmpresaId armazenado no Tag }
     0, { TODO: obter UserId da sessão }
     ATabela, AOperacao, ARegistroId,
     ADadosAnteriores, ADadosNovos]);
  try
    LQuery := TSQLQuery.Create(nil);
    try
      LQuery.DataBase := FConexao.Connection;
      LQuery.Transaction := FConexao.Transaction;
      LQuery.SQL.Text := LSQL;
      LQuery.ExecSQL;
    finally
      LQuery.Free;
    end;
  except
    // Log não deve interromper operação principal
  end;
end;

end.
