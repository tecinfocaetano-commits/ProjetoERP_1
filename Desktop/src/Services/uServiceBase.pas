unit uServiceBase;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Service Base
  Descrição: Classe base para serviços de negócio
  Padrão: Service Layer + Template Method
  ============================================================ }

interface

uses
  Classes, SysUtils, uRepositoryBase, uConexao;

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
