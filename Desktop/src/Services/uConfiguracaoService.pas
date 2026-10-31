unit uConfiguracaoService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Service da tela Sistema > Configurações
  ------------------------------------------------------------
  Edita a tabela CONFIGURACAO da empresa da sessão (CHAVE /
  VALOR / DESCRICAO) - as mesmas chaves que os módulos leem
  (PRODUCAO_TALAO_MODO, PRODUCAO_TALAO_LOTE, ...).

  Regras:
    - escopo da empresa como em TProducaoService.LerConfiguracao
      (EMPRESA_ID = sessão ou NULL);
    - uma única transação por gravação: INSERT/UPDATE/DELETE +
      auditoria (uAuditoria.RegistrarAuditoria) + COMMIT; qualquer
      falha => ROLLBACK e a exceção sobe para a tela;
    - a listagem devolve uma query que PERTENCE ao chamador (a tela
      cria a query e liga a conexão; o service só preenche).

  Suposição: chave vazia no cadastro = apagar a configuração e
  voltar ao padrão do sistema (mesmo significado de valor vazio
  do GravarChaveConfig da Produção).
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uConexao;

type
  TConfiguracaoService = class
  private
    FConexao: TConexao;
    function NovaConsulta: TSQLQuery;
  public
    constructor Create;

    { Preenche AQuery (criada e ligada à conexão pelo chamador) com as
      chaves da empresa da sessão. }
    procedure Carregar(AQuery: TSQLQuery; const AFiltro: string = '');

    { Cria ou atualiza a chave (com auditoria). }
    procedure Gravar(const AChave, AValor, ADescricao: string);

    { Apaga a chave pelo ID (com auditoria) - restaura o padrão. }
    procedure Excluir(AId: Int64);
  end;

implementation

uses
  uSessao, uAuditoria;

const
  TABELA = 'CONFIGURACAO';

constructor TConfiguracaoService.Create;
begin
  inherited Create;
  FConexao := TConexao.GetInstance;
end;

function TConfiguracaoService.NovaConsulta: TSQLQuery;
begin
  Result := TSQLQuery.Create(nil);
  Result.DataBase := FConexao.Connection;
  Result.Transaction := FConexao.Transaction;
end;

procedure TConfiguracaoService.Carregar(AQuery: TSQLQuery;
  const AFiltro: string);
var
  LTermo: string;
begin
  if AQuery = nil then
    raise Exception.Create('Carregar: query não informada.');

  LTermo := Trim(AFiltro);
  AQuery.Close;
  if LTermo = '' then
    AQuery.SQL.Text :=
      'SELECT ID, CHAVE, VALOR, DESCRICAO FROM CONFIGURACAO ' +
      'WHERE (EMPRESA_ID = :EMP OR EMPRESA_ID IS NULL) ' +
      'ORDER BY CHAVE'
  else
    AQuery.SQL.Text :=
      'SELECT ID, CHAVE, VALOR, DESCRICAO FROM CONFIGURACAO ' +
      'WHERE (EMPRESA_ID = :EMP OR EMPRESA_ID IS NULL) ' +
      'AND UPPER(CHAVE) CONTAINING :FILTRO ' +
      'ORDER BY CHAVE';

  AQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
  if LTermo <> '' then
    AQuery.ParamByName('FILTRO').AsString := UpperCase(LTermo);
  AQuery.Open;
end;

procedure TConfiguracaoService.Gravar(const AChave, AValor, ADescricao: string);
var
  LChave, LValor, LDesc: string;
  LQuery: TSQLQuery;
  LExiste: Boolean;
  LAnterior: string;
