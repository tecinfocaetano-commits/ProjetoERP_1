unit uPermissaoService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Service da tela Sistema > Permissões
  ------------------------------------------------------------
  Editor da matriz PERMISSAO (GRUPO_ID x MODULO x TELA e as
  colunas PODE_*). A leitura em tempo de execução continua sendo
  a de uPermissao.TemPermissao (fail-closed: sem linha = negado);
  aqui só se cadastra quem pode o quê.

  Regras:
    - chave de negócio = (GRUPO_ID, MODULO, TELA) comparada em
      MAIÚSCULAS, igual à consulta de uPermissao.TemPermissao;
    - Gravar faz UPSERT: atualiza a linha existente ou cria a
      nova (trigger TRG_PERMISSAO_BI gera o ID);
    - uma transação por gravação com auditoria no mesmo caminho
      único (uAuditoria.RegistrarAuditoria).

  Suposição: os módulos/ telas são texto livre em maiúsculas
  (PRODUCAO/MAPA_PRODUCAO, SISTEMA/CONFIGURACOES, ...) - o seed
  novo vem em Banco\013_telas_administracao.sql.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uConexao;

type
  TPermissaoService = class
  private
    FConexao: TConexao;
    function NovaConsulta: TSQLQuery;
    function Normalizar(const ATexto: string; const ACampo: string): string;
  public
    constructor Create;

    { Preenche AQuery (do chamador) com os grupos ativos. }
    procedure CarregarGrupos(AQuery: TSQLQuery);

    { Preenche AQuery (do chamador) com as permissões do grupo. }
    procedure CarregarPermissoes(AQuery: TSQLQuery; AGrupoId: Int64);

    { Upsert de uma linha da matriz. Devolve True quando criou linha nova. }
    function Gravar(AGrupoId: Int64; const AModulo, ATela: string;
      AVisualizar, AInserir, AEditar, AExcluir, AImprimir: Boolean): Boolean;

    { Remove a linha de permissão (com auditoria). }
    procedure Excluir(AId: Int64);
  end;

implementation

uses
  uAuditoria;

const
  TABELA = 'PERMISSAO';

constructor TPermissaoService.Create;
begin
  inherited Create;
  FConexao := TConexao.GetInstance;
end;

function TPermissaoService.NovaConsulta: TSQLQuery;
begin
  Result := TSQLQuery.Create(nil);
  Result.DataBase := FConexao.Connection;
  Result.Transaction := FConexao.Transaction;
end;

function TPermissaoService.Normalizar(const ATexto: string;
  const ACampo: string): string;
begin
  Result := UpperCase(Trim(ATexto));
  if Result = '' then
    raise Exception.CreateFmt('O campo %s é obrigatório.', [ACampo]);
  if Length(Result) > 50 then
    raise Exception.CreateFmt('O campo %s pode ter no máximo 50 caracteres.',
      [ACampo]);
end;

procedure TPermissaoService.CarregarGrupos(AQuery: TSQLQuery);
begin
  if AQuery = nil then
    raise Exception.Create('CarregarGrupos: query não informada.');
  AQuery.Close;
  AQuery.SQL.Text :=
    'SELECT ID, NOME FROM GRUPO WHERE ATIVO = ''A'' ORDER BY NOME';
  AQuery.Open;
end;

procedure TPermissaoService.CarregarPermissoes(AQuery: TSQLQuery;
  AGrupoId: Int64);
begin
  if AQuery = nil then
    raise Exception.Create('CarregarPermissoes: query não informada.');
  if AGrupoId <= 0 then
    raise Exception.Create('Grupo inválido.');

  AQuery.Close;
  AQuery.SQL.Text :=
    'SELECT ID, MODULO, TELA, PODE_VISUALIZAR, PODE_INSERIR, ' +
    'PODE_EDITAR, PODE_EXCLUIR, PODE_IMPRIMIR FROM PERMISSAO ' +
    'WHERE GRUPO_ID = :GRP ORDER BY MODULO, TELA';
  AQuery.ParamByName('GRP').AsLargeInt := AGrupoId;
  AQuery.Open;
end;

function TPermissaoService.Gravar(AGrupoId: Int64;
  const AModulo, ATela: string; AVisualizar, AInserir, AEditar,
  AExcluir, AImprimir: Boolean): Boolean;
var
  LModulo, LTela: string;
  LQuery: TSQLQuery;
  LId: Int64;
  LAnterior, LNovo: string;
  function Marcador(AValor: Boolean): string;
  begin
    if AValor then
      Result := 'S'
    else
      Result := 'N';
  end;
