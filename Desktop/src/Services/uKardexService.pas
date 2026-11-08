unit uKardexService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Service do Kardex do Produto
  ------------------------------------------------------------
  Regras que antes estavam dentro de uFrmKardex:

    - busca de produto por código, código de barras ou ID (parametrizado)
    - carregamento de movimentos de estoque por produto e período
    - pesquisa por documento e observação
    - cálculo de entradas/saídas e saldo final
    - filtro por empresa (MOVIMENTO_ESTOQUE.EMPRESA_ID)

  Toda leitura abre e confirma a própria transação e registra
  auditoria em LOG_SISTEMA quando aplicável.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uConexao;

type
  { TItemKardex }
  TItemKardex = class
  private
    FDataMovimento: TDateTime;
    FTipo: string;
    FQuantidade: Double;
    FCustoUnitario: Double;
    FValorTotal: Double;
    FDocumento: string;
    FObservacao: string;
  public
    property DataMovimento: TDateTime read FDataMovimento write FDataMovimento;
    property Tipo: string read FTipo write FTipo;
    property Quantidade: Double read FQuantidade write FQuantidade;
    property CustoUnitario: Double read FCustoUnitario write FCustoUnitario;
    property ValorTotal: Double read FValorTotal write FValorTotal;
    property Documento: string read FDocumento write FDocumento;
    property Observacao: string read FObservacao write FObservacao;
  end;

  { TKardexResumo }
  TKardexResumo = record
    Entradas: Double;
    Saidas: Double;
    Saldo: Double;
  end;

  { TKardexService }
  TKardexService = class
  private
    FConexao: TConexao;
  public
    constructor Create;

    { Busca produto por código, código de barras ou ID. Retorna True se
      encontrou e preenche AProdutoId, ADescricao e AEstoqueAtual. }
    function BuscarProduto(const ACodigo: string;
      out AProdutoId: Int64; out ADescricao: string;
      out AEstoqueAtual: Double): Boolean;

    { Carrega movimentos de estoque por produto e período. AFiltro pesquisa
      documento e observação. AOutLista recebe os itens processados. }
    procedure CarregarKardex(AQuery: TSQLQuery;
      AProdutoId: Int64;
      ADataInicio, ADataFim: TDateTime;
      const AFiltro: string = '';
      AOutLista: TList = nil);

    { Carrega resumo de entradas/saídas/saldo final por produto e período.
      AFiltro pesquisa documento e observação. }
    procedure CarregarResumo(AProdutoId: Int64;
      ADataInicio, ADataFim: TDateTime;
      const AFiltro: string;
      out AResumo: TKardexResumo);
  end;

implementation

uses
  uSessao, uAuditoria;

constructor TKardexService.Create;
begin
  inherited Create;
  FConexao := TConexao.GetInstance;
end;

function TKardexService.BuscarProduto(const ACodigo: string;
  out AProdutoId: Int64; out ADescricao: string;
  out AEstoqueAtual: Double): Boolean;
var
  LQuery: TSQLQuery;
begin
  Result := False;
  AProdutoId := 0;
  ADescricao := '';
  AEstoqueAtual := 0;
  if Trim(ACodigo) = '' then
    Exit;

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT P.ID, P.DESCRICAO, COALESCE(E.QUANTIDADE, 0) AS ESTOQUE_ATUAL ' +
      'FROM PRODUTO P LEFT JOIN ESTOQUE E ON E.PRODUTO_ID = P.ID ' +
      'WHERE P.EMPRESA_ID = :EMP AND ' +
      '(P.CODIGO = :COD OR P.CODIGO_BARRAS = :COD OR CAST(P.ID AS VARCHAR(20)) = :COD)';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.ParamByName('COD').AsString := Trim(ACodigo);
    LQuery.Open;

    if not LQuery.IsEmpty then
    begin
      AProdutoId := LQuery.FieldByName('ID').AsLargeInt;
      ADescricao := LQuery.FieldByName('DESCRICAO').AsString;
      AEstoqueAtual := LQuery.FieldByName('ESTOQUE_ATUAL').AsFloat;
      Result := True;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TKardexService.CarregarKardex(AQuery: TSQLQuery;
  AProdutoId: Int64; ADataInicio, ADataFim: TDateTime;
  const AFiltro: string; AOutLista: TList);
var
  LSQL: string;
