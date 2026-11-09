unit uServiceBase;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Service Base
  Descrição: Classe base para serviços de negócio
  Padrão: Service Layer + Template Method
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uRepositoryBase, uConexao, uSessao;

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
    { garante que o registro pertence à empresa da sessão;
      ATabela é nome interno de tabela (nunca entrada do usuário) }
    procedure GarantirDaEmpresa(const ATabela: string; AId: Int64;
      const AMensagem: string);
    { mesma garantia para consultas com JOIN: ASQL deve retornar a
      coluna EMPRESA_ID e usar :ID como parâmetro do registro }
    procedure GarantirDaEmpresaSql(const ASQL: string; AId: Int64;
      const AMensagem: string);
    procedure LogOperacao(const ATabela, AOperacao: string; ARegistroId: Int64;
      const ADadosAnteriores: string = ''; const ADadosNovos: string = '');
  public
    constructor Create(ARepository: TRepositoryBase);
    destructor Destroy; override;
  end;

{ Garantia de isolamento multiempresa reutilizável por services que
  não herdam de TServiceBase. ASQL deve retornar a coluna EMPRESA_ID
  e usar :ID como parâmetro do registro. }
procedure GarantirEmpresaBanco(AConexao: TConexao; const ASQL: string;
  AId: Int64; const AMensagem: string);

implementation

uses
  uAuditoria;

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

procedure GarantirEmpresaBanco(AConexao: TConexao; const ASQL: string;
  AId: Int64; const AMensagem: string);
var
  LQuery: TSQLQuery;
begin
  if AId <= 0 then
    Exit; // registro novo: a empresa vem da sessão no INSERT
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := AConexao.Connection;
    LQuery.Transaction := AConexao.Transaction;
    LQuery.SQL.Text := ASQL;
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if LQuery.IsEmpty or
       (LQuery.FieldByName('EMPRESA_ID').AsLargeInt <>
        TSessao.GetInstance.EmpresaId) then
      raise Exception.Create(AMensagem);
  finally
    LQuery.Free;
  end;
end;

procedure TServiceBase.GarantirDaEmpresa(const ATabela: string; AId: Int64;
  const AMensagem: string);
begin
  GarantirEmpresaBanco(FConexao,
    Format('SELECT EMPRESA_ID FROM %s WHERE ID = :ID', [ATabela]),
    AId, AMensagem);
end;

procedure TServiceBase.GarantirDaEmpresaSql(const ASQL: string; AId: Int64;
  const AMensagem: string);
begin
  GarantirEmpresaBanco(FConexao, ASQL, AId, AMensagem);
end;

procedure TServiceBase.LogOperacao(const ATabela, AOperacao: string;
  ARegistroId: Int64; const ADadosAnteriores: string;
  const ADadosNovos: string);
begin
  { via uAuditoria: SQL parametrizado, empresa/usuário da sessão e
    truncamento nas colunas de 255 — o INSERT antigo concatenava strings
    (quebrava o SQL com aspas) e gravava USUARIO_ID = 0 (TODO).
    Segura: falha de log nunca interrompe a operação principal. }
  RegistrarAuditoriaSegura(ATabela, AOperacao, ARegistroId,
    ADadosAnteriores, ADadosNovos);
end;

end.