begin
  if AGrupoId <= 0 then
    raise Exception.Create('Grupo inválido.');
  LModulo := Normalizar(AModulo, 'Módulo');
  LTela := Normalizar(ATela, 'Tela');

  FConexao.IniciarTransacao;
  LQuery := NovaConsulta;
  try
    try
      { a linha já existe? comparação igual à de uPermissao.TemPermissao }
      LQuery.SQL.Text :=
        'SELECT ID, PODE_VISUALIZAR, PODE_INSERIR, PODE_EDITAR, ' +
        'PODE_EXCLUIR, PODE_IMPRIMIR FROM PERMISSAO ' +
        'WHERE GRUPO_ID = :GRP AND UPPER(MODULO) = :MOD AND UPPER(TELA) = :TELA';
      LQuery.ParamByName('GRP').AsLargeInt := AGrupoId;
      LQuery.ParamByName('MOD').AsString := LModulo;
      LQuery.ParamByName('TELA').AsString := LTela;
      LQuery.Open;

      LId := 0;
      LAnterior := '';
      if not LQuery.IsEmpty then
      begin
        LId := LQuery.FieldByName('ID').AsLargeInt;
        LAnterior :=
          'VIS=' + Trim(LQuery.FieldByName('PODE_VISUALIZAR').AsString) +
          ' INS=' + Trim(LQuery.FieldByName('PODE_INSERIR').AsString) +
          ' EDT=' + Trim(LQuery.FieldByName('PODE_EDITAR').AsString) +
          ' EXC=' + Trim(LQuery.FieldByName('PODE_EXCLUIR').AsString) +
          ' IMP=' + Trim(LQuery.FieldByName('PODE_IMPRIMIR').AsString);
      end;
      LQuery.Close;

      LNovo :=
        'VIS=' + Marcador(AVisualizar) +
        ' INS=' + Marcador(AInserir) +
        ' EDT=' + Marcador(AEditar) +
        ' EXC=' + Marcador(AExcluir) +
        ' IMP=' + Marcador(AImprimir);

      Result := LId = 0;

      if LId > 0 then
      begin
        LQuery.SQL.Text :=
          'UPDATE PERMISSAO SET PODE_VISUALIZAR = :V, PODE_INSERIR = :I, ' +
          'PODE_EDITAR = :E, PODE_EXCLUIR = :X, PODE_IMPRIMIR = :P ' +
          'WHERE ID = :ID';
        LQuery.ParamByName('V').AsString := Marcador(AVisualizar);
        LQuery.ParamByName('I').AsString := Marcador(AInserir);
        LQuery.ParamByName('E').AsString := Marcador(AEditar);
        LQuery.ParamByName('X').AsString := Marcador(AExcluir);
        LQuery.ParamByName('P').AsString := Marcador(AImprimir);
        LQuery.ParamByName('ID').AsLargeInt := LId;
        LQuery.ExecSQL;
      end
      else
      begin
        LQuery.SQL.Text :=
          'INSERT INTO PERMISSAO (GRUPO_ID, MODULO, TELA, PODE_VISUALIZAR, ' +
          'PODE_INSERIR, PODE_EDITAR, PODE_EXCLUIR, PODE_IMPRIMIR) ' +
          'VALUES (:GRP, :MOD, :TELA, :V, :I, :E, :X, :P)';
        LQuery.ParamByName('GRP').AsLargeInt := AGrupoId;
        LQuery.ParamByName('MOD').AsString := LModulo;
        LQuery.ParamByName('TELA').AsString := LTela;
        LQuery.ParamByName('V').AsString := Marcador(AVisualizar);
        LQuery.ParamByName('I').AsString := Marcador(AInserir);
        LQuery.ParamByName('E').AsString := Marcador(AEditar);
        LQuery.ParamByName('X').AsString := Marcador(AExcluir);
        LQuery.ParamByName('P').AsString := Marcador(AImprimir);
        LQuery.ExecSQL;

        { ID da linha recém-criada (para a auditoria registrar o registro) }
        LQuery.SQL.Text :=
          'SELECT FIRST 1 ID FROM PERMISSAO ' +
          'WHERE GRUPO_ID = :GRP AND UPPER(MODULO) = :MOD AND UPPER(TELA) = :TELA';
        LQuery.ParamByName('GRP').AsLargeInt := AGrupoId;
        LQuery.ParamByName('MOD').AsString := LModulo;
        LQuery.ParamByName('TELA').AsString := LTela;
        LQuery.Open;
        if not LQuery.IsEmpty then
          LId := LQuery.FieldByName('ID').AsLargeInt;
        LQuery.Close;
      end;

      if LAnterior = '' then
        LAnterior := '(linha nova) ' + LModulo + '/' + LTela;

      RegistrarAuditoria(TABELA, 'ALTERACAO', LId,
        LAnterior, LModulo + '/' + LTela + ' ' + LNovo);

      FConexao.Confirmar;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TPermissaoService.Excluir(AId: Int64);
var
  LQuery: TSQLQuery;
  LModulo, LTela: string;
begin
  if AId <= 0 then
    raise Exception.Create('Permissão: ID inválido.');

  FConexao.IniciarTransacao;
  LQuery := NovaConsulta;
  try
    try
      LQuery.SQL.Text :=
        'SELECT MODULO, TELA FROM PERMISSAO WHERE ID = :ID';
      LQuery.ParamByName('ID').AsLargeInt := AId;
      LQuery.Open;
      if LQuery.IsEmpty then
        raise Exception.Create('Permissão não encontrada.');
      LModulo := Trim(LQuery.FieldByName('MODULO').AsString);
      LTela := Trim(LQuery.FieldByName('TELA').AsString);
      LQuery.Close;

      LQuery.SQL.Text := 'DELETE FROM PERMISSAO WHERE ID = :ID';
      LQuery.ParamByName('ID').AsLargeInt := AId;
      LQuery.ExecSQL;

      RegistrarAuditoria(TABELA, 'EXCLUSAO', AId,
        LModulo + '/' + LTela, '(linha removida)');

      FConexao.Confirmar;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

end.