begin
  LChave := Trim(AChave);
  LValor := Trim(AValor);
  LDesc := Trim(ADescricao);

  if LChave = '' then
    raise Exception.Create('O campo Chave é obrigatório.');
  if Length(LChave) > 50 then
    raise Exception.Create('A Chave pode ter no máximo 50 caracteres.');
  if Length(LValor) > 255 then
    raise Exception.Create('O Valor pode ter no máximo 255 caracteres.');
  if Length(LDesc) > 255 then
    raise Exception.Create('A Descrição pode ter no máximo 255 caracteres.');

  FConexao.IniciarTransacao;
  LQuery := NovaConsulta;
  try
    try
      { valor anterior, para a auditoria registrar o que mudou }
      LQuery.SQL.Text :=
        'SELECT FIRST 1 VALOR FROM CONFIGURACAO ' +
        'WHERE CHAVE = :CHAVE AND (EMPRESA_ID = :EMP OR EMPRESA_ID IS NULL) ' +
        'ORDER BY EMPRESA_ID DESC';
      LQuery.ParamByName('CHAVE').AsString := LChave;
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.Open;
      if LQuery.IsEmpty then
        LAnterior := ''
      else
        LAnterior := Trim(LQuery.FieldByName('VALOR').AsString);
      LQuery.Close;

      if LValor = '' then
      begin
        { valor vazio = remover a chave e voltar ao padrão }
        LQuery.SQL.Text :=
          'DELETE FROM CONFIGURACAO ' +
          'WHERE CHAVE = :CHAVE AND (EMPRESA_ID = :EMP OR EMPRESA_ID IS NULL)';
        LQuery.ParamByName('CHAVE').AsString := LChave;
        LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
        LQuery.ExecSQL;
        RegistrarAuditoria(TABELA, 'ALTERACAO', 0,
          LChave + '=' + LAnterior, LChave + '=PADRAO');
      end
      else
      begin
        LQuery.SQL.Text :=
          'SELECT COUNT(*) AS QTD FROM CONFIGURACAO ' +
          'WHERE CHAVE = :CHAVE AND (EMPRESA_ID = :EMP OR EMPRESA_ID IS NULL)';
        LQuery.ParamByName('CHAVE').AsString := LChave;
        LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
        LQuery.Open;
        LExiste := LQuery.FieldByName('QTD').AsInteger > 0;
        LQuery.Close;

        if LExiste then
        begin
          LQuery.SQL.Text :=
            'UPDATE CONFIGURACAO SET VALOR = :VALOR, DESCRICAO = :DESCR ' +
            'WHERE CHAVE = :CHAVE AND (EMPRESA_ID = :EMP OR EMPRESA_ID IS NULL)';
          LQuery.ParamByName('VALOR').AsString := LValor;
          LQuery.ParamByName('DESCR').AsString := LDesc;
          LQuery.ParamByName('CHAVE').AsString := LChave;
          LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
          LQuery.ExecSQL;
        end
        else
        begin
          { ID vem da trigger TRG_CONFIGURACAO_BI (GEN_CONFIGURACAO_ID) }
          LQuery.SQL.Text :=
            'INSERT INTO CONFIGURACAO (EMPRESA_ID, CHAVE, VALOR, DESCRICAO) ' +
            'VALUES (:EMP, :CHAVE, :VALOR, :DESCR)';
          LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
          LQuery.ParamByName('CHAVE').AsString := LChave;
          LQuery.ParamByName('VALOR').AsString := LValor;
          LQuery.ParamByName('DESCR').AsString := LDesc;
          LQuery.ExecSQL;
        end;

        RegistrarAuditoria(TABELA, 'ALTERACAO', 0,
          LChave + '=' + LAnterior, LChave + '=' + LValor);
      end;

      FConexao.Confirmar;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TConfiguracaoService.Excluir(AId: Int64);
var
  LQuery: TSQLQuery;
  LChave, LValor: string;
begin
  if AId <= 0 then
    raise Exception.Create('Configuração: ID inválido.');

  FConexao.IniciarTransacao;
  LQuery := NovaConsulta;
  try
    try
      LQuery.SQL.Text :=
        'SELECT CHAVE, VALOR FROM CONFIGURACAO ' +
        'WHERE ID = :ID AND (EMPRESA_ID = :EMP OR EMPRESA_ID IS NULL)';
      LQuery.ParamByName('ID').AsLargeInt := AId;
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.Open;
      if LQuery.IsEmpty then
        raise Exception.Create('Configuração não encontrada.');
      LChave := Trim(LQuery.FieldByName('CHAVE').AsString);
      LValor := Trim(LQuery.FieldByName('VALOR').AsString);
      LQuery.Close;

      LQuery.SQL.Text :=
        'DELETE FROM CONFIGURACAO ' +
        'WHERE ID = :ID AND (EMPRESA_ID = :EMP OR EMPRESA_ID IS NULL)';
      LQuery.ParamByName('ID').AsLargeInt := AId;
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.ExecSQL;

      RegistrarAuditoria(TABELA, 'ALTERACAO', AId,
        LChave + '=' + LValor, LChave + '=PADRAO');

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
