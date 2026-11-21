unit uAuditoria;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Auditoria de operações
  ------------------------------------------------------------
  Grava em LOG_SISTEMA (tabela já existente) quem fez o quê,
  quando e com quais valores antes/depois.

  Regras:
    - SQL parametrizado (nunca concatenação);
    - Empresa/Usuário vindos de TSessao;
    - largura de DADOS_ANTERIORES/DADOS_NOVOS respeitada (255);
    - o registro entra na transação corrente do TConexao, de modo
      que a auditoria e a operação de negócio sejam atômicas.
  ============================================================ }

interface

uses
  SysUtils, SQLDB, IBConnection;

type
  EAuditoria = class(Exception);

const
  { Tamanho das colunas DADOS_ANTERIORES / DADOS_NOVOS em LOG_SISTEMA }
  AUDITORIA_TAMANHO_DADOS = 255;
  { Tamanho das colunas TABELA / OPERACAO }
  AUDITORIA_TAMANHO_TABELA  = 50;
  AUDITORIA_TAMANHO_OPERACAO = 20;

{ Registra a operação na trilha de auditoria.
  ATabela          tabela afetada (ex.: 'MAPA_PRODUCAO')
  AOperacao        operação (ex.: 'INSERT', 'UPDATE', 'CANCELAR', 'BIPAGEM')
  ARegistroId      chave do registro afetado
  ADadosAnteriores resumo dos valores antes ('' quando não houver)
  ADadosNovos      resumo dos valores depois ('' quando não houver) }
procedure RegistrarAuditoria(const ATabela, AOperacao: string;
  ARegistroId: Int64; const ADadosAnteriores: string = '';
  const ADadosNovos: string = '');

{ Mesmo que RegistrarAuditoria, porém nunca levanta exceção.
  Usar quando a auditoria não pode impedir a operação principal. }
procedure RegistrarAuditoriaSegura(const ATabela, AOperacao: string;
  ARegistroId: Int64; const ADadosAnteriores: string = '';
  const ADadosNovos: string = '');

{ Variante para quem não tem TSessao (API REST, threads do Horse):
  recebe conexão/transação e empresa/usuário explícitos. Mesma
  gravação em LOG_SISTEMA dentro da transação informada. }
procedure RegistrarAuditoriaConexao(AConnection: TIBConnection;
  ATransaction: TSQLTransaction; AEmpresaId, AUsuarioId: Int64;
  const ATabela, AOperacao: string; ARegistroId: Int64;
  const ADadosAnteriores: string = '';
  const ADadosNovos: string = '');
procedure RegistrarAuditoriaSeguraConexao(AConnection: TIBConnection;
  ATransaction: TSQLTransaction; AEmpresaId, AUsuarioId: Int64;
  const ATabela, AOperacao: string; ARegistroId: Int64;
  const ADadosAnteriores: string = '';
  const ADadosNovos: string = '');

{ Monta "CAMPO=valor; CAMPO=valor" para o resumo da auditoria,
  truncando o resultado no limite da coluna. }
function ResumoAuditoria(const ACampos: array of string): string;

implementation

uses
  uConexao, uSessao;

function Truncar(const AValor: string; ATamanho: Integer): string;
begin
  if Length(AValor) <= ATamanho then
    Result := AValor
  else
    Result := Copy(AValor, 1, ATamanho);
end;

function ResumoAuditoria(const ACampos: array of string): string;
var
  I: Integer;
begin
  Result := '';
  for I := Low(ACampos) to High(ACampos) do
  begin
    if ACampos[I] = '' then
      Continue;
    if Result <> '' then
      Result := Result + '; ';
    Result := Result + ACampos[I];
  end;
  Result := Truncar(Result, AUDITORIA_TAMANHO_DADOS);
end;

procedure Gravar(const ATabela, AOperacao: string; ARegistroId: Int64;
  const ADadosAnteriores, ADadosNovos: string);
var
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LSessao: TSessao;
begin
  LConexao := TConexao.GetInstance;
  if not LConexao.Conectado then
    raise EAuditoria.Create('Sem conexão com o banco para registrar a auditoria.');

  LSessao := TSessao.GetInstance;
  RegistrarAuditoriaConexao(LConexao.Connection, LConexao.Transaction,
    LSessao.EmpresaId, LSessao.UsuarioId, ATabela, AOperacao, ARegistroId,
    ADadosAnteriores, ADadosNovos);
end;

procedure RegistrarAuditoriaConexao(AConnection: TIBConnection;
  ATransaction: TSQLTransaction; AEmpresaId, AUsuarioId: Int64;
  const ATabela, AOperacao: string; ARegistroId: Int64;
  const ADadosAnteriores, ADadosNovos: string);
var
  LQuery: TSQLQuery;
begin
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := AConnection;
    LQuery.Transaction := ATransaction;
    LQuery.SQL.Text :=
      'INSERT INTO LOG_SISTEMA (EMPRESA_ID, USUARIO_ID, TABELA, OPERACAO, ' +
      '  REGISTRO_ID, DADOS_ANTERIORES, DADOS_NOVOS, DATA_OPERACAO, DATA_HORA) ' +
      'VALUES (:EMP, :USR, :TAB, :OP, :REG, :ANT, :NOV, CURRENT_DATE, CURRENT_TIMESTAMP)';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.ParamByName('USR').AsLargeInt := AUsuarioId;
    LQuery.ParamByName('TAB').AsString := Truncar(ATabela, AUDITORIA_TAMANHO_TABELA);
    LQuery.ParamByName('OP').AsString := Truncar(AOperacao, AUDITORIA_TAMANHO_OPERACAO);
    LQuery.ParamByName('REG').AsLargeInt := ARegistroId;
    LQuery.ParamByName('ANT').AsString := Truncar(ADadosAnteriores, AUDITORIA_TAMANHO_DADOS);
    LQuery.ParamByName('NOV').AsString := Truncar(ADadosNovos, AUDITORIA_TAMANHO_DADOS);
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

procedure RegistrarAuditoriaSeguraConexao(AConnection: TIBConnection;
  ATransaction: TSQLTransaction; AEmpresaId, AUsuarioId: Int64;
  const ATabela, AOperacao: string; ARegistroId: Int64;
  const ADadosAnteriores, ADadosNovos: string);
begin
  try
    RegistrarAuditoriaConexao(AConnection, ATransaction, AEmpresaId,
      AUsuarioId, ATabela, AOperacao, ARegistroId,
      ADadosAnteriores, ADadosNovos);
  except
    // Auditoria não pode interromper a operação principal
  end;
end;

procedure RegistrarAuditoria(const ATabela, AOperacao: string;
  ARegistroId: Int64; const ADadosAnteriores: string;
  const ADadosNovos: string);
begin
  Gravar(ATabela, AOperacao, ARegistroId, ADadosAnteriores, ADadosNovos);
end;

procedure RegistrarAuditoriaSegura(const ATabela, AOperacao: string;
  ARegistroId: Int64; const ADadosAnteriores: string;
  const ADadosNovos: string);
begin
  try
    Gravar(ATabela, AOperacao, ARegistroId, ADadosAnteriores, ADadosNovos);
  except
    // Auditoria não pode interromper a operação principal
  end;
end;

end.
