unit uEstoqueService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Service de movimentação de estoque
  ------------------------------------------------------------
  Regras que antes estavam dentro de uFrmMovEstoque:

    - registro de movimento: produto existente na empresa da sessão,
      tipo E (entrada), S (saída), A (ajuste) ou I (inventário),
      quantidade maior que zero e custo unitário não negativo;
      documento e observação respeitam o tamanho das colunas
      (50 e 255) e o usuário vem da sessão;
    - o saldo é atualizado pela trigger TRG_MOVEST_AI:
      E e A somam, S subtrai e I não altera a quantidade;
      quando o produto ainda não tem linha em ESTOQUE a trigger
      cria a linha;
    - listagem: período (dia inicial até o dia final, inclusive),
      tipo, pesquisa por descrição/código/documento e sempre no
      escopo da empresa da sessão. Antes a tela não filtrava
      empresa e o filtro de texto estourava "string right
      truncation" quando o texto passava do tamanho de CODIGO;
    - consulta de saldo do produto na empresa da sessão.

  Toda escrita abre e confirma a própria transação (mesmo padrão dos
  demais Services) e registra auditoria em LOG_SISTEMA.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uConexao;

type
  { TEstoqueService }
  TEstoqueService = class
  private
    FConexao: TConexao;

    procedure ValidarMovimento(AProdutoId: Int64; const ATipo: string;
      AQuantidade, ACustoUnitario: Double; const ADocumento,
      AObservacao: string);
    procedure ValidarTipo(const ATipo: string);
  public
    constructor Create;

    { Registra o movimento, deixa a trigger atualizar ESTOQUE e
      devolve o ID gerado. }
    function RegistrarMovimento(AProdutoId: Int64; const ATipo: string;
      AQuantidade, ACustoUnitario: Double; const ADocumento: string = '';
      const AObservacao: string = ''): Int64;

    { Preenche AQuery com os movimentos do período. ATipo: '' = todos,
      'E' = entradas, 'S' = saídas, 'A' = ajustes, 'I' = inventário.
      AFiltro pesquisa descrição, código e documento. }
    procedure CarregarMovimentos(AQuery: TSQLQuery;
      ADataInicio, ADataFim: TDateTime;
      const ATipo: string = ''; const AFiltro: string = '');

    { Saldo atual do produto na empresa da sessão (0 quando não há
      linha em ESTOQUE). }
    function SaldoProduto(AProdutoId: Int64): Double;
  end;

implementation

uses
  uSessao, uAuditoria;

const
  { MOVIMENTO_ESTOQUE.DOCUMENTO e OBSERVACAO têm 50 e 255 caracteres. }
  TAMANHO_DOCUMENTO = 50;
  TAMANHO_OBSERVACAO = 255;
  { O CAST do parâmetro evita "string right truncation" quando o texto
    digitado é maior que CODIGO (30) ou DOCUMENTO (50). }
  SQL_FILTRO_TEXTO = 'VARCHAR(1000)';

constructor TEstoqueService.Create;
begin
  inherited Create;
  FConexao := TConexao.GetInstance;
end;

procedure TEstoqueService.ValidarTipo(const ATipo: string);
begin
  if not (ATipo = 'E') and not (ATipo = 'S') and not (ATipo = 'A') and
    not (ATipo = 'I') then
    raise Exception.Create(
      'Tipo de movimentação inválido (use E, S, A ou I).');
end;

procedure TEstoqueService.ValidarMovimento(AProdutoId: Int64;
  const ATipo: string; AQuantidade, ACustoUnitario: Double;
  const ADocumento, AObservacao: string);
begin
  if AProdutoId <= 0 then
    raise Exception.Create('Selecione um produto para a movimentação.');
  ValidarTipo(ATipo);
  if AQuantidade <= 0 then
    raise Exception.Create('A quantidade deve ser maior que zero.');
  if ACustoUnitario < 0 then
    raise Exception.Create('O custo unitário não pode ser negativo.');
  if Length(ADocumento) > TAMANHO_DOCUMENTO then
    raise Exception.CreateFmt('O documento deve ter no máximo %d caracteres.',
      [TAMANHO_DOCUMENTO]);
  if Length(AObservacao) > TAMANHO_OBSERVACAO then
    raise Exception.CreateFmt('A observação deve ter no máximo %d caracteres.',
      [TAMANHO_OBSERVACAO]);
end;

function TEstoqueService.RegistrarMovimento(AProdutoId: Int64;
  const ATipo: string; AQuantidade, ACustoUnitario: Double;
  const ADocumento, AObservacao: string): Int64;
var
  LQuery: TSQLQuery;