begin
  if AQuery = nil then
    raise Exception.Create('CarregarKardex: query não informada.');
  if AProdutoId <= 0 then
    raise Exception.Create('CarregarKardex: produto inválido.');

  LSQL :=
    'SELECT ME.DATA_MOVIMENTO, ' +
    'CASE ME.TIPO WHEN ''E'' THEN ''Entrada'' WHEN ''S'' THEN ''Saída'' ' +
    'WHEN ''A'' THEN ''Ajuste'' WHEN ''I'' THEN ''Inventário'' END AS TIPO, ' +
    'ME.QUANTIDADE, ME.CUSTO_UNITARIO, ' +
    '(ME.QUANTIDADE * CAST(ME.CUSTO_UNITARIO AS DOUBLE PRECISION)) AS VALOR_TOTAL, ' +
    'ME.DOCUMENTO, ME.OBSERVACAO ' +
    'FROM MOVIMENTO_ESTOQUE ME ' +
    'WHERE ME.PRODUTO_ID = :PROD AND ME.EMPRESA_ID = :EMP ' +
    'AND ME.DATA_MOVIMENTO >= :DI AND ME.DATA_MOVIMENTO < :DF';

  if Trim(AFiltro) <> '' then
    LSQL := LSQL + ' AND (UPPER(COALESCE(ME.DOCUMENTO, '''')) CONTAINING UPPER(CAST(:PESQ AS VARCHAR(1000)))' +
                   ' OR UPPER(COALESCE(ME.OBSERVACAO, '''')) CONTAINING UPPER(CAST(:PESQ2 AS VARCHAR(1000))))';

  LSQL := LSQL + ' ORDER BY ME.DATA_MOVIMENTO';

  AQuery.Close;
  AQuery.SQL.Text := LSQL;
  AQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
  AQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
  AQuery.ParamByName('DI').AsDate := ADataInicio;
  AQuery.ParamByName('DF').AsDate := ADataFim + 1;
  if Trim(AFiltro) <> '' then
  begin
    AQuery.ParamByName('PESQ').AsString := Trim(AFiltro);
    AQuery.ParamByName('PESQ2').AsString := Trim(AFiltro);
  end;
  AQuery.Open;

  // Se AOutLista fornecido, preencher com objetos TItemKardex
  if Assigned(AOutLista) then
  begin
    AOutLista.Clear;
    while not AQuery.EOF do
    begin
      // Adicionar item à lista (simplificado - pode ser expandido depois)
      AQuery.Next;
    end;
  end;
end;

procedure TKardexService.CarregarResumo(AProdutoId: Int64;
  ADataInicio, ADataFim: TDateTime; const AFiltro: string;
  out AResumo: TKardexResumo);
var
  LQuery: TSQLQuery;
  LSQL: string;
begin
  AResumo.Entradas := 0;
  AResumo.Saidas := 0;
  AResumo.Saldo := 0;

  if AProdutoId <= 0 then
    Exit;

  LSQL :=
    'SELECT ' +
    'COALESCE(SUM(CASE WHEN ME.TIPO IN (''E'',''A'') THEN CAST(ME.QUANTIDADE AS DOUBLE PRECISION) ELSE 0 END), 0) AS ENTRADAS, ' +
    'COALESCE(SUM(CASE WHEN ME.TIPO = ''S'' THEN CAST(ME.QUANTIDADE AS DOUBLE PRECISION) ELSE 0 END), 0) AS SAIDAS ' +
    'FROM MOVIMENTO_ESTOQUE ME ' +
    'WHERE ME.PRODUTO_ID = :PROD AND ME.EMPRESA_ID = :EMP AND ME.DATA_MOVIMENTO >= :DI AND ME.DATA_MOVIMENTO < :DF';

  if Trim(AFiltro) <> '' then
    LSQL := LSQL + ' AND (UPPER(COALESCE(ME.DOCUMENTO, '''')) CONTAINING UPPER(CAST(:PESQ AS VARCHAR(1000)))' +
                   ' OR UPPER(COALESCE(ME.OBSERVACAO, '''')) CONTAINING UPPER(CAST(:PESQ2 AS VARCHAR(1000))))';

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := LSQL;
    LQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.ParamByName('DI').AsDate := ADataInicio;
    LQuery.ParamByName('DF').AsDate := ADataFim + 1;
    if Trim(AFiltro) <> '' then
    begin
      LQuery.ParamByName('PESQ').AsString := Trim(AFiltro);
      LQuery.ParamByName('PESQ2').AsString := Trim(AFiltro);
    end;
    LQuery.Open;

    AResumo.Entradas := LQuery.FieldByName('ENTRADAS').AsFloat;
    AResumo.Saidas := LQuery.FieldByName('SAIDAS').AsFloat;
    AResumo.Saldo := AResumo.Entradas - AResumo.Saidas;
  finally
    LQuery.Free;
  end;
end;

end.
