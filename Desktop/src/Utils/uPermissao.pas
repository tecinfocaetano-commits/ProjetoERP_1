unit uPermissao;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Permissões por módulo/tela/ação
  ------------------------------------------------------------
  Usa a tabela PERMISSAO (GRUPO_ID, MODULO, TELA, PODE_*), que já
  existia no banco mas não era consultada por nenhuma tela.

  Regras:
    - usuário com USUARIO.ADMINISTRADOR = 'S' tem acesso total;
    - sem registro de permissão para o grupo => acesso negado
      (seguro por padrão);
    - qualquer erro de banco => acesso negado (não libera por falha).
  ============================================================ }

interface

uses
  SysUtils;

type
  EPermissaoNegada = class(Exception);

const
  PERM_VISUALIZAR = 'VISUALIZAR';
  PERM_INSERIR    = 'INSERIR';
  PERM_EDITAR     = 'EDITAR';
  PERM_EXCLUIR    = 'EXCLUIR';
  PERM_IMPRIMIR   = 'IMPRIMIR';

{ Módulo/telas do módulo de Produção (espelham o script 012) }
  MODULO_PRODUCAO       = 'PRODUCAO';
  TELA_MAPA_PRODUCAO    = 'MAPA_PRODUCAO';
  TELA_BIPAGEM          = 'BIPAGEM';
  TELA_CONSUMO          = 'CONSUMO';
  TELA_FICHA_TECNICA    = 'FICHA_TECNICA';

{ Verdadeiro quando o usuário logado pode executar a ação. }
function TemPermissao(const AModulo, ATela, AAcao: string): Boolean;

{ Levanta EPermissaoNegada quando não tem permissão, com mensagem
  amigável (e opcional). }
procedure VerificarPermissao(const AModulo, ATela, AAcao: string;
  const AMensagem: string = '');

implementation

uses
  SQLDB, uConexao, uSessao;

function ColunaDaAcao(const AAcao: string): string;
begin
  if AAcao = PERM_VISUALIZAR then
    Result := 'PODE_VISUALIZAR'
  else if AAcao = PERM_INSERIR then
    Result := 'PODE_INSERIR'
  else if AAcao = PERM_EDITAR then
    Result := 'PODE_EDITAR'
  else if AAcao = PERM_EXCLUIR then
    Result := 'PODE_EXCLUIR'
  else if AAcao = PERM_IMPRIMIR then
    Result := 'PODE_IMPRIMIR'
  else
    Result := '';
end;

function TemPermissao(const AModulo, ATela, AAcao: string): Boolean;
var
  LConexao: TConexao;
  LSessao: TSessao;
  LQuery: TSQLQuery;
  LColuna: string;
begin
  Result := False;

  LSessao := TSessao.GetInstance;
  if LSessao.Administrador then
    Exit(True);

  LColuna := ColunaDaAcao(UpCase(Trim(AAcao)));
  if LColuna = '' then
    Exit(False);

  if LSessao.GrupoId <= 0 then
    Exit(False);

  try
    LConexao := TConexao.GetInstance;
    if (LConexao = nil) or (not LConexao.Conectado) then
      Exit(False);

    LQuery := TSQLQuery.Create(nil);
    try
      LQuery.DataBase := LConexao.Connection;
      LQuery.Transaction := LConexao.Transaction;
      LQuery.SQL.Text :=
        'SELECT ' + LColuna + ' AS PERMITIDO FROM PERMISSAO ' +
        'WHERE GRUPO_ID = :GRP AND UPPER(MODULO) = :MOD AND UPPER(TELA) = :TELA';
      LQuery.ParamByName('GRP').AsLargeInt := LSessao.GrupoId;
      LQuery.ParamByName('MOD').AsString := UpperCase(Trim(AModulo));
      LQuery.ParamByName('TELA').AsString := UpperCase(Trim(ATela));
      LQuery.Open;
      if not LQuery.IsEmpty then
        Result := UpperCase(Trim(LQuery.FieldByName('PERMITIDO').AsString)) = 'S';
    finally
      LQuery.Free;
    end;
  except
    // Falha ao consultar permissão => nega o acesso
    Result := False;
  end;
end;

procedure VerificarPermissao(const AModulo, ATela, AAcao: string;
  const AMensagem: string);
begin
  if TemPermissao(AModulo, ATela, AAcao) then
    Exit;
  if AMensagem <> '' then
    raise EPermissaoNegada.Create(AMensagem);
  raise EPermissaoNegada.CreateFmt(
    'Seu usuário não tem permissão para %s neste módulo (%s/%s).',
    [LowerCase(AAcao), AModulo, ATela]);
end;

end.