begin
  ValidarMovimento(AProdutoId, ATipo, AQuantidade, ACustoUnitario,
    ADocumento, AObservacao);

  FConexao.IniciarTransacao;
  LQuery := TSQLQuery.Create(nil);
  try
    try
      LQuery.DataBase := FConexao.Connection;
      LQuery.Transaction := FConexao.Transaction;

      { o produto precisa existir na empresa da sessão: a trigger
        TRG_MOVEST_AI atualiza ESTOQUE pela empresa do movimento }
      LQuery.SQL.Text :=
        'SELECT FIRST 1 ID FROM PRODUTO ' +
        'WHERE ID = :ID AND EMPRESA_ID = :EMP';
      LQuery.ParamByName('ID').AsLargeInt := AProdutoId;
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.Open;
      if LQuery.IsEmpty then
        raise Exception.Create('Produto não encontrado.');
      LQuery.Close;

      LQuery.SQL.Text :=
        'INSERT INTO MOVIMENTO_ESTOQUE (EMPRESA_ID, PRODUTO_ID, TIPO, ' +
        '  QUANTIDADE, CUSTO_UNITARIO, DOCUMENTO, OBSERVACAO, USUARIO_ID) ' +
        'VALUES (:EMP, :PROD, :TIPO, :QTD, :CUSTO, :DOC, :OBS, :USR) ' +
        'RETURNING ID';
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
      LQuery.ParamByName('TIPO').AsString := ATipo;
      LQuery.ParamByName('QTD').AsFloat := AQuantidade;
      LQuery.ParamByName('CUSTO').AsFloat := ACustoUnitario;
      LQuery.ParamByName('DOC').AsString := Trim(ADocumento);
      LQuery.ParamByName('OBS').AsString := Trim(AObservacao);
      LQuery.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
      LQuery.Open;
      Result := LQuery.FieldByName('ID').AsLargeInt;
      LQuery.Close;

      RegistrarAuditoriaSegura('MOVIMENTO_ESTOQUE', 'INSERT', Result, '',
        ResumoAuditoria([
          'PRODUTO_ID=' + IntToStr(AProdutoId),
          'TIPO=' + ATipo,
          'QUANTIDADE=' + FloatToStr(AQuantidade),
          'CUSTO_UNITARIO=' + FloatToStr(ACustoUnitario),
          'DOCUMENTO=' + Trim(ADocumento)]));

      FConexao.Confirmar;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TEstoqueService.CarregarMovimentos(AQuery: TSQLQuery;
  ADataInicio, ADataFim: TDateTime; const ATipo, AFiltro: string);
var
  LSQL: string;
begin
  if AQuery = nil then
    raise Exception.Create('CarregarMovimentos: query não informada.');
  if ADataFim < ADataInicio then
    raise Exception.Create('A data final não pode ser anterior à inicial.');
  if Trim(ATipo) <> '' then
    ValidarTipo(Trim(ATipo));

  LSQL :=
    'SELECT ME.ID, P.DESCRICAO AS PRODUTO, P.CODIGO, ' +
    'CASE ME.TIPO WHEN ''E'' THEN ''Entrada'' WHEN ''S'' THEN ''Saída'' ' +
    'WHEN ''A'' THEN ''Ajuste'' WHEN ''I'' THEN ''Inventário'' END AS TIPO_DESC, ' +
    'ME.TIPO, ME.QUANTIDADE, ME.CUSTO_UNITARIO, ME.DOCUMENTO, ' +
    'ME.OBSERVACAO, ME.DATA_MOVIMENTO ' +
    'FROM MOVIMENTO_ESTOQUE ME ' +
    'JOIN PRODUTO P ON P.ID = ME.PRODUTO_ID ' +
    'WHERE ME.EMPRESA_ID = :EMP ' +
    '  AND ME.DATA_MOVIMENTO >= :DI ' +
    '  AND ME.DATA_MOVIMENTO < :DF';

  if Trim(ATipo) <> '' then
    LSQL := LSQL + ' AND ME.TIPO = :TIPO';

  if Trim(AFiltro) <> '' then
    LSQL := LSQL + ' AND (UPPER(P.DESCRICAO) ' +
      'CONTAINING UPPER(CAST(:PESQ AS ' + SQL_FILTRO_TEXTO + '))' +
      ' OR UPPER(P.CODIGO) ' +
      'CONTAINING UPPER(CAST(:PESQ2 AS ' + SQL_FILTRO_TEXTO + '))' +
      ' OR UPPER(COALESCE(ME.DOCUMENTO, '''')) ' +
      'CONTAINING UPPER(CAST(:PESQ3 AS ' + SQL_FILTRO_TEXTO + ')))';

  LSQL := LSQL + ' ORDER BY ME.DATA_MOVIMENTO DESC, ME.ID DESC';

  AQuery.Close;
  AQuery.SQL.Text := LSQL;
  AQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
  { o dia final entra inteiro: do início do primeiro dia até o
    início do dia seguinte }
  AQuery.ParamByName('DI').AsDate := Trunc(ADataInicio);
  AQuery.ParamByName('DF').AsDate := Trunc(ADataFim) + 1;
  if Trim(ATipo) <> '' then
    AQuery.ParamByName('TIPO').AsString := Trim(ATipo);
  if Trim(AFiltro) <> '' then
  begin
    AQuery.ParamByName('PESQ').AsString := Trim(AFiltro);
    AQuery.ParamByName('PESQ2').AsString := Trim(AFiltro);
    AQuery.ParamByName('PESQ3').AsString := Trim(AFiltro);
  end;
  AQuery.Open;
end;

function TEstoqueService.SaldoProduto(AProdutoId: Int64): Double;
var
  LQuery: TSQLQuery;
begin
  if AProdutoId <= 0 then
    raise Exception.Create('SaldoProduto: produto inválido.');

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    { O CAST tipa o retorno do SUM: sem ele o SQLDB entrega o campo
      como ftUnknown e AsFloat volta 0 (mesma lição do saldo do caixa). }
    LQuery.SQL.Text :=
      'SELECT CAST(COALESCE(SUM(QUANTIDADE), 0) AS NUMERIC(15,4)) AS SALDO ' +
      'FROM ESTOQUE WHERE EMPRESA_ID = :EMP AND PRODUTO_ID = :PROD';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
    LQuery.Open;
    Result := LQuery.FieldByName('SALDO').AsFloat;
  finally
    LQuery.Free;
  end;
end;

end.
